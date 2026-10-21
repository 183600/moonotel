///|
struct CompositeProbeProcessor {
  id : String
  log : Ref[Array[String]]
  flushes : Ref[Int32]
  shutdowns : Ref[Int32]
}

///|
pub impl @sdk.SpanProcessor for CompositeProbeProcessor with fn on_start(
  self,
  span,
) {
  self.log.val.push(self.id + ":start:" + span.name())
}

///|
pub impl @sdk.SpanProcessor for CompositeProbeProcessor with fn on_end(
  self,
  data,
) {
  self.log.val.push(self.id + ":end:" + data.name)
}

///|
pub impl @sdk.SpanProcessor for CompositeProbeProcessor with fn force_flush(
  self,
) {
  self.flushes.val = self.flushes.val + 1
}

///|
pub impl @sdk.SpanProcessor for CompositeProbeProcessor with fn shutdown(self) {
  self.shutdowns.val = self.shutdowns.val + 1
}

///|
fn composite_probe(
  id : String,
  log : Ref[Array[String]],
) -> CompositeProbeProcessor {
  { id, log, flushes: Ref(0), shutdowns: Ref(0), }
}

///|
test "multi_span_processor_forwards_in_order" {
  let log : Ref[Array[String]] = Ref([])
  let first = composite_probe("first", log)
  let second = composite_probe("second", log)
  let processors : Array[&@sdk.SpanProcessor] = [first, second]
  let multi = @sdk.MultiSpanProcessor::new(processors~)
  assert_eq(multi.processor_count(), 2)
  let provider = @sdk.TracerProviderSdk::new(service_name="multi")
    .with_span_processor(multi)
    .with_sampler(@sdk.Sampler::always_on())
  provider.get_tracer("multi").start_root_span("root").end()
  assert_eq(log.val.length(), 4)
  assert_eq(log.val[0], "first:start:root")
  assert_eq(log.val[1], "second:start:root")
  assert_eq(log.val[2], "first:end:root")
  assert_eq(log.val[3], "second:end:root")
}

///|
test "multi_span_processor_flushes_and_shuts_down_each_child_once" {
  let log : Ref[Array[String]] = Ref([])
  let first = composite_probe("first", log)
  let second = composite_probe("second", log)
  let multi = @sdk.MultiSpanProcessor::new(processors=[first, second])
  multi.force_flush()
  multi.shutdown()
  multi.shutdown()
  multi.force_flush()
  assert_true(multi.is_shutdown())
  assert_eq(first.flushes.val, 1)
  assert_eq(second.flushes.val, 1)
  assert_eq(first.shutdowns.val, 1)
  assert_eq(second.shutdowns.val, 1)
}

///|
test "multi_span_processor_ignores_events_after_shutdown" {
  let log : Ref[Array[String]] = Ref([])
  let first = composite_probe("first", log)
  let multi = @sdk.MultiSpanProcessor::new(processors=[first])
  multi.shutdown()
  let provider = @sdk.TracerProviderSdk::new(service_name="multi-off").with_span_processor(
    multi,
  )
  provider.get_tracer("multi-off").start_root_span("late").end()
  assert_eq(log.val.length(), 0)
}

///|
test "multi_span_processor_with_processor_does_not_mutate_the_source" {
  let log : Ref[Array[String]] = Ref([])
  let first = composite_probe("first", log)
  let empty = @sdk.MultiSpanProcessor::new()
  let one = empty.with_processor(first)
  assert_eq(empty.processor_count(), 0)
  assert_eq(one.processor_count(), 1)
}

///|
test "provider_registers_several_processors_at_once" {
  let log : Ref[Array[String]] = Ref([])
  let first = composite_probe("first", log)
  let second = composite_probe("second", log)
  let provider = @sdk.TracerProviderSdk::new(service_name="multi-provider")
    .with_span_processors([first, second])
    .with_sampler(@sdk.Sampler::always_on())
  assert_eq(provider.processor_count(), 2)
  provider.get_tracer("multi-provider").start_root_span("root").end()
  assert_eq(log.val.length(), 4)
  assert_eq(log.val[0], "first:start:root")
  assert_eq(log.val[2], "first:end:root")
}
