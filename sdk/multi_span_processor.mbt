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
  // Guards `force_flush` against reentry from a child processor. A nested
  // request on the same child set is a no-op; a copy only flushes children the
  // outer pass does not own.
  flushing : Ref[Bool]
  // Children currently owned by the outer `force_flush`. Shared with copies; a
  // nested flush on a copy skips those and still reaches children added to that
  // copy.
  flushing_owner : Ref[Array[&SpanProcessor]?]
  // Shutdown requests made by a copy while another copy is already draining.
  // They run after the outer shutdown has finished.
  shutdown_waiters : Ref[Array[() -> Unit]]
  // Set by a provider shutdown that arrived while this processor was already
  // draining directly; run once the outer drain has finished.
  mut shutdown_completion : (() -> Unit)?
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
    flushing: Ref(false),
    flushing_owner: Ref(None),
    shutdown_waiters: Ref([]),
    shutdown_completion: None,
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
      // A child may shut this processor down while handling the event. The
      // remaining children are shut down by `shutdown` and must not receive
      // span events afterwards.
      if self.shutdown_called.val {
        break
      }
      processor.on_start(span)
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn on_end(self, data) {
  if !self.shutdown_called.val {
    for processor in self.processors {
      // See `on_start`: a reentrant shutdown closes the remaining children.
      if self.shutdown_called.val {
        break
      }
      // `SpanData` is immutable by contract. Give each child its own snapshot
      // so a processor that mutates its copy cannot change what a later child
      // (or the ended span's accessors) observes.
      processor.on_end(data.copy())
    }
  }
}

///|
fn MultiSpanProcessor::force_flush_children(
  self : MultiSpanProcessor,
  skip : Array[&SpanProcessor]?,
) -> Unit {
  for i, processor in self.processors {
    // A child's flush may shut this processor down reentrantly; the outer
    // `shutdown` has already drained and closed the remaining children.
    if self.draining.val {
      break
    }
    // A child added to a copy starts out unshut-down even when the shared
    // shutdown marker was set by another copy, so it can still be flushed.
    if !self.shutdowns[i].val &&
      !(match skip {
        Some(owner) => processor_in_array(owner, processor)
        None => false
      }) {
      processor.force_flush()
    }
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn force_flush(self) {
  // A shutdown in progress owns the children.
  if self.draining.val {
    return
  }
  // A flush on the same child set is a no-op. A flush on a copy only owns the
  // children the outer pass does not own, so run those instead of dropping the
  // request.
  if self.flushing.val {
    match self.flushing_owner.val {
      Some(owner) => {
        let previous = self.flushing_owner.val
        self.flushing_owner.val = Some(self.processors)
        defer { self.flushing_owner.val = previous }
        self.force_flush_children(Some(owner))
      }
      None => ()
    }
    return
  }
  self.flushing.val = true
  let previous = self.flushing_owner.val
  self.flushing_owner.val = Some(self.processors)
  defer {
    self.flushing_owner.val = previous
    self.flushing.val = false
  }
  self.force_flush_children(None)
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn drain_before_shutdown(
  self,
) {
  // A child's drain may call `shutdown` reentrantly. Let the outer drain finish
  // first: shutting a child down while its own drain is still on the stack (and
  // before the provider has drained the remaining processors) can close an
  // exporter that another processor still needs to drain. `shutdown` is still
  // responsible for closing every child once the drain has completed.
  if self.draining.val {
    return
  }
  self.draining.val = true
  defer { self.draining.val = false }
  if !self.shutdown_called.val {
    for i, processor in self.processors {
      if self.shutdown_called.val {
        break
      }
      if !self.shutdowns[i].val && !self.drained[i].val {
        self.drained[i].val = true
        processor.drain_before_shutdown()
      }
    }
  }
  // See `BatchSpanProcessor::drain_before_shutdown`: a provider shutdown that
  // arrived during this direct drain left a completion callback behind. Run
  // it after clearing the drain guard so that shutdown can finish.
  self.draining.val = false
  match self.shutdown_completion {
    Some(completion) => {
      self.shutdown_completion = None
      completion()
    }
    None => ()
  }
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn is_draining(self) {
  self.draining.val
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn set_shutdown_completion(
  self,
  completion,
) {
  self.shutdown_completion = Some(completion)
}

///|
pub impl SpanProcessor for MultiSpanProcessor with fn shutdown(self) {
  // A child processor or exporter may call back into `shutdown`; let the outer
  // call finish the drain and shutdown sequence. A copy may own children the
  // outer call does not, so queue its shutdown until the outer one finishes.
  if self.draining.val {
    self.shutdown_waiters.val.push(() => self.shutdown())
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
  // Claim this copy's children before running deferred copy shutdowns. Copies
  // share these markers, so a copy only handles children it added itself. The
  // actual shutdown calls happen after deferred copies have drained, allowing
  // a copy's new child to export through an exporter shared with these
  // children.
  let to_shutdown : Array[&SpanProcessor] = Array(
    capacity=self.processors.length(),
  )
  let mut i = 0
  while i < self.processors.length() {
    if !self.shutdowns[i].val {
      self.shutdowns[i].val = true
      to_shutdown.push(self.processors[i])
    }
    i = i + 1
  }
  self.draining.val = false
  let waiters = self.shutdown_waiters.val
  self.shutdown_waiters.val = []
  let completion = self.shutdown_completion
  self.shutdown_completion = None
  // Deferred copies may own children that still need to export through an
  // exporter shared with this copy's children.
  for waiter in waiters {
    waiter()
  }
  match completion {
    Some(callback) => callback()
    None => ()
  }
  for processor in to_shutdown {
    processor.shutdown()
  }
}

///|
pub extend MultiSpanProcessor with SpanProcessor::{
  on_end,
  on_start,
  force_flush,
  drain_before_shutdown,
  is_draining,
  set_shutdown_completion,
  shutdown,
}
