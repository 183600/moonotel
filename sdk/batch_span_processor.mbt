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
  queue : Array[SpanData]
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
    shutdown_called: false,
  }
}

// Number of spans currently buffered.
pub fn BatchSpanProcessor::queue_size(self : BatchSpanProcessor) -> Int {
  self.queue.length()
}

// Whether `shutdown` has been called.
pub fn BatchSpanProcessor::is_shutdown(self : BatchSpanProcessor) -> Bool {
  self.shutdown_called
}

// Export up to `max_export_batch_size` spans from the front of the queue.
pub fn BatchSpanProcessor::flush_batch(self : BatchSpanProcessor) -> Unit {
  let available = self.queue.length()
  if available == 0 {
    return
  }
  let n = if available < self.max_export_batch_size {
    available
  } else {
    self.max_export_batch_size
  }
  let batch : Array[SpanData] = []
  while batch.length() < n {
    batch.push(self.queue.remove(0))
  }
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
  while self.queue.length() > self.max_queue_size {
    let _ = self.queue.remove(0)
  }
  if self.queue.length() >= self.max_export_batch_size {
    self.flush_batch()
  }
}

pub impl SpanProcessor for BatchSpanProcessor with force_flush(self) {
  while self.queue.length() > 0 {
    self.flush_batch()
  }
}

pub impl SpanProcessor for BatchSpanProcessor with shutdown(self) {
  if !self.shutdown_called {
    while self.queue.length() > 0 {
      self.flush_batch()
    }
    self.shutdown_called = true
    self.exporter.shutdown()
  }
}
