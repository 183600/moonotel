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

pub struct BatchSpanProcessor {
  exporter : &SpanExporter
  max_queue_size : Int
  max_export_batch_size : Int
  flush_interval_millis : Int
  // Fixed-capacity ring buffer: `head` is the index of the oldest buffered
  // span and `count` is how many spans are live. Once full, the oldest span is
  // overwritten in place.
  queue : Array[SpanData]
  mut head : Int
  mut count : Int
  mut last_flush_time_millis : UInt64
  mut shutdown_called : Bool
  mut dropped_spans : UInt64
}

// Create a batch processor. Defaults: queue size 2048, batch size 512,
// flush interval 5000ms.
pub fn BatchSpanProcessor::new(
  exporter : &SpanExporter,
  max_queue_size? : Int,
  max_export_batch_size? : Int,
  flush_interval_millis? : Int
) -> BatchSpanProcessor {
  let queue_size = max_queue_size.unwrap_or(2048)
  let batch_size = max_export_batch_size.unwrap_or(512)
  let interval = flush_interval_millis.unwrap_or(5000)
  {
    exporter,
    max_queue_size: if queue_size < 1 { 1 } else { queue_size },
    max_export_batch_size: if batch_size < 1 { 1 } else { batch_size },
    flush_interval_millis: if interval < 0 { 0 } else { interval },
    queue: [],
    head: 0,
    count: 0,
    last_flush_time_millis: @env.now(),
    shutdown_called: false,
    dropped_spans: 0,
  }
}

// Create a batch processor with an explicit `BatchConfig`.
pub fn BatchSpanProcessor::with_config(
  exporter : &SpanExporter,
  config : BatchConfig
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
pub fn BatchSpanProcessor::from_env(
  exporter : &SpanExporter
) -> BatchSpanProcessor {
  BatchSpanProcessor::with_config(exporter, BatchConfig::from_env())
}

// Number of spans currently buffered.
pub fn BatchSpanProcessor::queue_size(self : BatchSpanProcessor) -> Int {
  self.count
}

// The scheduled flush interval in milliseconds (0 disables timed flushes).
pub fn BatchSpanProcessor::flush_interval_millis(
  self : BatchSpanProcessor
) -> Int {
  self.flush_interval_millis
}

// Whether `shutdown` has been called.
pub fn BatchSpanProcessor::is_shutdown(self : BatchSpanProcessor) -> Bool {
  self.shutdown_called
}

// Number of spans discarded because the queue was full.
pub fn BatchSpanProcessor::dropped_spans(
  self : BatchSpanProcessor
) -> UInt64 {
  self.dropped_spans
}

// Number of buffered spans, ignoring consumed slots at the front.
fn BatchSpanProcessor::live_count(self : BatchSpanProcessor) -> Int {
  self.count
}

// Append a span, overwriting the oldest buffered span when the queue is full.
fn BatchSpanProcessor::push_span(self : BatchSpanProcessor, data : SpanData) -> Unit {
  let capacity = self.max_queue_size
  if self.count >= capacity {
    self.queue.unsafe_set(self.head, data)
    let next = self.head + 1
    self.head = if next >= capacity { 0 } else { next }
    self.dropped_spans = self.dropped_spans + 1
    return
  }
  let index = self.head + self.count
  let index = if index >= capacity { index - capacity } else { index }
  if index >= self.queue.length() {
    self.queue.push(data)
  } else {
    self.queue.unsafe_set(index, data)
  }
  self.count = self.count + 1
}

// Export up to `max_export_batch_size` spans from the front of the queue.
pub fn BatchSpanProcessor::flush_batch(self : BatchSpanProcessor) -> Unit {
  self.flush_batch_at(@env.now())
}

// Export up to `max_export_batch_size` spans from the front of the queue,
// stamping the flush with `now`.
fn BatchSpanProcessor::flush_batch_at(
  self : BatchSpanProcessor,
  now : UInt64
) -> Unit {
  let available = self.live_count()
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
  let batch : Array[SpanData] = Array(capacity=n)
  let mut index = self.head
  let mut i = 0
  while i < n {
    batch.push(queue.unsafe_get(index))
    index = index + 1
    if index >= capacity {
      index = 0
    }
    i = i + 1
  }
  self.head = index
  self.count = available - n
  self.last_flush_time_millis = now
  let _ = self.exporter.export_spans(batch)
}

// Export the queue when the scheduled flush interval has elapsed. This is a
// no-op when the queue is empty or the interval has not elapsed, so it is safe
// to call from a periodic loop.
pub fn BatchSpanProcessor::tick(self : BatchSpanProcessor) -> Unit {
  if self.shutdown_called || self.live_count() == 0 {
    return
  }
  if self.flush_interval_millis > 0 {
    let now = @env.now()
    if now - self.last_flush_time_millis >=
      self.flush_interval_millis.to_uint64() {
      self.flush_batch_at(now)
    }
  }
}

pub impl SpanProcessor for BatchSpanProcessor with on_start(self, _span) {
  let _ = self
}

pub impl SpanProcessor for BatchSpanProcessor with on_end(self, data) {
  if self.shutdown_called {
    return
  }
  if !data.span_context.is_sampled() {
    return
  }
  self.push_span(data)
  if self.live_count() >= self.max_export_batch_size {
    self.flush_batch_at(current_millis())
  } else if self.flush_interval_millis > 0 {
    let now = current_millis()
    if now - self.last_flush_time_millis >=
      self.flush_interval_millis.to_uint64() {
      self.flush_batch_at(now)
    }
  }
}

pub impl SpanProcessor for BatchSpanProcessor with force_flush(self) {
  if self.live_count() > 0 {
    let now = @env.now()
    while self.live_count() > 0 {
      self.flush_batch_at(now)
    }
  }
}

pub impl SpanProcessor for BatchSpanProcessor with shutdown(self) {
  if !self.shutdown_called {
    if self.live_count() > 0 {
      let now = @env.now()
      while self.live_count() > 0 {
        self.flush_batch_at(now)
      }
    }
    self.shutdown_called = true
    self.exporter.shutdown()
  }
}

pub extend BatchSpanProcessor with SpanProcessor::{on_end, on_start, force_flush, shutdown}
