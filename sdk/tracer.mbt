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

// Start a new span. When `parent` is a valid SpanContext, the new span joins
// that trace; otherwise the span is the root of a new trace. `links` may
// associate the new span with other spans in the same or a different trace.

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
    Some(ctx) => if ctx.is_valid() { Some(ctx) } else { None }
    None => None
  }
  let (trace_id, parent_span_id, tracestate) = match valid_parent {
    Some(ctx) => (ctx.trace_id_view(), ctx.span_id_view(), ctx.tracestate())
    None => (self.provider.id_generator.generate_trace_id(), [], "")
  }
  let span_id = self.provider.id_generator.generate_span_id()
  let decision = self.provider.sampler.should_sample(valid_parent, trace_id)
  let flags = if decision.is_sampled { @api.TRACE_FLAGS_SAMPLED } else { 0 }
  let span_context = @api.span_context(trace_id, span_id, flags, tracestate~)
  let start_time = match start_time_unix_nano {
    Some(value) => value
    None => unix_nano_now()
  }
  // Non-recording spans (DROP) keep no links, matching the SDK spec;
  // `create_span` ignores links for non-recording spans. Links with an
  // invalid SpanContext are dropped, and the link count/attribute limits are
  // enforced, as required by the specification.
  let span_links : Array[SpanLink]? = if decision.is_recorded {
    links
  } else {
    None
  }
  let span = create_span(
    name,
    span_context,
    parent_span_id,
    kind.unwrap_or(@api.SpanKind::Internal),
    start_time,
    decision.is_recorded,
    span_links,
    self.provider.span_limits(),
    self.provider.processors,
    self.provider.resource.attributes_shared(),
    self.scope_name,
    self.scope_version,
  )
  if span.recording {
    for processor in self.provider.processors {
      processor.on_start(span)
    }
  }
  match attributes {
    Some(attrs) => span.set_attributes(attrs)
    None => ()
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
// root span); an explicit `context` is used only when `parent` is absent.
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
  let previous = @context.attach(@context.current_context().with_span(span.context()))
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
  let previous = @context.attach(@context.current_context().with_span(span.context()))
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
