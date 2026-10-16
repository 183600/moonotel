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

fn fill_zero_checked(bytes : Array[Int]) -> Array[Int] {
  let mut nonzero = false
  for b in bytes {
    if b != 0 {
      nonzero = true
      break
    }
  }
  if !nonzero {
    bytes[bytes.length() - 1] = 1
  }
  bytes
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
  let out : Array[Int] = Array::make(n, 0)
  let mut filled = 0
  while filled < n {
    let mut word = splitmix64(state)
    let mut taken = 0
    while taken < 8 && filled < n {
      out.unsafe_set(filled, (word & 0xFF).to_int())
      word = word >> 8
      taken = taken + 1
      filled = filled + 1
    }
  }
  fill_zero_checked(out)
}

// Bytes requested from the entropy source per draw (enough for 20 trace IDs
// plus their span IDs).
const RANDOM_DRAW_BYTES : Int = 480

// Consume `n` bytes from the buffered draw, if enough remain.
fn take_buffered(
  n : Int,
  pending : Ref[Array[Int]],
  offset : Ref[Int]
) -> Array[Int]? {
  let source = pending.val
  let start = offset.val
  if source.length() - start < n {
    return None
  }
  let out : Array[Int] = Array::make(n, 0)
  out.unsafe_blit(0, source, start, n)
  if start + n >= source.length() {
    pending.val = []
    offset.val = 0
  } else {
    offset.val = start + n
  }
  Some(fill_zero_checked(out))
}

fn random_bytes(
  n : Int,
  state : Ref[UInt64],
  pending : Ref[Array[Int]],
  offset : Ref[Int]
) -> Array[Int] {
  match take_buffered(n, pending, offset) {
    Some(bytes) => bytes
    None => {
      let draw = if n < RANDOM_DRAW_BYTES { RANDOM_DRAW_BYTES } else { n }
      match @env.rand(draw) {
        Some(bytes) => {
          let view = bytes.exact_view()
          let out : Array[Int] = Array::make(n, 0)
          let rest : Array[Int] = Array::make(draw - n, 0)
          let mut nonzero = false
          let mut i = 0
          while i < n {
            let b = view.unsafe_get(i).to_int() & 0xFF
            out.unsafe_set(i, b)
            if b != 0 {
              nonzero = true
            }
            i = i + 1
          }
          let mut j = 0
          while i < draw {
            rest.unsafe_set(j, view.unsafe_get(i).to_int() & 0xFF)
            j = j + 1
            i = i + 1
          }
          if !nonzero {
            out.unsafe_set(n - 1, 1)
          }
          pending.val = rest
          offset.val = 0
          out
        }
        None => pseudo_random_bytes(n, state)
      }
    }
  }
}

// A generator producing random IDs.
pub fn IdGenerator::random() -> IdGenerator {
  let state = Ref(@env.now() ^ 88172645463325252)
  let pending : Ref[Array[Int]] = Ref([])
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
