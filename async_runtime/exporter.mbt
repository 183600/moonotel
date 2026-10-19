// An OTLP/HTTP span exporter that sends batches from a background task.
//
// Span processors call `export_spans` synchronously when spans end, but the
// production OTLP transport (`moonbitlang/async/http`) is asynchronous. This
// exporter bridges the two: `export_spans` appends the batch to an in-memory
// queue and a background task created in the caller's `TaskGroup` drains the
// queue and performs the HTTP request with `@otlp_async`.
//
// The queue is bounded: the oldest batches are discarded when it is full.
// When the exporter is shut down, or when the surrounding task group is
// cancelled, the pending queue is drained before the background task exits,
// so shutdown does not lose spans that were already accepted.

// Most spans coalesced into a single OTLP request.

///|
const MAX_EXPORT_SPANS : Int32 = 512

///|
pub struct OtlpHttpAsyncSpanExporter {
  exporter : @otlp_async.OtlpHttpAsyncExporter
  queue : @aqueue.Queue[Array[@sdk.SpanData]]
  mut shutdown_called : Bool
  mut dropped : UInt64
  mut failures : UInt64
}

// Create an exporter and start its background sender in `group`. The queue
// holds at most `max_queue_size` batches (default 256); when it is full the
// oldest batch is discarded and counted by `dropped_batches`.

///|
pub fn[G] OtlpHttpAsyncSpanExporter::new(
  config : @otlp.OtlpHttpConfig,
  group : @async.TaskGroup[G],
  max_queue_size? : Int32,
) -> OtlpHttpAsyncSpanExporter {
  let size = match max_queue_size {
    Some(value) => if value < 1 { 1 } else { value }
    None => 256
  }
  let exporter : OtlpHttpAsyncSpanExporter = {
    exporter: @otlp_async.OtlpHttpAsyncExporter::new(config),
    queue: @aqueue.Queue(kind=@aqueue.DiscardOldest(size)),
    shutdown_called: false,
    dropped: 0,
    failures: 0,
  }
  group.spawn_bg(no_wait=true) <| () => { exporter.run() }
  // The background sender is cancelled when the group exits, before the group
  // defers run. Defer a final drain as well so that batches queued by later
  // defers (for example a `spawn_flush_loop` force-flush registered after this
  // exporter was created, which runs first because defers run last-in-first-out)
  // are still exported.
  group.add_defer(() => @async.protect_from_cancel(() => exporter.drain()))
  exporter
}

// The exporter configuration.

///|
pub fn OtlpHttpAsyncSpanExporter::config(
  self : OtlpHttpAsyncSpanExporter,
) -> @otlp.OtlpHttpConfig {
  self.exporter.config()
}

// Number of batches discarded because the queue was full.

///|
pub fn OtlpHttpAsyncSpanExporter::dropped_batches(
  self : OtlpHttpAsyncSpanExporter,
) -> UInt64 {
  self.dropped
}

// Number of OTLP requests that failed to export, including requests that
// hit the configured timeout. The result of an asynchronous export cannot be
// reported through `export_spans`, so failures are surfaced here instead.

///|
pub fn OtlpHttpAsyncSpanExporter::export_failures(
  self : OtlpHttpAsyncSpanExporter,
) -> UInt64 {
  self.failures
}

// Whether `shutdown` has been called.

///|
pub fn OtlpHttpAsyncSpanExporter::is_shutdown(
  self : OtlpHttpAsyncSpanExporter,
) -> Bool {
  self.shutdown_called
}

// Queue a batch for the background sender. Never blocks: when the queue is
// full the oldest batch is dropped to make room.

///|
fn OtlpHttpAsyncSpanExporter::enqueue(
  self : OtlpHttpAsyncSpanExporter,
  spans : Array[@sdk.SpanData],
) -> @sdk.ExportResult {
  if self.shutdown_called {
    return @sdk.ExportFailure("OTLP async exporter is shut down")
  }
  let accepted = self.queue.try_put(spans) catch { _ => false }
  if accepted {
    return @sdk.ExportSuccess
  }
  // The queue is full: discard the oldest batch to make room, then retry once.
  let discarded : Bool = try {
    match self.queue.try_get() {
      Some(_) => true
      None => false
    }
  } catch {
    _ => false
  }
  let accepted = self.queue.try_put(spans) catch { _ => false }
  if discarded {
    self.dropped = self.dropped + 1
  }
  if accepted {
    @sdk.ExportSuccess
  } else {
    @sdk.ExportFailure("OTLP async export queue is full")
  }
}

