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

const INSTRUMENTATION_SCOPE : String = "yourname/otel/instrumentation/async_http_server"

fn default_tracer() -> @sdk.Tracer? {
  match @sdk.global_tracer_provider() {
    Some(provider) => Some(provider.get_tracer(INSTRUMENTATION_SCOPE))
    None => None
  }
}

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

fn status_reason(status_code : Int) -> String {
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

fn parse_port(text : StringView) -> Int {
  try {
    @string.parse_int(text)
  } catch {
    _ => -1
  }
}

fn split_path_query(path : String) -> (String, String) {
  match path.find("?") {
    Some(index) => (path[:index].to_owned(), path[index + 1:].to_owned())
    None => (path, "")
  }
}

// Parse the incoming W3C context of a request: `traceparent` (with a valid
// `tracestate`) and `baggage`. Request headers are already keyed
// case-insensitively.
fn extract_context_with_baggage(
  headers : Map[@http.CaseInsensitiveString, String]
) -> (@context.Context, Bool) {
  let mut context = @context.Context::root()
  match headers.get(
    @http.CaseInsensitiveString(@propagation.traceparent_header_name()),
  ) {
    Some(value) =>
      match @propagation.parse_traceparent(value) {
        Some(parsed) => {
          let mut span_context = parsed
          match headers.get(
            @http.CaseInsensitiveString(@propagation.tracestate_header_name()),
          ) {
            Some(state) =>
              match @propagation.parse_tracestate(state) {
                Some(normalized) =>
                  span_context = span_context.with_tracestate(normalized)
                None => ()
              }
            None => ()
          }
          context = context.with_span(span_context)
        }
        None => ()
      }
    None => ()
  }
  let mut has_baggage = false
  match headers.get(
    @http.CaseInsensitiveString(@propagation.baggage_header_name()),
  ) {
    Some(value) =>
      for entry in @propagation.parse_baggage(value) {
        has_baggage = true
        let (key, item_value) = entry
        context = context.with_value(key, item_value)
      }
    None => ()
  }
  (context, has_baggage)
}

pub fn extract_context(
  headers : Map[@http.CaseInsensitiveString, String]
) -> @context.Context {
  extract_context_with_baggage(headers).0
}

// Parse the W3C `traceparent` header of an incoming request, if present.
pub fn extract_parent(
  headers : Map[@http.CaseInsensitiveString, String]
) -> @api.SpanContext? {
  extract_context(headers).span_context()
}

fn record_host_attributes(
  span : @sdk.SpanSdk,
  headers : Map[@http.CaseInsensitiveString, String]
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

fn end_span(span : @sdk.SpanSdk?) -> Unit {
  match span {
    Some(value) => value.end()
    None => ()
  }
}

// An instrumented server request: the request, its body, the connection to
// respond on, the SERVER span and the tracer that created it (both absent when
// tracing is disabled).
pub(all) struct ServerCall {
  request : @http.Request
  body : &@io.Reader
  connection : @http.ServerConnection
  span : @sdk.SpanSdk?
  tracer : @sdk.Tracer?
}

// Upper-case HTTP method of the request.
pub fn ServerCall::http_method(self : ServerCall) -> String {
  http_method_name(self.request.meth)
}

// Request path, without the query string.
pub fn ServerCall::path(self : ServerCall) -> String {
  split_path_query(self.request.path).0
}

// Request query string, without the leading `?`.
pub fn ServerCall::query(self : ServerCall) -> String {
  split_path_query(self.request.path).1
}

// Look up a request header by name.
pub fn ServerCall::header(self : ServerCall, name : String) -> String? {
  self.request.headers.get(@http.CaseInsensitiveString(name))
}

// The span context of the SERVER span, if tracing is enabled.
pub fn ServerCall::span_context(self : ServerCall) -> @api.SpanContext? {
  match self.span {
    Some(span) => Some(span.context())
    None => None
  }
}

// Record the matched route on the SERVER span. Following the HTTP semantic
// conventions the span is renamed to `METHOD route` and the route is stored as
// the `http.route` attribute. Returns `false` when tracing is disabled.
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
pub fn ServerCall::start_span(
  self : ServerCall,
  name : String,
  kind? : @api.SpanKind,
  attributes? : Map[String, @sdk.AttributeValue]
) -> @sdk.SpanSdk? {
  match (self.tracer, self.span) {
    (Some(tracer), Some(server_span)) =>
      Some(
        tracer.start_span(
          name,
          kind?=kind,
          parent=server_span.context(),
          attributes?=attributes,
        ),
      )
    _ => None
  }
}

// Send a response and record `http.response.status_code` on the SERVER span.
// 5xx responses set the span status to `Error`. The body, when present, is
// written before the response is ended.
pub async fn ServerCall::respond(
  self : ServerCall,
  status_code : Int,
  reason? : String,
  body? : String,
  headers? : Map[String, String]
) -> Unit {
  let extra_headers : @http.Headers = Map([])
  match headers {
    Some(values) =>
      values.each(fn(key, value) {
        extra_headers.set(@http.CaseInsensitiveString(key), value)
      })
    None => ()
  }
  self.connection.send_response(
    status_code,
    reason.unwrap_or(status_reason(status_code)),
    extra_headers=extra_headers,
  )
  match body {
    Some(text) => self.connection.write(text)
    None => ()
  }
  self.connection.end_response()
  match self.span {
    Some(span) => {
      span.set_attribute(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
        @sdk.IntValue(status_code.to_int64()),
      )
      if status_code >= 500 {
        span.set_attribute(
          @sdk.ERROR_TYPE,
          @sdk.StringValue(status_code.to_string()),
        )
        span.set_status(
          @api.StatusCode::Error,
          description=status_code.to_string(),
        )
      }
    }
    None => ()
  }
}

// Run an HTTP server that traces every request. The handler receives a
// `ServerCall` and is responsible for sending exactly one response (usually
// via `ServerCall::respond`).
pub async fn run_server(
  addr : @socket.Addr,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int
) -> Unit {
  let server = @http.Server(addr)
  defer server.close()
  run_server_on(server, handler, tracer?=tracer, allow_failure?=allow_failure, max_connections?=max_connections)
}

// Like `run_server`, but on an already constructed server (for example one
// bound to port 0 whose actual port was read from `server.addr`). The caller
// keeps ownership of `server`.
pub async fn run_server_on(
  server : @http.Server,
  handler : async (ServerCall) -> Unit,
  tracer? : @sdk.Tracer,
  allow_failure? : Bool,
  max_connections? : Int
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
            tracer.start_span(
              method_name,
              kind=@api.SpanKind::Server,
              parent?=parent,
            ),
          )
        None => None
      }
      let call : ServerCall = { request, body, connection, span, tracer: active_tracer, }
      match span {
        Some(server_span) => {
          server_span.set_attribute(
            @sdk.HTTP_REQUEST_METHOD,
            @sdk.StringValue(method_name),
          )
          let (path, query) = split_path_query(request.path)
          server_span.set_attribute(@sdk.URL_PATH, @sdk.StringValue(path))
          if query != "" {
            server_span.set_attribute(@sdk.URL_QUERY, @sdk.StringValue(query))
          }
          server_span.set_attribute(
            @sdk.CLIENT_ADDRESS,
            @sdk.StringValue(connection.client_addr().to_string()),
          )
          record_host_attributes(server_span, request.headers)
        }
        None => ()
      }
      let attached : @context.Context? = match span {
        Some(server_span) =>
          Some(
            @context.attach(
              parent_context.with_span(server_span.context()),
            ),
          )
        None =>
          if parent_has_baggage {
            Some(@context.attach(parent_context))
          } else {
            None
          }
      }
      defer (
        match attached {
          Some(previous) => @context.detach(previous)
          None => ()
        }
      )
      defer end_span(span)
      let outcome = try {
        Ok(handler(call))
      } catch {
        error => Err(error)
      }
      match outcome {
        Ok(_) => ()
        Err(error) => {
          match span {
            Some(server_span) => {
              server_span.set_status(
                @api.StatusCode::Error,
                description=error.to_string(),
              )
              server_span.record_exception(error)
            }
            None => ()
          }
          raise error
        }
      }
    },
    allow_failure?=allow_failure,
    max_connections?=max_connections,
  )
}
