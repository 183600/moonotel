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

fn default_tracer() -> @sdk.Tracer? {
  match @sdk.global_tracer_provider() {
    Some(provider) => Some(provider.get_tracer(INSTRUMENTATION_SCOPE))
    None => None
  }
}

// Upper-case name of a request method, as required by the semantic
// conventions (`http.request.method`).
pub fn http_method_name(method : @http.RequestMethod) -> String {
  match method {
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

// Best-effort split of an absolute URL into (host, port). The port falls back
// to the scheme default when it is not explicit; malformed URLs yield
// `(host, -1)` and are still traced.
pub fn split_url(url : String) -> (String, Int) {
  let after_scheme = match url.find("://") {
    Some(index) => url[index + 3:]
    None => url
  }
  let default_port = if url.has_prefix("https://") { 443 } else { 80 }
  let authority = match after_scheme.find("/") {
    Some(index) => after_scheme[:index]
    None => after_scheme
  }
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
        (host, port)
      }
      None => (host_port.to_owned(), default_port)
    }
  } else {
    match host_port.find(":") {
      Some(colon) =>
        (host_port[:colon].to_owned(), parse_port(host_port[colon + 1:]))
      None => (host_port.to_owned(), default_port)
    }
  }
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
  span_context : @api.SpanContext
) -> Map[@http.CaseInsensitiveString, String] {
  let out = plain_headers(headers)
  if span_context.is_valid() {
    out.set(
      @http.CaseInsensitiveString("traceparent"),
      @propagation.format_traceparent(span_context),
    )
  }
  out
}

// Perform a traced HTTP request. The response headers, the fully read
// response body and the client span are returned; the span is ended before
// this function returns.
pub async fn request(
  url : String,
  method : @http.RequestMethod,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String
) -> (@http.Response, &@io.Data) {
  let active_tracer : @sdk.Tracer? = match tracer {
    Some(value) => Some(value)
    None => default_tracer()
  }
  match active_tracer {
    None => @http.request(url, method, plain_headers(headers), body)
    Some(tracer) => {
      let method_name = http_method_name(method)
      let span = tracer.start_span(
        span_name.unwrap_or(method_name),
        kind=@api.SpanKind::Client,
        parent?=@context.current_span_context(),
      )
      defer span.end()
      span.set_attribute(@sdk.HTTP_REQUEST_METHOD, @sdk.StringValue(method_name))
      span.set_attribute(@sdk.URL_FULL, @sdk.StringValue(url))
      let (host, port) = split_url(url)
      span.set_attribute(@sdk.SERVER_ADDRESS, @sdk.StringValue(host))
      span.set_attribute(@sdk.SERVER_PORT, @sdk.IntValue(port.to_int64()))
      let result = try {
        @http.request(url, method, traced_headers(headers, span.context()), body)
      } catch {
        error => {
          span.set_status(@api.StatusCode::Error, description=error.to_string())
          span.record_exception(error)
          raise error
        }
      }
      let (response, response_body) = result
      span.set_attribute(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
        @sdk.IntValue(response.code.to_int64()),
      )
      if response.code >= 400 {
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
  span_name? : String
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Get,
    b"",
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
  )
}

// Traced `POST` request.
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Post,
    body,
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
  )
}

// Traced `PUT` request.
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Put,
    body,
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
  )
}

// Traced `DELETE` request.
pub async fn delete(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Delete,
    b"",
    headers?=headers,
    tracer?=tracer,
    span_name?=span_name,
  )
}
