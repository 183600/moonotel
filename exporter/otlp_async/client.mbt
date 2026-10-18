// OTLP/HTTP exporter backed by the real `moonbitlang/async/http` client.
//
// This is the production transport counterpart of the injectable `Transport`
// used by `@otlp.OtlpHttpExporter`: it POSTs an encoded
// `ExportTraceServiceRequest` to `<endpoint>/v1/traces`, with
// `Content-Type: application/x-protobuf` (`http/protobuf`) or
// `application/json` (`http/json`), decodes the response (including
// `partial_success`) and retries only retryable HTTP statuses. Each attempt
// is bounded by `config.timeout_millis`.
//
// The package targets native only, because the async HTTP stack does.

///|
fn is_retryable_status(status_code : Int32) -> Bool {
  match status_code {
    429 | 502 | 503 | 504 => true
    _ => false
  }
}

///|
fn request_headers(
  config : @otlp.OtlpHttpConfig,
  gzip : Bool,
) -> Map[@http.CaseInsensitiveString, String] {
  let headers = Map([], capacity=(config.headers.length() + 2) * 2)
  config.headers.each(fn(key, value) {
    headers.set(@http.CaseInsensitiveString(key), value)
  })
  headers.set(
    @http.CaseInsensitiveString("content-type"),
    @otlp.content_type_for_protocol(config.protocol),
  )
  if gzip {
    headers.set(@http.CaseInsensitiveString("content-encoding"), "gzip")
  }
  headers
}

// Compress `data` with gzip. The encoder writes into an in-memory pipe that
// the returned reader drains.

///|
async fn gzip_compress(data : Bytes) -> Bytes {
  let reader = @io.MemoryReader() <| w => {
    let encoder = @gzip.Encoder(w)
    encoder.write(data)
    encoder.end()
  }
  defer reader.close()
  reader.read_all().binary()
}

// Parse two ASCII digits at `at` into their 0-99 value.

///|
fn http_date_two_digits(value : StringView, at : Int32) -> Int32? {
  let hi = value.unsafe_get(at).to_int()
  let lo = value.unsafe_get(at + 1).to_int()
  if hi < 0x30 || hi > 0x39 || lo < 0x30 || lo > 0x39 {
    return None
  }
  Some((hi - 0x30) * 10 + (lo - 0x30))
}

// Number of the month named by a three-letter abbreviation, or `None`.

///|
fn http_date_month(name : StringView) -> Int32? {
  if name == "Jan" {
    Some(1)
  } else if name == "Feb" {
    Some(2)
  } else if name == "Mar" {
    Some(3)
  } else if name == "Apr" {
    Some(4)
  } else if name == "May" {
    Some(5)
  } else if name == "Jun" {
    Some(6)
  } else if name == "Jul" {
    Some(7)
  } else if name == "Aug" {
    Some(8)
  } else if name == "Sep" {
    Some(9)
  } else if name == "Oct" {
    Some(10)
  } else if name == "Nov" {
    Some(11)
  } else if name == "Dec" {
    Some(12)
  } else {
    None
  }
}

// Number of days since the Unix epoch of a proleptic Gregorian date, using
// Howard Hinnant's `days_from_civil` algorithm.

///|
fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int64 {
  let y = if month <= 2 { year - 1 } else { year }
  let era = if y >= 0 { y / 400 } else { (y - 399) / 400 }
  let yoe = y - era * 400
  let mp = (month + 9) % 12
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  (era * 146097 + doe - 719468).to_int64()
}

// Parse the IMF-fixdate form of an HTTP date (`Sun, 06 Nov 1994 08:49:37 GMT`)
// into seconds since the Unix epoch. The obsolete RFC 850 and asctime forms
// and any other value yield `None`.

