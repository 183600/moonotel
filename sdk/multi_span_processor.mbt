///|
pub struct MultiSpanProcessor {
  processors : Array[&SpanProcessor]
  // Per-child shutdown state, shared with copies that contain the same child.
  // A processor added to a copy starts out unshut-down even when the copy
  // itself already is, so `shutdown` can release it exactly once.
  shutdowns : Array[Ref[Bool]]
  // Per-child drain state, shared with copies that contain the same child.
  // The provider drains a multi-processor before shutting it down, and
  // `shutdown` also drains; remembering that a child was already drained keeps
  // each child's `drain_before_shutdown` called at most once. A drain that
  // triggers a reentrant shutdown therefore cannot call `drain_before_shutdown`
  // on a child that `shutdown` has already closed.
  drained : Array[Ref[Bool]]
  // Shared with copies, so shutting down any copy also stops the others.
  shutdown_called : Ref[Bool]
  // Guards the drain/shutdown sequence against reentry from a child processor
  // or an exporter it calls.
  draining : Ref[Bool]
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
  let drained : Array[Ref[Bool]] = Array(capacity=processors.length())
  for _ in processors {
    shutdowns.push(Ref(false))
    drained.push(Ref(false))
  }
  {
    processors,
    shutdowns,
    drained,
    shutdown_called: Ref(false),
    draining: Ref(false),
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
  let drained = self.drained.copy()
  drained.push(Ref(false))
  { ..self, processors, shutdowns, drained, }
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
      // A child's flush may shut this processor down reentrantly; the outer
      // `shutdown` has already drained and closed the remaining children.
      if self.shutdown_called.val {
        break
      }
      processor.force_flush()
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn drain_before_shutdown(
  self,
) {
  if !self.shutdown_called.val {
    for i, processor in self.processors {
      // A child's drain may shut this processor down reentrantly. `shutdown`
      // then drains and closes every remaining child, so continuing here would
      // drain (and possibly export through) processors that are already shut
      // down.
      if self.shutdown_called.val {
        break
      }
      if !self.shutdowns[i].val && !self.drained[i].val {
        self.drained[i].val = true
        processor.drain_before_shutdown()
      }
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn shutdown(self) {
  // A child processor or exporter may call back into `shutdown`; let the outer
  // call finish the drain and shutdown sequence.
  if self.draining.val {
    return
  }
  self.draining.val = true
  defer { self.draining.val = false }
  self.shutdown_called.val = true
  // Drain all not-yet-drained children before shutting any of them down,
  // matching the provider's shutdown order when children share an exporter.
  // The provider may already have called `drain_before_shutdown`; a child is
  // drained at most once so its exporter cannot be used after it is closed.
  for i, processor in self.processors {
    if !self.shutdowns[i].val && !self.drained[i].val {
      self.drained[i].val = true
      processor.drain_before_shutdown()
    }
  }
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
