// SpanKind describes the relationship between the Span, its parents, and its
// children in a Trace.
pub(all) enum SpanKind {
  Internal
  Server
  Client
  Producer
  Consumer
} derive(Eq, @debug.Debug)

// Lower-case name of the span kind, following the OpenTelemetry specification
pub fn SpanKind::to_string(self : SpanKind) -> String {
  match self {
    Internal => "internal"
    Server => "server"
    Client => "client"
    Producer => "producer"
    Consumer => "consumer"
  }
}

// Numeric value used by the OTLP protobuf encoding
pub fn SpanKind::otlp_value(self : SpanKind) -> Int {
  match self {
    Internal => 1
    Server => 2
    Client => 3
    Producer => 4
    Consumer => 5
  }
}

pub extend SpanKind with Eq::{not_equal, equal}
pub extend SpanKind with @debug.Debug::{to_repr}