///|
fn parse_http_date_seconds(value : StringView) -> Int64? {
  // `Www, dd Mmm yyyy HH:MM:SS GMT` is exactly 29 characters.
  if value.length() != 29 {
    return None
  }
  let day_name = value.view(start_offset=0, end_offset=3)
  let known_day = day_name == "Mon" ||
    day_name == "Tue" ||
    day_name == "Wed" ||
    day_name == "Thu" ||
    day_name == "Fri" ||
    day_name == "Sat" ||
    day_name == "Sun"
  if !known_day ||
    value.unsafe_get(3).to_int() != 0x2C ||
    value.unsafe_get(4).to_int() != 0x20 ||
    value.unsafe_get(7).to_int() != 0x20 ||
    value.unsafe_get(11).to_int() != 0x20 ||
    value.unsafe_get(16).to_int() != 0x20 ||
    value.unsafe_get(19).to_int() != 0x3A ||
    value.unsafe_get(22).to_int() != 0x3A ||
    value.unsafe_get(25).to_int() != 0x20 ||
    value.unsafe_get(26).unsafe_to_char() != 'G' ||
    value.unsafe_get(27).unsafe_to_char() != 'M' ||
    value.unsafe_get(28).unsafe_to_char() != 'T' {
    return None
  }
  let day = match http_date_two_digits(value, 5) {
    Some(value) => value
    None => return None
  }
  let month = match http_date_month(value.view(start_offset=8, end_offset=11)) {
    Some(value) => value
    None => return None
  }
  let year = match http_date_two_digits(value, 12) {
    Some(high) =>
      match http_date_two_digits(value, 14) {
        Some(low) => high * 100 + low
        None => return None
      }
    None => return None
  }
  let hour = match http_date_two_digits(value, 17) {
    Some(value) => value
    None => return None
  }
  let minute = match http_date_two_digits(value, 20) {
    Some(value) => value
    None => return None
  }
  let second = match http_date_two_digits(value, 23) {
    Some(value) => value
    None => return None
  }
  if day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60 {
    return None
  }
  let days = days_from_civil(year, month, day)
  Some(days * 86400L + (hour * 3600 + minute * 60 + second).to_int64())
}

// Parse an HTTP `Retry-After` header value, which is either a non-negative
// number of seconds or an IMF-fixdate HTTP date (for example
// `Sun, 06 Nov 1994 08:49:37 GMT`). Returns the delay in milliseconds, capped
// at 60 seconds so that a misbehaving server cannot stall the exporter
// indefinitely. Dates in the past yield a zero delay; other values yield
// `None`.

///|
fn retry_after_millis(value : String) -> Int32? {
  let trimmed = value.trim()
  if trimmed == "" {
    return None
  }
  let parsed = Some(@string.parse_int(trimmed)) catch { _ => None }
  match parsed {
    Some(seconds) =>
      if seconds < 0 {
        None
      } else if seconds > 60 {
        Some(60000)
      } else {
        Some(seconds * 1000)
      }
    None =>
      // Not a delta-seconds value: many servers send an IMF-fixdate instead.
      match parse_http_date_seconds(trimmed[:]) {
        Some(epoch_seconds) => {
          let now_seconds = (@env.now() / 1000).reinterpret_as_int64()
          let delay_seconds = epoch_seconds - now_seconds
          if delay_seconds <= 0 {
            Some(0)
          } else if delay_seconds > 60 {
            Some(60000)
          } else {
            Some((delay_seconds * 1000).to_int())
          }
        }
        None => None
      }
  }
}

// POST an already encoded `ExportTraceServiceRequest` body to the configured
// trace endpoint and interpret the response. Both `http/protobuf` and
// `http/json` bodies are supported; the response is decoded with the matching
// encoding. Network errors and retryable statuses (429, 502, 503, 504) are
// retried up to `config.max_retries` times. The delay before a retry is taken
// from the response's `Retry-After` header when it holds a number of seconds
// or an HTTP date, and a short linear backoff is used otherwise. When
// `config.compression` is `gzip` the body is compressed once and sent with
// `Content-Encoding: gzip`.

