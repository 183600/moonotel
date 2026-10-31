test "baggage fast path matches general parser longer strings" {
  let alphabet = [
    "a", "%", "2", "f", "g", ",", "=", ";", " ", "\t", "\\", "\"",
  ]
  let inputs : Array[String] = []
  probe_generate(alphabet, "", 5, inputs)
  for value in inputs {
    let general = parse_baggage_general(value)
    match parse_baggage_plain(value) {
      Some(plain) => {
        if plain != general {
          println("MISMATCH pairs input=" + value)
          println(Repr(plain))
          println(Repr(general))
          abort("baggage pair fast-path mismatch")
        }
        let fast_entries : Array[BaggageEntry] = []
        for pair in plain {
          fast_entries.push({ key: pair.0, value: pair.1, properties: [], })
        }
        let general_entries = parse_baggage_entries_general(value)
        if fast_entries != general_entries {
          println("MISMATCH entries input=" + value)
          println(Repr(fast_entries))
          println(Repr(general_entries))
          abort("baggage entry fast-path mismatch")
        }
        let formatted = format_baggage(plain)
        if parse_baggage(formatted) != general {
          println("MISMATCH roundtrip input=" + value)
          println(formatted)
          println(Repr(parse_baggage(formatted)))
          println(Repr(general))
          abort("baggage roundtrip mismatch")
        }
      }
      None => ()
    }
  }
}
