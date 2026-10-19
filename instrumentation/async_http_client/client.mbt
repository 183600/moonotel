// Tracing instrumentation for `moonbitlang/async/http` client requests.
//
// Every request starts a CLIENT span, injects the current context through the
// process-wide propagator (the W3C `traceparent` header and `baggage` by
// default) so the downstream service can continue the trace, and records the
// stable HTTP semantic-convention attributes. The span ends once the response
// body has been fully read.
//
// When no TracerProvider has been installed (see
// `@sdk.set_global_tracer_provider` / `yourname/otel` setup) or no tracer is
// passed explicitly, requests are performed untraced.

///|
const INSTRUMENTATION_SCOPE : String = "yourname/otel/instrumentation/async_http_client"

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

// The tracer derived from the global provider, cached together with the
// provider it was built from. Tracers are immutable, so the request path can
// reuse one until the global provider is replaced.

///|
let default_tracer_cache : Ref[(@sdk.TracerProviderSdk, @sdk.Tracer)?] = Ref(
  None,
)

///|
fn default_tracer() -> @sdk.Tracer? {
  match @sdk.global_tracer_provider() {
    Some(provider) => {
      match default_tracer_cache.val {
        Some((cached_provider, tracer)) =>
          if physical_equal(cached_provider, provider) {
            return Some(tracer)
          }
        None => ()
      }
      let tracer = provider.get_tracer(INSTRUMENTATION_SCOPE)
      default_tracer_cache.val = Some((provider, tracer))
      Some(tracer)
    }
    None => {
      if default_tracer_cache.val is Some(_) {
        default_tracer_cache.val = None
      }
      None
    }
  }
}

// Upper-case name of a request method, as required by the semantic
// conventions (`http.request.method`).

///|
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

///|
fn parse_port(text : StringView) -> Int32 {
  @string.parse_int(text) catch {
    _ => -1
  }
}

