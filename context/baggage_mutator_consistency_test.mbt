// Deterministic randomized consistency check for every Context baggage mutator.
// The flattened views, point lookups, properties and emptiness predicate must
// agree with a reference model after arbitrary interleavings of values,
// properties, removals, map/list updates and cross-context merges.

///|
enum FuzzOp {
  FuzzValue(String, String)
  FuzzEntry(String, String, Array[(String, String)])
  FuzzDelete(String)
  FuzzMap(Array[(String, String)])
  FuzzOwned(Array[(String, String)])
  FuzzEntries(Array[@context.BaggageEntry])
  FuzzClear
  FuzzMerge(Int32)
}

///|
fn fuzz_apply(
  ctx : @context.Context,
  op : FuzzOp,
  sources : Array[@context.Context],
) -> @context.Context {
  match op {
    FuzzValue(k, v) => ctx.with_value(k, v)
    FuzzEntry(k, v, props) =>
      ctx.with_baggage_entry(k, v, properties=props.copy())
    FuzzDelete(k) => ctx.without_value(k)
    FuzzMap(pairs) => {
      let map : Map[String, String] = Map([])
      for pair in pairs {
        map.set(pair.0, pair.1)
      }
      ctx.with_baggage(map)
    }
    FuzzOwned(pairs) => {
      let map : Map[String, String] = Map([])
      for pair in pairs {
        map.set(pair.0, pair.1)
      }
      ctx.with_baggage_owned(map)
    }
    FuzzEntries(entries) => ctx.with_baggage_entries(entries)
    FuzzClear => ctx.without_baggage()
    FuzzMerge(index) => ctx.with_baggage_from(sources[index])
  }
}

///|
fn fuzz_sources() -> (Array[@context.Context], Array[Array[FuzzOp]]) {
  let contexts : Array[@context.Context] = []
  let histories : Array[Array[FuzzOp]] = []
  let sources : Array[@context.Context] = []
  let first : Array[FuzzOp] = [
    FuzzValue("a", "old"),
    FuzzDelete("a"),
    FuzzValue("b", "source-b"),
  ]
  let second : Array[FuzzOp] = [
    FuzzValue("c", "hidden"),
    FuzzValue("d", "source-d"),
    FuzzEntries([]),
    FuzzEntry("e", "source-e", [("p", "1")]),
  ]
  let third : Array[FuzzOp] = [
    FuzzEntries([
      @context.BaggageEntry::new("a", "entries-a", properties=[("p", "2")]),
      @context.BaggageEntry::new("f", "entries-f"),
    ]),
    FuzzDelete("b"),
  ]
  for history in [first, second, third] {
    let mut ctx = @context.Context::root()
    for op in history {
      ctx = fuzz_apply(ctx, op, sources)
    }
    contexts.push(ctx)
    histories.push(history)
  }
  (contexts, histories)
}

///|
fn fuzz_props_for(seed : Int32) -> Array[(String, String)] {
  if seed % 2 == 0 {
    []
  } else {
    [("p", seed.to_string())]
  }
}

///|
fn fuzz_expected(
  history : Array[FuzzOp],
  key : String,
) -> @context.BaggageEntry? {
  let mut i = history.length() - 1
  while i >= 0 {
    match history[i] {
      FuzzValue(k, v) =>
        if k == key {
          return Some(@context.BaggageEntry::new(k, v))
        }
      FuzzEntry(k, v, props) =>
        if k == key {
          return Some(@context.BaggageEntry::new(k, v, properties=props))
        }
      FuzzDelete(k) => if k == key { return None }
      FuzzMap(pairs) =>
        if pairs.length() == 0 {
          return None
        } else {
          for pair in pairs {
            if pair.0 == key {
              return Some(@context.BaggageEntry::new(pair.0, pair.1))
            }
          }
        }
      FuzzOwned(pairs) =>
        if pairs.length() == 0 {
          return None
        } else {
          for pair in pairs {
            if pair.0 == key {
              return Some(@context.BaggageEntry::new(pair.0, pair.1))
            }
          }
        }
      FuzzEntries(entries) => {
        if entries.length() == 0 {
          return None
        }
        let mut found : @context.BaggageEntry? = None
        let mut present = false
        for entry in entries {
          if entry.key == key {
            found = Some(entry)
            present = true
          }
        }
        if present {
          return found
        }
      }
      FuzzClear => return None
      FuzzMerge(_) => abort("merge should not be in a history")
    }
    i = i - 1
  }
  None
}

