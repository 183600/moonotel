// Tracing instrumentation for `moonbitlang/async/http` client requests.
//
// Every request starts a CLIENT span, injects the W3C `traceparent` header so
// the downstream service can continue the trace, and records the stable HTTP
// semantic-convention attributes. The span ends when the response headers are
// available.
//
// When no TracerProvider has been installed (see
// `@sdk.set_global_tracer_provider` / `yourname/otel` setup) or no tracer is
// passed explicitly, requests are performed untraced.

const INSTRUMENTATION_SCOPE : String = "yourname/otel/instrumentation/async_http_client"

// Immutable attribute values reused by every request so that the constant
// semantic-convention attributes do not allocate per request.
let protocol_name_http : @sdk.AttributeValue = @sdk.StringValue("http")
let protocol_version_http_1_1 : @sdk.AttributeValue = @sdk.StringValue("1.1")
let method_get : @sdk.AttributeValue = @sdk.StringValue("GET")
let method_head : @sdk.AttributeValue = @sdk.StringValue("HEAD")
let method_post : @sdk.AttributeValue = @sdk.StringValue("POST")
let method_put : @sdk.AttributeValue = @sdk.StringValue("PUT")
let method_delete : @sdk.AttributeValue = @sdk.StringValue("DELETE")
let method_connect : @sdk.AttributeValue = @sdk.StringValue("CONNECT")
let method_options : @sdk.AttributeValue = @sdk.StringValue("OPTIONS")
let method_trace : @sdk.AttributeValue = @sdk.StringValue("TRACE")
let method_patch : @sdk.AttributeValue = @sdk.StringValue("PATCH")

