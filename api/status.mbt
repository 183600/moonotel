// StatusCode represents the canonical status of a Span operation.
pub(all) enum StatusCode {
  Unset
  Ok
  Error
} derive(Eq, @debug.Debug)

// Lower-case name of the status code
pub fn StatusCode::to_string(self : StatusCode) -> String {
  match self {
    Unset => "unset"
    Ok => "ok"
    Error => "error"
  }
}

// Numeric value used by the OTLP protobuf encoding
pub fn StatusCode::otlp_value(self : StatusCode) -> Int {
  match self {
    Unset => 0
    Ok => 1
    Error => 2
  }
}
