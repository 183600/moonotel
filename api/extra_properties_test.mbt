// Extra property-based tests
test "property_hex_to_bytes_roundtrip" {
  let mut i = 0
  while i < 256 {
    let bytes = [i]
    let hex = bytes_to_hex(bytes)
    let back = hex_to_bytes(hex)
    assert_eq(back.length(), 1)
    assert_eq(back[0], i)
    i = i + 1
  }
}

test "property_hex_to_bytes_two_bytes_roundtrip" {
  let mut i = 0
  while i < 256 {
    let bytes = [i, 255 - i]
    let hex = bytes_to_hex(bytes)
    let back = hex_to_bytes(hex)
    assert_eq(back.length(), 2)
    assert_eq(back[0], i)
    assert_eq(back[1], 255 - i)
    i = i + 1
  }
}

test "property_is_zero_on_varied_lengths" {
  let mut len = 1
  while len < 100 {
    let arr = Array::make(len, 0)
    assert_true(is_zero(arr))
    
    // Set one element to non-zero
    let mut j = 0
    while j < len {
      arr[j] = 1
      assert_false(is_zero(arr))
      arr[j] = 0 // reset
      j = j + 1
    }
    len = len + 1
  }
}

test "property_hex_to_int_roundtrip" {
  let mut i = 0
  while i < 1000 {
    // We don't have a direct int_to_hex, but we can check some known values
    // or just check that it's consistent.
    // Let's test single hex digits
    let digits = "0123456789abcdefABCDEF"
    let d_arr = digits.to_array()
    let mut j = 0
    while j < d_arr.length() {
      let c = d_arr[j]
      let s = c.to_string()
      let val = hex_to_int(s)
      if j < 10 {
        assert_eq(val, j)
      } else if j < 16 {
        assert_eq(val, j)
      } else {
        assert_eq(val, j - 6) // A is at index 16, should be 10
      }
      j = j + 1
    }
    i = 1000 // break
  }
}
