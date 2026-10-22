// Encode a string view as UTF-8, replacing unpaired UTF-16 surrogates with
// U+FFFD so that invalid strings cannot abort the encoder.

///|
fn encode_utf8_lossy(value : StringView) -> Bytes {
  let len = value.length()
  let mut i = 0
  let mut has_unpaired = false
  while i < len {
    let unit = value.unsafe_get(i).to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      if i + 1 < len {
        let next = value.unsafe_get(i + 1).to_int()
        if next >= 0xDC00 && next <= 0xDFFF {
          i = i + 2
          continue
        }
      }
      has_unpaired = true
      break
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      has_unpaired = true
      break
    }
    i = i + 1
  }
  if !has_unpaired {
    return @utf8.encode(value)
  }
  let sb = StringBuilder()
  let mut j = 0
  while j < len {
    let unit = value.unsafe_get(j).to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      if j + 1 < len {
        let next = value.unsafe_get(j + 1).to_int()
        if next >= 0xDC00 && next <= 0xDFFF {
          sb.write_char(unit.unsafe_to_char())
          sb.write_char(next.unsafe_to_char())
          j = j + 2
          continue
        }
      }
      sb.write_char((0xFFFD).unsafe_to_char())
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      sb.write_char((0xFFFD).unsafe_to_char())
    } else {
      sb.write_char(unit.unsafe_to_char())
    }
    j = j + 1
  }
  @utf8.encode(sb.to_string())
}
