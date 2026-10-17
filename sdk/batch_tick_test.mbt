// Tests for time-based flushing in BatchSpanProcessor. The interval is only
// consulted when spans end or when `tick` is called, so these tests use a
// short interval and busy-wait for the clock to advance.

fn wait_millis(millis : UInt64) -> Unit {
  let start = @env.now()
  while @env.now() - start < millis {
  }
}

test "timed_flush_does_not_trigger_immediately" {
  let exporter : ProbeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=60000,
  )
  processor.on_end(probe_span("s0"))
  processor.tick()
  assert_eq(exporter.names.length(), 0)
  assert_eq(processor.queue_size(), 1)
}

test "tick_flushes_after_interval_elapsed" {
  let exporter : ProbeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=1,
  )
  processor.on_end(probe_span("s0"))
  // With a 1ms interval the span may already have been exported by `on_end`
  // when the interval elapsed between construction and the call; either way
  // exactly one copy must be pending or exported, never lost or duplicated.
  assert_eq(processor.queue_size() + exporter.names.length(), 1)
  wait_millis(5)
  processor.tick()
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, ["s0"]))
}

test "on_end_flushes_when_interval_elapsed" {
  let exporter : ProbeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=1,
  )
  processor.on_end(probe_span("s0"))
  wait_millis(5)
  processor.on_end(probe_span("s1"))
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1"]))
}

test "flush_interval_zero_disables_timed_flush" {
  let exporter : ProbeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=0,
  )
  assert_eq(processor.flush_interval_millis(), 0)
  processor.on_end(probe_span("s0"))
  wait_millis(5)
  processor.tick()
  assert_eq(processor.queue_size(), 1)
  assert_eq(exporter.names.length(), 0)
}

test "tick_on_empty_queue_is_noop" {
  let exporter : ProbeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    flush_interval_millis=1,
  )
  wait_millis(5)
  processor.tick()
  assert_eq(exporter.names.length(), 0)
}

test "timed_flush_respects_batch_size" {
  let exporter : ProbeExporter = { names: [] }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=2,
    flush_interval_millis=1,
  )
  processor.on_end(probe_span("s0"))
  processor.on_end(probe_span("s1"))
  processor.on_end(probe_span("s2"))
  assert_eq(processor.queue_size(), 1)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1"]))
  wait_millis(5)
  processor.tick()
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, ["s0", "s1", "s2"]))
}
