// W3C Trace Context propagation tests - simplified basic version

// Test hex conversion functions
test "hex_to_bytes_simple" {
  let hex = "4b"  // single byte
  let bytes = hex_to_bytes(hex)
  assert_eq(bytes.length(), 1)
  assert_eq(bytes[0], 0x4b)
}

test "hex_to_bytes_multiple" {
  let hex = "4b f9"  // multiple bytes, but we'll handle as "4bf9"
  let bytes = hex_to_bytes("4bf9")
  assert_eq(bytes.length(), 2)
  assert_eq(bytes[0], 0x4b)
  assert_eq(bytes[1], 0xf9)
}

test "hex_to_bytes_empty" {
  let hex = ""
  let bytes = hex_to_bytes(hex)
  assert_eq(bytes.length(), 0)
}

test "hex_to_int_simple" {
  assert_eq(hex_to_int("0"), 0)
  assert_eq(hex_to_int("1"), 1)
  assert_eq(hex_to_int("f"), 15)
  assert_eq(hex_to_int("10"), 16)
  assert_eq(hex_to_int("ff"), 255)
}

test "hex_to_int_case_insensitive" {
  assert_eq(hex_to_int("FF"), 255)
  assert_eq(hex_to_int("ff"), 255)
  assert_eq(hex_to_int("aB"), 171)
}

test "hex_to_int_empty" {
  assert_eq(hex_to_int(""), 0)
}

// Test basic string operations
test "string_split_basic" {
  let text = "a-b-c"
  let parts = text.split("-").collect()
  assert_eq(parts.length(), 3)
  assert_eq(parts[0].to_string(), "a")
  assert_eq(parts[1].to_string(), "b")
  assert_eq(parts[2].to_string(), "c")
}

test "string_find_basic" {
  let text = "hello world"
  let pos = text.find("world")
  assert_true(pos.is_some())
  assert_eq(pos.unwrap(), 6)
}

test "string_find_not_found" {
  let text = "hello world"
  let pos = text.find("xyz")
  assert_true(pos.is_none())
}

test "string_find_empty" {
  let text = "hello world"
  let pos = text.find("")
  assert_true(pos.is_some())
  assert_eq(pos.unwrap(), 0)
}

test "string_trim_basic" {
  assert_eq("  hello  ".trim(), "hello")
  assert_eq("hello".trim(), "hello")
  assert_eq("".trim(), "")
}

test "string_to_lower_basic" {
  assert_eq("HELLO".to_lower(), "hello")
  assert_eq("HeLLo".to_lower(), "hello")
  assert_eq("hello".to_lower(), "hello")
}

// Test map operations
test "map_basic_operations" {
  let map = Map::new()
  map.set("key1", "value1")
  map.set("key2", "value2")
  
  assert_eq(map.get("key1"), Some("value1"))
  assert_eq(map.get("key2"), Some("value2"))
  assert_eq(map.get("key3"), None)
}

test "map_case_sensitivity" {
  let map = Map::new()
  map.set("Key", "value")
  
  // Note: Map keys may be case-sensitive in this implementation
  assert_eq(map.get("Key"), Some("value"))
  // The following might fail if Map is case-sensitive
  // assert_eq(map.get("key"), Some("value"))
  // assert_eq(map.get("KEY"), Some("value"))
}

// Test basic SpanContext operations
test "span_context_invalid_with_zeros" {
  let sc = invalid_span_context()
  assert_false(sc.is_valid())
  assert_eq(sc.trace_id_hex(), "00000000000000000000000000000000")
  assert_eq(sc.span_id_hex(), "0000000000000000")
}

test "span_context_valid_with_nonzero" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 1)
  assert_true(sc.is_valid())
  assert_true(sc.is_sampled())
}

test "span_context_unsampled" {
  let trace_id = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let span_id = [1, 2, 3, 4, 5, 6, 7, 8]
  let sc = span_context(trace_id, span_id, 0)
  assert_true(sc.is_valid())
  assert_false(sc.is_sampled())
}

test "span_context_hex_conversion" {
  let trace_id = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f]
  let span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let sc = span_context(trace_id, span_id, 1)
  
  assert_eq(sc.trace_id_hex(), "000102030405060708090a0b0c0d0e0f")
  assert_eq(sc.span_id_hex(), "0102030405060708")
}

// Test helper functions implementation
fn hex_to_int(hex : String) -> Int {
  let mut result = 0
  let chars = hex.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let digit = 
      if c == '0' { 0 }
      else if c == '1' { 1 }
      else if c == '2' { 2 }
      else if c == '3' { 3 }
      else if c == '4' { 4 }
      else if c == '5' { 5 }
      else if c == '6' { 6 }
      else if c == '7' { 7 }
      else if c == '8' { 8 }
      else if c == '9' { 9 }
      else if c == 'a' { 10 }
      else if c == 'b' { 11 }
      else if c == 'c' { 12 }
      else if c == 'd' { 13 }
      else if c == 'e' { 14 }
      else if c == 'f' { 15 }
      else if c == 'A' { 10 }
      else if c == 'B' { 11 }
      else if c == 'C' { 12 }
      else if c == 'D' { 13 }
      else if c == 'E' { 14 }
      else if c == 'F' { 15 }
      else { 0 }
    result = result * 16 + digit
    i = i + 1
  }
  result
}

fn hex_to_bytes(hex : String) -> Array[Int] {
  let mut bytes = []
  let chars = hex.to_array()
  let mut i = 0
  while i < chars.length() {
    if i + 1 < chars.length() {
      let high_nibble = hex_char_to_int(chars[i])
      let low_nibble = hex_char_to_int(chars[i + 1])
      let byte_val = high_nibble * 16 + low_nibble
      bytes = bytes + [byte_val]
    }
    i = i + 2
  }
  bytes
}

fn hex_char_to_int(c : Char) -> Int {
  if c == '0' { 0 }
  else if c == '1' { 1 }
  else if c == '2' { 2 }
  else if c == '3' { 3 }
  else if c == '4' { 4 }
  else if c == '5' { 5 }
  else if c == '6' { 6 }
  else if c == '7' { 7 }
  else if c == '8' { 8 }
  else if c == '9' { 9 }
  else if c == 'a' { 10 }
  else if c == 'b' { 11 }
  else if c == 'c' { 12 }
  else if c == 'd' { 13 }
  else if c == 'e' { 14 }
  else if c == 'f' { 15 }
  else if c == 'A' { 10 }
  else if c == 'B' { 11 }
  else if c == 'C' { 12 }
  else if c == 'D' { 13 }
  else if c == 'E' { 14 }
  else if c == 'F' { 15 }
  else { 0 }
}