test "JSON hex encoding matches bytes_to_hex for every length" {
  let mut len = 0
  while len <= 17 {
    let bytes : Array[Int32] = Array(capacity=len)
    let mut i = 0
    while i < len {
      bytes.push(
        if i % 7 == 0 {
          -1
        } else if i % 5 == 0 {
          256 + i
        } else {
          (i * 37 + 5) & 0xFF
        },
      )
      i = i + 1
    }
    let sb = JsonBuf::new(4)
    json_write_hex_quoted(sb, bytes)
    let actual = @utf8.decode_lossy(sb.to_bytes())
    assert_eq(actual, "\"" + @api.bytes_to_hex(bytes) + "\"")
    len = len + 1
  }
}
