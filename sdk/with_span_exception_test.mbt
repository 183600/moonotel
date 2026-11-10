// Tests for the error recording done by `Tracer::with_span`. An error raised
// by the callback is recorded on the span (the exception semantic
// conventions: an `exception` event, an `error.type` attribute and an `Error`
// status), the original error is re-raised, and the deferred `end` +
// context-restore still run afterwards.

///|
struct WithSpanExceptionExporter {
  spans : Array[@sdk.SpanData]
}

///|
pub impl @sdk.SpanExporter for WithSpanExceptionExporter with fn export_spans(
  self,
  spans,
) {
  for span in spans {
    self.spans.push(span)
  }
  @sdk.ExportSuccess
}

///|
pub impl @sdk.SpanExporter for WithSpanExceptionExporter with fn shutdown(self) {
  let _ = self
}

///|
#derive(@debug.Debug)
suberror WithSpanBoom {
  WithSpanBoom(String)
}

///|
fn exception_tracer() -> (@sdk.Tracer, WithSpanExceptionExporter) {
  let exporter : WithSpanExceptionExporter = { spans: [], }
  let provider = @sdk.TracerProviderSdk::new(service_name="svc")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  (provider.get_tracer("t"), exporter)
}

// The `error.type` / status description derived from the raised error.

///|
fn type_name_from(exporter : WithSpanExceptionExporter) -> String {
  match exporter.spans[0].events[0].attributes.get(@sdk.EXCEPTION_TYPE) {
    Some(@sdk.StringValue(type_name)) => type_name
    Some(_) | None => "missing"
  }
}

///|
test "with_span records a raised error and re-raises it" {
  let (tracer, exporter) = exception_tracer()
  let raised = try {
    tracer.with_span("failing", span => {
      span.set_attribute("op.stage", @sdk.StringValue("before-error"))
      raise WithSpanBoom("boom")
    })
    false
  } catch {
    _ => true
  }
  assert_true(raised)
  assert_eq(exporter.spans.length(), 1)
  let data = exporter.spans[0]
  // The error event and attributes were recorded before the deferred `end`
  // ran, so the exported snapshot carries them.
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].name, "exception")
  match data.events[0].attributes.get(@sdk.EXCEPTION_MESSAGE) {
    Some(@sdk.StringValue(message)) => assert_true(message.contains("boom"))
    _ => fail("exception.message attribute is missing")
  }
  assert_true(type_name_from(exporter).contains("WithSpanBoom"))
  match data.attributes.get(@sdk.ERROR_TYPE) {
    Some(@sdk.StringValue(type_name)) =>
      match type_name.contains("WithSpanBoom") || type_name.contains("boom") {
        true => ()
        false => fail("error.type does not name the raised error: \{type_name}")
      }
    _ => fail("error.type attribute is missing")
  }
  assert_true(data.attributes.get("op.stage") is Some(_))
  assert_eq(data.status, @api.StatusCode::Error)
  // The status description matches the `exception.type` derived from the
  // error (`WithSpanBoom.WithSpanBoom`).
  assert_eq(data.status_description, type_name_from(exporter))
}

///|
test "with_span leaves the span ended and the context detached" {
  let (tracer, exporter) = exception_tracer()
  let observed : @ref.Ref[@api.SpanContext?] = @ref.Ref(None)
  let raised = try {
    tracer.with_span("failing", span => {
      observed.val = Some(span.context())
      raise WithSpanBoom("boom")
    })
    false
  } catch {
    _ => true
  }
  assert_true(raised)
  // The context no longer carries the span and the exported span is finished.
  assert_true(@context.current_span_context() is None)
  assert_eq(exporter.spans.length(), 1)
  assert_true(observed.val is Some(_))
}

///|
test "with_span without an error keeps the span unset" {
  let (tracer, exporter) = exception_tracer()
  let result = tracer.with_span("healthy", span => {
    span.set_attribute("op.stage", @sdk.StringValue("done"))
    "value"
  })
  assert_eq(result, "value")
  assert_eq(exporter.spans.length(), 1)
  let data = exporter.spans[0]
  assert_eq(data.events.length(), 0)
  assert_eq(data.status, @api.StatusCode::Unset)
  assert_eq(data.attributes.get("op.stage"), Some(@sdk.StringValue("done")))
}

///|
test "with_span keeps an Ok status set by the callback even when it raises" {
  let (tracer, exporter) = exception_tracer()
  let raised = try {
    tracer.with_span("late-failure", span => {
      span.set_status(@api.StatusCode::Ok)
      raise WithSpanBoom("boom")
    })
    false
  } catch {
    _ => true
  }
  assert_true(raised)
  assert_eq(exporter.spans.length(), 1)
  let data = exporter.spans[0]
  // `Ok` is final per the OpenTelemetry status rules; the `Error` attempt is
  // ignored, but the exception event and `error.type` are still recorded.
  assert_eq(data.status, @api.StatusCode::Ok)
  assert_eq(data.events.length(), 1)
  assert_eq(data.events[0].name, "exception")
  match data.attributes.get(@sdk.ERROR_TYPE) {
    Some(@sdk.StringValue(_)) => ()
    _ => fail("error.type attribute is missing")
  }
}
