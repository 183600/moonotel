// The SDK Tracer. A tracer creates spans for one instrumentation scope and
// links them to an explicit parent SpanContext when one is supplied.

///|
pub struct Tracer {
  provider : TracerProviderSdk
  scope_name : String
  scope_version : String
}

// The instrumentation scope name of this tracer.

///|
pub fn Tracer::scope_name(self : Tracer) -> String {
  self.scope_name
}

// The instrumentation scope version of this tracer.

///|
pub fn Tracer::scope_version(self : Tracer) -> String {
  self.scope_version
}

// Whether this tracer will record and export spans. False when the SDK is
// disabled through `OTEL_SDK_DISABLED`, when no span processor is registered
// and after the provider has been shut down, as specified by the OpenTelemetry
// tracing SDK.

///|
pub fn Tracer::enabled(self : Tracer) -> Bool {
  !self.provider.disabled &&
  !self.provider.is_shutdown() &&
  self.provider.processor_count() > 0
}

// Start a new span. When `parent` is a valid SpanContext, the new span joins
// that trace; otherwise the span is the root of a new trace. `links` may
// associate the new span with other spans in the same or a different trace.
// When the SDK is disabled or the provider has been shut down, the tracer acts
// as a no-op tracer: the returned span is non-recording and wraps the parent
// SpanContext (or an empty SpanContext for root spans).

///|
pub fn Tracer::start_span(
  self : Tracer,
  name : String,
  kind? : @api.SpanKind,
  parent? : @api.SpanContext,
  attributes? : Map[String, AttributeValue],
  links? : Array[SpanLink],
  start_time_unix_nano? : Int64,
) -> SpanSdk {
  let valid_parent = match parent {
    Some(ctx) => if has_live_valid_ids(ctx) { Some(ctx) } else { None }
    None => None
  }
  let span_kind = kind.unwrap_or(@api.SpanKind::Internal)
  let start_time = match start_time_unix_nano {
    Some(value) => value
    None => unix_nano_now()
  }
  if self.provider.disabled || self.provider.is_shutdown() {
    let (context, parent_span_id) = match valid_parent {
      Some(ctx) => (ctx.copy(), ctx.span_id())
      None => (@api.invalid_span_context(), no_parent_span_id)
    }
    return create_span(
      name,
      context,
      parent_span_id,
      span_kind,
      start_time,
      false,
      None,
      self.provider.span_limits(),
      self.provider.processors,
      self.provider.resource.attributes_shared(),
      self.scope_name,
      self.scope_version,
    )
  }
  let (trace_id, parent_span_id, tracestate) = match valid_parent {
    Some(ctx) => (ctx.trace_id(), ctx.span_id(), ctx.tracestate())
    None => (self.provider.id_generator.generate_trace_id(), no_parent_span_id, "")
  }
  let span_id = self.provider.id_generator.generate_span_id()
  let sampler_attributes : Map[String, AttributeValue] = match attributes {
    Some(values) => values
    None => Map([])
  }
  let sampler_links : Array[SpanLink] = match links {
    Some(values) => values
    None => []
  }
  let decision = self.provider.sampler.should_sample_parameters({
    parent: valid_parent,
    trace_id,
    name,
    kind: span_kind,
    attributes: sampler_attributes,
    links: sampler_links,
  })
  // The sampled flag may only be set together with a recording decision
  // (RECORD_AND_SAMPLE); a DROP decision must never set it, even when a
  // misbehaving sampler asks for sampling. The W3C random-trace-id flag is a
  // property of the trace ID, so it is preserved when continuing a parent.
  let parent_random_flag = match valid_parent {
    Some(ctx) => ctx.trace_flags() & @api.TRACE_FLAGS_RANDOM
    None => 0
  }
  let flags = parent_random_flag |
    (if decision.is_sampled && decision.is_recorded {
      @api.TRACE_FLAGS_SAMPLED
    } else {
      0
    })
  let span_context = @api.span_context(trace_id, span_id, flags, tracestate~)
  // Non-recording spans (DROP) keep no links, matching the SDK spec;
  // `create_span` ignores links for non-recording spans. Links whose
  // SpanContext is invalid are dropped unless they carry attributes or a
  // non-empty tracestate, and the link count/attribute limits are enforced,
  // as specified.
  let span_links : Array[SpanLink]? = if decision.is_recorded {
    links
  } else {
    None
  }
  let span = create_span(
    name,
    span_context,
    parent_span_id,
    span_kind,
    start_time,
    decision.is_recorded,
    span_links,
    self.provider.span_limits(),
    self.provider.processors,
    self.provider.resource.attributes_shared(),
    self.scope_name,
    self.scope_version,
  )
  match attributes {
    Some(attrs) => span.set_attributes(attrs)
    None => ()
  }
  if span.recording {
    for processor in self.provider.processors {
      processor.on_start(span)
    }
  }
  span
}