///|
pub async fn post_trace_request(
  config : @otlp.OtlpHttpConfig,
  body : Bytes,
) -> @sdk.ExportResult {
  if !@otlp.is_supported_protocol(config.protocol) {
    return @sdk.ExportFailure("unsupported OTLP protocol: " + config.protocol)
  }
  let json = config.protocol == @otlp.OTLP_HTTP_JSON_PROTOCOL
  let gzip = config.compression == "gzip"
  if !gzip && config.compression != "none" {
    return @sdk.ExportFailure(
      "unsupported OTLP compression: " + config.compression,
    )
  }
  let body = if gzip {
    let compressed : Bytes? = Some(gzip_compress(body)) catch { _ => None }
    match compressed {
      Some(payload) => payload
      None =>
        return @sdk.ExportFailure(
          "failed to gzip-compress the OTLP request body",
        )
    }
  } else {
    body
  }
  let url = config.traces_url()
  let headers = request_headers(config, gzip)
  let mut attempt = 0
  let mut last_failure = ""
  let mut retry_after : Int32? = None
  while attempt <= config.max_retries {
    if attempt > 0 {
      let delay = match retry_after {
        Some(value) => value
        None => 100 * attempt
      }
      if delay > 0 {
        @async.sleep(delay)
      }
    }
    retry_after = None
    let timeout = config.timeout_millis
    let outcome = try {
      if timeout > 0 {
        Some(
          @async.with_timeout(timeout, () => @http.post(url, body, headers~)),
        )
      } else {
        Some(@http.post(url, body, headers~))
      }
    } catch {
      error => {
        last_failure = "OTLP request to " +
          url +
          " failed: " +
          error.to_string()
        None
      }
    }
    match outcome {
      Some((response, response_body)) => {
        if response.code == 200 {
          if json {
            return @otlp.decode_export_response_json(response_body.binary())
          } else {
            return @otlp.decode_export_response(response_body.binary())
          }
        }
        last_failure = "OTLP export failed with HTTP status " +
          response.code.to_string()
        if !is_retryable_status(response.code) {
          return @sdk.ExportFailure(last_failure)
        }
        match response.headers.get(@http.CaseInsensitiveString("retry-after")) {
          Some(value) => retry_after = retry_after_millis(value)
          None => ()
        }
      }
      None => ()
    }
    attempt = attempt + 1
  }
  @sdk.ExportFailure(last_failure)
}

// Encode and export the given spans over OTLP/HTTP, using the encoding
// selected by `config.protocol`. Exporting an empty array is a no-op success.

///|
pub async fn export_spans(
  config : @otlp.OtlpHttpConfig,
  spans : Array[@sdk.SpanData],
) -> @sdk.ExportResult {
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  let body = if config.protocol == @otlp.OTLP_HTTP_JSON_PROTOCOL {
    @otlp.encode_trace_request_json(spans)
  } else {
    @otlp.encode_trace_request(spans)
  }
  post_trace_request(config, body)
}

// An async span exporter over OTLP/HTTP. Use it with an async flush loop
// (for example `export_spans` inside `@async.with_task_group`).

///|
pub struct OtlpHttpAsyncExporter {
  config : @otlp.OtlpHttpConfig
}

// Create an exporter that sends spans to `config`.

///|
pub fn OtlpHttpAsyncExporter::new(
  config : @otlp.OtlpHttpConfig,
) -> OtlpHttpAsyncExporter {
  { config, }
}

// The exporter configuration.

///|
pub fn OtlpHttpAsyncExporter::config(
  self : OtlpHttpAsyncExporter,
) -> @otlp.OtlpHttpConfig {
  self.config
}

// Export a batch of finished spans.

///|
pub async fn OtlpHttpAsyncExporter::export_batch(
  self : OtlpHttpAsyncExporter,
  spans : Array[@sdk.SpanData],
) -> @sdk.ExportResult {
  export_spans(self.config, spans)
}
