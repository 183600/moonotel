// Tracing instrumentation for `moonbitlang/async/http` servers.
//
// `run_server` wraps `@http.Server::run_forever`: every request starts a
// SERVER span whose parent is extracted from the incoming W3C `traceparent`
// header, the extracted context is installed as the current context while the
// handler runs, and the span is ended when the handler returns (or raises).
//
// Use `ServerCall::respond` to send the response and record the status code on
// the span, and `ServerCall::start_span` to create child spans that are
// explicitly parented to the request even when several connections run
// concurrently.

///|
const INSTRUMENTATION_SCOPE : String = "yourname/otel/instrumentation/async_http_server"

// Constant semantic-convention attribute values.

///|
let protocol_name_http : @sdk.AttributeValue = @sdk.StringValue("http")

///|
let protocol_version_http_1_1 : @sdk.AttributeValue = @sdk.StringValue("1.1")

///|
let url_scheme_http : @sdk.AttributeValue = @sdk.StringValue("http")

///|
let method_get : @sdk.AttributeValue = @sdk.StringValue("GET")

///|
let method_head : @sdk.AttributeValue = @sdk.StringValue("HEAD")

///|
let method_post : @sdk.AttributeValue = @sdk.StringValue("POST")

///|
let method_put : @sdk.AttributeValue = @sdk.StringValue("PUT")

///|
let method_delete : @sdk.AttributeValue = @sdk.StringValue("DELETE")

///|
let method_connect : @sdk.AttributeValue = @sdk.StringValue("CONNECT")

///|
let method_options : @sdk.AttributeValue = @sdk.StringValue("OPTIONS")

///|
let method_trace : @sdk.AttributeValue = @sdk.StringValue("TRACE")

///|
let method_patch : @sdk.AttributeValue = @sdk.StringValue("PATCH")

///|
fn method_attribute_value(
  request_method : @http.RequestMethod,
) -> @sdk.AttributeValue {
  match request_method {
    Get => method_get
    Head => method_head
    Post => method_post
    Put => method_put
    Delete => method_delete
    Connect => method_connect
    Options => method_options
    Trace => method_trace
    Patch => method_patch
  }
}

///|
fn default_tracer() -> @sdk.Tracer? {
  match @sdk.global_tracer_provider() {
    Some(provider) => Some(provider.get_tracer(INSTRUMENTATION_SCOPE))
    None => None
  }
}

