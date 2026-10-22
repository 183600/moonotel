// Tracing instrumentation for `moonbitlang/async/http` servers.
//
// `run_server` wraps `@http.Server::run_forever`: every request starts a
// SERVER span whose parent is extracted through the process-wide propagator
// (the W3C `traceparent` header by default), the extracted context is
// installed as the current context while the handler runs, and the span is
// ended when the handler returns (or raises).
//
// Use `ServerCall::respond` to send the response and record the status code on
// the span, and `ServerCall::start_span` to create child spans that are
// explicitly parented to the request even when several connections run
// concurrently.

///|
const INSTRUMENTATION_SCOPE : String = "183600/moonotel/instrumentation/async_http_server"

///|
fn map_capacity_for_entries(entries : Int) -> Int {
  let capacity = entries.next_power_of_two()
  if entries > capacity * 13 / 16 {
    capacity * 2
  } else {
    capacity
  }
}

// Constant semantic-convention attribute values.

///|
let protocol_name_http : @sdk.AttributeValue = @sdk.StringValue("http")

///|
let protocol_version_http_1_1 : @sdk.AttributeValue = @sdk.StringValue("1.1")

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
  let len = text.length()
  if len == 0 {
    return -1
  }
  let mut port = 0
  let mut i = 0
  while i < len {
    let code = text.unsafe_get(i).to_int()
    if code < 0x30 || code > 0x39 {
      return -1
    }
    let digit = code - 0x30
    if port > (65535 - digit) / 10 {
      return -1
    }
    port = port * 10 + digit
    i = i + 1
  }
  port
}

// Trim HTTP optional whitespace (SP / HTAB only) from both ends of a header
// value. The HTTP reader used by the instrumentation strips at most one leading
// space and keeps trailing whitespace, so numeric and authority values must be
// trimmed here before parsing.

///|
fn trim_header_ows(value : StringView) -> StringView {
  let len = value.length()
  let mut start = 0
  while start < len && is_http_ows(value.unsafe_get(start).unsafe_to_char()) {
    start = start + 1
  }
  let mut end = len
  while end > start && is_http_ows(value.unsafe_get(end - 1).unsafe_to_char()) {
    end = end - 1
  }
  if start == 0 && end == len {
    value
  } else {
    value.view(start_offset=start, end_offset=end)
  }
}

// Parse a non-negative decimal `Content-Length` value. Values that do not fit
// in an `Int64` are rejected so a hostile header cannot overflow the attribute.

///|
fn parse_content_length(text : StringView) -> Int64? {
  let len = text.length()
  if len == 0 {
    return None
  }
  let max = 9223372036854775807UL
  let mut value : UInt64 = 0
  let mut i = 0
  while i < len {
    let code = text.unsafe_get(i).to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    let digit = (code - 0x30).to_uint64()
    if value > (max - digit) / 10UL {
      return None
    }
    value = value * 10UL + digit
    i = i + 1
  }
  Some(value.reinterpret_as_int64())
}

// Declared request body size, from `Content-Length`. A `Transfer-Encoding`
// header means the body length is not given by `Content-Length` (RFC 9112),
// so the attribute is omitted in that case.

///|
fn request_body_size(
  headers : Map[@http.CaseInsensitiveString, String],
) -> Int64? {
  match headers.get(@http.CaseInsensitiveString("transfer-encoding")) {
    // Any Transfer-Encoding header, even an empty one, means Content-Length
    // no longer describes the body (RFC 9112 section 6.3).
    Some(_) => return None
    None => ()
  }
  match headers.get(@http.CaseInsensitiveString("content-length")) {
    Some(value) => parse_content_length(trim_header_ows(value[:]))
    None => None
  }
}

