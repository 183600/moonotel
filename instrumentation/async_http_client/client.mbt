// Tracing instrumentation for `moonbitlang/async/http` client requests.
//
// Every request starts a CLIENT span, injects the current context through the
// process-wide propagator (the W3C `traceparent` header and `baggage` by
// default) so the downstream service can continue the trace, and records the
// stable HTTP semantic-convention attributes. The span ends once the response
// body has been fully read.
//
// When no TracerProvider has been installed (see
// `@sdk.set_global_tracer_provider` / `183600/moonotel` setup) or no tracer is
// passed explicitly, requests are performed untraced.

///|
const INSTRUMENTATION_SCOPE : String = "183600/moonotel/instrumentation/async_http_client"

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

// The tracer derived from the global provider, stored together with the
// provider it was built from. Tracers are immutable; a tracer is derived again
// when the global provider is replaced.

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

// Parse a valid absolute URL scheme. Returns the lower-cased scheme and the
// index just past its `://` separator, or `None` when the text before `://`
// is not a valid scheme. A `://` after an invalid scheme is part of a relative
// URL, not an authority delimiter.

///|
fn parse_url_scheme(url : String) -> (String, Int32?) {
  match url.find("://") {
    Some(index) =>
      if index == 0 {
        ("", None)
      } else {
        let candidate = url[:index]
        if !is_alpha(candidate.unsafe_get(0).unsafe_to_char()) {
          ("", None)
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
            (sb.to_string(), Some(index + 3))
          } else {
            ("", None)
          }
        }
      }
    None => ("", None)
  }
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

// Split the path and query components of a URL. The fragment is dropped and
// the query is returned without its leading `?`. An URL without a path yields
// an empty path; callers apply the semantic conventions default.

///|
fn split_url_path_query(url : String) -> (String, String) {
  // A network-path reference (`//authority/path`) carries an authority even
  // though it has no scheme, so it must be stripped just like an absolute
  // URL's authority. Otherwise `url.path` would include (and leak) userinfo.
  let rest = if url.has_prefix("//") {
    let after_authority = url[2:]
    after_authority[find_authority_end(after_authority):]
  } else {
    match parse_url_scheme(url).1 {
      Some(index) => {
        let after_scheme = url[index:]
        after_scheme[find_authority_end(after_scheme):]
      }
      None => url[:]
    }
  }
  let without_fragment = match rest.find("#") {
    Some(index) => rest[:index]
    None => rest
  }
  match without_fragment.find("?") {
    Some(index) =>
      (
        without_fragment[:index].to_owned(),
        without_fragment[index + 1:].to_owned(),
      )
    None => (without_fragment.to_owned(), "")
  }
}

// Split an absolute URL into (scheme, host, port). The scheme is "" when the
// URL has no valid scheme; the port falls back to the scheme default when it
// is not explicit; an explicit but unparsable port yields -1.

