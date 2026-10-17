// Differential probe for the `parse_tracestate` first-key rewrite: the old
// implementation (from before the perf commit) is copied verbatim below and
// compared against the public function on a fuzz corpus.

fn ts_rand(state : Ref[Int], bound : Int) -> Int {
  state.val = (state.val * 25173 + 13849) & 0xFFFF
  state.val % bound
}

fn diff_is_trim_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

fn diff_trim_ows(value : StringView) -> StringView {
  let len = value.length()
  if len == 0 {
    return value
  }
  if !diff_is_trim_char(value.unsafe_get(0).unsafe_to_char()) &&
    !diff_is_trim_char(value.unsafe_get(len - 1).unsafe_to_char()) {
    return value
  }
  let mut start = 0
  let mut end = len
  while start < end &&
    diff_is_trim_char(value.unsafe_get(start).unsafe_to_char()) {
    start = start + 1
  }
  while end > start &&
    diff_is_trim_char(value.unsafe_get(end - 1).unsafe_to_char()) {
    end = end - 1
  }
  value.view(start_offset=start, end_offset=end)
}

fn diff_find_code_unit(view : StringView, needle : UInt16, start : Int) -> Int {
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

fn diff_is_lcalpha(c : Char) -> Bool {
  c >= 'a' && c <= 'z'
}

fn diff_is_digit_char(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

fn diff_is_tracestate_key_tail(c : Char) -> Bool {
  diff_is_lcalpha(c) ||
  diff_is_digit_char(c) ||
  c == '_' ||
  c == '-' ||
  c == '*' ||
  c == '/'
}

fn diff_is_valid_tracestate_key(key : StringView) -> Bool {
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
    if !diff_is_lcalpha(key.unsafe_get(0).unsafe_to_char()) {
      return false
    }
    let mut j = 1
    while j < len {
      if !diff_is_tracestate_key_tail(key.unsafe_get(j).unsafe_to_char()) {
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
    if !diff_is_lcalpha(first) && !diff_is_digit_char(first) {
      return false
    }
    let mut j = 1
    while j < at {
      if !diff_is_tracestate_key_tail(key.unsafe_get(j).unsafe_to_char()) {
        return false
      }
      j = j + 1
    }
    if !diff_is_lcalpha(key.unsafe_get(at + 1).unsafe_to_char()) {
      return false
    }
    let mut k = at + 2
    while k < len {
      if !diff_is_tracestate_key_tail(key.unsafe_get(k).unsafe_to_char()) {
        return false
      }
      k = k + 1
    }
    true
  }
}

fn diff_is_valid_tracestate_value(value : StringView) -> Bool {
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

fn diff_write_normalized_tracestate(view : StringView, len : Int) -> String {
  let sb = StringBuilder(size_hint=len * 2)
  let mut count = 0
  let mut start = 0
  while true {
    let end = diff_find_code_unit(view, ',', start)
    let item = diff_trim_ows(view.view(start_offset=start, end_offset=end))
    let eq = diff_find_code_unit(item, '=', 0)
    let key = diff_trim_ows(item[:eq])
    let member_value = diff_trim_ows(item[eq + 1:])
    if count > 0 {
      sb.write_char(',')
    }
    sb.write_stringview(key)
    sb.write_char('=')
    sb.write_stringview(member_value)
    count = count + 1
    if end == len {
      break
    }
    start = end + 1
  }
  sb.to_string()
}

fn diff_old_parse_tracestate(value : String) -> String? {
  if value == "" {
    return None
  }
  let seen : Array[StringView] = []
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let mut unchanged = true
  while true {
    if seen.length() >= 32 {
      return None
    }
    let end = diff_find_code_unit(view, ',', start)
    let raw_item = view.view(start_offset=start, end_offset=end)
    let item = diff_trim_ows(raw_item)
    if item.length() == 0 {
      return None
    }
    if item.length() != raw_item.length() {
      unchanged = false
    }
    let eq = diff_find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return None
    }
    let raw_key = item[:eq]
    let key = diff_trim_ows(raw_key)
    let raw_value = item[eq + 1:]
    let member_value = diff_trim_ows(raw_value)
    if key.length() != raw_key.length() ||
      member_value.length() != raw_value.length() {
      unchanged = false
    }
    if !diff_is_valid_tracestate_key(key) ||
      !diff_is_valid_tracestate_value(member_value) {
      return None
    }
    for existing in seen {
      if existing == key {
        return None
      }
    }
    seen.push(key)
    if end == len {
      break
    }
    start = end + 1
  }
  if unchanged {
    Some(value)
  } else {
    Some(diff_write_normalized_tracestate(view, len))
  }
}

///|
test "parse_tracestate_matches_old_implementation" {
  let key_chars = "abcxyz019_-*/@"
  let value_chars = "abcXYZ019_-*/!~ #"
  let state = Ref(4242)
  let mut round = 0
  while round < 6000 {
    round = round + 1
    let members = 1 + ts_rand(state, 35)
    let sb = StringBuilder()
    let mut i = 0
    while i < members {
      i = i + 1
      if i > 1 {
        if ts_rand(state, 4) == 0 {
          sb.write_string(" , ")
        } else {
          sb.write_char(',')
        }
      }
      if ts_rand(state, 5) != 0 {
        if ts_rand(state, 6) == 0 {
          sb.write_char(' ')
        }
        let key_len = 1 + ts_rand(state, 6)
        let mut k = 0
        while k < key_len {
          k = k + 1
          sb.write_char(
            key_chars.unsafe_get(ts_rand(state, key_chars.length())).unsafe_to_char(),
          )
        }
        sb.write_char('=')
        let value_len = ts_rand(state, 8)
        let mut v = 0
        while v < value_len {
          v = v + 1
          sb.write_char(
            value_chars
            .unsafe_get(ts_rand(state, value_chars.length()))
            .unsafe_to_char(),
          )
        }
        if ts_rand(state, 6) == 0 {
          sb.write_char('\t')
        }
      } else {
        sb.write_string("garbage")
      }
    }
    let value = sb.to_string()
    let old_result = diff_old_parse_tracestate(value)
    let new_result = @propagation.parse_tracestate(value)
    if new_result != old_result {
      fail(
        "input=" +
        value +
        " old=@" +
        (match old_result {
          Some(v) => v
          None => "<None>"
        }) +
        "@ new=@" +
        (match new_result {
          Some(v) => v
          None => "<None>"
        }) +
        "@",
      )
    }
  }
  // Explicit boundary cases: 32 vs 33 members, duplicates, whitespace.
  let all_members = StringBuilder()
  let mut i = 0
  while i < 33 {
    i = i + 1
    if i > 1 {
      all_members.write_char(',')
    }
    all_members.write_string("k" + i.to_string() + "=v")
  }
  let members_33 = all_members.to_string()
  let cut = members_33.rev_find(",").unwrap()
  let members_32 = members_33[:cut].to_owned()
  let cases : Array[String] = [
    members_32, members_33, "a=1,a=2", "a=1, a=2",
    "a=1 ,b=2", " a=1", "a=1 ", "a=", "=1", "a=1,", ",a=1", "a=1,,b=2",
    "congo=t61rcWkgMzE", "rojo=00f067aa0ba90207", "congo=t61rcWkgMzE,",
    "a@b=c", "a@=c", "@b=c", "a@b@c=d", "A=1", "a=1;B=2", "a=1\na=2",
  ]
  for value in cases {
    let old_result = diff_old_parse_tracestate(value)
    let new_result = @propagation.parse_tracestate(value)
    assert_eq(new_result, old_result)
  }
}
