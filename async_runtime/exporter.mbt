// An OTLP/HTTP span exporter that sends batches from a background task.
//
// Span processors call `export_spans` synchronously when spans end, but the
// production OTLP transport (`moonbitlang/async/http`) is asynchronous. This
// exporter bridges the two: `export_spans` appends the batch to an in-memory
// queue and a background task created in the caller's `TaskGroup` drains the
// queue and performs the HTTP request with `@otlp_async`.
//
// The queue is bounded (oldest batches are discarded when full) so that a slow
// or unavailable collector cannot grow the process without bound. When the
// exporter is shut down, or when the surrounding task group is cancelled, the
// pending queue is drained before the background task exits, so shutdown does
// not lose spans that were already accepted.

// Most spans coalesced into a single OTLP request.
const MAX_EXPORT_SPANS : Int = 512

pub struct OtlpHttpAsyncSpanExporter {
  config : @otlp.OtlpHttpConfig
  queue : @aqueue.Queue[Array[@sdk.SpanData]]
  mut shutdown_called : Bool
  mut dropped : UInt64
}

// Create an exporter and start its background sender in `group`. The queue
// holds at most `max_queue_size` batches (default 256); when it is full the
// oldest batch is discarded and counted by `dropped_batches`.
pub fn[G] OtlpHttpAsyncSpanExporter::new(
  config : @otlp.OtlpHttpConfig,
  group : @async.TaskGroup[G],
  max_queue_size? : Int
) -> OtlpHttpAsyncSpanExporter {
  let size = match max_queue_size {
    Some(value) => if value < 1 { 1 } else { value }
    None => 256
  }
  let exporter : OtlpHttpAsyncSpanExporter = {
    config,
    queue: @aqueue.Queue(kind=@aqueue.DiscardOldest(size)),
    shutdown_called: false,
    dropped: 0,
  }
  group.spawn_bg(no_wait=true) <| () => { exporter.run() }
  exporter
}

// The exporter configuration.
pub fn OtlpHttpAsyncSpanExporter::config(
  self : OtlpHttpAsyncSpanExporter
) -> @otlp.OtlpHttpConfig {
  self.config
}

// Number of batches discarded because the queue was full.
pub fn OtlpHttpAsyncSpanExporter::dropped_batches(
  self : OtlpHttpAsyncSpanExporter
) -> UInt64 {
  self.dropped
}

// Whether `shutdown` has been called.
pub fn OtlpHttpAsyncSpanExporter::is_shutdown(
  self : OtlpHttpAsyncSpanExporter
) -> Bool {
  self.shutdown_called
}

// Queue a batch for the background sender. Never blocks: when the queue is
// full the oldest batch is dropped to make room.
fn OtlpHttpAsyncSpanExporter::enqueue(
  self : OtlpHttpAsyncSpanExporter,
  spans : Array[@sdk.SpanData]
) -> @sdk.ExportResult {
  if self.shutdown_called {
    return @sdk.ExportFailure("OTLP async exporter is shut down")
  }
  let accepted = try {
    self.queue.try_put(spans)
  } catch {
    _ => false
  }
  if accepted {
    return @sdk.ExportSuccess
  }
  // `try_put` refuses to evict when the queue is full, so discard the oldest
  // batch explicitly and retry once.
  let _ : Array[@sdk.SpanData]? = try {
    self.queue.try_get()
  } catch {
    _ => None
  }
  let accepted = try {
    self.queue.try_put(spans)
  } catch {
    _ => false
  }
  self.dropped = self.dropped + 1
  if accepted {
    @sdk.ExportSuccess
  } else {
    @sdk.ExportFailure("OTLP async export queue is full")
  }
}

// Export `first` plus every batch that is already queued.
async fn OtlpHttpAsyncSpanExporter::export_available(
  self : OtlpHttpAsyncSpanExporter,
  first : Array[@sdk.SpanData]
) -> Unit {
  let batch : Array[@sdk.SpanData] = []
  for data in first {
    batch.push(data)
  }
  while batch.length() < MAX_EXPORT_SPANS {
    let next : Array[@sdk.SpanData]? = try {
      self.queue.try_get()
    } catch {
      _ => None
    }
    match next {
      Some(items) => {
        for data in items {
          batch.push(data)
        }
      }
      None => break
    }
  }
  self.send(batch)
}

// Send one OTLP request. The request is protected from cancellation so that a
// batch already taken from the queue is not lost when the task group exits
// while a request is in flight; `timeout_millis` bounds how long shutdown can
// be delayed by an unresponsive collector.
async fn OtlpHttpAsyncSpanExporter::send(
  self : OtlpHttpAsyncSpanExporter,
  batch : Array[@sdk.SpanData]
) -> Unit {
  if batch.length() == 0 {
    return
  }
  let timeout = self.config.timeout_millis
  let _ = @async.protect_from_cancel(() => {
    let outcome : @sdk.ExportResult? = if timeout > 0 {
      try {
        Some(
          @async.with_timeout(
            timeout,
            () => @otlp_async.export_spans(self.config, batch),
          ),
        )
      } catch {
        _ => None
      }
    } else {
      Some(@otlp_async.export_spans(self.config, batch))
    }
    let _ = outcome
  })
}

// Drain and export everything left in the queue.
async fn OtlpHttpAsyncSpanExporter::drain(
  self : OtlpHttpAsyncSpanExporter
) -> Unit {
  while true {
    let next : Array[@sdk.SpanData]? = try {
      self.queue.try_get()
    } catch {
      _ => None
    }
    match next {
      Some(batch) => self.export_available(batch)
      None => break
    }
  }
}

// The background sender: export batches until the queue is closed or the task
// is cancelled, then drain whatever remains.
async fn OtlpHttpAsyncSpanExporter::run(
  self : OtlpHttpAsyncSpanExporter
) -> Unit {
  defer {
    let _ = @async.protect_from_cancel(() => { self.drain() })
  }
  while true {
    let next : Array[@sdk.SpanData]? = try {
      Some(self.queue.get())
    } catch {
      _ => None
    }
    match next {
      Some(batch) => self.export_available(batch)
      None => break
    }
  }
}

pub impl @sdk.SpanExporter for OtlpHttpAsyncSpanExporter with export_spans(self, spans) {
  self.enqueue(spans)
}

pub impl @sdk.SpanExporter for OtlpHttpAsyncSpanExporter with shutdown(self) {
  if !self.shutdown_called {
    self.shutdown_called = true
    self.queue.close()
  }
}

pub extend OtlpHttpAsyncSpanExporter with @sdk.SpanExporter::{export_spans, shutdown}
