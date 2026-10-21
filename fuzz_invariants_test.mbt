// Randomized invariant tests for the W3C propagators.
//
// The parsers must accept arbitrary input without failing, and every encoder
// must round-trip: the encoded form decodes back to the original text, the
// normalized forms are stable, and the propagators preserve the span
// identifiers.

///|
struct FuzzRng {
  state : Ref[Int64]
}

///|
fn FuzzRng::new(seed : Int64) -> FuzzRng {
  { state: Ref(seed) }
}

///|
fn FuzzRng::next(self : FuzzRng) -> Int64 {
  // xorshift64
  let mut x = self.state.val
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state.val = x
  x
}

///|
fn FuzzRng::below(self : FuzzRng, bound : Int) -> Int {
  let value = self.next() & 0x7FFFFFFFFFFFFFFFL
  (value % bound.to_int64()).to_int()
}

// Fragments used to build random header values. They cover the characters
// that drive the parsers (separators, escapes, whitespace) as well as
// multi-byte text.

///|
let fuzz_fragments : Array[String] = [
  "a", "b", "z", "0", "9", "_", "-", ".", "*", "/", "@", "~", "!", "#", "$",
  "%", "%20", "%2C", "%3B", "%zz", "%", "=", ";", ",", " ", "\t", "\r", "\n",
  "\"", "\\", "}", "{", "[", "]", ":", "|", "<", ">", "?", "^", "`", "'", "(",
  ")", "+", "é", "🤣", "\u{7f}", "\u{0}",
]

// HTTP token characters, the only characters a baggage key may hold.

///|
let fuzz_token_fragments : Array[String] = [
  "a", "b", "z", "A", "Z", "0", "9", "_", "-", ".", "~", "!", "#", "$", "%",
  "&", "'", "*", "+", "^", "`", "|",
]

///|
fn random_text(rng : FuzzRng, max_fragments : Int) -> String {
  let sb = StringBuilder()
  let count = rng.below(max_fragments + 1)
  let mut i = 0
  while i < count {
    let fragment = fuzz_fragments[rng.below(fuzz_fragments.length())]
    sb.write_view(fragment[:])
    i = i + 1
  }
  sb.to_string()
}

///|
fn random_token(rng : FuzzRng) -> String {
  let sb = StringBuilder()
  let count = 1 + rng.below(6)
  let mut i = 0
  while i < count {
    let fragment = fuzz_token_fragments[rng.below(fuzz_token_fragments.length())]
    sb.write_view(fragment[:])
    i = i + 1
  }
  sb.to_string()
}

///|
fn random_bytes(rng : FuzzRng, count : Int) -> Array[Int32] {
  let bytes : Array[Int32] = Array(capacity=count)
  let mut i = 0
  while i < count {
    bytes.push(rng.below(256))
    i = i + 1
  }
  bytes
}

// Whether a character may appear literally in a baggage value.

///|
fn is_literal_value_char(c : Char) -> Bool {
  let code = c.to_int()
  code == 0x21 ||
  (code >= 0x23 && code <= 0x2B && code != 0x25) ||
  (code >= 0x2D && code <= 0x3A) ||
  (code >= 0x3C && code <= 0x5B) ||
  (code >= 0x5D && code <= 0x7E)
}

///|
fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
test "fuzz_percent_encoding_round_trips" {
  let rng = FuzzRng::new(0x1234_5678_9ABC_DEF0L)
  let mut i = 0
  while i < 3000 {
    let text = random_text(rng, 10)
    let encoded = @propagation.percent_encode(text)
    // The reported length must match the encoded form.
    assert_eq(@propagation.percent_encoded_length(text), encoded.length())
    // The encoded form only holds literal value characters and `%XX` escapes.
    let mut j = 0
    while j < encoded.length() {
      let c = encoded[j].unsafe_to_char()
      if c == '%' {
        assert_true(j + 2 < encoded.length())
        assert_true(is_hex_digit(encoded[j + 1].unsafe_to_char()))
        assert_true(is_hex_digit(encoded[j + 2].unsafe_to_char()))
        j = j + 3
      } else {
        assert_true(is_literal_value_char(c))
        j = j + 1
      }
    }
    // Decoding the encoded form returns the original text.
    assert_eq(@propagation.percent_decode(encoded), Some(text))
    i = i + 1
  }
}

