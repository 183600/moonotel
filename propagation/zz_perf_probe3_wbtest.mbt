///|
fn probe_parse_ts_arr(value : String) -> String? {
  if value == "" {
    return None
  }
  let keys : Array[StringView] = []
  let mut member_count = 0
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let mut unchanged = true
  while true {
    if member_count >= 32 {
      return None
    }
    let end = find_code_unit(view, ',', start)
    let raw_item = view.view(start_offset=start, end_offset=end)
    let item = trim_ows(raw_item)
    if item.length() == 0 {
      return None
    }
    if item.length() != raw_item.length() {
      unchanged = false
    }
    let eq = find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return None
    }
    let raw_key = item[:eq]
    let key = trim_ows(raw_key)
    let raw_value = item[eq + 1:]
    let member_value = trim_ows(raw_value)
    if key.length() != raw_key.length() || member_value.length() != raw_value.length() {
      unchanged = false
    }
    if !is_valid_tracestate_key(key) || !is_valid_tracestate_value(member_value) {
      return None
    }
    let n = keys.length()
    let mut i = 0
    while i < n {
      if keys.unsafe_get(i) == key {
        return None
      }
      i = i + 1
    }
    keys.push(key)
    member_count = member_count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  if unchanged {
    Some(value)
  } else {
    Some(write_normalized_tracestate(view, len))
  }
}

///|
test "zz_probe_ts_ab" (b : @bench.T) {
  let three = "vendor1=value1,vendor2=value2,vendor3=value3"
  let one = "vendor1=value1"
  let six = "a=1,b=2,c=3,d=4,e=5,f=6"
  b.bench(fn() {
    let _ = parse_tracestate(three)
  })
  b.bench(fn() {
    let _ = probe_parse_ts_arr(three)
  })
  b.bench(fn() {
    let _ = parse_tracestate(one)
  })
  b.bench(fn() {
    let _ = probe_parse_ts_arr(one)
  })
  b.bench(fn() {
    let _ = parse_tracestate(six)
  })
  b.bench(fn() {
    let _ = probe_parse_ts_arr(six)
  })
}

///|
fn probe_parse_ts_hybrid(value : String) -> String? {
  if value == "" {
    return None
  }
  let mut first_key : StringView = ""
  let mut have_first = false
  let mut seen : Array[StringView]? = None
  let mut member_count = 0
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let mut unchanged = true
  while true {
    if member_count >= 32 {
      return None
    }
    let end = find_code_unit(view, ',', start)
    let raw_item = view.view(start_offset=start, end_offset=end)
    let item = trim_ows(raw_item)
    if item.length() == 0 {
      return None
    }
    if item.length() != raw_item.length() {
      unchanged = false
    }
    let eq = find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return None
    }
    let raw_key = item[:eq]
    let key = trim_ows(raw_key)
    let raw_value = item[eq + 1:]
    let member_value = trim_ows(raw_value)
    if key.length() != raw_key.length() || member_value.length() != raw_value.length() {
      unchanged = false
    }
    if !is_valid_tracestate_key(key) || !is_valid_tracestate_value(member_value) {
      return None
    }
    match seen {
      Some(keys) => {
        let n = keys.length()
        let mut i = 0
        while i < n {
          if keys.unsafe_get(i) == key {
            return None
          }
          i = i + 1
        }
        keys.push(key)
      }
      None =>
        if have_first {
          if first_key == key {
            return None
          }
          let keys : Array[StringView] = [first_key, key]
          seen = Some(keys)
        } else {
          first_key = key
          have_first = true
        }
    }
    member_count = member_count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  if unchanged {
    Some(value)
  } else {
    Some(write_normalized_tracestate(view, len))
  }
}

///|
test "zz_probe_ts_hybrid" (b : @bench.T) {
  let three = "vendor1=value1,vendor2=value2,vendor3=value3"
  let one = "vendor1=value1"
  let six = "a=1,b=2,c=3,d=4,e=5,f=6"
  b.bench(fn() {
    let _ = parse_tracestate(three)
  })
  b.bench(fn() {
    let _ = probe_parse_ts_hybrid(three)
  })
  b.bench(fn() {
    let _ = parse_tracestate(one)
  })
  b.bench(fn() {
    let _ = probe_parse_ts_hybrid(one)
  })
  b.bench(fn() {
    let _ = parse_tracestate(six)
  })
  b.bench(fn() {
    let _ = probe_parse_ts_hybrid(six)
  })
}
