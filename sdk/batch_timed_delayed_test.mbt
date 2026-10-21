///|
test "delayed_on_end_still_flushes_after_the_interval" {
  let exporter : ProbeExporter = { names: [], }
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_export_batch_size=10,
    flush_interval_millis=100,
  )
  let end_millis = @env.now()
  wait_millis(150)
  let span : @sdk.SpanData = {
    ..probe_span("delayed"),
    end_time_unix_nano: end_millis.reinterpret_as_int64() * 1000000L,
  }
  processor.on_end(span)
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, ["delayed"]))
}
