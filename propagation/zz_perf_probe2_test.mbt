///|
fn probe_find_code_unit(view : StringView, needle : UInt16, start : Int) -> Int {
  let len = view.length()
  let mut i = start
  while i < len {
    if view.unsafe_get(i) == needle {
      return i
    }
    i = i + 1
  }
  len
}

///|
fn probe_trim_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn probe_trim_ows(value : StringView) -> StringView {
  let len = value.length()
  if len == 0 {
    return value
  }
  if !probe_trim_char(value.unsafe_get(0).unsafe_to_char()) &&
    !probe_trim_char(value.unsafe_get(len - 1).unsafe_to_char()) {
    return value
  }
  let mut start = 0
  let mut end = len
  while start < end && probe_trim_char(value.unsafe_get(start).unsafe_to_char()) {
    start = start + 1
  }
  while end > start && probe_trim_char(value.unsafe_get(end - 1).unsafe_to_char()) {
    end = end - 1
  }
  value.view(start_offset=start, end_offset=end)
}

///|
fn probe_valid_key(key : StringView) -> Bool {
  let len = key.length()
  if len == 0 || len > 256 {
    return false
  }
  let mut at = -1
  let mut i = 0
  while i < len {
    let c = key.unsafe_get(i).unsafe_to_char()
    let ok = (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c == '-' ||
      c == '*' ||
      c == '/'
    if c == '@' {
      if at >= 0 {
        return false
      }
      at = i
    } else if !ok {
      return false
    }
    i = i + 1
  }
  if at < 0 {
    key.unsafe_get(0).unsafe_to_char() >= 'a' &&
      key.unsafe_get(0).unsafe_to_char() <= 'z'
  } else {
    true
  }
}

///|
fn probe_valid_value(value : StringView) -> Bool {
  let len = value.length()
  if len > 255 {
    return false
  }
  let mut i = 0
  while i < len {
    let code = value.unsafe_get(i).unsafe_to_char().to_int()
    if code < 0x20 || code > 0x7E || code == 0x2C || code == 0x3D {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn probe_parse_v1(value : String) -> Bool {
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let mut count = 0
  while true {
    let end = probe_find_code_unit(view, ',', start)
    let item = probe_trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      return false
    }
    let eq = probe_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return false
    }
    let key = probe_trim_ows(item[:eq])
    let member_value = probe_trim_ows(item[eq + 1:])
    if !probe_valid_key(key) || !probe_valid_value(member_value) {
      return false
    }
    count = count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  count > 0
}

///|
fn probe_parse_v2(value : String) -> Bool {
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let mut first_key : StringView? = None
  let mut seen : Array[StringView]? = None
  let mut count = 0
  while true {
    let end = probe_find_code_unit(view, ',', start)
    let item = probe_trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      return false
    }
    let eq = probe_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return false
    }
    let key = probe_trim_ows(item[:eq])
    let member_value = probe_trim_ows(item[eq + 1:])
    if !probe_valid_key(key) || !probe_valid_value(member_value) {
      return false
    }
    match seen {
      Some(keys) => {
        for existing in keys {
          if existing == key {
            return false
          }
        }
        keys.push(key)
      }
      None =>
        match first_key {
          None => first_key = Some(key)
          Some(existing) =>
            if existing == key {
              return false
            } else {
              let keys : Array[StringView] = [existing, key]
              seen = Some(keys)
            }
        }
    }
    count = count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  count > 0
}

///|
fn probe_parse_v3(value : String) -> Bool {
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let keys : Array[StringView] = []
  let mut count = 0
  while true {
    let end = probe_find_code_unit(view, ',', start)
    let item = probe_trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      return false
    }
    let eq = probe_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return false
    }
    let key = probe_trim_ows(item[:eq])
    let member_value = probe_trim_ows(item[eq + 1:])
    if !probe_valid_key(key) || !probe_valid_value(member_value) {
      return false
    }
    for existing in keys {
      if existing == key {
        return false
      }
    }
    keys.push(key)
    count = count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  count > 0
}

///|
test "zz_probe_parse_variants" (b : @bench.T) {
  let three = "vendor1=value1,vendor2=value2,vendor3=value3"
  let one = "vendor1=value1"
  b.bench(fn() {
    let _ = probe_parse_v1(three)
  })
  b.bench(fn() {
    let _ = probe_parse_v2(three)
  })
  b.bench(fn() {
    let _ = probe_parse_v3(three)
  })
  b.bench(fn() {
    let _ = probe_parse_v3(one)
  })
}

///|
fn probe_parse_v4(value : String) -> Bool {
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let keys : Array[StringView] = []
  while true {
    let end = probe_find_code_unit(view, ',', start)
    let item = probe_trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      return false
    }
    let eq = probe_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return false
    }
    let key = probe_trim_ows(item[:eq])
    let member_value = probe_trim_ows(item[eq + 1:])
    if !probe_valid_key(key) || !probe_valid_value(member_value) {
      return false
    }
    keys.push(key)
    if end == len {
      break
    }
    start = end + 1
  }
  keys.length() > 0
}