///|
test "fuzz_percent_decode_is_stable" {
  let rng = FuzzRng::new(0x0FED_CBA9_8765_4321L)
  let mut i = 0
  while i < 2000 {
    let text = random_text(rng, 8)
    match @propagation.percent_decode(text) {
      Some(decoded) => {
        // A decoded value may hold any character; re-encoding and decoding
        // it again returns the same text.
        let encoded = @propagation.percent_encode(decoded)
        assert_eq(@propagation.percent_decode(encoded), Some(decoded))
      }
      None => ()
    }
    i = i + 1
  }
}

///|
test "fuzz_baggage_round_trips" {
  let rng = FuzzRng::new(0x0BAD_C0DE_1234_5678L)
  let mut i = 0
  while i < 2000 {
    let key = random_token(rng)
    let value = random_text(rng, 6)
    let pairs : Array[(String, String)] = [(key, value)]
    let formatted = @propagation.format_baggage(pairs)
    assert_eq(@propagation.parse_baggage(formatted), pairs)
    i = i + 1
  }
}

///|
test "fuzz_baggage_entries_round_trip" {
  let rng = FuzzRng::new(0x5EED_1234_ABCD_0001L)
  let mut i = 0
  while i < 2000 {
    let key = random_token(rng)
    let value = random_text(rng, 6)
    let property_key = random_token(rng)
    let property_value = random_text(rng, 4)
    let entries : Array[@propagation.BaggageEntry] = [
      @propagation.BaggageEntry::new(
        key,
        value,
        properties=[(property_key, property_value)],
      ),
    ]
    let formatted = @propagation.format_baggage_entries(entries)
    assert_eq(@propagation.parse_baggage_entries(formatted), entries)
    i = i + 1
  }
}

///|
test "fuzz_baggage_parsers_accept_arbitrary_input" {
  let rng = FuzzRng::new(0xDEAD_BEEF_0000_0001L)
  let mut i = 0
  while i < 2000 {
    let text = random_text(rng, 12)
    let pairs = @propagation.parse_baggage(text)
    let entries = @propagation.parse_baggage_entries(text)
    // The plain parser keeps the properties out of the way, so both parsers
    // see the same members and keys.
    assert_eq(pairs.length(), entries.length())
    let mut j = 0
    while j < pairs.length() {
      assert_eq(pairs[j].0, entries[j].key)
      assert_eq(pairs[j].1, entries[j].value)
      j = j + 1
    }
    i = i + 1
  }
}

///|
test "fuzz_tracestate_normalization_is_stable" {
  let rng = FuzzRng::new(0x0C0FFEE_1234_5678L)
  let mut i = 0
  while i < 3000 {
    let text = random_text(rng, 12)
    match @propagation.parse_tracestate(text) {
      Some(normalized) => {
        // The normalized form is valid and does not change any more.
        assert_eq(@propagation.parse_tracestate(normalized), Some(normalized))
      }
      None => ()
    }
    i = i + 1
  }
}

///|
test "fuzz_traceparent_round_trips" {
  let rng = FuzzRng::new(0x1234_ABCD_5678_9F0FL)
  let mut i = 0
  while i < 1000 {
    let trace_id = random_bytes(rng, 16)
    let span_id = random_bytes(rng, 8)
    // All-zero identifiers are invalid and are never formatted.
    if @api.is_zero(trace_id) || @api.is_zero(span_id) {
      i = i + 1
      continue
    }
    let flags = rng.below(4)
    let sc = @moonotel.span_context(trace_id, span_id, flags)
    let header = @propagation.format_traceparent(sc)
    let parsed = @propagation.parse_traceparent(header).unwrap()
    assert_eq(parsed.trace_id_hex(), sc.trace_id_hex())
    assert_eq(parsed.span_id_hex(), sc.span_id_hex())
    assert_eq(parsed.trace_flags(), sc.trace_flags() & 0x03)
    i = i + 1
  }
}

///|
test "fuzz_traceparent_parser_accepts_arbitrary_input" {
  let rng = FuzzRng::new(0x0F0F_0F0F_0F0F_0F0FL)
  let mut i = 0
  while i < 3000 {
    let text = random_text(rng, 20)
    match @propagation.parse_traceparent(text) {
      Some(sc) => {
        // A parsed context is valid and its identifiers are not all zero.
        assert_true(sc.is_valid())
        assert_false(@api.is_zero(sc.trace_id()))
        assert_false(@api.is_zero(sc.span_id()))
        // Only the sampled and random bits survive the round-trip.
        assert_true(sc.trace_flags() >= 0 && sc.trace_flags() <= 3)
      }
      None => ()
    }
    i = i + 1
  }
}
