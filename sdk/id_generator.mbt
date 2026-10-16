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
  let out : Array[Int] = []
  while out.length() < n {
    let mut word = splitmix64(state)
    for j = 0; j < 8; j = j + 1 {
      if out.length() < n {
        out.push((word % 256).to_int())
        word = word / 256
      }
    }
  }
  fill_zero_checked(out)
}

fn random_bytes(n : Int, state : Ref[UInt64]) -> Array[Int] {
  match @env.rand(n) {
    Some(bytes) => {
      let out : Array[Int] = []
      for i = 0; i < bytes.length(); i = i + 1 {
        out.push(bytes[i].to_int() & 0xFF)
      }
      fill_zero_checked(out)
    }
    None => pseudo_random_bytes(n, state)
  }
}

// A generator producing random IDs.
pub fn IdGenerator::random() -> IdGenerator {
  let state = Ref(@env.now() ^ 88172645463325252)
  IdGenerator::new(
    fn() { random_bytes(16, state) },
    fn() { random_bytes(8, state) },
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
