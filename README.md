# 183600/moonotel

An OpenTelemetry **Tracing MVP for MoonBit**:

- **Trace API + SDK** – `SpanContext`, `TracerProvider`, `Tracer`, recording
  spans, attributes, events, status, samplers and span processors.
- **W3C Trace Context** – `traceparent` / `tracestate` injection and
  extraction, plus an in-memory `TextMapCarrier`.
- **OTLP/HTTP exporter** – encodes spans as
  `ExportTraceServiceRequest` protobuf and POSTs them to
  `<endpoint>/v1/traces`, including `partial_success` handling and retries.
- **`moonbitlang/async/http` instrumentation** – one-call server wrapper and
  traced client helpers that create spans and propagate context
  automatically.
- **`183600/moonotel` entry package** – re-exports the stable surface and
  offers a one-call `setup`.

The library follows the OpenTelemetry specification where it matters
(sampling semantics, W3C propagation, OTLP wire format) and keeps the
implementation deliberately compact. The repository and MoonBit module are
both `183600/moonotel`; the entry package is the module root and is imported
as `@moonotel`.

## Install

The module is not yet published to the mooncakes registry, so `moon add
183600/moonotel` does not work at the moment. Until it is published, consume
the module from a git checkout through a MoonBit workspace.

Declare the dependency in your application's `moon.mod` (version must match
the module's `moon.mod`):

```toml
import {
  "183600/moonotel@0.1.0",
}
```

Clone the repository next to your project and register both modules as
workspace members:

```bash
git clone https://github.com/183600/moonotel.git
moon work init                # creates moon.work, skip if it exists
moon work use ./moonotel
moon work use ./path/to/your-app
```

Then import the packages you need (for example the root facade plus the
SDK):

```moonbit
import {
  "183600/moonotel",
  "183600/moonotel/sdk",
}
```

## Packages

| Package | Purpose | Targets |
| --- | --- | --- |
| `183600/moonotel/api` | Trace API data types (`SpanContext`, `SpanKind`, `StatusCode`) | all |
| `183600/moonotel/context` | Immutable `Context` and current-context storage | all |
| `183600/moonotel/propagation` | W3C Trace Context propagator | all |
| `183600/moonotel/sdk` | Tracer provider, spans, samplers, processors, semconv keys | all |
| `183600/moonotel/exporter/otlp` | OTLP/HTTP encoder/exporter with an injectable transport | all |
| `183600/moonotel/exporter/otlp_async` | OTLP/HTTP exporter over the real async HTTP client | native+wasm |
| `183600/moonotel/async_runtime` | Async batching exporter with `moonbitlang/async` | native+wasm |
| `183600/moonotel/instrumentation/async_http_client` | Traced `get`/`post`/`put`/`delete` for `moonbitlang/async/http` | native+wasm |
| `183600/moonotel/instrumentation/async_http_server` | `run_server` wrapper that traces every request | native+wasm |
| `183600/moonotel/instrumentation/http_header_capture` | Request/response header capture into span attributes | native+wasm |
| `183600/moonotel` | Re-exports, `setup`, global provider helpers | all |

## Getting started (SDK only)

```moonbit
let provider = @sdk.TracerProviderSdk::new(service_name="checkout")
  .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
let tracer = provider.get_tracer("checkout", version="1.0.0")

let span = tracer.start_root_span("charge-card", kind=@api.SpanKind::Client)
span.set_attribute("payment.provider", @sdk.StringValue("acme"))
span.add_event("retry", attributes={ "attempt": @sdk.IntValue(1) })
span.set_status(@api.StatusCode::Ok)
span.end()
```

Samplers: `always_on`, `always_off`, `record_only`, `trace_id_ratio_based`
and `parent_based(root)` (the OTel default). Processors:
`SimpleSpanProcessor` (export on end) and `BatchSpanProcessor` (bounded
queue, batched export).

`BatchSpanProcessor` keeps span completion cheap in the common case: `on_end`
just enqueues, and when the queue is full it overwrites the oldest buffered
span, increments `dropped_spans()`, and continues; export failures are counted
separately in `export_failures()`. Note that export itself runs
synchronously: once the live queue reaches `max_export_batch_size` the batch
is exported on the thread that ends the span, and `tick()` likewise exports on
its caller (the async exporter in
`183600/moonotel/async_runtime` moves this off the hot path). The queue
size, batch size, and flush interval are configurable through `BatchConfig` /
`OTEL_BSP_*`. Timed flushes are driven by `tick()` (or by span completion), so
a quiet application should call `tick()`
from its own loop or use the async runtime helper.