///|
fn split_path_query(path : String) -> (String, String) {
  let lower = path.to_lower()
  let has_absolute_uri = lower.has_prefix("http://") || lower.has_prefix("https://")
  let mut rest : StringView = if lower.has_prefix("http://") {
    path[7:]
  } else if lower.has_prefix("https://") {
    path[8:]
  } else {
    path[:]
  }
  if has_absolute_uri {
    let mut authority_end = 0
    while authority_end < rest.length() &&
      rest.unsafe_get(authority_end).to_int() != 0x2F &&
      rest.unsafe_get(authority_end).to_int() != 0x3F &&
      rest.unsafe_get(authority_end).to_int() != 0x23 {
      authority_end = authority_end + 1
    }
    rest = rest[authority_end:]
  }
  // A fragment is not part of the request target components: drop it before
  // looking for the query separator.
  let without_fragment = match rest.find("#") {
    Some(index) => rest[:index]
    None => rest
  }
  match without_fragment.find("?") {
    Some(index) => {
      let path_part = without_fragment[:index]
      (
        if path_part.length() == 0 { "/" } else { path_part.to_owned() },
        without_fragment[index + 1:].to_owned(),
      )
    }
    None =>
      if without_fragment.length() == 0 {
        ("/", "")
      } else {
        (without_fragment.to_owned(), "")
      }
  }
}

///|
fn request_target_scheme(path : String) -> String {
  let lower = path.to_lower()
  if lower.has_prefix("https://") { "https" } else { "http" }
}

// Parse the incoming trace context of a request through the process-wide
// propagator (see `@propagation.global_propagator`), which by default handles
// the W3C `traceparent`/`tracestate` headers and `baggage`. Request headers
// are already keyed case-insensitively. The second result reports whether the
// extracted context carries baggage.

///|
fn extract_context_with_baggage(
  headers : Map[@http.CaseInsensitiveString, String],
) -> (@context.Context, Bool) {
  let carrier = @propagation.TextMapCarrier::from_getter(fn(key) {
    headers.get(@http.CaseInsensitiveString(key))
  })
  let context = @propagation.global_propagator().extract(carrier)
  (context, context.has_baggage())
}

///|
pub fn extract_context(
  headers : Map[@http.CaseInsensitiveString, String],
) -> @context.Context {
  extract_context_with_baggage(headers).0
}

// Parse the parent SpanContext of an incoming request through the
// process-wide propagator, if the request carries one.

///|
pub fn extract_parent(
  headers : Map[@http.CaseInsensitiveString, String],
) -> @api.SpanContext? {
  extract_context(headers).span_context()
}

// Strip the square brackets of a bracketed IPv6 literal so that
// `server.address` holds the bare address, matching `client_host_string`.

///|
fn strip_ipv6_brackets(address : String) -> String {
  if address.has_prefix("[") && address.has_suffix("]") {
    address[1:address.length() - 1].to_owned()
  } else {
    address
  }
}

// The host[:port] component of an absolute-form request target
// (`http://[userinfo@]host[:port]/path`), or `None` when the target is not in
// absolute-form or carries no host. Any userinfo prefix is discarded because
// it is not part of `server.address`.

///|
fn absolute_target_authority(path : String) -> String? {
  let lower = path.to_lower()
  let rest : StringView = if lower.has_prefix("http://") {
    path[7:]
  } else if lower.has_prefix("https://") {
    path[8:]
  } else {
    return None
  }
  let mut end = 0
  while end < rest.length() {
    let code = rest.unsafe_get(end).to_int()
    if code == 0x2F || code == 0x3F || code == 0x23 {
      break
    }
    end = end + 1
  }
  let authority = rest[:end]
  let host = match authority.rev_find("@") {
    Some(index) => authority[index + 1:]
    None => authority
  }
  if host.length() == 0 {
    None
  } else {
    Some(host.to_owned())
  }
}

///|
fn is_absolute_target(path : String) -> Bool {
  let lower = path.to_lower()
  lower.has_prefix("http://") || lower.has_prefix("https://")
}