///|
fn http_method_name(request_method : @http.RequestMethod) -> String {
  match request_method {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
fn status_reason(status_code : Int32) -> String {
  match status_code {
    200 => "OK"
    201 => "Created"
    202 => "Accepted"
    204 => "No Content"
    301 => "Moved Permanently"
    302 => "Found"
    304 => "Not Modified"
    307 => "Temporary Redirect"
    308 => "Permanent Redirect"
    400 => "Bad Request"
    401 => "Unauthorized"
    403 => "Forbidden"
    404 => "Not Found"
    405 => "Method Not Allowed"
    408 => "Request Timeout"
    409 => "Conflict"
    413 => "Payload Too Large"
    415 => "Unsupported Media Type"
    422 => "Unprocessable Entity"
    429 => "Too Many Requests"
    500 => "Internal Server Error"
    501 => "Not Implemented"
    502 => "Bad Gateway"
    503 => "Service Unavailable"
    504 => "Gateway Timeout"
    _ => ""
  }
}

///|
fn parse_port(text : StringView) -> Int32 {
  @string.parse_int(text) catch {
    _ => -1
  }
}

///|
fn split_path_query(path : String) -> (String, String) {
  match path.find("?") {
    Some(index) => (path[:index].to_owned(), path[index + 1:].to_owned())
    None => (path, "")
  }
}

// Parse the incoming W3C context of a request: `traceparent` (with a valid
// `tracestate`) and `baggage`. Request headers are already keyed
// case-insensitively; a request without trace context or baggage yields the
// root context.

///|
fn extract_context_with_baggage(
  headers : Map[@http.CaseInsensitiveString, String],
) -> (@context.Context, Bool) {
  let traceparent_name = @propagation.traceparent_header_name()
  let baggage_name = @propagation.baggage_header_name()
  let traceparent = headers.get(@http.CaseInsensitiveString(traceparent_name))
  let baggage = headers.get(@http.CaseInsensitiveString(baggage_name))
  if traceparent is None && baggage is None {
    return (@context.Context::root(), false)
  }
  let mut context = @context.Context::root()
  let mut has_baggage = false
  match baggage {
    Some(value) => {
      let entries = @propagation.parse_baggage(value)
      has_baggage = entries.length() > 0
      for entry in entries {
        context = context.with_value(entry.0, entry.1)
      }
    }
    None => ()
  }
  match traceparent {
    Some(value) =>
      match @propagation.parse_traceparent(value) {
        Some(sc) => {
          let sc = match
            headers.get(
              @http.CaseInsensitiveString(@propagation.tracestate_header_name()),
            ) {
            Some(state) =>
              match @propagation.parse_tracestate(state) {
                Some(normalized) => sc.with_tracestate(normalized)
                None => sc
              }
            None => sc
          }
          context = context.with_span(sc)
        }
        None => ()
      }
    None => ()
  }
  (context, has_baggage)
}

///|
pub fn extract_context(
  headers : Map[@http.CaseInsensitiveString, String],
) -> @context.Context {
  extract_context_with_baggage(headers).0
}

// Parse the W3C `traceparent` header of an incoming request, if present.

///|
pub fn extract_parent(
  headers : Map[@http.CaseInsensitiveString, String],
) -> @api.SpanContext? {
  extract_context(headers).span_context()
}

///|
fn record_host_attributes(
  span : @sdk.SpanSdk,
  headers : Map[@http.CaseInsensitiveString, String],
) -> Unit {
  match headers.get(@http.CaseInsensitiveString("host")) {
    Some(host) => {
      let (address, port) = match host.rev_find(":") {
        Some(colon) =>
          if host[colon + 1:].find("]") is None {
            (host[:colon].to_owned(), parse_port(host[colon + 1:]))
          } else {
            (host, -1)
          }
        None => (host, -1)
      }
      span.set_attribute(@sdk.SERVER_ADDRESS, @sdk.StringValue(address))
      if port > 0 {
        span.set_attribute(@sdk.SERVER_PORT, @sdk.IntValue(port.to_int64()))
      }
    }
    None => ()
  }
}

///|
fn end_span(span : @sdk.SpanSdk?) -> Unit {
  match span {
    Some(value) => value.end()
    None => ()
  }
}

// An instrumented server request: the request, its body, the connection to
// respond on, the SERVER span and the tracer that created it (both absent when
// tracing is disabled).

///|
pub(all) struct ServerCall {
  request : @http.Request
  body : &@io.Reader
  connection : @http.ServerConnection
  span : @sdk.SpanSdk?
  tracer : @sdk.Tracer?
}

// Upper-case HTTP method of the request.

///|
pub fn ServerCall::http_method(self : ServerCall) -> String {
  http_method_name(self.request.meth)
}

// Request path, without the query string.

///|
pub fn ServerCall::path(self : ServerCall) -> String {
  split_path_query(self.request.path).0
}

// Request query string, without the leading `?`.

///|
pub fn ServerCall::query(self : ServerCall) -> String {
  split_path_query(self.request.path).1
}

// Look up a request header by name.

///|
pub fn ServerCall::header(self : ServerCall, name : String) -> String? {
  self.request.headers.get(@http.CaseInsensitiveString(name))
}

// The span context of the SERVER span, if tracing is enabled.

///|
pub fn ServerCall::span_context(self : ServerCall) -> @api.SpanContext? {
  match self.span {
    Some(span) => Some(span.context())
    None => None
  }
}

// Record the matched route on the SERVER span. Following the HTTP semantic
// conventions the span is renamed to `METHOD route` and the route is stored as
// the `http.route` attribute. Returns `false` when tracing is disabled.

///|
pub fn ServerCall::set_route(self : ServerCall, route : String) -> Bool {
  match self.span {
    Some(span) => {
      span.set_attribute(@sdk.HTTP_ROUTE, @sdk.StringValue(route))
      span.update_name(http_method_name(self.request.meth) + " " + route)
      true
    }
    None => false
  }
}

// Start a child span of the SERVER span, explicitly parented to the request.
// Returns `None` when tracing is disabled.

///|
pub fn ServerCall::start_span(
  self : ServerCall,
  name : String,
  kind? : @api.SpanKind,
  attributes? : Map[String, @sdk.AttributeValue],
  links? : Array[@sdk.SpanLink],
) -> @sdk.SpanSdk? {
  match (self.tracer, self.span) {
    (Some(tracer), Some(server_span)) =>
      Some(
        tracer.start_span(
          name,
          kind?,
          parent=server_span.context(),
          attributes?,
          links?,
        ),
      )
    _ => None
  }
}

///|
fn is_http_ows(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

// Whether the five code units at `start` spell `close` ignoring ASCII case.

///|
fn is_close_token_at(value : String, start : Int32) -> Bool {
  (value.unsafe_get(start).to_int() | 32) == 99 &&
  (value.unsafe_get(start + 1).to_int() | 32) == 108 &&
  (value.unsafe_get(start + 2).to_int() | 32) == 111 &&
  (value.unsafe_get(start + 3).to_int() | 32) == 115 &&
  (value.unsafe_get(start + 4).to_int() | 32) == 101
}

// Whether a comma-separated `Connection` header value contains the token
// `close` (case-insensitive, optional whitespace ignored). Equivalent to
// `value.split(",")` plus `trim`/`to_lower`.

///|
fn has_close_token(value : String) -> Bool {
  let len = value.length()
  let mut start = 0
  while start <= len {
    let mut token_start = start
    while token_start < len &&
          is_http_ows(value.unsafe_get(token_start).unsafe_to_char()) {
      token_start = token_start + 1
    }
    let mut end = token_start
    while end < len && value.unsafe_get(end).unsafe_to_char() != ',' {
      end = end + 1
    }
    let mut token_end = end
    while token_end > token_start &&
          is_http_ows(value.unsafe_get(token_end - 1).unsafe_to_char()) {
      token_end = token_end - 1
    }
    if token_end - token_start == 5 && is_close_token_at(value, token_start) {
      return true
    }
    if end >= len {
      return false
    }
    start = end + 1
  }
  false
}

// Whether the request asked for the connection to be closed once the
// response has been sent (`Connection: close`). Handlers that bypass
// `respond` can use this to decide whether to call
// `ServerCall::close_connection` themselves.

///|
pub fn ServerCall::connection_close_requested(self : ServerCall) -> Bool {
  match self.request.headers.get(@http.CaseInsensitiveString("connection")) {
    Some(value) => has_close_token(value)
    None => false
  }
}

// Close the underlying connection after the current response. The server loop
// then stops reading requests from this connection. Safe to call multiple
// times.

///|
pub fn ServerCall::close_connection(self : ServerCall) -> Unit {
  self.connection.close()
}

// Number of UTF-8 bytes a string encodes to, counted without allocating.
// Surrogate pairs count as one four-byte character.

///|
fn utf8_byte_length(value : String) -> Int32 {
  let len = value.length()
  let mut total = 0
  let mut i = 0
  while i < len {
    let unit = value.unsafe_get(i).to_int()
    if unit < 0x80 {
      total = total + 1
    } else if unit < 0x800 {
      total = total + 2
    } else if unit >= 0xD800 &&
      unit <= 0xDBFF &&
      i + 1 < len &&
      value.unsafe_get(i + 1).to_int() >= 0xDC00 &&
      value.unsafe_get(i + 1).to_int() <= 0xDFFF {
      total = total + 4
      i = i + 1
    } else {
      total = total + 3
    }
    i = i + 1
  }
  total
}

// Send a response and record `http.response.status_code` and
// `http.response.body.size` on the SERVER span. 5xx responses set the span
// status to `Error`. The body, when present, is written before the response
// is ended. When the request carried `Connection: close`, the connection is
// closed after the response, as required by HTTP/1.1.

///|
pub async fn ServerCall::respond(
  self : ServerCall,
  status_code : Int32,
  reason? : String,
  body? : String,
  headers? : Map[String, String],
) -> Unit {
  let extra_headers : @http.Headers = match headers {
    Some(values) => Map([], capacity=(values.length() + 1) * 2)
    None => Map([], capacity=2)
  }
  match headers {
    Some(values) =>
      for key, value in values {
        extra_headers.set(@http.CaseInsensitiveString(key), value)
      }
    None => ()
  }
  let close_requested = self.connection_close_requested()
  if close_requested &&
    extra_headers.get(@http.CaseInsensitiveString("connection")) is None {
    extra_headers.set(@http.CaseInsensitiveString("connection"), "close")
  }
  self.connection.send_response(
    status_code,
    reason.unwrap_or(status_reason(status_code)),
    extra_headers~,
  )
  match body {
    Some(text) => {
      self.connection.write(text)
      match self.span {
        Some(span) =>
          span.set_attribute(
            @sdk.HTTP_RESPONSE_BODY_SIZE,
            @sdk.IntValue(utf8_byte_length(text).to_int64()),
          )
        None => ()
      }
    }
    None => ()
  }
  self.connection.end_response()
  if close_requested {
    self.connection.close()
  }
  match self.span {
    Some(span) => {
      span.set_attribute(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
        @sdk.IntValue(status_code.to_int64()),
      )
      if status_code >= 500 {
        let status_text = status_code.to_string()
        span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(status_text))
        span.set_status(@api.StatusCode::Error, description=status_text)
      }
    }
    None => ()
  }
}

// Run an HTTP server that traces every request. The handler receives a
// `ServerCall` and is responsible for sending exactly one response (usually
// via `ServerCall::respond`).

///|
pub async fn run_server(
  addr : @socket.Addr,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  let server = @http.Server(addr)
  defer server.close()
  run_server_on(server, handler, tracer?, allow_failure?, max_connections?)
}

// Like `run_server`, but on an already constructed server (for example one
// bound to port 0 whose actual port was read from `server.addr`). The caller
// keeps ownership of `server`.

///|
pub async fn run_server_on(
  server : @http.Server,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  let active_tracer : @sdk.Tracer? = match tracer {
    Some(value) => Some(value)
    None => default_tracer()
  }
  server.run_forever(
    async fn(request, body, connection) {
      let (parent_context, parent_has_baggage) = extract_context_with_baggage(
        request.headers,
      )
      let parent = parent_context.span_context()
      let method_name = http_method_name(request.meth)
      let span = match active_tracer {
        Some(tracer) =>
          Some(
            tracer.start_span(method_name, kind=@api.SpanKind::Server, parent?),
          )
        None => None
      }
      let call : ServerCall = {
        request,
        body,
        connection,
        span,
        tracer: active_tracer,
      }
      match span {
        Some(server_span) => {
          server_span.set_attribute(
            @sdk.HTTP_REQUEST_METHOD,
            method_attribute_value(request.meth),
          )
          server_span.set_attribute(@sdk.URL_SCHEME, url_scheme_http)
          server_span.set_attribute(
            @sdk.NETWORK_PROTOCOL_NAME,
            protocol_name_http,
          )
          // `moonbitlang/async/http` speaks HTTP/1.1 only.
          server_span.set_attribute(
            @sdk.NETWORK_PROTOCOL_VERSION,
            protocol_version_http_1_1,
          )
          let (path, query) = split_path_query(request.path)
          server_span.set_attribute(@sdk.URL_PATH, @sdk.StringValue(path))
          if query != "" {
            server_span.set_attribute(@sdk.URL_QUERY, @sdk.StringValue(query))
          }
          record_host_attributes(server_span, request.headers)
          match request.headers.get(@http.CaseInsensitiveString("user-agent")) {
            Some(agent) =>
              server_span.set_attribute(
                @sdk.USER_AGENT_ORIGINAL,
                @sdk.StringValue(agent),
              )
            None => ()
          }
        }
        None => ()
      }
      let attached : @context.Context? = match span {
        Some(server_span) =>
          Some(@context.attach(parent_context.with_span(server_span.context())))
        None =>
          if parent_has_baggage {
            Some(@context.attach(parent_context))
          } else {
            None
          }
      }
      defer (match attached {
        Some(previous) => @context.detach(previous)
        None => ()
      })
      defer end_span(span)
      let outcome = Ok(handler(call)) catch { error => Err(error) }
      match outcome {
        Ok(_) => ()
        Err(error) => {
          match span {
            Some(server_span) => {
              let type_name = error.to_string()
              server_span.set_attribute(
                @sdk.ERROR_TYPE,
                @sdk.StringValue(type_name),
              )
              server_span.set_status(
                @api.StatusCode::Error,
                description=type_name,
              )
              server_span.record_exception(error)
            }
            None => ()
          }
          raise error
        }
      }
    },
    allow_failure?,
    max_connections?,
  )
}
