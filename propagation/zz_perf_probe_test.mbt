///|
fn probe_is_tracestate_key_old(key : StringView) -> Bool {
  fn is_lcalpha(c : Char) -> Bool {
    c >= 'a' && c <= 'z'
  }
  fn is_digit_char(c : Char) -> Bool {
    c >= '0' && c <= '9'
  }
  fn is_tail(c : Char) -> Bool {
    is_lcalpha(c) || is_digit_char(c) || c == '_' || c == '-' || c == '*' || c == '/'
  }
  let len = key.length()
  if len == 0 || len > 256 {
    return false
  }
  let mut at = -1
  let mut i = 0
  while i < len {
    if key.unsafe_get(i).unsafe_to_char() == '@' {
      if at >= 0 {
        return false
      }
      at = i
    }
    i = i + 1
  }
  if at < 0 {
    if !is_lcalpha(key.unsafe_get(0).unsafe_to_char()) {
      return false
    }
    let mut j = 1
    while j < len {
      if !is_tail(key.unsafe_get(j).unsafe_to_char()) {
        return false
      }
      j = j + 1
    }
    true
  } else {
    let tenant_len = at
    let system_len = len - at - 1
    if tenant_len < 1 || tenant_len > 241 || system_len < 1 || system_len > 14 {
      return false
    }
    let first = key.unsafe_get(0).unsafe_to_char()
    if !is_lcalpha(first) && !is_digit_char(first) {
      return false
    }
    let mut j = 1
    while j < at {
      if !is_tail(key.unsafe_get(j).unsafe_to_char()) {
        return false
      }
      j = j + 1
    }
    if !is_lcalpha(key.unsafe_get(at + 1).unsafe_to_char()) {
      return false
    }
    let mut k = at + 2
    while k < len {
      if !is_tail(key.unsafe_get(k).unsafe_to_char()) {
        return false
      }
      k = k + 1
    }
    true
  }
}

///|
fn probe_is_tracestate_key_new(key : StringView) -> Bool {
  fn is_lcalpha(c : Char) -> Bool {
    c >= 'a' && c <= 'z'
  }
  fn is_digit_char(c : Char) -> Bool {
    c >= '0' && c <= '9'
  }
  fn is_tail(c : Char) -> Bool {
    is_lcalpha(c) || is_digit_char(c) || c == '_' || c == '-' || c == '*' || c == '/'
  }
  let len = key.length()
  if len == 0 || len > 256 {
    return false
  }
  let mut at = -1
  let mut i = 0
  while i < len {
    let c = key.unsafe_get(i).unsafe_to_char()
    if c == '@' {
      if at >= 0 {
        return false
      }
      at = i
    } else if !is_tail(c) {
      return false
    }
    i = i + 1
  }
  if at < 0 {
    is_lcalpha(key.unsafe_get(0).unsafe_to_char())
  } else {
    let tenant_len = at
    let system_len = len - at - 1
    if tenant_len < 1 || tenant_len > 241 || system_len < 1 || system_len > 14 {
      return false
    }
    let first = key.unsafe_get(0).unsafe_to_char()
    if !is_lcalpha(first) && !is_digit_char(first) {
      return false
    }
    is_lcalpha(key.unsafe_get(at + 1).unsafe_to_char())
  }
}

///|
test "zz_probe_tracestate_key" (b : @bench.T) {
  let simple : StringView = "vendor1"
  let complex : StringView = "tenant@system"
  b.bench(fn() {
    let _ = probe_is_tracestate_key_old(simple)
  })
  b.bench(fn() {
    let _ = probe_is_tracestate_key_new(simple)
  })
  b.bench(fn() {
    let _ = probe_is_tracestate_key_old(complex)
  })
  b.bench(fn() {
    let _ = probe_is_tracestate_key_new(complex)
  })
}

///|
test "zz_probe_tracestate_sizes" (b : @bench.T) {
  let one = "vendor1=value1"
  let three = "vendor1=value1,vendor2=value2,vendor3=value3"
  b.bench(fn() {
    let _ = parse_tracestate(one)
  })
  b.bench(fn() {
    let _ = parse_tracestate(three)
  })
  let spaces = "vendor1=value1, vendor2=value2, vendor3=value3"
  b.bench(fn() {
    let _ = parse_tracestate(spaces)
  })
  b.bench(fn() {
    let _ = Tracestate::parse(three)
  })
  let baggage = "key1=value1;prop=1,key2=value2,key3=value3"
  b.bench(fn() {
    let _ = parse_baggage(baggage)
  })
}
