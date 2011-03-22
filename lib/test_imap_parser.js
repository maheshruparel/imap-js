
var testCase = require('nodeunit').testCase;
var ImapParser = require('./imap_parser').ImapParser;
var p = new ImapParser();


function runner(str) {
  var b = new Buffer(str);

  return function() {
    return p.execute(b, 0, b.length);
  }
}


module.exports = testCase({
  setUp: function(callback) {
    p.reinitialize();
    callback();
  },

  response_data: {
    resp_cond_state: {
      cap: function(test) {
        test.doesNotThrow(runner("a001 OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE STARTTLS LOGINDISABLED] Dovecot ready.\r\n"));
        test.done();
      },
      badcharset: function(test) {
        test.doesNotThrow(function() {
          try {
            runner("a001 OK [BADCHARSET (OMG WHAT HAHAH)] OH YEAH\r\n")();
          }
          catch (e) {
            console.log(e);
          }
        });
        test.done();
      },
      badcharset_literal: function(test) {
        test.doesNotThrow(function() {
          try {
            runner("a001 OK [BADCHARSET ({5}\r\nABCDE \"BADSET\")] OH YEAH\r\n")();
          }
          catch (e) {
            console.log(e);
          }
        });
        test.done();
      },
 

      perm: function(test) {
        test.doesNotThrow(function() {
          try {
            runner("a001 OK [PERMANENTFLAGS (\\Answered \\* FLAG)] OH YEAH\r\n")();
          }
          catch (e) {
            console.log(e);
          }
        });
        test.done();
      },
      perm2: function(test) {
        test.doesNotThrow(function() {
          try {
            runner("a001 OK [PERMANENTFLAGS ()] OH YEAH\r\n")();
          }
          catch (e) {
            console.log(e);
          }
        });
        test.done();
      },
      unseen: function(test) {
        test.doesNotThrow(function() {
          try {
            runner("a001 OK [UNSEEN 10] OH YEAH\r\n")();
          }
          catch (e) {
            console.log(e);
          }
        });
        test.done();
      },


      bad : function(test) {
        test.doesNotThrow(runner('a001 BAD [READ-ONLY] Failure\r\n'));
        setTimeout( function() {
          test.done();
        }, 500);
      },
      ok : function(test) {
        test.doesNotThrow(runner('a001 OK Failure\r\n'));
        test.done();
      },
      no : function(test) {
        test.doesNotThrow(runner('a001 NO [ALERT] Failure\r\n'));
        test.done();
      },
      bye : function(test) {
        test.throws(runner('a001 BYE Failure\r\n'));
        test.done();
      },
      b : function(test) {
        test.throws(runner('a001 B Failure\r\n'));
        test.done();
      },
      random : function(test) {
        test.throws(runner('a001 hfbgfd Failure\r\n'));
        test.done();
      },
    },
    resp_cond_bye: {
      correct: function(test) {
        test.doesNotThrow(function() {
          runner('* BYE misc test\r\n')();
        });
        test.done();
      },
      wrong: function(test) {
        test.throws(runner('* BYE\r\n'));
        test.done();
      },
    }
  },

  /*
  continue_req: {
    resp_text: {
      no_code: function(test) {
        test.doesNotThrow(runner("+ some random text hagahaha\r\n"));
        test.done();
      },
      code_alert: function(test) {
        test.doesNotThrow(runner("+ [ALERT] some random text hagahaha\r\n"));
        test.done();
      },
      code_badcharset: function(test) {
        test.doesNotThrow(runner("+ [BADCHARSET (jhdsfdgsfg)] some random text hagahaha\r\n"));
        test.done();
      },
      code_badcharset_dquoted: function(test) {
        test.doesNotThrow(runner("+ [BADCHARSET (\"jhdsfdgsfg\")] some random text hagahaha\r\n"));
        test.done();
      },
      code_badcharset_literal: function(test) {
        test.doesNotThrow(runner("+ [BADCHARSET ({2}\r\nAB)] some random text hagahaha\r\n"));
        test.done();
      },
      code_badcharset_literal_two: function(test) {
        test.doesNotThrow(runner("+ [BADCHARSET ({2}\r\nAB{3}\r\n123)] some random text hagahaha\r\n"));
        test.done();
      },
      code_parse: function(test) {
        test.doesNotThrow(runner("+ [PARSE] some random text hagahaha\r\n"));
        test.done();
      },
      code_permflags: function(test) {
        test.doesNotThrow(runner("+ [PERMANENTFLAGS ()] some random text hagahaha\r\n"));
        test.done();
      },
      code_permflags_multi: function(test) {
        test.doesNotThrow(runner("+ [PERMANENTFLAGS (\\Answered \\Deleted)] some random text hagahaha\r\n"));
        test.done();
      },
      code_readonly: function(test) {
        test.doesNotThrow(runner("+ [READ-ONLY] some random text hagahaha\r\n"));
        test.done();
      },
      code_readwrite: function(test) {
        test.doesNotThrow(runner("+ [READ-WRITE] some random text hagahaha\r\n"));
        test.done();
      },
      code_trycreate: function(test) {
        test.doesNotThrow(runner("+ [TRYCREATE] some random text hagahaha\r\n"));
        test.done();
      },
      code_uidnext: function(test) {
        test.doesNotThrow(runner("+ [UIDNEXT 345] some random text hagahaha\r\n"));
        test.done();
      },
      code_uidvalidity: function(test) {
        test.doesNotThrow(runner("+ [UIDVALIDITY 654] some random text hagahaha\r\n"));
        test.done();
      },
      code_unseen: function(test) {
        test.doesNotThrow(runner("+ [UNSEEN 654] some random text hagahaha\r\n"));
        test.done();
      },
      code_atom: function(test) {
        test.doesNotThrow(runner("+ [G FGH] some random text hagahaha\r\n"));
        test.done();
      },
      code_atom_noarg: function(test) {
        test.doesNotThrow(runner("+ [J] some random text hagahaha\r\n"));
        test.done();
      },
    },
    base64: {
      two_b64: function(test) {
        test.doesNotThrow(runner("+ ++==\r\n"));
        test.doesNotThrow(runner("+ 94==\r\n"));
        test.doesNotThrow(runner("+ A9==\r\n"));
        test.doesNotThrow(runner("+ /H==\r\n"));
        test.done();
      },
      three_b64: function(test) {
        test.doesNotThrow(runner("+ +L+=\r\n"));
        test.doesNotThrow(runner("+ 9A4=\r\n"));
        test.doesNotThrow(runner("+ AV9=\r\n"));
        test.doesNotThrow(runner("+ /QH=\r\n"));
        test.done();
      }
    }
  },
  */
});