///|
fn record_host_attributes(
  span : @sdk.SpanSdk,
  headers : Map[@http.CaseInsensitiveString, String],
  path : String,
) -> Unit {
  // With an absolute-form request target the authority of the target wins
  // over the Host header (HTTP semantic conventions, footnotes [2] and [3];
  // RFC 9112 also requires servers to ignore Host in that case). An
  // absolute-form target with an empty authority therefore has no server
  // address; falling back to Host would use a header the request told us to
  // ignore.
  let host : String? = match absolute_target_authority(path) {
    Some(authority) => Some(authority)
    None =>
      if is_absolute_target(path) {
        None
      } else {
        // A Host header must not contain userinfo, but a malformed or hostile
        // request may still send it. Discard it exactly like the authority of
        // an absolute-form target so credentials never reach `server.address`.
        match headers.get(@http.CaseInsensitiveString("host")) {
        Some(value) => {
          let value = trim_header_ows(value[:])
          let host = match value.rev_find("@") {
            Some(index) =>
              if index + 1 >= value.length() {
                None
              } else {
                Some(value[index + 1:].to_owned())
              }
            None => Some(value.to_owned())
          }
          match host {
            Some(value) => if value == "" { None } else { Some(value) }
            None => None
          }
        }
        None => None
      }
      }
  }
  match host {
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
      let address = strip_ipv6_brackets(address)
      if address != "" {
        span.set_attribute(@sdk.SERVER_ADDRESS, @sdk.StringValue(address))
        // `-1` marks an absent or invalid port; an explicit port 0 is valid
        // and must still be recorded.
        if port >= 0 {
          span.set_attribute(@sdk.SERVER_PORT, @sdk.IntValue(port.to_int64()))
        }
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
  // `(path, query)` split of the request target, computed on first use and
  // shared by `path` and `query`.
  mut path_query : (String, String)?
  // Whether `respond` has completely sent a response for this request.
  mut responded : Bool
  // Whether the connection was closed by `respond` (`Connection: close`) or
  // by `close_connection`.
  mut connection_closed : Bool
}

// Upper-case HTTP method of the request.

///|
pub fn ServerCall::http_method(self : ServerCall) -> String {
  http_method_name(self.request.meth)
}

// Request path, without the query string.

///|
pub fn ServerCall::path(self : ServerCall) -> String {
  self.path_and_query().0
}

// Request query string, without the leading `?`.

///|
pub fn ServerCall::query(self : ServerCall) -> String {
  self.path_and_query().1
}

///|
fn ServerCall::path_and_query(self : ServerCall) -> (String, String) {
  match self.path_query {
    Some(pair) => pair
    None => {
      let pair = split_path_query(self.request.path)
      self.path_query = Some(pair)
      pair
    }
  }
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
  c == ' ' || c == '\t'
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
  if self.responded {
    // The response is already on the wire, so the connection can be closed
    // immediately.
    self.connection.close()
  }
  // Before the response is sent, the close is deferred to `respond`: closing
  // the socket first would make the response impossible to send.
  self.connection_closed = true
}

// Replace unpaired UTF-16 surrogates with U+FFFD so that a response body can
// always be encoded as UTF-8. Well-formed strings are returned unchanged.

///|
fn sanitize_utf16_surrogates(value : String) -> String {
  let len = value.length()
  let mut i = 0
  while i < len {
    let unit = value.unsafe_get(i).to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      if i + 1 < len {
        let next = value.unsafe_get(i + 1).to_int()
        if next >= 0xDC00 && next <= 0xDFFF {
          i = i + 2
          continue
        }
      }
      break
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      break
    }
    i = i + 1
  }
  if i >= len {
    return value
  }
  let sb = StringBuilder(size_hint=len)
  let mut j = 0
  while j < len {
    let unit = value.unsafe_get(j).to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      if j + 1 < len {
        let next = value.unsafe_get(j + 1).to_int()
        if next >= 0xDC00 && next <= 0xDFFF {
          sb.write_char(unit.unsafe_to_char())
          sb.write_char(next.unsafe_to_char())
          j = j + 2
          continue
        }
      }
      sb.write_char((0xFFFD).unsafe_to_char())
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      sb.write_char((0xFFFD).unsafe_to_char())
    } else {
      sb.write_char(unit.unsafe_to_char())
    }
    j = j + 1
  }
  sb.to_string()
}

