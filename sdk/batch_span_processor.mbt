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
  mut queue : Array[SpanData]
  mut head : Int
  mut last_flush_time_millis : UInt64
  mut shutdown_called : Bool
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
    last_flush_time_millis: @env.now(),
    shutdown_called: false,
  }
}

// Number of spans currently buffered.
pub fn BatchSpanProcessor::queue_size(self : BatchSpanProcessor) -> Int {
  self.queue.length() - self.head
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

// Number of buffered spans, ignoring consumed slots at the front.
fn BatchSpanProcessor::live_count(self : BatchSpanProcessor) -> Int {
  self.queue.length() - self.head
}

// Whether the scheduled flush interval has elapsed since the last export.
fn BatchSpanProcessor::is_flush_due(self : BatchSpanProcessor) -> Bool {
  self.flush_interval_millis > 0 &&
  @env.now() - self.last_flush_time_millis >=
  self.flush_interval_millis.to_uint64()
}

// Drop the consumed slots at the front, dropping empty or mostly-consumed
// backing arrays so the buffer does not grow without bound.
fn BatchSpanProcessor::compact(self : BatchSpanProcessor) -> Unit {
  let remaining = self.live_count()
  let rest : Array[SpanData] = Array(capacity=remaining)
  let mut i = self.head
  while i < self.queue.length() {
    rest.push(self.queue[i])
    i = i + 1
  }
  self.queue = rest
  self.head = 0
}

fn BatchSpanProcessor::compact_if_needed(self : BatchSpanProcessor) -> Unit {
  if self.head == 0 {
    return
  }
  let consumed = self.head
  let length = self.queue.length()
  if consumed == length || (consumed >= 64 && consumed * 2 >= length) {
    self.compact()
  }
}

// Export up to `max_export_batch_size` spans from the front of the queue.
pub fn BatchSpanProcessor::flush_batch(self : BatchSpanProcessor) -> Unit {
  let available = self.live_count()
  if available == 0 {
    return
  }
  let n = if available < self.max_export_batch_size {
    available
  } else {
    self.max_export_batch_size
  }
  let batch : Array[SpanData] = Array(capacity=n)
  let end = self.head + n
  let mut i = self.head
  while i < end {
    batch.push(self.queue[i])
    i = i + 1
  }
  self.head = end
  self.compact_if_needed()
  self.last_flush_time_millis = @env.now()
  let _ = self.exporter.export_spans(batch)
}

// Export the queue when the scheduled flush interval has elapsed. This is a
// no-op when the queue is empty or the interval has not elapsed, so it is safe
// to call from a periodic loop.
pub fn BatchSpanProcessor::tick(self : BatchSpanProcessor) -> Unit {
  if self.shutdown_called || self.live_count() == 0 {
    return
  }
  if self.is_flush_due() {
    self.flush_batch()
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
  self.queue.push(data)
  while self.live_count() > self.max_queue_size {
    self.head = self.head + 1
  }
  self.compact_if_needed()
  if self.live_count() >= self.max_export_batch_size || self.is_flush_due() {
    self.flush_batch()
  }
}

pub impl SpanProcessor for BatchSpanProcessor with force_flush(self) {
  while self.live_count() > 0 {
    self.flush_batch()
  }
}

pub impl SpanProcessor for BatchSpanProcessor with shutdown(self) {
  if !self.shutdown_called {
    while self.live_count() > 0 {
      self.flush_batch()
    }
    self.shutdown_called = true
    self.exporter.shutdown()
  }
}

pub extend BatchSpanProcessor with SpanProcessor::{on_end, on_start, force_flush, shutdown}
