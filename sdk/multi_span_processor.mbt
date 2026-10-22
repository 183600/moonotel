///|
pub struct MultiSpanProcessor {
  processors : Array[&SpanProcessor]
  // Per-child shutdown state, shared with copies that contain the same child.
  // A processor added to a copy starts out unshut-down even when the copy
  // itself already is, so `shutdown` can release it exactly once.
  shutdowns : Array[Ref[Bool]]
  // Shared with copies, so shutting down any copy also stops the others.
  shutdown_called : Ref[Bool]
}

///|
pub fn MultiSpanProcessor::new(
  processors? : Array[&SpanProcessor],
) -> MultiSpanProcessor {
  let processors = match processors {
    Some(values) => values.copy()
    None => []
  }
  let shutdowns : Array[Ref[Bool]] = Array(capacity=processors.length())
  for _ in processors {
    shutdowns.push(Ref(false))
  }
  {
    processors,
    shutdowns,
    shutdown_called: Ref(false),
  }
}

///|
pub fn MultiSpanProcessor::with_processor(
  self : MultiSpanProcessor,
  processor : &SpanProcessor,
) -> MultiSpanProcessor {
  let processors = self.processors.copy()
  processors.push(processor)
  let shutdowns = self.shutdowns.copy()
  shutdowns.push(Ref(false))
  { ..self, processors, shutdowns, }
}

///|
pub fn MultiSpanProcessor::processor_count(self : MultiSpanProcessor) -> Int32 {
  self.processors.length()
}

///|
pub fn MultiSpanProcessor::is_shutdown(self : MultiSpanProcessor) -> Bool {
  self.shutdown_called.val
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn on_start(self, span) {
  if !self.shutdown_called.val {
    for processor in self.processors {
      processor.on_start(span)
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn on_end(self, data) {
  if !self.shutdown_called.val {
    for processor in self.processors {
      processor.on_end(data)
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn force_flush(self) {
  if !self.shutdown_called.val {
    for processor in self.processors {
      processor.force_flush()
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn drain_before_shutdown(
  self,
) {
  if !self.shutdown_called.val {
    for processor in self.processors {
      processor.drain_before_shutdown()
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn shutdown(self) {
  self.shutdown_called.val = true
  let mut i = 0
  while i < self.processors.length() {
    if !self.shutdowns[i].val {
      self.shutdowns[i].val = true
      self.processors[i].shutdown()
    }
    i = i + 1
  }
}

///|
pub extend MultiSpanProcessor with SpanProcessor::{
  on_end,
  on_start,
  force_flush,
  drain_before_shutdown,
  shutdown,
}