// Number of UTF-8 bytes a string encodes to.
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
    Some(values) =>
      Map([], capacity=map_capacity_for_entries(values.length() + 1))
    None => Map([], capacity=2)
  }
  match headers {
    Some(values) =>
      for key, value in values {
        // Header strings are written as UTF-8 by the transport; replace
        // unpaired surrogates instead of aborting the connection task.
        extra_headers.set(
          @http.CaseInsensitiveString(sanitize_utf16_surrogates(key)),
          sanitize_utf16_surrogates(value),
        )
      }
    None => ()
  }
  let close_requested = self.connection_close_requested()
  // A handler may have requested the close before sending the response; the
  // socket must stay open until the response has been written.
  let mut close_after_response = close_requested || self.connection_closed
  match extra_headers.get(@http.CaseInsensitiveString("connection")) {
    Some(value) =>
      if has_close_token(value) {
        close_after_response = true
      }
    None => ()
  }
  if close_after_response {
    // Announce the close on every path that will close the socket: a request
    // `Connection: close`, a response header containing the token, or a
    // handler that called `close_connection`. Without this header an HTTP/1.1
    // client may try to reuse a connection the server is about to close.
    extra_headers.set(@http.CaseInsensitiveString("connection"), "close")
  }
  match self.span {
    Some(span) =>
      @http_header_capture.HeaderCapture::from_env(
        @http_header_capture.ENV_SERVER_RESPONSE_HEADERS,
      ).record_response(extra_headers, span)
    None => ()
  }
  self.connection.send_response(
    status_code,
    sanitize_utf16_surrogates(reason.unwrap_or(status_reason(status_code))),
    extra_headers~,
  )
  let body_allowed = match (self.request.meth, status_code) {
    (Head, _) => false
    (Connect, 200..<300) => false
    (_, 100..<200 | 204 | 205 | 304) => false
    _ => true
  }
  match body {
    Some(text) =>
      if body_allowed {
        // An unpaired surrogate cannot be encoded as UTF-8 by the transport;
        // substitute U+FFFD instead of aborting the connection task.
        let response_body = sanitize_utf16_surrogates(text)
        self.connection.write(response_body)
        match self.span {
          Some(span) =>
            span.set_attribute(
              @sdk.HTTP_RESPONSE_BODY_SIZE,
              @sdk.IntValue(utf8_byte_length(response_body).to_int64()),
            )
          None => ()
        }
      }
    None => ()
  }
  self.connection.end_response()
  self.responded = true
  if close_after_response {
    self.connection.close()
    self.connection_closed = true
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
        span.set_status(@api.StatusCode::Error)
      }
    }
    None => ()
  }
}

// Run an HTTP server that traces every request. The address of the TCP peer
// of each connection is recorded as `client.address`/`client.port` on the
// SERVER span. The handler receives a `ServerCall` and is responsible for
// sending exactly one response (usually via `ServerCall::respond`).

///|
pub async fn run_server(
  addr : @socket.Addr,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  run_server_with_client_address(
    addr,
    handler,
    tracer?,
    allow_failure?,
    max_connections?,
  )
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
      let _ = serve_call(
        request,
        body,
        connection,
        active_tracer,
        handler,
        None,
        None,
      )
    },
    allow_failure?,
    max_connections?,
  )
}

// Serve one request: start the SERVER span (recording the peer address as
// `client.address`/`client.port` when the connection's peer is known), install
// the extracted context while the handler runs, end the span afterwards, and
// return the `ServerCall` so the caller can inspect how the handler responded.