///|
test "baggage lookup stays consistent across every mutator" {
  let (sources, source_histories) = fuzz_sources()
  let keys : Array[String] = ["a", "b", "c", "d", "e", "f", "g"]
  let values : Array[String] = ["", "0", "1", "two"]
  let mut seed = 987654321
  let history : Array[FuzzOp] = []
  let mut ctx = @context.Context::root()
  let mut step = 0
  while step < 3000 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let kind = seed % 8
    let key = keys[seed / 7 % keys.length()]
    let value = values[seed / 13 % values.length()]
    let op = if kind == 0 {
      FuzzValue(key, value)
    } else if kind == 1 {
      FuzzEntry(key, value, fuzz_props_for(seed / 17))
    } else if kind == 2 {
      FuzzDelete(key)
    } else if kind == 3 {
      let pairs : Array[(String, String)] = []
      for k in keys {
        if seed / (19 + k.length()) % 3 == 0 {
          pairs.push((k, "m" + k))
        }
      }
      FuzzMap(pairs)
    } else if kind == 4 {
      let pairs : Array[(String, String)] = []
      for k in keys {
        if seed / (23 + k.length()) % 4 == 0 {
          pairs.push((k, "o" + k))
        }
      }
      FuzzOwned(pairs)
    } else if kind == 5 {
      let entries : Array[@context.BaggageEntry] = []
      for k in keys {
        if seed / (29 + k.length()) % 5 == 0 {
          entries.push(
            @context.BaggageEntry::new(
              k,
              "e" + k,
              properties=fuzz_props_for(seed),
            ),
          )
        }
      }
      FuzzEntries(entries)
    } else if kind == 6 {
      FuzzClear
    } else {
      FuzzMerge(seed / 31 % sources.length())
    }
    ctx = fuzz_apply(ctx, op, sources)
    if op is FuzzMerge(index) {
      for source_op in source_histories[index] {
        history.push(source_op)
      }
    } else {
      history.push(op)
    }
    let actual = ctx.baggage_entries()
    let seen : Array[String] = []
    for entry in actual {
      if seen.contains(entry.key) {
        abort("duplicate key at step " + step.to_string() + ": " + entry.key)
      }
      seen.push(entry.key)
      let expected = fuzz_expected(history, entry.key)
      match expected {
        Some(want) =>
          if want.value != entry.value || want.properties != entry.properties {
            abort(
              "entry mismatch at step " + step.to_string() + ": " + entry.key,
            )
          }
        None => abort("unexpected entry at step " + step.to_string())
      }
    }
    let flat = ctx.baggage()
    if flat.length() != actual.length() {
      abort("flat length mismatch at step " + step.to_string())
    }
    for key in keys {
      let expected = fuzz_expected(history, key)
      let expected_value = match expected {
        Some(entry) => Some(entry.value)
        None => None
      }
      if ctx.value(key) != expected_value {
        abort("value mismatch at step " + step.to_string() + ": " + key)
      }
      let expected_entry = ctx.baggage_entry(key)
      match (expected, expected_entry) {
        (Some(want), Some(got)) =>
          if want.value != got.value || want.properties != got.properties {
            abort("baggage_entry mismatch at step " + step.to_string())
          }
        (None, None) => ()
        _ =>
          abort("baggage_entry presence mismatch at step " + step.to_string())
      }
      if flat.get(key) != expected_value {
        abort("flat value mismatch at step " + step.to_string() + ": " + key)
      }
    }
    if ctx.has_baggage() != (actual.length() > 0) {
      abort("has_baggage mismatch at step " + step.to_string())
    }
    step = step + 1
  }
}
