// A SpanProcessor that buffers finished spans and exports them in batches.
//
// The processor is bounded: when the queue exceeds `max_queue_size` the oldest
// spans are dropped. A batch is exported synchronously as soon as the queue
// reaches `max_export_batch_size`, and `force_flush`/`shutdown` drain the
// remaining queue.

pub struct BatchSpanProcessor {
  exporter : &SpanExporter
  max_queue_size : Int
  max_export_batch_size : Int
  mut queue : Array[SpanData]
  mut head : Int
  mut shutdown_called : Bool
}

// Create a batch processor. Defaults: queue size 2048, batch size 512.
pub fn BatchSpanProcessor::new(
  exporter : &SpanExporter,
  max_queue_size? : Int,
  max_export_batch_size? : Int
) -> BatchSpanProcessor {
  let queue_size = max_queue_size.unwrap_or(2048)
  let batch_size = max_export_batch_size.unwrap_or(512)
  {
    exporter,
    max_queue_size: if queue_size < 1 { 1 } else { queue_size },
    max_export_batch_size: if batch_size < 1 { 1 } else { batch_size },
    queue: [],
    head: 0,
    shutdown_called: false,
  }
}

// Number of spans currently buffered.
pub fn BatchSpanProcessor::queue_size(self : BatchSpanProcessor) -> Int {
  self.queue.length() - self.head
}

// Whether `shutdown` has been called.
pub fn BatchSpanProcessor::is_shutdown(self : BatchSpanProcessor) -> Bool {
  self.shutdown_called
}

// Number of buffered spans, ignoring consumed slots at the front.
fn BatchSpanProcessor::live_count(self : BatchSpanProcessor) -> Int {
  self.queue.length() - self.head
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
  let _ = self.exporter.export_spans(batch)
}

pub impl SpanProcessor for BatchSpanProcessor with on_start(self, _span) {
  let _ = self
}

pub impl SpanProcessor for BatchSpanProcessor with on_end(self, data) {
  if self.shutdown_called {
    return
  }
  self.queue.push(data)
  while self.live_count() > self.max_queue_size {
    self.head = self.head + 1
  }
  self.compact_if_needed()
  if self.live_count() >= self.max_export_batch_size {
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