fn method_attribute_value(request_method : @http.RequestMethod) -> @sdk.AttributeValue {
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

fn default_tracer() -> @sdk.Tracer? {
  match @sdk.global_tracer_provider() {
    Some(provider) => Some(provider.get_tracer(INSTRUMENTATION_SCOPE))
    None => None
  }
}

// Upper-case name of a request method, as required by the semantic
// conventions (`http.request.method`).
pub fn http_method_name(request_method : @http.RequestMethod) -> String {
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

fn parse_port(text : StringView) -> Int {
  try {
    @string.parse_int(text)
  } catch {
    _ => -1
  }
}

fn ascii_to_lower(c : Char) -> Char {
  let code = c.to_int()
  if code >= 65 && code <= 90 {
    (code + 32).unsafe_to_char()
  } else {
    c
  }
}

fn is_scheme_char(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  c == '+' ||
  c == '-' ||
  c == '.'
}

fn is_alpha(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

// Split an absolute URL into (scheme, host, port) in a single pass. The scheme
// is "" when the URL has no valid scheme; the port falls back to the scheme
// default when it is not explicit; malformed URLs yield `(host, -1)`.
fn split_url_parts(url : String) -> (String, String, Int) {
  let scheme_index = url.find("://")
  let scheme = match scheme_index {
    Some(index) => {
      if index == 0 {
        ""
      } else {
        let candidate = url[:index]
        if !is_alpha(candidate.unsafe_get(0).unsafe_to_char()) {
          ""
        } else {
          let sb = StringBuilder(size_hint=index)
          let mut valid = true
          let mut i = 0
          while i < index {
            let c = candidate.unsafe_get(i).unsafe_to_char()
            if !is_scheme_char(c) {
              valid = false
              break
            }
            sb.write_char(ascii_to_lower(c))
            i = i + 1
          }
          if valid {
            sb.to_string()
          } else {
            ""
          }
        }
      }
    }
    None => ""
  }
  let after_scheme = match scheme_index {
    Some(index) => url[index + 3:]
    None => url
  }
  let default_port = if scheme == "https" { 443 } else { 80 }
  // The authority ends at the first `/` (path), `?` (query) or `#` (fragment).
  let mut authority_end = after_scheme.length()
  match after_scheme.find("/") {
    Some(index) => authority_end = index
    None => ()
  }
  match after_scheme.find("?") {
    Some(index) => if index < authority_end { authority_end = index }
    None => ()
  }
  match after_scheme.find("#") {
    Some(index) => if index < authority_end { authority_end = index }
    None => ()
  }
  let authority = after_scheme[:authority_end]
  let host_port = match authority.rev_find("@") {
    Some(index) => authority[index + 1:]
    None => authority
  }
  if host_port.has_prefix("[") {
    match host_port.find("]") {
      Some(close) => {
        let host = host_port[:close + 1].to_owned()
        let rest = host_port[close + 1:]
        let port = match rest.find(":") {
          Some(colon) => parse_port(rest[colon + 1:])
          None => default_port
        }
        (scheme, host, port)
      }
      None => (scheme, host_port.to_owned(), default_port)
    }
  } else {
    match host_port.find(":") {
      Some(colon) =>
        (scheme, host_port[:colon].to_owned(), parse_port(host_port[colon + 1:]))
      None => (scheme, host_port.to_owned(), default_port)
    }
  }
}

// Lower-case scheme of an absolute URL, without the `://` separator.
// Returns "" when the URL has no scheme or the text before `://` is not a
// valid scheme.
pub fn split_scheme(url : String) -> String {
  split_url_parts(url).0
}

// Best-effort split of an absolute URL into (host, port). The port falls back
// to the scheme default when it is not explicit; malformed URLs yield
// `(host, -1)` and are still traced.
pub fn split_url(url : String) -> (String, Int) {
  let (_, host, port) = split_url_parts(url)
  (host, port)
}

fn plain_headers(
  headers : Map[String, String]?
) -> Map[@http.CaseInsensitiveString, String] {
  let out = Map([])
  match headers {
    Some(values) =>
      values.each(fn(key, value) {
        out.set(@http.CaseInsensitiveString(key), value)
      })
    None => ()
  }
  out
}

fn traced_headers(
  headers : Map[String, String]?,
  span_context : @api.SpanContext,
  context : @context.Context
) -> Map[@http.CaseInsensitiveString, String] {
  let out = plain_headers(headers)
  if span_context.is_valid() {
    out.set(
      @http.CaseInsensitiveString(@propagation.traceparent_header_name()),
      @propagation.format_traceparent(span_context),
    )
    let tracestate = span_context.tracestate()
    if tracestate != "" {
      out.set(
        @http.CaseInsensitiveString(@propagation.tracestate_header_name()),
        tracestate,
      )
    }
  }
  match @propagation.context_baggage_header(context) {
    Some(value) =>
      out.set(
        @http.CaseInsensitiveString(@propagation.baggage_header_name()),
        value,
      )
    None => ()
  }
  out
}

// Perform a traced HTTP request. The response headers, the fully read
// response body and the client span are returned; the span is ended before
// this function returns.
//
// The parent span and baggage are taken from `context` when given, and from
// the current context otherwise.
pub async fn request(
  url : String,
  request_method : @http.RequestMethod,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  let active_tracer : @sdk.Tracer? = match tracer {
    Some(value) => Some(value)
    None => default_tracer()
  }
  match active_tracer {
    None => @http.request(url, request_method, plain_headers(headers), body)
    Some(tracer) => {
      let request_context : @context.Context = match context {
        Some(value) => value
        None => @context.current_context()
      }
      let method_name = http_method_name(request_method)
      let span = tracer.start_span(
        span_name.unwrap_or(method_name),
        kind=@api.SpanKind::Client,
        parent?=request_context.span_context(),
      )
      defer span.end()
      span.set_attribute(
        @sdk.HTTP_REQUEST_METHOD,
        method_attribute_value(request_method),
      )
      span.set_attribute(@sdk.URL_FULL, @sdk.StringValue(url))
      span.set_attribute(@sdk.NETWORK_PROTOCOL_NAME, protocol_name_http)
      // `moonbitlang/async/http` speaks HTTP/1.1 only.
      span.set_attribute(
        @sdk.NETWORK_PROTOCOL_VERSION,
        protocol_version_http_1_1,
      )
      let (scheme, host, port) = split_url_parts(url)
      if scheme != "" {
        span.set_attribute(@sdk.URL_SCHEME, @sdk.StringValue(scheme))
      }
      span.set_attribute(@sdk.SERVER_ADDRESS, @sdk.StringValue(host))
      span.set_attribute(@sdk.SERVER_PORT, @sdk.IntValue(port.to_int64()))
      let outcome = try {
        Ok(
          @http.request(
            url,
            request_method,
            traced_headers(headers, span.context(), request_context),
            body,
          ),
        )
      } catch {
        error => Err(error)
      }
      let (response, response_body) = match outcome {
        Ok(result) => result
        Err(error) => {
          span.set_status(@api.StatusCode::Error, description=error.to_string())
          span.record_exception(error)
          raise error
        }
      }
      span.set_attribute(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
        @sdk.IntValue(response.code.to_int64()),
      )
      if response.code >= 400 {
        span.set_attribute(
          @sdk.ERROR_TYPE,
          @sdk.StringValue(response.code.to_string()),
        )
        span.set_status(
          @api.StatusCode::Error,
          description=response.code.to_string(),
        )
      }
      (response, response_body)
    }
  }
}

// Traced `GET` request (no request body).
pub async fn get(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Get,
    b"",
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}

// Traced `POST` request.
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Post,
    body,
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}

// Traced `PUT` request.
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Put,
    body,
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}

// Traced `DELETE` request.
pub async fn delete(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Delete,
    b"",
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}

// Traced `HEAD` request (no request body).
pub async fn head(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Head,
    b"",
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}

// Traced `PATCH` request.
pub async fn patch(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Patch,
    body,
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}

// Traced `OPTIONS` request (no request body).
pub async fn options(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Options,
    b"",
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
    context?=context,
  )
}
