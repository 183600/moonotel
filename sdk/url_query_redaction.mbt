// Query parameter names whose values the HTTP semantic conventions ask
// instrumentations to redact by default.
// https://opentelemetry.io/docs/specs/semconv/registry/attributes/url/

///|
fn is_sensitive_query_parameter(name : StringView) -> Bool {
  let lower = name.to_lower()
  lower == "x-amz-signature" ||
  lower == "x-amz-credential" ||
  lower == "x-amz-security-token" ||
  lower == "awsaccesskeyid" ||
  lower == "signature" ||
  lower == "sig" ||
  lower == "x-goog-signature"
}

///|
fn query_hex_value(code : Int32) -> Int32 {
  if code >= 0x30 && code <= 0x39 {
    code - 0x30
  } else if code >= 0x41 && code <= 0x46 {
    code - 0x37
  } else if code >= 0x61 && code <= 0x66 {
    code - 0x57
  } else {
    -1
  }
}

// Percent-decode a query parameter name. Returns `None` for a malformed escape
// or a non-ASCII literal, neither of which can name a well-known sensitive
// parameter. A `+` is not treated as a space: parameter names are not form
// data.

///|
fn decode_query_parameter_name(name : StringView) -> String? {
  let len = name.length()
  let bytes : Array[Byte] = Array(capacity=len)
  let mut i = 0
  while i < len {
    let code = name.unsafe_get(i).to_int()
    if code == 0x25 {
      if i + 2 >= len {
        return None
      }
      let hi = query_hex_value(name.unsafe_get(i + 1).to_int())
      let lo = query_hex_value(name.unsafe_get(i + 2).to_int())
      if hi < 0 || lo < 0 {
        return None
      }
      bytes.push((hi * 16 + lo).to_byte())
      i = i + 3
    } else if code >= 0x80 {
      return None
    } else {
      bytes.push(code.to_byte())
      i = i + 1
    }
  }
  Some(@utf8.decode_lossy(Bytes::from_array(bytes).exact_view()))
}

// Whether a query parameter name denotes a sensitive parameter, either
// literally or after percent-decoding (for example
// `X%2DAmz%2DSignature`).

///|
fn is_sensitive_query_key(name : StringView) -> Bool {
  if is_sensitive_query_parameter(name) {
    true
  } else if name.find("%") is Some(_) {
    match decode_query_parameter_name(name) {
      Some(decoded) => is_sensitive_query_parameter(decoded[:])
      None => false
    }
  } else {
    false
  }
}

// Replace the value of each well-known sensitive query parameter with
// `REDACTED`, preserving parameter order, separators and unrelated values.
// Matching is case-insensitive; percent-encoded parameter names are decoded
// before matching while their original spelling is preserved in the output.

///|
pub fn redact_sensitive_query_string(query : String) -> String {
  let len = query.length()
  let mut start = 0
  let mut changed = false
  let out = StringBuilder(size_hint=len)
  while start <= len {
    let end = match query[start:].find("&") {
      Some(offset) => start + offset
      None => len
    }
    let part = query[start:end]
    let equal = match part.find("=") {
      Some(offset) => offset
      None => -1
    }
    if equal >= 0 && is_sensitive_query_key(part[:equal]) {
      out.write_stringview(part[:equal])
      out.write_char('=')
      out.write_string("REDACTED")
      changed = true
    } else {
      out.write_stringview(part)
    }
    if end >= len {
      break
    }
    out.write_char('&')
    start = end + 1
  }
  if changed {
    out.to_string()
  } else {
    query
  }
}
