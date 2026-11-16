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
  // Each queued batch carries the sequence number assigned when it was
  // accepted. Sequence numbers let `flush` wait only for batches that existed
  // when it started, without waiting for spans that keep arriving.
  queue : @aqueue.Queue[(UInt64, Array[@sdk.SpanData])]
  mut shutdown_called : Bool
  mut dropped : UInt64
  mut failures : UInt64
  mut active_sends : Int32
  // Number of batches accepted by `enqueue`; also the sequence number of the
  // next accepted batch.
  mut accepted_batches : UInt64
  // Number of accepted batches whose export attempt has finished (including
  // batches discarded on overflow).
  mut completed_batches : UInt64
  // Every batch with a sequence number below this value has finished. This is
  // the contiguous completion watermark used by `flush`.
  mut completed_prefix : UInt64
  // Accepted batches that have neither finished nor been discarded.
  outstanding_batches : Map[UInt64, Unit]
  // A batch pulled from the head of the queue that `flush` does not own. It is
  // put back logically in front of the queue and taken first by the background
  // sender.
  mut deferred_batch : (UInt64, Array[@sdk.SpanData])?
  send_finished : @cond_var.Cond
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
    active_sends: 0,
    accepted_batches: 0,
    completed_batches: 0,
    completed_prefix: 0,
    outstanding_batches: Map([]),
    deferred_batch: None,
    send_finished: @cond_var.Cond(),
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

// Drain and export every batch accepted before this call, waiting for the
// OTLP requests to finish. Spans accepted after the flush started may remain
// in the queue for the background sender. Failed requests are counted by
// `export_failures`; they are not retried beyond the exporter's configured
// retry policy.

///|
pub async fn OtlpHttpAsyncSpanExporter::flush(
  self : OtlpHttpAsyncSpanExporter,
) -> Unit {
  // Snapshot the sequence counter: batches accepted after this point are not
  // part of this flush. Using a per-batch watermark instead of the global
  // accepted/completed counters keeps the wait bounded even while producers
  // keep enqueueing spans.
  let target = self.accepted_batches
  while true {
    self.drain_until(target)
    if self.completed_prefix >= target {
      return
    }
    self.send_finished.wait()
  }
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
  // An empty export is a no-op success, like the synchronous and async OTLP
  // exporters. It must not occupy a queue slot or evict a real batch.
  if spans.length() == 0 {
    return @sdk.ExportSuccess
  }
  let sequence = self.accepted_batches
  let mut accepted = self.queue.try_put((sequence, spans)) catch { _ => false }
  if !accepted {
    // The queue is full: discard the oldest batch to make room, then retry
    // once.
    let discarded : (UInt64, Array[@sdk.SpanData])? = self.queue.try_get() catch {
      _ => None
    }
    accepted = self.queue.try_put((sequence, spans)) catch { _ => false }
    match discarded {
      Some((discarded_sequence, _)) => {
        self.dropped = self.dropped + 1
        // The evicted batch will never be exported; mark it finished so a
        // waiting `flush` does not wait for it forever.
        self.finish_batch(discarded_sequence)
      }
      None => ()
    }
  }
  if accepted {
    self.accepted_batches = self.accepted_batches + 1
    self.outstanding_batches.set(sequence, ())
    @sdk.ExportSuccess
  } else {
    @sdk.ExportFailure("OTLP async export queue is full")
  }
}

// Take the next batch for export: a batch deferred by `flush` comes first,
// then the head of the queue.

///|
fn OtlpHttpAsyncSpanExporter::try_take_batch(
  self : OtlpHttpAsyncSpanExporter,
) -> (UInt64, Array[@sdk.SpanData])? raise {
  match self.deferred_batch {
    Some(batch) => {
      self.deferred_batch = None
      Some(batch)
    }
    None => self.queue.try_get()
  }
}

// Export `first` plus batches already queued, sending at most
// `MAX_EXPORT_SPANS` spans per request. A queued batch that does not fit in
// the room left is split so no request exceeds the limit.

