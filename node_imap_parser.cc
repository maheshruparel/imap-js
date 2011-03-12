
#include <v8.h>
#include <node.h>
#include <node_buffer.h>

#include "imap_parser.h"


using namespace node;
using namespace v8;



Persistent<FunctionTemplate> ImapParserNew;

static imap_parser_settings settings;


class ImapParser: ObjectWrap {
private:
  imap_parser parser;

  void Init() {
    imap_parser_init(&parser);
    parser.data = this;
  }

public:
  ImapParser() {
    Init();
  }

  ~ImapParser() {
  }

  static Handle<Value> New(const Arguments& args) {
    HandleScope scope;
    ImapParser *self = new ImapParser();
    self->Wrap(args.This());
    return args.This();
  }

  static Handle<Value> Reinitialize(const Arguments& args) {
    HandleScope scope;
    ImapParser *self = ObjectWrap::Unwrap<ImapParser>(args.This());

    self->Init();

    return Undefined();
  }

  static Handle<Value> Execute(const Arguments& args) {
    HandleScope scope;
    ImapParser *self = ObjectWrap::Unwrap<ImapParser>(args.This());

    Local<Value> buffer_arg = args[0];
    if (!Buffer::HasInstance(buffer_arg)) {
      return ThrowException(Exception::TypeError(String::New("Buffer argument needed")));
    }

    Local<Object> buffer = buffer_arg->ToObject();
    char* buffer_data = Buffer::Data(buffer);
    size_t buffer_len = Buffer::Length(buffer);

    size_t offset = args[1]->Int32Value();
    size_t length = args[2]->Int32Value();

    if (offset >= buffer_len) {
      return ThrowException(Exception::Error(String::New("Offset larger than buffer")));
    }
    if (offset + length >= buffer_len) {
      return ThrowException(Exception::Error(String::New("Length from offset larger than buffer")));
    }


    size_t parsed_amount = imap_parser_execute(&(self->parser), &settings, buffer_data + offset, length );

    Local<Integer> parsed_amount_val = Integer::New(parsed_amount);
    if (parsed_amount != length) {
      Local<Value> e = Exception::Error(String::NewSymbol("Parse Error"));
      e->ToObject()->Set(String::NewSymbol("bytesParsed"), parsed_amount_val);
      return scope.Close(e);
    }
    else {
      return scope.Close(parsed_amount_val);
    }
  }
};




extern "C" {
  static void init (Handle<Object> target)
  {
    HandleScope scope;

    Local<FunctionTemplate> t = FunctionTemplate::New(ImapParser::New);

    ImapParserNew = Persistent<FunctionTemplate>::New(t);
    ImapParserNew->InstanceTemplate()->SetInternalFieldCount(1);
    ImapParserNew->SetClassName(String::NewSymbol("ImapParser"));


    NODE_SET_PROTOTYPE_METHOD(ImapParserNew, "reinitialize", ImapParser::Reinitialize);
    NODE_SET_PROTOTYPE_METHOD(ImapParserNew, "execute", ImapParser::Execute);

    target->Set(String::NewSymbol("ImapParser"), ImapParserNew->GetFunction());
  }

  NODE_MODULE(imap_parser, init); // Must match file name
}
