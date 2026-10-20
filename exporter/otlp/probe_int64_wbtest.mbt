///|
test "probe numeric int64 boundaries" {
  let cases : Array[String] = [
    "9223372036854775807",
    "9223372036854775808",
    "-9223372036854775808",
    "-9223372036854775809",
    "9223372036854775808.0",
    "9223372036854775807.0",
    "-9223372036854775808.0",
    "-9223372036854775809.0",
    "1e19",
    "9.3e18",
  ]
  for text in cases {
    let parsed = json_parse_numeric_int64(text)
    let rendered = match parsed {
      Some(value) => value.to_string()
      None => "None"
    }
    println(text + " -> " + rendered)
  }
}
