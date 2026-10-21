// W3C `tracestate` as a first-class, immutable list of members.
//
// The tracing API requires `tracestate` operations beyond raw pass-through:
// looking up a member and producing a modified copy (add / update / remove)
// without ever building an invalid header value. The rules implemented here
// follow the W3C Trace Context specification:
//
// - a member is `key=value`, both validated by the same rules as
//   `parse_tracestate`; values must not be empty;
// - at most 32 members; adding to a full list drops the right-most member;
// - a key occurs at most once; a modified member moves to the beginning while
//   the order of the other members is preserved;
// - every mutating operation validates its inputs and returns the unchanged
//   list when they are invalid.
//
// All operations return new values; a `Tracestate` is never mutated in place.

// Maximum number of members in a `tracestate` list, as defined by W3C.

///|
pub const TRACESTATE_MAX_MEMBERS : Int32 = 32

///|
pub struct Tracestate {
  // Ordered members; keys are unique.
  members : Array[(String, String)]
}

// The empty `tracestate`.

///|
pub fn Tracestate::empty() -> Tracestate {
  { members: [], }
}

// Validate one member with the shared key/value rules; values must not be
// empty because W3C requires a value to end with a non-blank character.

///|
fn is_valid_tracestate_member(key : StringView, value : StringView) -> Bool {
  is_valid_tracestate_key(key) &&
  is_valid_tracestate_value(value) &&
  value.length() > 0
}

// Parse a `tracestate` header value. Empty and whitespace-only list members
// are allowed and carry no member; a duplicated key keeps its first member.
// Returns None when the value is empty, has more than 32 list-members,
// contains a malformed member, or has an invalid value. Optional whitespace
// around members is ignored, and `key = value` is accepted; blanks directly
// after `=` belong to the value.

///|
pub fn Tracestate::parse(value : String) -> Tracestate? {
  if value == "" {
    return None
  }
  let members : Array[(String, String)] = []
  let view = value[:]
  let len = view.length()
  let mut start = 0
  let mut member_count = 0
  while true {
    if member_count >= TRACESTATE_MAX_MEMBERS {
      return None
    }
    member_count = member_count + 1
    let end = find_code_unit(view, ',', start)
    let item = trim_ows(view.view(start_offset=start, end_offset=end))
    if item.length() == 0 {
      // Empty and whitespace-only list-members are allowed and carry no
      // key/value pair.
      if end == len {
        break
      }
      start = end + 1
      continue
    }
    let eq = find_code_unit(item, '=', 0)
    if eq >= item.length() {
      return None
    }
    let key_view = item[:eq]
    let key = trim_ows(key_view).to_owned()
    // A blank after `=` is part of the value (W3C `value` includes `%x20`); it
    // is only trimmed together with whitespace before `=` in `key = value`.
    let value_view = item[eq + 1:]
    let member_value = if key_view.length() == key.length() {
      value_view.to_owned()
    } else {
      trim_ows(value_view).to_owned()
    }
    if !is_valid_tracestate_member(key[:], member_value[:]) {
      return None
    }
    let mut duplicate = false
    for existing in members {
      if existing.0 == key {
        duplicate = true
        break
      }
    }
    // A duplicated key keeps its first member.
    if !duplicate {
      members.push((key, member_value))
    }
    if end == len {
      break
    }
    start = end + 1
  }
  Some({ members, })
}

// Parse a `tracestate` header value, yielding the empty list when it is
// absent or invalid. Useful when a best-effort `tracestate` is wanted.

///|
pub fn Tracestate::parse_or_empty(value : String) -> Tracestate {
  match Tracestate::parse(value) {
    Some(parsed) => parsed
    None => Tracestate::empty()
  }
}

// Number of members.

///|
pub fn Tracestate::length(self : Tracestate) -> Int32 {
  self.members.length()
}

// Whether the list has no members.

///|
pub fn Tracestate::is_empty(self : Tracestate) -> Bool {
  self.members.length() == 0
}

// The value of `key`, or None when the key is absent.

///|
pub fn Tracestate::get(self : Tracestate, key : String) -> String? {
  for entry in self.members {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

// The members in order, as fresh `(key, value)` pairs.

///|
pub fn Tracestate::entries(self : Tracestate) -> Array[(String, String)] {
  let out : Array[(String, String)] = Array(capacity=self.members.length())
  for entry in self.members {
    out.push(entry)
  }
  out
}

// Render the list as a `tracestate` header value. The empty list yields "".

///|
pub fn Tracestate::to_header(self : Tracestate) -> String {
  if self.members.length() == 0 {
    return ""
  }
  let mut size_hint = 0
  for entry in self.members {
    size_hint = size_hint + entry.0.length() + entry.1.length() + 2
  }
  let sb = StringBuilder(size_hint=size_hint * 2)
  let mut count = 0
  for entry in self.members {
    if count > 0 {
      sb.write_char(',')
    }
    sb.write_string(entry.0)
    sb.write_char('=')
    sb.write_string(entry.1)
    count = count + 1
  }
  sb.to_string()
}

// Append `members` to `out` while there is room, keeping their order and
// skipping the member whose key is `skip`.

///|
fn take_members(
  out : Array[(String, String)],
  members : Array[(String, String)],
  skip : String,
) -> Unit {
  for entry in members {
    if out.length() >= TRACESTATE_MAX_MEMBERS {
      return
    }
    if entry.0 != skip {
      out.push(entry)
    }
  }
}

// Add `key=value` at the beginning of the list. When the key is already
// present its old member is replaced. Adding to a full list drops the
// right-most member. Invalid keys or values leave the list unchanged.

///|
pub fn Tracestate::add(
  self : Tracestate,
  key : String,
  value : String,
) -> Tracestate {
  if !is_valid_tracestate_member(key[:], value[:]) {
    return self
  }
  let count = self.members.length()
  let capacity = if count < TRACESTATE_MAX_MEMBERS {
    count + 1
  } else {
    TRACESTATE_MAX_MEMBERS
  }
  let members : Array[(String, String)] = Array(capacity~)
  members.push((key, value))
  take_members(members, self.members, key)
  { members, }
}

// Update the value of `key`, moving the member to the beginning of the list.
// When the key is absent the list is unchanged. Invalid keys or values leave
// the list unchanged.

///|
pub fn Tracestate::update(
  self : Tracestate,
  key : String,
  value : String,
) -> Tracestate {
  if !is_valid_tracestate_member(key[:], value[:]) {
    return self
  }
  match self.get(key) {
    None => self
    Some(_) => {
      let count = self.members.length()
      let capacity = if count < TRACESTATE_MAX_MEMBERS {
        count + 1
      } else {
        TRACESTATE_MAX_MEMBERS
      }
      let members : Array[(String, String)] = Array(capacity~)
      members.push((key, value))
      take_members(members, self.members, key)
      { members, }
    }
  }
}

// Remove the member with `key`. Removing an absent key leaves the list
// unchanged.

///|
pub fn Tracestate::remove(self : Tracestate, key : String) -> Tracestate {
  let members : Array[(String, String)] = Array(capacity=self.members.length())
  for entry in self.members {
    if entry.0 != key {
      members.push(entry)
    }
  }
  { members, }
}