The process-wide provider can be installed once and used from anywhere:

```moonbit
@moonotel.setup(service_name="checkout")           // installs a global provider
let tracer = @sdk.global_tracer("checkout")    // or @moonotel.global_tracer(...)
```

## HTTP instrumentation (`moonbitlang/async/http`)

The instrumentation packages target native and wasm, matching the async HTTP
stack (the default wasm-gc target skips their bodies). They degrade
gracefully: when no tracer is available the wrappers simply forward the
request. URL attributes strip userinfo and redact the values of the
well-known sensitive query parameters listed by the HTTP semantic
conventions (`X-Amz-Signature`, `X-Amz-Credential`, `X-Amz-Security-Token`,
`AWSAccessKeyId`, `Signature`, `sig`, and `X-Goog-Signature`).

### Server

```moonbit
let provider = @sdk.TracerProviderSdk::new(service_name="greeter")
  .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))

async fn main {
  let addr = @socket.Addr::parse("127.0.0.1:8080")
  @server.run_server(addr, call => {
    // `call.start_span("db.query")` creates children parented to the request.
    call.respond(200, body="hello")
  }, tracer=provider.get_tracer("greeter"))
}
```

`run_server` extracts `traceparent` from each request, starts a `Server`
span with the standard HTTP attributes (`http.request.method`, `url.path`,
`url.query`, `server.address`, `client.address`, …), installs the context
while the handler runs, and ends the span afterwards. `respond` records
`http.response.status_code` and marks 5xx spans as `Error`. Handler
exceptions are recorded as `exception` events and re-raised.

### Client

```moonbit
let (response, body) = @client.get("http://127.0.0.1:8080/hello", tracer=tracer)
let (response, body) = @client.post(url, "payload", tracer=tracer)
```

Each call starts a `Client` span, injects `traceparent`, records the method,
URL, resolved server address/port and response status, and marks the span as
`Error` for 4xx/5xx responses.

## OTLP/HTTP export

`exporter/otlp` is transport-agnostic: provide a
`(url, headers, body) -> TransportResponse` function (a test double, a custom
client, …) and the exporter handles encoding, headers, status handling and
retries.

`exporter/otlp_async` provides the production transport:

```moonbit
let config = @otlp.OtlpHttpConfig::from_env() // reads OTEL_EXPORTER_OTLP_*
let result = @otlp_async.export_spans(config, finished_spans)
```

Supported environment variables:

- `OTEL_EXPORTER_OTLP_ENDPOINT` (default `http://localhost:4318`) is a **base
  URL**; `/v1/traces` is appended. If the value already ends in `/v1/traces`
  (or `/v1/traces/`), it is used as-is instead of being doubled.
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` is used **verbatim** and takes
  precedence over the generic endpoint; do not append `/v1/traces` yourself.
- `OTEL_EXPORTER_OTLP_HEADERS` (`key=value,key2=value2`)
- `OTEL_EXPORTER_OTLP_COMPRESSION` (`none` or `gzip`; any other value is
  rejected with a clear error). `gzip` is implemented by the async exporter;
  the synchronous `exporter/otlp` exporter rejects it rather than sending an
  uncompressed body under a `Content-Encoding: gzip` header.
- `OTEL_EXPORTER_OTLP_PROTOCOL` (`http/protobuf`, the default, or `http/json`)
- `OTEL_EXPORTER_OTLP_TIMEOUT` (milliseconds; enforced by the async exporter
  — the synchronous exporter runs whatever `Transport` you inject, so the
  transport itself is expected to enforce any deadline)
- `OTEL_SERVICE_NAME`

The signal-specific `OTEL_EXPORTER_OTLP_TRACES_HEADERS`,
`OTEL_EXPORTER_OTLP_TRACES_COMPRESSION`, `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`
and `OTEL_EXPORTER_OTLP_TRACES_TIMEOUT` variables take precedence over their
generic counterparts.

Requests announce `Content-Type` and `Accept` for the configured protocol and
carry a default `User-Agent` identifying the exporter and SDK version
(`OTel-OTLP-Exporter-MoonBit/<version>`); a `User-Agent` supplied through
`OTEL_EXPORTER_OTLP_HEADERS` / `OTEL_EXPORTER_OTLP_TRACES_HEADERS` is kept
instead.

HTTP 200 is never retried, but a `partial_success` payload is surfaced as an
export failure (`ExportFailure("partial success: …")`) rather than as a
success.
The retryable statuses are exactly the OTLP transient set: 429/502/503/504.
Transport failures and those statuses are retried up to `max_retries`; a
`Retry-After` header (delta-seconds or HTTP-date, capped at 60s) takes
precedence over the jittered linear backoff. Other 4xx/5xx responses,
including 500, are terminal and returned as an export failure.

Exporters are single-use sinks. `OtlpHttpExporter` rejects every batch after
`shutdown()` — including an empty one — with
`ExportFailure("OTLP exporter is shut down")`; the async span exporter closes
its queue on shutdown. Shutting a provider down drains batch processors before
shutting their exporters down, so already-ending spans are not lost.

## Configuration

Besides the OTLP variables above, the SDK reads the standard OpenTelemetry
environment configuration:

- `OTEL_SDK_DISABLED=true` makes tracers no-op (nothing is recorded or
  exported).
- `OTEL_TRACES_EXPORTER` is a comma-separated list of `otlp`, `console` and
  `none`; it defaults to `otlp`, and `none` disables every exporter. The
  facade `setup` and the async `setup` use this list unless an explicit
  `exporters` argument is given.
- `OTEL_TRACES_SAMPLER` selects `always_on`, `always_off`, `traceidratio`,
  `parentbased_always_on` (the default), `parentbased_always_off` or
  `parentbased_traceidratio`; `OTEL_TRACES_SAMPLER_ARG` is the ratio for the
  ratio-based variants.
- `OTEL_BSP_MAX_QUEUE_SIZE`, `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` and
  `OTEL_BSP_SCHEDULE_DELAY` (milliseconds) configure `BatchSpanProcessor`.
- `OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT`, `OTEL_SPAN_EVENT_COUNT_LIMIT`,
  `OTEL_SPAN_LINK_COUNT_LIMIT`, `OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT`,
  `OTEL_LINK_ATTRIBUTE_COUNT_LIMIT` and
  `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` configure span collection limits,
  with the generic `OTEL_ATTRIBUTE_*` variables as fallbacks.
- `OTEL_RESOURCE_ATTRIBUTES` (`key=value,key2=value2`, percent-encoded) and
  `OTEL_SERVICE_NAME` configure the resource.
- `OTEL_PROPAGATORS` selects the global propagators (default
  `tracecontext,baggage`; `none` disables propagation).
- `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST`,
  `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_RESPONSE`,
  `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_CLIENT_REQUEST` and
  `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_CLIENT_RESPONSE` opt into
  header capture as span attributes.

## Testing and CI

```sh
moon update
moon check
moon test
moon check --target native
moon test --target native
```

The async instrumentation/exporter packages target native and wasm. The
default wasm-gc target skips their bodies, while `moon check --target native`
and `moon test --target native` compile and run them (`moon check --target
wasm` also compiles them). The push/PR workflow `.github/workflows/ci.yml`
runs both the default and native checks so a green CI means the native code
was actually compiled and tested.

## W3C Trace Context

```moonbit
let carrier = @propagation.TextMapCarrier::new()
@propagation.inject(span.context(), carrier)      // writes traceparent
let parent = @propagation.extract(carrier)        // SpanContext?
```

Parsing is strict about the specification (version `ff`, all-zero IDs,
field lengths, version-00 extra fields) and, per the version-00 `HEXDIGLC`
ABNF, requires lowercase hex for `version=00` headers; future versions
(`>= 01`) accept hex in either case. `inject_with_tracestate` validates and
normalizes its explicit `tracestate` override, dropping a malformed value
instead of writing an invalid header.

## Context

`Context` is an immutable chain carrying the current span and string baggage.
`@context.with_context(ctx, fn() { ... })`, `attach`/`detach` and
`with_span_context` scope it; `Tracer::start_span_with_context` picks up the
current context automatically. An empty baggage update
(`with_baggage(Map([]))`, or `without_baggage()`) hides every value stored in
outer contexts while keeping values added afterwards.

## Development

The repository also contains a `PLAN.md` with the original design notes. The
test suite lives next to each package; add a regression test when changing
behavior, and run both default and native checks before committing.

## License

Apache-2.0
