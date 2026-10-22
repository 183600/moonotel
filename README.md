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

Attribute keys must be non-empty, as required by the OpenTelemetry data
model. An empty key passed to a span, event, link or resource setter is
ignored (it is not recorded, exported or counted as dropped by a limit).

Samplers: `always_on`, `always_off`, `record_only`, `trace_id_ratio_based`
and `parent_based(root)` (the OTel default). The ratio sampler uses the
rightmost 8 bytes of the trace ID with a deterministic threshold, so a
timestamp or other structured prefix does not bias the decision, a given trace
ID always gets the same decision, and a higher ratio samples every trace a
lower ratio would. The exact `TraceIdRatioBased` algorithm is not standardized
(the OpenTelemetry specification explicitly warns that different SDKs may
disagree), so do not rely on the same trace ID being sampled identically by
another language's SDK. Processors: `SimpleSpanProcessor` (export on end) and
`BatchSpanProcessor` (bounded queue, batched export). `always_record(root)`
wraps a sampler so spans it would drop are still recorded locally
(`RECORD_ONLY`) without being exported, which lets processors see every span.

A recording span keeps its data readable after `end()`: the accessors return a
snapshot of the recorded attributes, events and links, including when the
provider has no processors registered.

A `SpanContext` snapshots its validity when it is constructed. The ID views are
read-only by contract; if an aliased ID array is shortened or zeroed anyway, the
context is treated as invalid wherever it is consumed: starting a child creates
a new root trace, an attribute-less link is dropped (a link carrying attributes
or tracestate is kept), and no all-zero `traceparent` is written. The copying
`trace_id()` / `span_id()` accessors and the `*_hex()` accessors keep their
canonical 16/8-byte and 32/16-character shapes by reporting a shortened or grown
ID as the all-zero ID. An invalid context is never reported as remote.