// Export `first` plus batches already queued, sending at most
// `MAX_EXPORT_SPANS` spans per request. A queued batch that does not fit in
// the room left is split so no request exceeds the limit.

///|
async fn OtlpHttpAsyncSpanExporter::export_available(
  self : OtlpHttpAsyncSpanExporter,
  first : Array[@sdk.SpanData],
) -> Unit {
  let mut pending = first
  // The queue loop below only enforces the limit on spans appended from the
  // queue, so split an oversized initial batch first.
  while pending.length() > MAX_EXPORT_SPANS {
    self.send(pending[:MAX_EXPORT_SPANS].to_owned())
    pending = pending[MAX_EXPORT_SPANS:].to_owned()
  }
  let mut split = false
  while pending.length() > 0 {
    let batch = pending
    batch.reserve_capacity(MAX_EXPORT_SPANS)
    while batch.length() < MAX_EXPORT_SPANS {
      let next : Array[@sdk.SpanData]? = self.queue.try_get() catch { _ => None }
      match next {
        Some(items) => {
          let remaining = MAX_EXPORT_SPANS - batch.length()
          if items.length() <= remaining {
            batch.append(items)
          } else {
            batch.append(items[:remaining])
            pending = items[remaining:].to_owned()
            split = true
            break
          }
        }
        None => break
      }
    }
    self.send(batch)
    if !split {
      break
    }
    split = false
  }
}

// Send one OTLP request. The request is protected from cancellation so that a
// batch already taken from the queue is not lost when the task group exits
// while a request is in flight; `timeout_millis` bounds how long shutdown can
// be delayed by an unresponsive collector. A failed request (including a
// timeout) is counted and not retried here: the exporter below already retried
// it according to the configuration.

///|
async fn OtlpHttpAsyncSpanExporter::send(
  self : OtlpHttpAsyncSpanExporter,
  batch : Array[@sdk.SpanData],
) -> Unit {
  if batch.length() == 0 {
    return
  }
  let timeout = self.exporter.config().timeout_millis
  let _ = @async.protect_from_cancel(() => {
    let outcome : @sdk.ExportResult? = if timeout > 0 {
      Some(
        @async.with_timeout(timeout, () => {
          self.exporter.export_batch(batch)
        }),
      ) catch {
        _ => None
      }
    } else {
      Some(self.exporter.export_batch(batch))
    }
    match outcome {
      Some(@sdk.ExportSuccess) => ()
      _ => self.failures = self.failures + 1
    }
  })
}

// Drain and export everything left in the queue.

///|
async fn OtlpHttpAsyncSpanExporter::drain(
  self : OtlpHttpAsyncSpanExporter,
) -> Unit {
  while true {
    let next : Array[@sdk.SpanData]? = self.queue.try_get() catch { _ => None }
    match next {
      Some(batch) => self.export_available(batch)
      None => break
    }
  }
}

// The background sender: export batches until the queue is closed or the task
// is cancelled, then drain whatever remains.

///|
async fn OtlpHttpAsyncSpanExporter::run(
  self : OtlpHttpAsyncSpanExporter,
) -> Unit {
  defer {
    let _ = @async.protect_from_cancel(() => self.drain())
  }
  while true {
    let next : Array[@sdk.SpanData]? = Some(self.queue.get()) catch {
      _ => None
    }
    match next {
      Some(batch) => self.export_available(batch)
      None => break
    }
  }
}

///|
pub impl @sdk.SpanExporter for OtlpHttpAsyncSpanExporter with fn export_spans(
  self,
  spans,
) {
  self.enqueue(spans)
}

///|
pub impl @sdk.SpanExporter for OtlpHttpAsyncSpanExporter with fn shutdown(self) {
  if !self.shutdown_called {
    self.shutdown_called = true
    self.queue.close()
  }
}

///|
pub extend OtlpHttpAsyncSpanExporter with @sdk.SpanExporter::{
  export_spans,
  export_span,
  shutdown,
}