///|
fn ascii_to_lower(c : Char) -> Char {
  let code = c.to_int()
  if code >= 65 && code <= 90 {
    (code + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn is_scheme_char(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  c == '+' ||
  c == '-' ||
  c == '.'
}

///|
fn is_alpha(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

// The authority of an absolute URL ends at the first `/` (path), `?` (query)
// or `#` (fragment), or at the end of the string.

///|
fn find_authority_end(text : StringView) -> Int32 {
  let len = text.length()
  let mut i = 0
  while i < len {
    let c = text.unsafe_get(i).unsafe_to_char()
    if c == '/' || c == '?' || c == '#' {
      return i
    }
    i = i + 1
  }
  len
}

// Split an absolute URL into (scheme, host, port). The scheme is "" when the
// URL has no valid scheme; the port falls back to the scheme default when it
// is not explicit; an explicit but unparsable port yields -1.

///|
fn split_url_parts(url : String) -> (String, String, Int32) {
  let scheme_index = url.find("://")
  let scheme = match scheme_index {
    Some(index) =>
      if index == 0 {
        ""
      } else {
        let candidate = url[:index]
        if !is_alpha(candidate.unsafe_get(0).unsafe_to_char()) {
          ""
        } else {
          let sb = StringBuilder(size_hint=index * 2)
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
    None => ""
  }
  let after_scheme = match scheme_index {
    Some(index) => url[index + 3:]
    None => url
  }
  let default_port = if scheme == "https" { 443 } else { 80 }
  let authority_end = find_authority_end(after_scheme)
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
        (
          scheme,
          host_port[:colon].to_owned(),
          parse_port(host_port[colon + 1:]),
        )
      None => (scheme, host_port.to_owned(), default_port)
    }
  }
}

// Lower-case scheme of an absolute URL, without the `://` separator.
// Returns "" when the URL has no scheme or the text before `://` is not a
// valid scheme.

///|
pub fn split_scheme(url : String) -> String {
  split_url_parts(url).0
}

// Best-effort split of an absolute URL into (host, port). The port falls back
// to the scheme default when it is not explicit; an explicit but unparsable
// port yields -1 and the URL is still traced.

///|
pub fn split_url(url : String) -> (String, Int32) {
  let (_, host, port) = split_url_parts(url)
  (host, port)
}

// Remove the `userinfo` (credentials) component from an absolute URL, as
// required by the HTTP semantic conventions for the `url.full` attribute.
// URLs without an authority or without userinfo are returned unchanged;
// `@` outside the authority (in a path, query or fragment) is preserved.

///|
pub fn redact_url(url : String) -> String {
  let scheme_end = match url.find("://") {
    Some(index) => index + 3
    None => return url
  }
  let rest = url[scheme_end:]
  let authority_end = find_authority_end(rest)
  let authority = rest[:authority_end]
  match authority.rev_find("@") {
    Some(at) => {
      let sb = StringBuilder(size_hint=url.length() * 2)
      sb.write_stringview(url[:scheme_end])
      sb.write_stringview(authority[at + 1:])
      sb.write_stringview(rest[authority_end:])
      sb.to_string()
    }
    None => url
  }
}

///|
fn map_capacity_for_entries(entries : Int) -> Int {
  let capacity = entries.next_power_of_two()
  if entries > capacity * 13 / 16 {
    capacity * 2
  } else {
    capacity
  }
}

///|
fn plain_headers(
  headers : Map[String, String]?,
  extra? : Int32,
) -> Map[@http.CaseInsensitiveString, String] {
  let extra = extra.unwrap_or(0)
  match headers {
    Some(values) => {
      let total = values.length() + extra
      let out = Map([], capacity=map_capacity_for_entries(total))
      for key, value in values {
        out.set(@http.CaseInsensitiveString(key), value)
      }
      out
    }
    None => Map([], capacity=map_capacity_for_entries(extra + 1))
  }
}

///|
fn traced_headers(
  headers : Map[String, String]?,
  span_context : @api.SpanContext,
  context : @context.Context,
) -> Map[@http.CaseInsensitiveString, String] {
  let out = plain_headers(headers, extra=3)
  // Inject through the process-wide propagator so that the headers written are
  // the ones selected by `OTEL_PROPAGATORS` (by default `traceparent`,
  // `tracestate` and `baggage`). The carrier reads and writes `out` directly,
  // so no intermediate map or second copy is needed for the injected headers.
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(key) { out.get(@http.CaseInsensitiveString(key)) },
    fn(key, value) { out.set(@http.CaseInsensitiveString(key), value) },
  )
  @propagation.global_propagator().inject(
    context.with_span(span_context),
    carrier,
  )
  out
}

// Perform a traced HTTP request. The response headers, the fully read
// response body and the client span are returned; the span is ended before
// this function returns.
//
// The parent span and baggage are taken from `context` when given, and from
// the current context otherwise.

///|
pub async fn request(
  url : String,
  request_method : @http.RequestMethod,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
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
      // The request body is in memory, so its size is always known. It is
      // encoded once and the resulting bytes are passed to the transport.
      let request_body : Bytes = body.binary()
      let request_size = request_body.length()
      if request_size > 0 {
        span.set_attribute(
          @sdk.HTTP_REQUEST_BODY_SIZE,
          @sdk.IntValue(request_size.to_int64()),
        )
      }
      // `url.full` must not leak credentials: strip the userinfo component.
      span.set_attribute(@sdk.URL_FULL, @sdk.StringValue(redact_url(url)))
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
      if port > 0 {
        span.set_attribute(@sdk.SERVER_PORT, @sdk.IntValue(port.to_int64()))
      }
      let outcome = Ok(
        @http.request(
          url,
          request_method,
          traced_headers(headers, span.context(), request_context),
          request_body,
        ),
      ) catch {
        error => Err(error)
      }
      let (response, response_body) = match outcome {
        Ok(result) => result
        Err(error) => {
          let type_name = error.to_string()
          span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(type_name))
          span.set_status(@api.StatusCode::Error, description=type_name)
          span.record_exception(error)
          raise error
        }
      }
      span.set_attribute(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
        @sdk.IntValue(response.code.to_int64()),
      )
      // The response body has been fully read, so its size is always known.
      let response_size = response_body.binary().length()
      if response_size > 0 {
        span.set_attribute(
          @sdk.HTTP_RESPONSE_BODY_SIZE,
          @sdk.IntValue(response_size.to_int64()),
        )
      }
      if response.code >= 400 {
        let status_text = response.code.to_string()
        span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(status_text))
        span.set_status(@api.StatusCode::Error, description=status_text)
      }
      (response, response_body)
    }
  }
}

// Traced `GET` request (no request body).

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Get,
    b"",
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `POST` request.

///|
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Post,
    body,
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `PUT` request.

///|
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Put,
    body,
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `DELETE` request.

///|
pub async fn delete(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Delete,
    b"",
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `HEAD` request (no request body).

///|
pub async fn head(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Head,
    b"",
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `PATCH` request.

///|
pub async fn patch(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Patch,
    body,
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `OPTIONS` request (no request body).

///|
pub async fn options(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Options,
    b"",
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}
