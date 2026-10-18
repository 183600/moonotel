// Tests for the async scoped-span helper `Tracer::with_span_async`.
//
// The native test driver runs async tests concurrently, and the default
// current-context storage is a single process-wide slot, so these tests only
// observe the ambient context at points that cannot interleave with other
// tests: inside the closure before its first await, and immediately after a
// `with_span_async` call whose closure never suspends.

struct AsyncScopeExporter {
  spans : Ref[Array[@sdk.SpanData]]
}

pub impl @sdk.SpanExporter for AsyncScopeExporter with export_spans(self, spans) {
  for data in spans {
    self.spans.val.push(data)
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for AsyncScopeExporter with shutdown(self) {
  let _ = self
}

fn span_context_eq(a : @api.SpanContext?, b : @api.SpanContext?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) =>
      x.span_id_hex() == y.span_id_hex() &&
      x.trace_id_hex() == y.trace_id_hex()
    _ => false
  }
}

fn async_scope_provider() -> (@sdk.TracerProviderSdk, AsyncScopeExporter) {
  let exporter : AsyncScopeExporter = { spans: Ref([]) }
  let provider = @sdk.TracerProviderSdk::new(service_name="with-span-async")
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
    .with_sampler(@sdk.Sampler::always_on())
  (provider, exporter)
}

async test "with_span_async returns the closure result" {
  let (provider, _exporter) = async_scope_provider()
  let tracer = provider.get_tracer("with-span-async")
  let value = tracer.with_span_async("value", (_span) => 21 * 2)
  assert_eq(value, 42)
}

async test "with_span_async installs the span as the current context" {
  let (provider, exporter) = async_scope_provider()
  let tracer = provider.get_tracer("with-span-async")
  let entry_matches : Ref[Bool] = Ref(false)
  let outer_context : Ref[@api.SpanContext?] = Ref(None)
  tracer.with_span_async("outer", (span) => {
    outer_context.val = Some(span.context())
    entry_matches.val = match @context.current_span_context() {
      Some(current) => current.span_id_hex() == span.context().span_id_hex()
      None => false
    }
    // Started before the first await, so the ambient context cannot have
    // been overwritten by a concurrently running test.
    let child = tracer.start_span_with_context("inner")
    assert_true(child.is_recording())
    child.end()
    @async.sleep(10)
    assert_true(span.context().is_valid())
  })
  assert_true(entry_matches.val)
  let outer = outer_context.val.unwrap()
  assert_eq(exporter.spans.val.length(), 2)
  // The child span ends first, so it is exported first.
  let child_data = exporter.spans.val[0]
  let outer_data = exporter.spans.val[1]
  assert_eq(outer_data.name, "outer")
  assert_eq(outer_data.span_context.span_id_hex(), outer.span_id_hex())
  assert_eq(child_data.name, "inner")
  assert_eq(child_data.span_context.trace_id_hex(), outer.trace_id_hex())
  assert_eq(child_data.parent_span_id, outer_data.span_context.span_id())
}

async test "with_span_async restores the previous context" {
  let (provider, _exporter) = async_scope_provider()
  let tracer = provider.get_tracer("with-span-async")
  let previous = @context.attach(
    @context.Context::root().with_value("user.id", "ada"),
  )
  let entry_value : Ref[String?] = Ref(None)
  let entry_has_span : Ref[Bool] = Ref(false)
  // The closure never suspends, so no other test can modify the slot between
  // the helper's `attach` and the assertions below.
  tracer.with_span_async("scoped", (_span) => {
    entry_value.val = @context.current_context().value("user.id")
    entry_has_span.val = @context.current_span_context() is Some(_)
  })
  assert_eq(entry_value.val, Some("ada"))
  assert_true(entry_has_span.val)
  assert_eq(@context.current_context().value("user.id"), Some("ada"))
  assert_true(@context.current_span_context() is None)
  @context.detach(previous)
}

async test "with_span_async ends the span when the closure raises" {
  // Another test may be holding its span in the shared slot, so compare
  // against the baseline instead of assuming an empty context.
  let baseline = @context.current_span_context()
  let (provider, exporter) = async_scope_provider()
  let tracer = provider.get_tracer("with-span-async")
  let caught : Ref[Bool] = Ref(false)
  try {
    tracer.with_span_async("raising", (_span) => {
      fail("boom")
    })
  } catch {
    _ => caught.val = true
  }
  assert_true(caught.val)
  assert_eq(exporter.spans.val.length(), 1)
  let data = exporter.spans.val[0]
  assert_eq(data.name, "raising")
  assert_true(data.end_time_unix_nano > 0L)
  // The previous context is restored even on the raising path; the closure
  // never suspended, so the check is race-free.
  assert_true(span_context_eq(@context.current_span_context(), baseline))
}

async test "with_span_async without a parent starts a root span" {
  let (provider, exporter) = async_scope_provider()
  let tracer = provider.get_tracer("with-span-async")
  // The explicit root context keeps the span parentless regardless of the
  // ambient context installed by concurrently running tests.
  tracer.with_span_async(
    "root",
    (span) => {
      assert_true(span.context().is_valid())
      assert_eq(span.parent_span_id().length(), 0)
    },
    context=@context.Context::root(),
  )
  assert_eq(exporter.spans.val.length(), 1)
  assert_eq(exporter.spans.val[0].parent_span_id.length(), 0)
}
