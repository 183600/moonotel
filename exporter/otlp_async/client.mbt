// OTLP/HTTP exporter backed by the real `moonbitlang/async/http` client.
//
// This is the production transport counterpart of the injectable `Transport`
// used by `@otlp.OtlpHttpExporter`: it POSTs an encoded
// `ExportTraceServiceRequest` to `<endpoint>/v1/traces` with
// `Content-Type: application/x-protobuf`, decodes the response (including
// `partial_success`) and retries only retryable HTTP statuses. Each attempt
// is bounded by `config.timeout_millis`.
//
// The package targets native only, because the async HTTP stack does.

///|
fn is_retryable_status(status_code : Int) -> Bool {
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
  let headers = Map(
    [],
    capacity=(config.headers.length() + 2) * 2,
  )
  config.headers.each(fn(key, value) {
    headers.set(@http.CaseInsensitiveString(key), value)
  })
  headers.set(
    @http.CaseInsensitiveString("content-type"),
    "application/x-protobuf",
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

// POST an already encoded `ExportTraceServiceRequest` body to the configured
// trace endpoint and interpret the response. Network errors and retryable
// statuses (429, 502, 503, 504) are retried up to `config.max_retries` times
// with a short linear backoff. When `config.compression` is `gzip` the body is
// compressed once and sent with `Content-Encoding: gzip`.

///|
pub async fn post_trace_request(
  config : @otlp.OtlpHttpConfig,
  body : Bytes,
) -> @sdk.ExportResult {
  if config.protocol != @otlp.OTLP_HTTP_PROTOBUF_PROTOCOL {
    return @sdk.ExportFailure("unsupported OTLP protocol: " + config.protocol)
  }
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
  while attempt <= config.max_retries {
    if attempt > 0 {
      @async.sleep(100 * attempt)
    }
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
          return @otlp.decode_export_response(response_body.binary())
        }
        last_failure = "OTLP export failed with HTTP status " +
          response.code.to_string()
        if !is_retryable_status(response.code) {
          return @sdk.ExportFailure(last_failure)
        }
      }
      None => ()
    }
    attempt = attempt + 1
  }
  @sdk.ExportFailure(last_failure)
}

// Encode and export the given spans over OTLP/HTTP. Exporting an empty array
// is a no-op success.

///|
pub async fn export_spans(
  config : @otlp.OtlpHttpConfig,
  spans : Array[@sdk.SpanData],
) -> @sdk.ExportResult {
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  post_trace_request(config, @otlp.encode_trace_request(spans))
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
