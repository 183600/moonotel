# yourname/otel

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
- **`yourname/otel` entry package** – re-exports the stable surface and
  offers a one-call `setup`.

The library follows the OpenTelemetry specification where it matters
(sampling semantics, W3C propagation, OTLP wire format) while staying small
enough to read in one sitting.

## Packages

| Package | Purpose | Targets |
| --- | --- | --- |
| `yourname/otel/api` | Trace API data types (`SpanContext`, `SpanKind`, `StatusCode`) | all |
| `yourname/otel/context` | Immutable `Context` and current-context storage | all |
| `yourname/otel/propagation` | W3C Trace Context propagator | all |
| `yourname/otel/sdk` | Tracer provider, spans, samplers, processors, semconv keys | all |
| `yourname/otel/exporter/otlp` | OTLP/HTTP encoder/exporter with an injectable transport | all |
| `yourname/otel/exporter/otlp_async` | OTLP/HTTP exporter over the real async HTTP client | native |
| `yourname/otel/instrumentation/async_http_client` | Traced `get`/`post`/`put`/`delete` for `moonbitlang/async/http` | native |
| `yourname/otel/instrumentation/async_http_server` | `run_server` wrapper that traces every request | native |
| `yourname/otel` | Re-exports, `setup`, global provider helpers | all |

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

The process-wide provider can be installed once and used from anywhere:

```moonbit
@otel.setup(service_name="checkout")           // installs a global provider
let tracer = @sdk.global_tracer("checkout")    // or @otel.global_tracer(...)
```

## HTTP instrumentation (`moonbitlang/async/http`)

The instrumentation packages are native-only because the async HTTP stack is.
They degrade gracefully: when no tracer is available the wrappers simply
forward the request.

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

- `OTEL_EXPORTER_OTLP_ENDPOINT` (default `http://localhost:4318`)
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` (used verbatim)
- `OTEL_EXPORTER_OTLP_HEADERS` (`key=value,key2=value2`)
- `OTEL_EXPORTER_OTLP_COMPRESSION` (`none`; other values are rejected)
- `OTEL_EXPORTER_OTLP_TIMEOUT` (milliseconds)
- `OTEL_SERVICE_NAME`

HTTP 200 – including `partial_success` – is a success and is never retried;
429/502/503/504 are retried up to `max_retries` with linear backoff.

## W3C Trace Context

```moonbit
let carrier = @propagation.TextMapCarrier::new()
@propagation.inject(span.context(), carrier)      // writes traceparent
let parent = @propagation.extract(carrier)        // SpanContext?
```

Parsing is strict about the specification (version `ff`, all-zero IDs,
field lengths, version-00 extra fields) and lenient about hex case.

## Context

`Context` is an immutable chain carrying the current span and string baggage.
`@context.with_context(ctx, fn() { ... })`, `attach`/`detach` and
`with_span_context` scope it; `Tracer::start_span_with_context` picks up the
current context automatically.

## Development

```sh
moon check
moon test                 # default target
moon test --target native # async instrumentation and exporter tests
```

Async packages and their tests are native-only; `moon check`/`moon test` on
other targets skip them.
