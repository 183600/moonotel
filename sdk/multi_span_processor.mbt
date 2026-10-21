///|
pub struct MultiSpanProcessor {
  processors : Array[&SpanProcessor]
  mut shutdown_called : Bool
}

///|
pub fn MultiSpanProcessor::new(
  processors? : Array[&SpanProcessor],
) -> MultiSpanProcessor {
  {
    processors: match processors {
      Some(values) => values.copy()
      None => []
    },
    shutdown_called: false,
  }
}

///|
pub fn MultiSpanProcessor::with_processor(
  self : MultiSpanProcessor,
  processor : &SpanProcessor,
) -> MultiSpanProcessor {
  let processors = self.processors.copy()
  processors.push(processor)
  { ..self, processors, }
}

///|
pub fn MultiSpanProcessor::processor_count(self : MultiSpanProcessor) -> Int32 {
  self.processors.length()
}

///|
pub fn MultiSpanProcessor::is_shutdown(self : MultiSpanProcessor) -> Bool {
  self.shutdown_called
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn on_start(self, span) {
  if !self.shutdown_called {
    for processor in self.processors {
      processor.on_start(span)
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn on_end(self, data) {
  if !self.shutdown_called {
    for processor in self.processors {
      processor.on_end(data)
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn force_flush(self) {
  if !self.shutdown_called {
    for processor in self.processors {
      processor.force_flush()
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn shutdown(self) {
  if !self.shutdown_called {
    self.shutdown_called = true
    for processor in self.processors {
      processor.shutdown()
    }
  }
}

///|
pub extend MultiSpanProcessor with SpanProcessor::{
  on_end,
  on_start,
  force_flush,
  shutdown,
}
