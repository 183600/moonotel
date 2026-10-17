// Trace/Span ID generation.
//
// Trace IDs are 16 bytes and Span IDs are 8 bytes, as required by the W3C
// Trace Context and OTLP specs. Random IDs use the platform entropy source
// when available and fall back to a splitmix64 PRNG seeded from the clock.

fn splitmix64(state : Ref[UInt64]) -> UInt64 {
  state.val = state.val + 11400714819323198485
  let mut z = state.val
  z = (z ^ (z >> 30)) * 13787848793156543929
  z = (z ^ (z >> 27)) * 10723151780598845931
  z ^ (z >> 31)
}

// A generator of trace IDs and span IDs.
pub struct IdGenerator {
  trace_id_source : () -> Array[Int]
  span_id_source : () -> Array[Int]
}

// Build a generator from two byte-array factories.
pub fn IdGenerator::new(
  trace_id_source : () -> Array[Int],
  span_id_source : () -> Array[Int]
) -> IdGenerator {
  { trace_id_source, span_id_source, }
}

fn pseudo_random_bytes(n : Int, state : Ref[UInt64]) -> Array[Int] {
  let out : Array[Int] = Array::unsafe_make_uninit(n)
  let mut filled = 0
  let mut acc = 0
  while filled < n {
    let mut word = splitmix64(state)
    let mut taken = 0
    while taken < 8 && filled < n {
      let b = (word & 0xFF).to_int()
      out.unsafe_set(filled, b)
      acc = acc | b
      word = word >> 8
      taken = taken + 1
      filled = filled + 1
    }
  }
  if acc == 0 {
    out.unsafe_set(n - 1, 1)
  }
  out
}

// Bytes requested from the entropy source per draw (enough for 80 trace IDs
// plus their span IDs).
const RANDOM_DRAW_BYTES : Int = 1920

// Consume `n` bytes from the buffered draw, if enough remain.
fn take_buffered(
  n : Int,
  pending : Ref[Bytes],
  offset : Ref[Int]
) -> Array[Int]? {
  let source = pending.val
  let start = offset.val
  if source.length() - start < n {
    return None
  }
  let out : Array[Int] = Array::unsafe_make_uninit(n)
  let mut acc : UInt64 = 0
  let mut i = 0
  // Copy whole 64-bit words while possible: one load feeds eight stores.
  while i + 8 <= n {
    let word = source.unsafe_read_uint64_le(start + i)
    acc = acc | word
    out.unsafe_set(i, (word & 0xFF).to_int())
    out.unsafe_set(i + 1, ((word >> 8) & 0xFF).to_int())
    out.unsafe_set(i + 2, ((word >> 16) & 0xFF).to_int())
    out.unsafe_set(i + 3, ((word >> 24) & 0xFF).to_int())
    out.unsafe_set(i + 4, ((word >> 32) & 0xFF).to_int())
    out.unsafe_set(i + 5, ((word >> 40) & 0xFF).to_int())
    out.unsafe_set(i + 6, ((word >> 48) & 0xFF).to_int())
    out.unsafe_set(i + 7, (word >> 56).to_int())
    i = i + 8
  }
  while i < n {
    let b = source.unsafe_get(start + i).to_int()
    acc = acc | b.to_uint64()
    out.unsafe_set(i, b)
    i = i + 1
  }
  if acc == 0 {
    out.unsafe_set(n - 1, 1)
  }
  if start + n >= source.length() {
    pending.val = b""
    offset.val = 0
  } else {
    offset.val = start + n
  }
  Some(out)
}

fn random_bytes(
  n : Int,
  state : Ref[UInt64],
  pending : Ref[Bytes],
  offset : Ref[Int]
) -> Array[Int] {
  match take_buffered(n, pending, offset) {
    Some(bytes) => bytes
    None => {
      let draw = if n < RANDOM_DRAW_BYTES { RANDOM_DRAW_BYTES } else { n }
      match @env.rand(draw) {
        Some(bytes) => {
          pending.val = bytes
          offset.val = 0
          match take_buffered(n, pending, offset) {
            Some(out) => out
            None => pseudo_random_bytes(n, state)
          }
        }
        None => pseudo_random_bytes(n, state)
      }
    }
  }
}

// A generator producing random IDs.
pub fn IdGenerator::random() -> IdGenerator {
  let state = Ref(@env.now() ^ 88172645463325252)
  let pending : Ref[Bytes] = Ref(b"")
  let offset : Ref[Int] = Ref(0)
  IdGenerator::new(
    fn() { random_bytes(16, state, pending, offset) },
    fn() { random_bytes(8, state, pending, offset) },
  )
}

// A deterministic generator based on splitmix64, useful for tests and demos.
pub fn IdGenerator::deterministic(seed : UInt64) -> IdGenerator {
  let state = Ref(seed)
  IdGenerator::new(
    fn() { pseudo_random_bytes(16, state) },
    fn() { pseudo_random_bytes(8, state) },
  )
}

// Generate a fresh 16-byte trace ID.
pub fn IdGenerator::generate_trace_id(self : IdGenerator) -> Array[Int] {
  (self.trace_id_source)()
}

// Generate a fresh 8-byte span ID.
pub fn IdGenerator::generate_span_id(self : IdGenerator) -> Array[Int] {
  (self.span_id_source)()
}