///|
fn split_url_parts(url : String) -> (String, String, Int32) {
  let (scheme, scheme_end) = parse_url_scheme(url)
  let after_scheme = match scheme_end {
    Some(index) => url[index:]
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
          Some(colon) =>
            // RFC 3986 allows an empty port, which denotes the scheme's
            // default port (e.g. `https://example.com:/path`).
            if colon + 1 == rest.length() {
              default_port
            } else {
              parse_port(rest[colon + 1:])
            }
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
          if colon + 1 == host_port.length() {
            default_port
          } else {
            parse_port(host_port[colon + 1:])
          },
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

// Strip the square brackets of a bracketed IPv6 literal so that
// `server.address` holds the bare address rather than the URI syntax.

///|
fn strip_ipv6_brackets(address : String) -> String {
  if address.has_prefix("[") && address.has_suffix("]") {
    address[1:address.length() - 1].to_owned()
  } else {
    address
  }
}

// Remove the `userinfo` (credentials) component from an absolute URL or a
// network-path reference (`//user:pass@host/path`). URLs without an authority
// or without userinfo are returned unchanged; `@` outside the authority (in a
// path, query or fragment) is preserved.

///|
fn strip_url_userinfo(url : String) -> String {
  let authority_start = if url.has_prefix("//") {
    Some(2)
  } else {
    match url.find("://") {
      Some(index) =>
        // A `://` sequence only introduces an authority after a valid scheme;
        // otherwise it is part of a relative path and must be preserved.
        if split_scheme(url) == "" {
          None
        } else {
          Some(index + 3)
        }
      None => None
    }
  }
  let authority_start = match authority_start {
    Some(value) => value
    None => return url
  }
  let rest = url[authority_start:]
  let authority_end = find_authority_end(rest)
  let authority = rest[:authority_end]
  match authority.rev_find("@") {
    Some(at) => {
      let sb = StringBuilder(size_hint=url.length() * 2)
      sb.write_stringview(url[:authority_start])
      sb.write_stringview(authority[at + 1:])
      sb.write_stringview(rest[authority_end:])
      sb.to_string()
    }
    None => url
  }
}

// Redact known sensitive values in the query component, leaving the path and
// fragment untouched.

///|
fn redact_url_query(url : String) -> String {
  let fragment_start = match url.find("#") {
    Some(index) => index
    None => url.length()
  }
  let query_start = match url.find("?") {
    Some(index) => if index < fragment_start { index } else { return url }
    None => return url
  }
  let query_begin = query_start + 1
  let query = url[query_begin:fragment_start].to_owned()
  let redacted = @sdk.redact_sensitive_query_string(query)
  let sb = StringBuilder(size_hint=url.length())
  sb.write_stringview(url[:query_begin])
  sb.write_string(redacted)
  sb.write_stringview(url[fragment_start:])
  sb.to_string()
}

// Sanitize an absolute URL or network-path reference for the `url.full`
// attribute: remove the `userinfo` (credentials) component and redact known
// sensitive query parameter values. The fragment is preserved, as the HTTP
// semantic conventions require.

///|
pub fn redact_url(url : String) -> String {
  redact_url_query(strip_url_userinfo(url))
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

// Replace unpaired UTF-16 surrogates with U+FFFD so that request header
// strings can always be encoded as UTF-8. Well-formed strings are returned
// unchanged.

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
        // Header strings are written as UTF-8 by the transport; replace
        // unpaired surrogates instead of aborting the request.
        out.set(
          @http.CaseInsensitiveString(sanitize_utf16_surrogates(key)),
          sanitize_utf16_surrogates(value),
        )
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
  // `tracestate` and `baggage`). The carrier reads and writes `out` directly.
  let carrier = @propagation.TextMapCarrier::from_getter_setter(
    fn(key) { out.get(@http.CaseInsensitiveString(key)) },
    fn(key, value) { out.set(@http.CaseInsensitiveString(key), value) },
    remove=fn(key) { out.remove(@http.CaseInsensitiveString(key)) },
  )
  @propagation.global_propagator().inject(
    context.with_span(span_context),
    carrier,
  )
  out
}

// Split an absolute URL into the origin (`scheme://authority`) and the
// request target (path and query). The fragment is not sent on the wire.
// Values that do not have a valid `scheme://` prefix are passed to the HTTP
// client unchanged so that it reports the same URL error as `@http.request`.

///|
fn split_url_for_transport(url : String) -> (String, String) {
  match parse_url_scheme(url).1 {
    Some(scheme_end) => {
      let after_scheme = url[scheme_end:]
      let authority_end = find_authority_end(after_scheme)
      let origin = url[:scheme_end + authority_end].to_owned()
      let rest = after_scheme[authority_end:]
      let without_fragment = match rest.find("#") {
        Some(index) => rest[:index]
        None => rest
      }
      let target = if without_fragment.length() == 0 {
        "/"
      } else if without_fragment.unsafe_get(0).unsafe_to_char() == '?' {
        // An absolute URL without a path is sent to the root path, with the
        // query preserved.
        "/" + without_fragment.to_owned()
      } else {
        without_fragment.to_owned()
      }
      (origin, target)
    }
    None => (url, "/")
  }
}

// Send one request through the streaming HTTP client and return the response
// together with the client that still owns the unread body. On failure the
// client is closed before the error propagates; on success the caller owns it.

///|
async fn open_request(
  url : String,
  request_method : @http.RequestMethod,
  headers : @http.Headers,
  body : Bytes,
) -> (@http.Response, @http.Client) {
  let (origin, target) = split_url_for_transport(url)
  let client = @http.Client(origin, headers~)
  errdefer client.close()
  client.request(request_method, target)
  client.write(body)
  let response = client.end_request()
  (response, client)
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
        let host = strip_ipv6_brackets(host)
        // A relative reference has no authority, so it has no known server
        // address or port. Do not turn its first path segment into fabricated
        // `server.*` attributes.
        if host != "" {
          span.set_attribute(@sdk.SERVER_ADDRESS, @sdk.StringValue(host))
          // `-1` marks an invalid explicit port; port 0 is a valid explicit
          // value and must still be recorded.
          if port >= 0 {
            span.set_attribute(@sdk.SERVER_PORT, @sdk.IntValue(port.to_int64()))
          }
        }
      }
      let (url_path, url_query) = split_url_path_query(url)
      span.set_attribute(
        @sdk.URL_PATH,
        @sdk.StringValue(if url_path == "" { "/" } else { url_path }),
      )
      let url_query = @sdk.redact_sensitive_query_string(url_query)
      if url_query != "" {
        span.set_attribute(@sdk.URL_QUERY, @sdk.StringValue(url_query))
      }
      let sent_headers = traced_headers(
        headers,
        span.context(),
        request_context,
      )
      let outcome = try {
        Ok(open_request(url, request_method, sent_headers, request_body))
      } catch {
        error => Err(error)
      }
      // Capture after the request attempt: the HTTP client adds headers that
      // are not in the caller's map (at least `Host` and `User-Agent`) by
      // mutating it, and the captured attributes must describe the headers
      // actually sent, including on a failed request.
      let request_capture = @http_header_capture.HeaderCapture::from_env(
        @http_header_capture.ENV_CLIENT_REQUEST_HEADERS,
      )
      request_capture.record_request(sent_headers, span)
      let (response, client) = match outcome {
        Ok(result) => result
        Err(error) => {
          let type_name = error.to_string()
          span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(type_name))
          span.set_status(@api.StatusCode::Error, description=type_name)
          span.record_exception(error)
          raise error
        }
      }
      defer client.close()
      // Record the response status and headers as soon as the response starts
      // arriving. A failure while reading the body (for example a truncated
      // Content-Length) must not erase the status that was actually received.
      @http_header_capture.HeaderCapture::from_env(
        @http_header_capture.ENV_CLIENT_RESPONSE_HEADERS,
      ).record_response(response.headers, span)
      span.set_attribute(
        @sdk.HTTP_RESPONSE_STATUS_CODE,
        @sdk.IntValue(response.code.to_int64()),
      )
      if response.code >= 400 {
        let status_text = response.code.to_string()
        span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(status_text))
        span.set_status(@api.StatusCode::Error)
      }
      let body_outcome = try {
        Ok(client.read_all())
      } catch {
        error => Err(error)
      }
      let response_body = match body_outcome {
        Ok(body) => body
        Err(error) => {
          let type_name = error.to_string()
          span.set_attribute(@sdk.ERROR_TYPE, @sdk.StringValue(type_name))
          span.set_status(@api.StatusCode::Error, description=type_name)
          span.record_exception(error)
          raise error
        }
      }
      // The response body has been fully read, so its size is always known.
      let response_size = response_body.binary().length()
      if response_size > 0 {
        span.set_attribute(
          @sdk.HTTP_RESPONSE_BODY_SIZE,
          @sdk.IntValue(response_size.to_int64()),
        )
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

// Traced `TRACE` request (no request body).

///|
pub async fn trace(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Trace,
    b"",
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}

// Traced `CONNECT` request (no request body).

///|
pub async fn connect(
  url : String,
  headers? : Map[String, String],
  tracer? : @sdk.Tracer,
  span_name? : String,
  context? : @context.Context,
) -> (@http.Response, &@io.Data) {
  request(
    url,
    @http.RequestMethod::Connect,
    b"",
    headers?,
    tracer?,
    span_name?,
    context?,
  )
}