// Start a span whose parent is taken from a Context. When no context is
// passed, the current context (as installed via `@context.attach` or
// `@context.with_context`) is used.

///|
pub fn Tracer::start_span_with_context(
  self : Tracer,
  name : String,
  context? : @context.Context,
  kind? : @api.SpanKind,
  attributes? : Map[String, AttributeValue],
  links? : Array[SpanLink],
  start_time_unix_nano? : Int64,
) -> SpanSdk {
  let parent : @api.SpanContext? = match context {
    Some(ctx) => ctx.span_context()
    None => @context.current_span_context()
  }
  self.start_span(
    name,
    kind?,
    parent?,
    attributes?,
    links?,
    start_time_unix_nano?,
  )
}

// Run `f` with a new span that becomes the current span for the duration of
// the call, so spans started inside `f` link to it automatically. When
// `parent` is omitted the span is a child of the current context's span (or a
// root span); an explicit `context` supplies the ambient base context
// (including baggage) while an explicit `parent` overrides the span parent.
// The span is ended and the previous context restored when `f` returns or
// raises.

///|
pub fn[X] Tracer::with_span(
  self : Tracer,
  name : String,
  f : (SpanSdk) -> X raise?,
  context? : @context.Context,
  kind? : @api.SpanKind,
  parent? : @api.SpanContext,
  attributes? : Map[String, AttributeValue],
  links? : Array[SpanLink],
  start_time_unix_nano? : Int64,
) -> X raise? {
  let span = match parent {
    Some(_) =>
      self.start_span(
        name,
        kind?,
        parent?,
        attributes?,
        links?,
        start_time_unix_nano?,
      )
    None =>
      self.start_span_with_context(
        name,
        context?,
        kind?,
        attributes?,
        links?,
        start_time_unix_nano?,
      )
  }
  let base = match context {
    Some(value) => value
    None => @context.current_context()
  }
  let previous = @context.attach(base.with_span(span.context()))
  defer @context.detach(previous)
  defer span.end()
  f(span)
}

// Async counterpart of `with_span`: run the async `f` with a new span that
// becomes the current span until `f` returns or raises, so spans started
// inside `f` (including ones started after an await) link to it
// automatically. The span is ended and the previous context restored
// afterwards. Argument semantics are identical to `with_span`.

///|
pub async fn[X] Tracer::with_span_async(
  self : Tracer,
  name : String,
  f : async (SpanSdk) -> X,
  context? : @context.Context,
  kind? : @api.SpanKind,
  parent? : @api.SpanContext,
  attributes? : Map[String, AttributeValue],
  links? : Array[SpanLink],
  start_time_unix_nano? : Int64,
) -> X {
  let span = match parent {
    Some(_) =>
      self.start_span(
        name,
        kind?,
        parent?,
        attributes?,
        links?,
        start_time_unix_nano?,
      )
    None =>
      self.start_span_with_context(
        name,
        context?,
        kind?,
        attributes?,
        links?,
        start_time_unix_nano?,
      )
  }
  let base = match context {
    Some(value) => value
    None => @context.current_context()
  }
  let previous = @context.attach(base.with_span(span.context()))
  defer @context.detach(previous)
  defer span.end()
  f(span)
}

// Start a new root span with no parent.

///|
pub fn Tracer::start_root_span(
  self : Tracer,
  name : String,
  kind? : @api.SpanKind,
  attributes? : Map[String, AttributeValue],
  links? : Array[SpanLink],
  start_time_unix_nano? : Int64,
) -> SpanSdk {
  self.start_span(name, kind?, attributes?, links?, start_time_unix_nano?)
}