`BatchSpanProcessor` keeps span completion cheap in the common case: `on_end`
just enqueues, and export failures are counted separately in
`export_failures()`. The effective export batch size is capped at the queue
size, so the synchronous processor normally flushes as soon as a batch is full;
the queue-overflow path is defensive: if the queue ever does fill, the oldest
buffered span is overwritten and counted by `dropped_spans()`. Note that export
itself runs synchronously: once the live queue reaches
`max_export_batch_size` the batch is exported on the thread that ends the span,
and `tick()` likewise exports on its caller (the async exporter in
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

Native applications that want the OTLP exporter to send from a background task
can call `@async_runtime.setup(group, ...)` inside a
`moonbitlang/async` task group instead. It accepts the same `service_name`,
resource, sampler, span-limit, endpoint, header, exporter-selection and batch
overrides, uses the same environment variables, and drains pending spans when
the group exits.

## HTTP instrumentation (`moonbitlang/async/http`)

The instrumentation packages target native and wasm, matching the async HTTP
stack (the default wasm-gc target skips their bodies). They degrade
gracefully: when no tracer is available the wrappers simply forward the
request. URL attributes strip userinfo and redact the values of the
well-known sensitive query parameters listed by the HTTP semantic
conventions (`X-Amz-Signature`, `X-Amz-Credential`, `X-Amz-Security-Token`,
`AWSAccessKeyId`, `Signature`, `sig`, and `X-Goog-Signature`). Captured header
values and `user_agent.original` have surrounding HTTP optional whitespace
removed. The server records the received `User-Agent`, and the client records
the `User-Agent` it actually sent (including one supplied by the HTTP client
when the caller did not set it).

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
while the handler runs, and ends the span afterwards. `set_route` records
`http.route` and renames the span to `METHOD route`; an empty or blank route is
ignored because no route was matched. `respond` records
`http.response.status_code` and marks 5xx spans as `Error`. Handler
exceptions are recorded as `exception` events and re-raised. `http_method()`,
`header(name)` and `span_context()` expose the request method, a header lookup
and the server span context to the handler; `start_span` creates a child span
explicitly parented to the request, even when several connections run
concurrently.

### Client

```moonbit
let (response, body) = @client.get("http://127.0.0.1:8080/hello", tracer=tracer)
let (response, body) = @client.post(url, "payload", tracer=tracer)
```

Each call starts a `Client` span, injects `traceparent`, records the method,
URL, resolved server address/port and response status, and marks the span as
`Error` for 4xx/5xx responses. Only URLs with an explicit scheme and authority
record `server.address`/`server.port`; a relative reference cannot contribute
those attributes. The `url.full` attribute strips credentials from both
absolute URLs and network-path references (`//user:pass@host/path`), and
`user_agent.original` records the request's `User-Agent` value.

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
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` is used **verbatim** (a URL with no path
  part is sent to the root path `/`) and takes precedence over the generic
  endpoint; do not append `/v1/traces` yourself.
- `OTEL_EXPORTER_OTLP_HEADERS` (`key=value,key2=value2`)
- `OTEL_EXPORTER_OTLP_COMPRESSION` (`none` or `gzip`; any other value is
  rejected with a clear error). `gzip` is implemented by the async exporter;
  the synchronous `exporter/otlp` exporter rejects it rather than sending an
  uncompressed body under a `Content-Encoding: gzip` header.
- `OTEL_EXPORTER_OTLP_PROTOCOL` (`http/protobuf`, the default, or `http/json`)
- `OTEL_EXPORTER_OTLP_TIMEOUT` (milliseconds; enforced by the async exporter
  as one overall budget for the whole export, covering every request attempt
  and every wait between retries. The synchronous exporter runs whatever
  `Transport` you inject, so the transport itself is expected to enforce any
  deadline.)
- `OTEL_SERVICE_NAME`

The signal-specific `OTEL_EXPORTER_OTLP_TRACES_HEADERS`,
`OTEL_EXPORTER_OTLP_TRACES_COMPRESSION`, `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`
and `OTEL_EXPORTER_OTLP_TRACES_TIMEOUT` variables take precedence over their
generic counterparts.

The facade and async `setup` functions merge their explicit `headers` argument
into the headers read from the environment: same-named entries are replaced
case-insensitively, while unrelated environment headers are still sent.

Configured headers are validated before they are sent. A name must be a
non-empty HTTP token, and a value must not contain CR, LF, NUL or any control
character other than HTAB; malformed entries are dropped both when the
`OTEL_EXPORTER_OTLP_*_HEADERS` variables are parsed and when the request
headers are built from a directly assembled `OtlpHttpConfig`. Transport-managed
body-framing headers (`Content-Length` and `Transfer-Encoding`) are not
forwarded, so a configured value cannot contradict the bytes actually sent;
`Content-Type`, `Accept` and `Content-Encoding` are likewise set by the
exporter.

Requests announce `Content-Type` and `Accept` for the configured protocol and
carry a default `User-Agent` identifying the exporter and SDK version
(`OTel-OTLP-Exporter-MoonBit/<version>`); a `User-Agent` supplied through
`OTEL_EXPORTER_OTLP_HEADERS` / `OTEL_EXPORTER_OTLP_TRACES_HEADERS` is kept
instead.

HTTP 200 is never retried, but a `partial_success` payload is surfaced as an
export failure (`ExportFailure("partial success: …")`) rather than as a
success.
The retryable statuses are exactly the OTLP transient set: 429/502/503/504.
Transport failures and those statuses are retried up to `max_retries`. The
async exporter honors a `Retry-After` header (delta-seconds or an HTTP-date,
including the obsolete RFC 850 and asctime forms that RFC 9110 requires
recipients to accept, capped at 60s) ahead of an exponential backoff with
jitter (100ms, doubling up to a 5s cap). RFC 850's two-digit year is expanded
relative to the current UTC year using the RFC 9110 "more than 50 years in the
future" rule. The synchronous
exporter's `TransportResponse` does not expose response headers, so its waits
are supplied through the injected `RetryWait` function instead; a non-positive
`status_code` reports a transport failure that never received an HTTP response
and is retried. Other 4xx/5xx
responses, including 500, are terminal and returned as an export failure.

`OtlpHttpConfig::new` applies the same defaults to programmatic values as
`from_env`: a negative timeout (0 means "no timeout") and blank protocol or
compression values fall back to 10s, `http/protobuf` and `none`; a negative
`max_retries` means no retries. A config assembled directly from the public
fields is normalized the same way when it is used: a negative timeout falls
back to 10s, blank protocol/compression values select `http/protobuf` / `none`,
blank or whitespace-only endpoints are treated as unset, and surrounding
whitespace is stripped before the export URL is built.

Exporters are single-use sinks. `OtlpHttpExporter` rejects every batch after
`shutdown()` — including an empty one — with
`ExportFailure("OTLP exporter is shut down")`; the async span exporter closes
its queue on shutdown. Shutting a provider down drains batch processors before
shutting their exporters down, so already-ending spans are not lost. Once
shutdown starts, no further `on_start` / `on_end` callbacks are delivered, even
when a processor triggers the shutdown from inside one of those callbacks.

The OTLP encoders validate live IDs at export time. A span whose trace ID is no
longer exactly 16 nonzero bytes or whose span ID is no longer exactly 8 nonzero
bytes is skipped instead of being serialized with a malformed `traceId` /
`spanId`. A link with such an ID loses only its ID fields; its attributes and
tracestate are still exported.

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

Header-capture values are comma-separated lists of header names matched
case-insensitively; `*` captures every header. Prefer explicit names: a
wildcard also captures credential-bearing headers such as `Authorization` and
`Cookie`, so only enable it when those values are safe to record.

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

Header names are matched case-insensitively. Repeated `tracestate` and
`baggage` fields are combined into one comma-separated value before parsing,
as required for HTTP fields; a duplicated `traceparent` (under any casing) is
ambiguous, so `extract` ignores the header and restarts the trace.

Parsing is strict about the specification (version `ff`, all-zero IDs,
field lengths, version-00 extra fields) and, per the version-00 `HEXDIGLC`
ABNF, requires lowercase hex for `version=00` headers; future versions
(`>= 01`) accept hex in either case. A root span created from the SDK's random
trace-ID generator sets the W3C Level 2 random-trace-id flag, and a child span
preserves the parent's flag; a custom generator opts in with
`IdGenerator::new(..., trace_id_is_random=true)`. For a future version the two flag
characters must be followed by the end of the value or by a dash; any
extension after that dash is ignored (it may be empty). Empty and
whitespace-only `tracestate` headers are accepted as carrying no state, and
`inject` never writes an empty `tracestate`. `inject_with_tracestate`
validates and normalizes its explicit `tracestate` override, dropping a
malformed value instead of writing an invalid header. `inject` removes a
`tracestate` left in the carrier by an earlier injection when the context
carries no valid state, so a stale value is never paired with a new
`traceparent`. At the context level, `inject_context` and
`TraceContextPropagator::inject` also remove both trace headers from a reused
carrier when the context has no valid span, so an old trace parent cannot leak
into an outgoing request that only carries baggage. The same rule applies to
baggage: `inject_baggage` (and the baggage propagator) removes a stale
`baggage` header from a reused carrier when the context carries no visible
member. Baggage parsing and formatting enforce the W3C limits of 64 members
and 8192 bytes; excess members are dropped whole.

## Context

`Context` is an immutable chain carrying the current span and string baggage.
`@context.with_context(ctx, fn() { ... })`, `attach`/`detach` and
`with_span_context` scope it; `Tracer::start_span_with_context` picks up the
current context automatically. The default ambient storage is a single
process-global slot, which is correct for synchronous single-flow code. It is
not coroutine-local: concurrent tasks that interleave `attach`/`detach` must
pass an explicit `Context` to the code they run (the HTTP instrumentation does
this) or install a task-aware backend with `@context.set_context_storage`.
An empty baggage update
(`with_baggage(Map([]))`, or `without_baggage()`) hides every value stored in
outer contexts while keeping values added afterwards. Baggage names must be
non-empty (as required by the OpenTelemetry Baggage API); setters and removals
silently ignore an empty name, and a non-empty update whose names are all
invalid leaves the context unchanged. `Context::with_baggage_entries` and
`Context::baggage_entries` use `@moonotel.ContextBaggageEntry` (an alias of
`@context.BaggageEntry`), which carries W3C baggage properties; it is distinct
from the propagation `BaggageEntry` used by the `baggage` header helpers.

## Development

The repository also contains a `PLAN.md` with the original design notes. The
test suite lives next to each package; add a regression test when changing
behavior, and run both default and native checks before committing.

## License

Apache-2.0
