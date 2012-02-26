
{EventEmitter} = require 'events'
Client = require './client'

module.exports = class OOClient extends Client
  @createClient: (options, cb) ->
    c = new OOClient options
    c.on 'connect', cb if cb
    return c

  box: (name, sep, flags) ->
    new Mailbox @, name, sep, flags

  boxes: (name, pat, subs, cb) ->
    if not cb
      cb = subs
      subs = null

    handler = (err, boxes) =>
      results = {}
      if not err
        for b in boxes
          results[b.mailbox] = new Mailbox @, b.mailbox, b.char, b.flags
      cb err, results

    if subs
      @lsub name, pat, handler
    else
      @list name, pat, handler

# emit select, unselect, delete
class Mailbox extends EventEmitter
  constructor: (@client, @name, @sep, @flags) ->
    @autoexpunge = false
    @selected = false

    @client.on 'unselect', =>
      @selected = false
      @emit 'unselect'
    @on 'select', =>
      @selected = true

  select: (cb) ->
    return process.nextTick cb if @selected
    @client.emit 'unselect'
    @client.select @name, (err, info) =>
      {@flags, @exist, @recent, @unseen, @permanentflags, @uidnext, @uidvalidity} = info
      @emit 'select' if not err
      cb err

  rename: (name, cb) ->
    return process.nextTick cb if name == @name

    @client.rename @name, name, (err) ->
      @name = name if not err
      cb err

  delete: (cb) ->
    @client.delete @name, name, (err) ->
      @emit 'delete' if not err
      cb err

  update: (cb) ->
    if @selected
      @client.noop (err, _, resp) =>
        @flags = resp.flags if resp.flags?
        @exists = resp.exists if resp.exists?
        @recent = resp.recent if resp.recent?
        # Need to check OK on these?
        @unseen = resp.state['UNSEEN']?.value if resp.state['UNSEEN']?
        @permanentflags = resp.state['PERMANENTFLAGS']?.value if resp.state['PERMANENTFLAGS']?
        @uidnext = resp.state['UIDNEXT']?.value if resp.state['UIDNEXT']?
        @uidvalidity = resp.state['UIDVALIDITY']?.value if resp.state['UIDVALIDITY']?
    else
      atts = ['messages', 'recent', 'uidnext', 'uidvalidity', 'unseen']
      @client.status @name, atts, (err, vals) =>
        {@recent, @uidnext, @uidvalidity, @unseen} = vals
        @exists = vals.messages

  expunge: (cb) -> @client.expunge @name, cb
  sub: (cb) -> @client.subscribe @name, cb
  unsub: (cb) -> @client.subscribe @name, cb

  search: (criteria, cb) ->
    @client.search criteria, true, (err, ids) =>
      cb err, new MessageSet @client, ids

  range: (start, end, cb) ->
    if typeof end == 'function'
      cb = end
      end = '*'
    @client.search "#{start}:#{end}", true, (err, ids, resp) =>
      cb err, if ids then new MessageSet @client, ids

  load: (uid, cb) ->
    cb null, new Message @client, uid

class MessageSet extends EventEmitter
  constructor: (@client, @sequence) ->
    @loaded = false

  setflags: (flags, cb) -> @client.store @sequence, 'set', flags, true, cb
  addflags: (flags, cb) -> @client.store @sequence, 'add', flags, true, cb
  delflags: (flags, cb) -> @client.store @sequence, 'del', flags, true, cb
  copyTo: (mailbox, cb) -> @client.copy @sequence, mailbox, true, cb

  search: (criteria, cb) ->
    criteria + ' UID ' + @sequence
    @client.search criteria, (err, ids) =>
      cb err, new MessageSet @client, ids

  load: (cb) ->
    return cb null if @loaded

    @client.fetch @sequence, 'ENVELOPE FLAGS INTERNALDATE UID', true, (err, msgs) =>
      @loaded = true
      max = 0
      console.log msgs
      for own k, msg of msgs
        k = parseInt k, 10
        m = new Message @client
        m._setMsg msg
        @[k] = m
        max = k if k > max
      @length = max
      cb err

class Message extends EventEmitter
  constructor: (@client, uid) ->
    @uid = uid if uid?
    @loaded = false

  _setMsg: (msg) ->
    {
      @uid, @flags, @internaldate,
      envelope: {
        @date, @subject, @from, @sender, 'reply-to':@['reply-to']
        @to, @cc, @bcc, 'in-reply-to': @['in-reply-to'], 'message-id':@['message-id']
      }
    } = msg

  setflags: (flags, cb) -> @client.store @uid, 'set', flags, true, cb
  addflags: (flags, cb) -> @client.store @uid, 'add', flags, true, cb
  delflags: (flags, cb) -> @client.store @uid, 'del', flags, true, cb
  copyTo: (mailbox, cb) -> @client.copy @uid, mailbox, true, cb

  load: (cb) ->
    return cb new Error "Cannot load message data with no UID" if not @uid?
    return cb null if @loaded
    @loaded = true

    @client.fetch @uid, 'ENVELOPE FLAGS INTERNALDATE UID', true, (err, msgs) =>
      @_setMsg msgs[@uid] if msgs[@uid]?
      cb err

  structure: (cb) ->
    return cb new Error "Cannot load message structure with no UID" if not @uid?

    @client.fetch @uid, 'BODYSTRUCTURE', true, (err, msgs) =>
      for own id, msg of msgs when msg.uid == @uid
        @structure = msg.bodystructure
      @structure ?= {}
      @sections = @_processSections(@structure) || {}
      cb err

  _processSections: (structure) ->
    if Array.isArray structure.body
      result = {}
      for data, i in structure.body
        k = i+1
        data = @_processSections data
        if data['']
          result[k] = data['']
        else if data.body
          result[k] = data.body
        else
          for j, body of data
            result["#{k}.#{j}"] = body
      return result
    else
      return {'': structure}

  _getSection: (it, cb) ->
    handler = (err) =>
      # console.log require('util').inspect @sections, false, 20, true
      cb err, (s for s, data of @sections when it data)
    if not @sections
      @structure handler
    else
      handler()

  attachments: (cb) ->
    handler = (err) =>
      all = for s, data of @sections when data.ext?.dsp?.name == 'attachment'
        section: s
        filename: (n.value for n in data.body.fields.param when n.key == 'name')[0]
        encoding: data.body.fields.enc
        size: data.body.fields.octets
        type: data.body.type
        subtype: data.body.subtype
      cb err, all

    if not @sections
      @structure handler
    else
      handler()

  body: (fulltype, cb) ->
    return cb new Error "Cannot load a message with no UID" if not @uid?
    @_getSection (data) ->
      {type, subtype} = data.body
      return fulltype == "#{type}/#{subtype}"
    , (err, sections) =>
      return cb new Error "Body type not found" if not sections.length
      @_loadBody sections[0], cb

  attachment: (section, s, cb) ->
    @_loadBody section, s, cb

  _loadBody: (section, wstream, cb) ->
    if typeof wstream == 'function'
      cb = wstream
      wstream = null

    crit = 'BODY'
    section = 'TEXT' if section == ''
    crit += "[#{section}]" if section
    @client.fetch @uid, crit, true, (err, msgs) =>
      crit = crit.toLowerCase()
      for own id, msg of msgs when msg.uid == @uid
        if wstream
          if not err
            wstream.write msg[crit].value
          wstream.end()
          return cb err
        else
          return cb err, msg[crit].value

      wstream.end() if not wstream
      return


