// Configuration for `BatchSpanProcessor`. It mirrors the `OTEL_BSP_*`
// environment variables so callers can tune batching in code instead of (or
// on top of) the environment.

// Read a positive integer from an environment variable, falling back to
// `default` when the variable is absent, not a valid integer, or not positive.

///|
fn env_int(name : String, default : Int32) -> Int32 {
  match @env.get_env_var(name) {
    Some(value) =>
      try {
        let parsed = @string.parse_int(value.trim())
        if parsed < 1 {
          default
        } else {
          parsed
        }
      } catch {
        _ => default
      }
    None => default
  }
}

// Read a non-negative integer from an environment variable, falling back to
// `default` when the variable is absent, not a valid integer, or negative.
// Durations accept zero; only negative values are invalid.

///|
fn env_duration(name : String, default : Int32) -> Int32 {
  match @env.get_env_var(name) {
    Some(value) =>
      try {
        let parsed = @string.parse_int(value.trim())
        if parsed < 0 {
          default
        } else {
          parsed
        }
      } catch {
        _ => default
      }
    None => default
  }
}

///|
pub struct BatchConfig {
  max_queue_size : Int32
  max_export_batch_size : Int32
  flush_interval_millis : Int32
}

// Create a batch configuration. Defaults: queue size 2048, export batch size
// 512, flush interval 5000ms. Non-positive queue and batch sizes are clamped
// to 1 and a negative interval is clamped to 0, matching the behavior of
// `BatchSpanProcessor::new`.

///|
pub fn BatchConfig::new(
  max_queue_size? : Int32,
  max_export_batch_size? : Int32,
  flush_interval_millis? : Int32,
) -> BatchConfig {
  let queue_size = max_queue_size.unwrap_or(2048)
  let batch_size = max_export_batch_size.unwrap_or(512)
  let interval = flush_interval_millis.unwrap_or(5000)
  {
    max_queue_size: if queue_size < 1 {
      1
    } else {
      queue_size
    },
    max_export_batch_size: if batch_size < 1 {
      1
    } else {
      batch_size
    },
    flush_interval_millis: if interval < 0 {
      0
    } else {
      interval
    },
  }
}

// The default batch configuration: queue size 2048, export batch size 512,
// flush interval 5000ms.

///|
pub fn BatchConfig::default() -> BatchConfig {
  BatchConfig::new()
}

// Read a configuration from the standard `OTEL_BSP_*` environment variables:
//
// - `OTEL_BSP_MAX_QUEUE_SIZE` (default 2048)
// - `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` (default 512, capped at the queue size)
// - `OTEL_BSP_SCHEDULE_DELAY` (default 5000 milliseconds)
//
// Absent or malformed values fall back to the defaults, as required by the
// OpenTelemetry specification.

///|
pub fn BatchConfig::from_env() -> BatchConfig {
  let queue_size = env_int("OTEL_BSP_MAX_QUEUE_SIZE", 2048)
  let batch_size = env_int("OTEL_BSP_MAX_EXPORT_BATCH_SIZE", 512)
  let schedule_delay = env_duration("OTEL_BSP_SCHEDULE_DELAY", 5000)
  let effective_batch = if batch_size > queue_size {
    queue_size
  } else {
    batch_size
  }
  BatchConfig::new(
    max_queue_size=queue_size,
    max_export_batch_size=effective_batch,
    flush_interval_millis=schedule_delay,
  )
}
