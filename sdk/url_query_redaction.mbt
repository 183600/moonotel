// Query parameter names whose values the HTTP semantic conventions ask
// instrumentations to redact by default.
// https://opentelemetry.io/docs/specs/semconv/registry/attributes/url/

///|
fn is_sensitive_query_parameter(name : StringView) -> Bool {
  let lower = name.to_lower()
  lower == "x-amz-signature" ||
  lower == "x-amz-credential" ||
  lower == "x-amz-security-token" ||
  lower == "sig" ||
  lower == "x-goog-signature"
}

// Replace the value of each well-known sensitive query parameter with
// `REDACTED`, preserving parameter order, separators and unrelated values.
// Matching is case-insensitive. Encoded parameter names are left unchanged.

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
    if equal >= 0 && is_sensitive_query_parameter(part[:equal]) {
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
