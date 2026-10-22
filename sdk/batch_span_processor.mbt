// A SpanProcessor that buffers finished sampled spans and exports them in
// batches.
//
// The processor is bounded: when the queue exceeds `max_queue_size` the oldest
// spans are dropped. A batch is exported synchronously as soon as the queue
// reaches `max_export_batch_size`, when `flush_interval_millis` has elapsed
// since the last export, and when `force_flush`/`shutdown` drain the queue.
//
// `flush_interval_millis` is only consulted when spans end or when `tick` is
// called; long-running applications that go quiet should call `tick` from
// their own loop (or use an async flush helper) to guarantee a timely export.

///|
pub struct BatchSpanProcessor {
  exporter : &SpanExporter
  max_queue_size : Int32
  max_export_batch_size : Int32
  flush_interval_millis : Int32
  // Fixed-capacity ring buffer: `head` is the index of the oldest buffered
  // span and `count` is how many spans are live. Once full, the oldest span is
  // overwritten in place; consumed slots are reset to `None`.
  queue : Array[SpanData?]
  mut head : Int32
  mut count : Int32
  mut last_flush_time_millis : UInt64
  mut shutdown_called : Bool
  mut dropped_spans : UInt64
  mut export_failures : UInt64
}

// Create a batch processor. Defaults: queue size 2048, batch size 512,
// flush interval 5000ms.

///|
pub fn BatchSpanProcessor::new(
  exporter : &SpanExporter,
  max_queue_size? : Int32,
  max_export_batch_size? : Int32,
  flush_interval_millis? : Int32,
) -> BatchSpanProcessor {
  let queue_size = max_queue_size.unwrap_or(2048)
  let batch_size = max_export_batch_size.unwrap_or(512)
  let interval = flush_interval_millis.unwrap_or(5000)
  {
    exporter,
    max_queue_size: if queue_size < 1 {
      1
    } else {
      queue_size
    },
    max_export_batch_size: if batch_size < 1 {
      1
    } else {
      batch_size
    },
    flush_interval_millis: if interval < 0 {
      0
    } else {
      interval
    },
    queue: [],
    head: 0,
    count: 0,
    last_flush_time_millis: @env.now(),
    shutdown_called: false,
    dropped_spans: 0,
    export_failures: 0,
  }
}

// Create a batch processor with an explicit `BatchConfig`.

///|
pub fn BatchSpanProcessor::with_config(
  exporter : &SpanExporter,
  config : BatchConfig,
) -> BatchSpanProcessor {
  BatchSpanProcessor::new(
    exporter,
    max_queue_size=config.max_queue_size,
    max_export_batch_size=config.max_export_batch_size,
    flush_interval_millis=config.flush_interval_millis,
  )
}

// Create a batch processor configured from the standard
// `OTEL_BSP_*` environment variables; see `BatchConfig::from_env`.

///|
pub fn BatchSpanProcessor::from_env(
  exporter : &SpanExporter,
) -> BatchSpanProcessor {
  BatchSpanProcessor::with_config(exporter, BatchConfig::from_env())
}

// Number of spans currently buffered.

///|
pub fn BatchSpanProcessor::queue_size(self : BatchSpanProcessor) -> Int32 {
  self.count
}

// The scheduled flush interval in milliseconds (0 disables timed flushes).

///|
pub fn BatchSpanProcessor::flush_interval_millis(
  self : BatchSpanProcessor,
) -> Int32 {
  self.flush_interval_millis
}

// Whether `shutdown` has been called.

///|
pub fn BatchSpanProcessor::is_shutdown(self : BatchSpanProcessor) -> Bool {
  self.shutdown_called
}

// Number of spans discarded because the queue was full.

///|
pub fn BatchSpanProcessor::dropped_spans(self : BatchSpanProcessor) -> UInt64 {
  self.dropped_spans
}

// Number of export attempts that failed. Failures are not retried; a non-zero
// value lets callers react (for example by logging or backing off).

///|
pub fn BatchSpanProcessor::export_failures(
  self : BatchSpanProcessor,
) -> UInt64 {
  self.export_failures
}

// Append a span, overwriting the oldest buffered span when the queue is full.

