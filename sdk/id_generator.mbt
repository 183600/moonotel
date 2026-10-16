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
  let out : Array[Int] = Array(capacity=n)
  let mut filled = 0
  while filled < n {
    let mut word = splitmix64(state)
    let mut taken = 0
    while taken < 8 && filled < n {
      out.push((word & 0xFF).to_int())
      word = word >> 8
      taken = taken + 1
      filled = filled + 1
    }
  }
  fill_zero_checked(out)
}

// Bytes requested from the entropy source per draw. A trace ID (16 bytes)
// plus a span ID (8 bytes) fit in one draw, so a whole span costs a single
// entropy call; the surplus stays buffered for the following call.
const RANDOM_DRAW_BYTES : Int = 24

fn take_buffered(n : Int, pending : Ref[Array[Int]]) -> Array[Int]? {
  let available = pending.val.length()
  if available < n {
    return None
  }
  let source = pending.val
  let out : Array[Int] = Array(capacity=n)
  for i = 0; i < n; i = i + 1 {
    out.push(source[i])
  }
  let rest : Array[Int] = Array(capacity=available - n)
  for i = n; i < available; i = i + 1 {
    rest.push(source[i])
  }
  pending.val = rest
  Some(fill_zero_checked(out))
}

fn random_bytes(n : Int, state : Ref[UInt64], pending : Ref[Array[Int]]) -> Array[Int] {
  match take_buffered(n, pending) {
    Some(bytes) => bytes
    None => {
      let draw = if n < RANDOM_DRAW_BYTES { RANDOM_DRAW_BYTES } else { n }
      match @env.rand(draw) {
        Some(bytes) => {
          let all : Array[Int] = Array(capacity=draw)
          for i = 0; i < draw; i = i + 1 {
            all.push(bytes[i].to_int() & 0xFF)
          }
          let out : Array[Int] = Array(capacity=n)
          for i = 0; i < n; i = i + 1 {
            out.push(all[i])
          }
          let rest : Array[Int] = Array(capacity=draw - n)
          for i = n; i < draw; i = i + 1 {
            rest.push(all[i])
          }
          pending.val = rest
          fill_zero_checked(out)
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
  IdGenerator::new(
    fn() { random_bytes(16, state, pending) },
    fn() { random_bytes(8, state, pending) },
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
