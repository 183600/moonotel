fn probe_hex_ref_byte(value : Int32) -> String {
  let digits = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e",
    "f",
  ]
  let hi = value >> 4
  let hi_char = if hi >= 0 && hi < 16 { digits[hi] } else { "0" }
  hi_char + digits[value & 0x0F]
}

fn probe_hex_ref(bytes : Array[Int32]) -> String {
  let sb = StringBuilder()
  for b in bytes {
    sb.write_string(probe_hex_ref_byte(b))
  }
  sb.to_string()
}

///|
test "bytes_to_hex fast paths" {
  let lengths = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 15, 16, 17, 31, 32]
  let values = [-65537, -1000, -256, -255, -17, -16, -1, 0, 1, 15, 16, 127, 255,
    256, 257, 511, 512, 1000, 65535, 65536]
  let mut seed : UInt64 = 12345
  for len in lengths {
    for _ in 0..<200 {
      let bytes : Array[Int32] = []
      for _ in 0..<len {
        seed = seed * 6364136223846793005UL + 1442695040888963407UL
        let index = (seed >> 33).to_int() % values.length()
        bytes.push(values[index])
      }
      let expected = probe_hex_ref(bytes)
      let actual = bytes_to_hex(bytes)
      if actual != expected {
        println("MISMATCH len=" + len.to_string())
        println(Repr(bytes))
        println(actual)
        println(expected)
        abort("bytes_to_hex mismatch")
      }
    }
  }
}