///|
async fn OtlpHttpAsyncSpanExporter::export_available(
  self : OtlpHttpAsyncSpanExporter,
  first_sequence : UInt64,
  first : Array[@sdk.SpanData],
) -> Array[UInt64] {
  // Coalescing appends queued spans to `batch`; own the array so the caller's
  // batch is never modified.
  let mut pending = first.copy()
  // Sequence numbers of the accepted batches this call finishes, including
  // `first`.
  let processed : Array[UInt64] = [first_sequence]
  let mut split = false
  while pending.length() > 0 {
    // The queue loop below only enforces the limit on spans appended from the
    // queue, so split an oversized batch (either the initial one or the
    // remainder of a split queued batch) before sending it.
    while pending.length() > MAX_EXPORT_SPANS {
      self.send(pending[:MAX_EXPORT_SPANS].to_owned())
      pending = pending[MAX_EXPORT_SPANS:].to_owned()
    }
    if pending.length() == 0 {
      break
    }
    let batch = pending
    batch.reserve_capacity(MAX_EXPORT_SPANS)
    while batch.length() < MAX_EXPORT_SPANS {
      let next : (UInt64, Array[@sdk.SpanData])? = self.try_take_batch() catch {
        _ => None
      }
      match next {
        Some((sequence, items)) => {
          processed.push(sequence)
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
  processed
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
  self.active_sends = self.active_sends + 1
  defer {
    self.active_sends = self.active_sends - 1
    self.send_finished.broadcast()
  }
  let timeout = self.exporter.config().effective_timeout_millis()
  let _ = @async.protect_from_cancel(() => {
    let outcome : @sdk.ExportResult? = if timeout > 0 {
      Some(
        @async.with_timeout(timeout, () => self.exporter.export_batch(batch)),
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

// Advance the contiguous completion watermark over batches that are already
// finished. A batch is finished either because its export attempt completed or
// because it was discarded on overflow.

///|
fn OtlpHttpAsyncSpanExporter::advance_completed_prefix(
  self : OtlpHttpAsyncSpanExporter,
) -> Unit {
  while self.completed_prefix < self.accepted_batches &&
        !self.outstanding_batches.contains(self.completed_prefix) {
    self.completed_prefix = self.completed_prefix + 1
  }
}

// Mark one accepted batch as handled without updating the completion
// watermark. Callers update the watermark once after a group of batches.

///|
fn OtlpHttpAsyncSpanExporter::mark_batch_completed(
  self : OtlpHttpAsyncSpanExporter,
  sequence : UInt64,
) -> Unit {
  let _ = self.outstanding_batches.remove(sequence)
  self.completed_batches = self.completed_batches + 1
}

// Record that one accepted batch has been fully handled.

///|
fn OtlpHttpAsyncSpanExporter::finish_batch(
  self : OtlpHttpAsyncSpanExporter,
  sequence : UInt64,
) -> Unit {
  self.mark_batch_completed(sequence)
  self.advance_completed_prefix()
  self.send_finished.broadcast()
}

// Record that `sequences` accepted batches have been fully handled and wake
// any `flush` waiting for them.

///|
fn OtlpHttpAsyncSpanExporter::finish_batches(
  self : OtlpHttpAsyncSpanExporter,
  sequences : Array[UInt64],
) -> Unit {
  for sequence in sequences {
    self.mark_batch_completed(sequence)
  }
  self.advance_completed_prefix()
  self.send_finished.broadcast()
}

// Drain and export everything left in the queue.

///|
async fn OtlpHttpAsyncSpanExporter::drain(
  self : OtlpHttpAsyncSpanExporter,
) -> Unit {
  while true {
    let next : (UInt64, Array[@sdk.SpanData])? = self.try_take_batch() catch {
      _ => None
    }
    match next {
      Some((sequence, batch)) => {
        let processed = self.export_available(sequence, batch)
        self.finish_batches(processed)
      }
      None => break
    }
  }
}

// Export queued batches only until every batch accepted before `target` has
// finished. A producer that keeps enqueueing spans would otherwise keep the
// full drain below busy indefinitely. A batch that belongs to a later flush is
// put back in `deferred_batch` instead of being exported here.

///|
async fn OtlpHttpAsyncSpanExporter::drain_until(
  self : OtlpHttpAsyncSpanExporter,
  target : UInt64,
) -> Unit {
  while self.completed_prefix < target {
    let next : (UInt64, Array[@sdk.SpanData])? = self.try_take_batch() catch {
      _ => None
    }
    match next {
      Some((sequence, batch)) => {
        if sequence >= target {
          // Belongs to a later flush or to the background sender; put it back
          // without spending a request on it.
          self.deferred_batch = Some((sequence, batch))
          break
        }
        let processed = self.export_available(sequence, batch)
        self.finish_batches(processed)
      }
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
    let next : (UInt64, Array[@sdk.SpanData])? = match self.deferred_batch {
      Some(batch) => {
        self.deferred_batch = None
        Some(batch)
      }
      None => Some(self.queue.get()) catch { _ => None }
    }
    match next {
      Some((sequence, batch)) => {
        let processed = self.export_available(sequence, batch)
        self.finish_batches(processed)
      }
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
