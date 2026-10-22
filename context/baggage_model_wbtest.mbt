///|
enum ProbeOp {
  V(String, String)
  E(String, String, Array[(String, String)])
  D(String)
  M(Array[(String, String)])
}

///|
fn probe_props(seed : Int) -> Array[(String, String)] {
  if seed % 3 == 0 {
    [("p", "1")]
  } else if seed % 3 == 1 {
    [("p", "1"), ("q", "2")]
  } else {
    []
  }
}

///|
fn probe_find(entries : Array[BaggageEntry], key : String) -> BaggageEntry? {
  for entry in entries {
    if entry.key == key {
      return Some(entry)
    }
  }
  None
}

///|
fn probe_seen(seen : Array[String], key : String) -> Bool {
  seen.contains(key)
}

///|
test "context baggage semantics" {
  let keys : Array[String] = ["a", "b", "c", "d"]
  let values : Array[String] = ["", "1", "2", " x"]
  let mut seed = 123456789
  let model : Array[ProbeOp] = []
  let mut ctx = Context::root()
  let mut step = 0
  while step < 4000 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let kind = seed % 4
    let key = keys[(seed / 7) % 4]
    let value = values[(seed / 13) % 4]
    if kind == 0 {
      ctx = ctx.with_value(key, value)
      model.push(V(key, value))
    } else if kind == 1 {
      let props = probe_props(seed / 17)
      ctx = ctx.with_baggage_entry(key, value, properties=props)
      model.push(E(key, value, props))
    } else if kind == 2 {
      ctx = ctx.without_value(key)
      model.push(D(key))
    } else {
      let pairs : Array[(String, String)] = []
      let map : Map[String, String] = Map([])
      for k in keys {
        if (seed / (11 + k.length())) % 2 == 0 {
          map.set(k, "m" + k)
          pairs.push((k, "m" + k))
        }
      }
      ctx = ctx.with_baggage(map)
      model.push(M(pairs))
    }
    // Rebuild the expected visible entries from the model history.
    let expected : Array[BaggageEntry] = []
    let seen : Array[String] = []
    let mut i = model.length() - 1
    while i >= 0 {
      match model[i] {
        V(k, v) =>
          if !probe_seen(seen, k) {
            seen.push(k)
            expected.push(BaggageEntry::new(k, v))
          }
        E(k, v, props) =>
          if !probe_seen(seen, k) {
            seen.push(k)
            expected.push(BaggageEntry::new(k, v, properties=props))
          }
        D(k) => if !probe_seen(seen, k) { seen.push(k) }
        M(pairs) =>
          if pairs.length() == 0 {
            // An empty baggage update hides every older operation. Values
            // added after it (already visited by this backwards scan) stay
            // visible.
            i = -1
          } else {
            for pair in pairs {
              if !probe_seen(seen, pair.0) {
                seen.push(pair.0)
                expected.push(BaggageEntry::new(pair.0, pair.1))
              }
            }
          }
      }
      i = i - 1
    }
    let actual = ctx.baggage_entries()
    if actual.length() != expected.length() {
      abort("length mismatch at step " + step.to_string())
    }
    for j, entry in actual {
      let exp = expected[j]
      if entry.key != exp.key || entry.value != exp.value {
        abort("entry mismatch at step " + step.to_string() + ": " + entry.key)
      }
      for prop in entry.properties {
        if !exp.properties.contains(prop) {
          abort("property mismatch at step " + step.to_string())
        }
      }
      if entry.properties.length() != exp.properties.length() {
        abort("property count mismatch at step " + step.to_string())
      }
    }
    if ctx.has_baggage() != (actual.length() > 0) {
      abort("has_baggage mismatch at step " + step.to_string())
    }
    let flat = ctx.baggage()
    if flat.length() != actual.length() {
      abort("baggage length mismatch at step " + step.to_string())
    }
    for entry in actual {
      if flat.get(entry.key) != Some(entry.value) {
        abort("baggage value mismatch at step " + step.to_string())
      }
      match ctx.baggage_entry(entry.key) {
        Some(got) =>
          if got.value != entry.value {
            abort("baggage_entry mismatch at step " + step.to_string())
          }
        None => abort("missing baggage_entry at step " + step.to_string())
      }
    }
    for k in keys {
      let expected_value : String? = match probe_find(actual, k) {
        Some(entry) => Some(entry.value)
        None => None
      }
      if ctx.value(k) != expected_value {
        abort("value mismatch at step " + step.to_string())
      }
    }
    step = step + 1
  }
}