///|
async fn serve_call(
  request : @http.Request,
  body : &@io.Reader,
  connection : @http.ServerConnection,
  active_tracer : @sdk.Tracer?,
  handler : async (ServerCall) -> Unit,
  client_address : String?,
  client_port : Int32?,
) -> ServerCall {
  let (parent_context, parent_has_baggage) = extract_context_with_baggage(
    request.headers,
  )
  let parent = parent_context.span_context()
  let method_name = http_method_name(request.meth)
  let span = match active_tracer {
    Some(tracer) =>
      Some(tracer.start_span(method_name, kind=@api.SpanKind::Server, parent?))
    None => None
  }
  let call : ServerCall = {
    request,
    body,
    connection,
    span,
    tracer: active_tracer,
    path_query: None,
    responded: false,
    connection_closed: false,
  }
  match span {
    Some(server_span) => {
      server_span.set_attribute(
        @sdk.HTTP_REQUEST_METHOD,
        method_attribute_value(request.meth),
      )
      server_span.set_attribute(
        @sdk.URL_SCHEME,
        @sdk.StringValue(request_target_scheme(request.path)),
      )
      server_span.set_attribute(@sdk.NETWORK_PROTOCOL_NAME, protocol_name_http)
      // `moonbitlang/async/http` speaks HTTP/1.1 only.
      server_span.set_attribute(
        @sdk.NETWORK_PROTOCOL_VERSION,
        protocol_version_http_1_1,
      )
      let path = call.path()
      let query = @sdk.redact_sensitive_query_string(call.query())
      server_span.set_attribute(@sdk.URL_PATH, @sdk.StringValue(path))
      if query != "" {
        server_span.set_attribute(@sdk.URL_QUERY, @sdk.StringValue(query))
      }
      record_host_attributes(server_span, request.headers, request.path)
      match client_address {
        Some(address) =>
          server_span.set_attribute(
            @sdk.CLIENT_ADDRESS,
            @sdk.StringValue(address),
          )
        None => ()
      }
      match client_port {
        Some(port) =>
          server_span.set_attribute(
            @sdk.CLIENT_PORT,
            @sdk.IntValue(port.to_int64()),
          )
        None => ()
      }
      match request.headers.get(@http.CaseInsensitiveString("user-agent")) {
        Some(agent) =>
          server_span.set_attribute(
            @sdk.USER_AGENT_ORIGINAL,
            @sdk.StringValue(agent),
          )
        None => ()
      }
      match request_body_size(request.headers) {
        Some(size) =>
          if size > 0L {
            server_span.set_attribute(
              @sdk.HTTP_REQUEST_BODY_SIZE,
              @sdk.IntValue(size),
            )
          }
        None => ()
      }
      @http_header_capture.HeaderCapture::from_env(
        @http_header_capture.ENV_SERVER_REQUEST_HEADERS,
      ).record_request(request.headers, server_span)
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
  // A handler that asked to close the connection without responding leaves
  // no response to wait for: close the socket now. (When it did respond,
  // `respond` has already closed the socket.)
  if call.connection_closed && !call.responded {
    call.connection.close()
  }
  match outcome {
    Ok(_) => call
    Err(error) => {
      match span {
        Some(server_span) => {
          let type_name = error.to_string()
          server_span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(type_name))
          server_span.set_status(@api.StatusCode::Error, description=type_name)
          server_span.record_exception(error)
        }
        None => ()
      }
      raise error
    }
  }
}

// Host part of a socket address, without the port and without the IPv6
// brackets, for the `client.address` attribute.

///|
fn client_host_string(addr : @socket.Addr) -> String {
  let text = addr.to_string()
  if addr.is_ipv6() {
    match text.find("]") {
      Some(close) =>
        if text.length() > 0 && text.unsafe_get(0).unsafe_to_char() == '[' {
          text[1:close].to_owned()
        } else {
          text
        }
      None => text
    }
  } else {
    match text.rev_find(":") {
      Some(colon) => text[:colon].to_owned()
      None => text
    }
  }
}

// Like `run_server`, but the address of the peer of each TCP connection is
// recorded as `client.address` and `client.port` on the SERVER span.
//
// `@http.Server::run_forever` does not expose the peer address of a
// connection, so this entry point drives the connection loop itself with
// `@socket.TcpServer`. The handler must send exactly one response per request
// (usually via `ServerCall::respond`); when it returns without having
// responded, the connection is closed so that a half-written response is
// never followed by another request.

///|
pub async fn run_server_with_client_address(
  addr : @socket.Addr,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  let server = @socket.TcpServer(addr)
  run_server_with_client_address_on(
    server,
    handler,
    tracer?,
    allow_failure?,
    max_connections?,
  )
}

// Like `run_server_with_client_address`, but on an already constructed TCP
// server (for example one bound to port 0 whose actual port was read from
// `server.addr`). The server is closed when `run_forever` returns.

///|
pub async fn run_server_with_client_address_on(
  server : @socket.TcpServer,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  let active_tracer : @sdk.Tracer? = match tracer {
    Some(value) => Some(value)
    None => default_tracer()
  }
  server.run_forever(allow_failure?, max_connections?) <| (tcp, peer_addr) => {
    let connection = @http.ServerConnection::new(tcp)
    let client_address = client_host_string(peer_addr)
    let client_port = peer_addr.port()
    for ;; {
      let request = connection.read_request()
      let call = serve_call(
        request,
        connection,
        connection,
        active_tracer,
        handler,
        Some(client_address),
        Some(client_port),
      )
      if call.connection_closed {
        break
      }
      if !call.responded {
        // The handler returned without finishing a response: close the
        // connection instead of leaving a partial response on the wire.
        connection.close()
        break
      }
    }
  }
}