///|
fn probe_parse_v5(value : String) -> Bool {
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let keys : Array[StringView] = []
  let mut count = 0
  while true {
    let end = probe_find_code_unit(view, ',', start)
    let item = probe_trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      return false
    }
    let eq = probe_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return false
    }
    let key = probe_trim_ows(item[:eq])
    let member_value = probe_trim_ows(item[eq + 1:])
    if !probe_valid_key(key) || !probe_valid_value(member_value) {
      return false
    }
    let mut i = 0
    let n = keys.length()
    while i < n {
      if keys.unsafe_get(i) == key {
        return false
      }
      i = i + 1
    }
    keys.push(key)
    count = count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  count > 0
}

///|
test "zz_probe_parse_variants2" (b : @bench.T) {
  let three = "vendor1=value1,vendor2=value2,vendor3=value3"
  b.bench(fn() {
    let _ = probe_parse_v4(three)
  })
  b.bench(fn() {
    let _ = probe_parse_v5(three)
  })
}

///|
fn probe_parse_v6(value : String) -> Bool {
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let starts : Array[Int] = []
  let lens : Array[Int] = []
  let mut count = 0
  while true {
    let end = probe_find_code_unit(view, ',', start)
    let item = probe_trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      return false
    }
    let eq = probe_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return false
    }
    let key = probe_trim_ows(item[:eq])
    let member_value = probe_trim_ows(item[eq + 1:])
    if !probe_valid_key(key) || !probe_valid_value(member_value) {
      return false
    }
    let key_start = key.start_offset()
    let key_len = key.length()
    let n = starts.length()
    let mut i = 0
    while i < n {
      if lens.unsafe_get(i) == key_len &&
        value.view(start_offset=starts.unsafe_get(i), end_offset=starts.unsafe_get(i) + key_len) ==
        key {
        return false
      }
      i = i + 1
    }
    starts.push(key_start)
    lens.push(key_len)
    count = count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  count > 0
}

///|
test "zz_probe_parse_variants3" (b : @bench.T) {
  let three = "vendor1=value1,vendor2=value2,vendor3=value3"
  b.bench(fn() {
    let _ = probe_parse_v6(three)
  })
}

///|
test "zz_probe_array_push" (b : @bench.T) {
  let v : StringView = "vendor1"
  b.bench(fn() {
    let a : Array[StringView] = []
    a.push(v)
    a.push(v)
    a.push(v)
    let _ = a.length()
  })
  b.bench(fn() {
    let a : Array[Int] = []
    a.push(1)
    a.push(2)
    a.push(3)
    let _ = a.length()
  })
  b.bench(fn() {
    let a : Array[String] = []
    a.push("vendor1")
    a.push("vendor1")
    a.push("vendor1")
    let _ = a.length()
  })
  b.bench(fn() {
    let a : Array[StringView] = Array(capacity=32)
    a.push(v)
    let _ = a.length()
  })
}

///|
test "zz_probe_baggage_header" (b : @bench.T) {
  let empty = @context.Context::root()
  let one = empty.with_value("k1", "v1")
  let two = one.with_value("k2", "v2")
  let three = two.with_value("k3", "v3")
  b.bench(fn() {
    let _ = context_baggage_header(empty)
  })
  b.bench(fn() {
    let _ = context_baggage_header(one)
  })
  b.bench(fn() {
    let _ = context_baggage_header(two)
  })
  b.bench(fn() {
    let _ = context_baggage_header(three)
  })
  b.bench(fn() {
    let _ = percent_decode("v1")
  })
  b.bench(fn() {
    let _ = format_baggage([("k1", "v1"), ("k2", "v2")])
  })
}
