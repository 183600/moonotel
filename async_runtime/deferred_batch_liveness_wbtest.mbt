// White-box regression test: a batch that `flush`/`drain_until` pulls from the
// queue but does not own must be put back into the queue. Keeping it only in
// `deferred_batch` strands it when the background sender is already blocked in
// `queue.get()`, because nothing wakes that wait until another enqueue or
// shutdown.

///|
async test "drain_until puts a later batch back into the queue" {
  let queue : @aqueue.Queue[(UInt64, Array[@sdk.SpanData])] = @aqueue.Queue(
    kind=@aqueue.DiscardOldest(4),
  )
  let exporter : OtlpHttpAsyncSpanExporter = {
    exporter: @otlp_async.OtlpHttpAsyncExporter::new(
      @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:1"),
    ),
    queue,
    shutdown_called: false,
    dropped: 0,
    failures: 0,
    active_sends: 0,
    accepted_batches: 3,
    completed_batches: 0,
    completed_prefix: 0,
    outstanding_batches: Map([(1UL, ()), (2UL, ())]),
    deferred_batch: None,
    send_finished: @cond_var.Cond(),
  }
  let _ = queue.try_put((2UL, [split_probe_span("later")])) catch { _ => false }
  exporter.drain_until(1UL)
  match exporter.deferred_batch {
    Some(_) => fail("a requeued batch must not stay in deferred_batch")
    None => ()
  }
  match queue.try_get() {
    Some((sequence, batch)) => {
      assert_eq(sequence, 2UL)
      assert_eq(batch.length(), 1)
      assert_eq(batch[0].name, "later")
    }
    None => fail("the later batch must be put back into the queue")
  }
}