///|
fn BatchSpanProcessor::push_span(
  self : BatchSpanProcessor,
  data : SpanData,
) -> Unit {
  let capacity = self.max_queue_size
  if self.count >= capacity {
    self.queue.unsafe_set(self.head, Some(data))
    let next = self.head + 1
    self.head = if next >= capacity { 0 } else { next }
    self.dropped_spans = self.dropped_spans + 1
    return
  }
  let index = self.head + self.count
  let index = if index >= capacity { index - capacity } else { index }
  if index >= self.queue.length() {
    self.queue.push(Some(data))
  } else {
    self.queue.unsafe_set(index, Some(data))
  }
  self.count = self.count + 1
}

// Export up to `max_export_batch_size` spans from the front of the queue.

///|
pub fn BatchSpanProcessor::flush_batch(self : BatchSpanProcessor) -> Unit {
  self.flush_batch_at(@env.now())
}

// Export up to `max_export_batch_size` spans from the front of the queue,
// stamping the flush with `now`.

///|
fn BatchSpanProcessor::flush_batch_at(
  self : BatchSpanProcessor,
  now : UInt64,
) -> Unit {
  let available = self.count
  if available == 0 {
    return
  }
  let n = if available < self.max_export_batch_size {
    available
  } else {
    self.max_export_batch_size
  }
  let capacity = self.max_queue_size
  let queue = self.queue
  let batch : Array[SpanData] = Array::unsafe_make_uninit(n)
  let mut index = self.head
  let mut i = 0
  while i < n {
    match queue.unsafe_get(index) {
      Some(data) => batch.unsafe_set(i, data)
      // Every slot in the live range must hold a span; fail loudly instead of
      // leaving an uninitialized element in the exported batch.
      None =>
        abort(
          "BatchSpanProcessor queue invariant violated: empty slot in live range",
        )
    }
    queue.unsafe_set(index, None)
    index = index + 1
    if index >= capacity {
      index = 0
    }
    i = i + 1
  }
  self.head = index
  self.count = available - n
  self.last_flush_time_millis = now
  match self.exporter.export_spans(batch) {
    ExportSuccess => ()
    ExportFailure(_) => self.export_failures = self.export_failures + 1
  }
}

// Export the queue when the scheduled flush interval has elapsed. This is a
// no-op when the queue is empty or the interval has not elapsed, so it is safe
// to call from a periodic loop.

///|
pub fn BatchSpanProcessor::tick(self : BatchSpanProcessor) -> Unit {
  if self.shutdown_called || self.count == 0 {
    return
  }
  if self.flush_interval_millis > 0 {
    let now = @env.now()
    if now >= self.last_flush_time_millis &&
      now - self.last_flush_time_millis >=
      self.flush_interval_millis.to_uint64() {
      self.flush_batch_at(now)
    }
  }
}

///|
pub impl SpanProcessor for BatchSpanProcessor with fn on_start(self, _span) {
  let _ = self
}

///|
pub impl SpanProcessor for BatchSpanProcessor with fn on_end(self, data) {
  if self.shutdown_called {
    return
  }
  if !data.span_context.is_sampled() {
    return
  }
  self.push_span(data)
  if self.count >= self.max_export_batch_size {
    self.flush_batch_at(@env.now())
  } else if self.flush_interval_millis > 0 {
    let now = @env.now()
    if now >= self.last_flush_time_millis &&
      now - self.last_flush_time_millis >=
      self.flush_interval_millis.to_uint64() {
      self.flush_batch_at(now)
    }
  }
}

///|
pub impl SpanProcessor for BatchSpanProcessor with fn force_flush(self) {
  if self.count > 0 {
    let now = @env.now()
    while self.count > 0 {
      self.flush_batch_at(now)
    }
  }
}

///|
pub impl SpanProcessor for BatchSpanProcessor with fn drain_before_shutdown(
  self,
) {
  if !self.shutdown_called && self.count > 0 {
    let now = @env.now()
    while self.count > 0 {
      self.flush_batch_at(now)
    }
  }
}

///|
pub impl SpanProcessor for BatchSpanProcessor with fn shutdown(self) {
  if !self.shutdown_called {
    // Mark the processor shut down before draining. An exporter may call back
    // into `shutdown` from `export_spans`; the reentrant call must not drain
    // the queue again or shut the exporter down a second time.
    self.shutdown_called = true
    if self.count > 0 {
      let now = @env.now()
      while self.count > 0 {
        self.flush_batch_at(now)
      }
    }
    self.exporter.shutdown()
  }
}

///|
pub extend BatchSpanProcessor with SpanProcessor::{
  on_end,
  on_start,
  force_flush,
  drain_before_shutdown,
  shutdown,
}
