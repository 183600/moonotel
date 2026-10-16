// The SDK Tracer. A tracer creates spans for one instrumentation scope and
// links them to an explicit parent SpanContext when one is supplied.

pub struct Tracer {
  provider : TracerProviderSdk
  scope_name : String
  scope_version : String
}

// The instrumentation scope name of this tracer.
pub fn Tracer::scope_name(self : Tracer) -> String {
  self.scope_name
}

// The instrumentation scope version of this tracer.
pub fn Tracer::scope_version(self : Tracer) -> String {
  self.scope_version
}

// Start a new span. When `parent` is a valid SpanContext, the new span joins
// that trace; otherwise the span is the root of a new trace.
pub fn Tracer::start_span(
  self : Tracer,
  name : String,
  kind? : @api.SpanKind,
  parent? : @api.SpanContext,
  attributes? : Map[String, AttributeValue],
  start_time_unix_nano? : Int64
) -> SpanSdk {
  let valid_parent = match parent {
    Some(ctx) => if ctx.is_valid() { Some(ctx) } else { None }
    None => None
  }
  let trace_id = match valid_parent {
    Some(ctx) => ctx.trace_id()
    None => self.provider.id_generator.generate_trace_id()
  }
  let span_id = self.provider.id_generator.generate_span_id()
  let decision = self.provider.sampler.should_sample(valid_parent, trace_id)
  let flags = if decision.is_sampled {
    @api.TRACE_FLAGS_SAMPLED
  } else {
    0
  }
  let tracestate = match valid_parent {
    Some(ctx) => ctx.tracestate()
    None => ""
  }
  let span_context = @api.span_context(
    trace_id,
    span_id,
    flags,
    tracestate=tracestate,
  )
  let parent_span_id = match valid_parent {
    Some(ctx) => ctx.span_id()
    None => []
  }
  let start_time = match start_time_unix_nano {
    Some(value) => value
    None => unix_nano_now()
  }
  let span = create_span(
    name,
    span_context,
    parent_span_id,
    kind.unwrap_or(@api.SpanKind::Internal),
    start_time,
    decision.is_recorded,
    self.provider.processors,
    self.provider.resource,
    self.scope_name,
    self.scope_version,
  )
  if span.is_recording() {
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
pub fn Tracer::start_span_with_context(
  self : Tracer,
  name : String,
  context? : @context.Context,
  kind? : @api.SpanKind,
  attributes? : Map[String, AttributeValue],
  start_time_unix_nano? : Int64
) -> SpanSdk {
  let parent : @api.SpanContext? = match context {
    Some(ctx) => ctx.span_context()
    None => @context.current_span_context()
  }
  self.start_span(
    name,
    kind?=kind,
    parent?=parent,
    attributes?=attributes,
    start_time_unix_nano?=start_time_unix_nano,
  )
}

// Start a new root span with no parent.
pub fn Tracer::start_root_span(
  self : Tracer,
  name : String,
  kind? : @api.SpanKind,
  attributes? : Map[String, AttributeValue],
  start_time_unix_nano? : Int64
) -> SpanSdk {
  self.start_span(
    name,
    kind?=kind,
    attributes?=attributes,
    start_time_unix_nano?=start_time_unix_nano,
  )
}
