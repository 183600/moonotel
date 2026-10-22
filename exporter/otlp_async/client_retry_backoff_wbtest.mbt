// Whitebox tests for the retry backoff helper in `client.mbt`.

///|
test "retry backoff doubles and stays within its jitter band" {
  for attempt = 1; attempt <= 8; attempt = attempt + 1 {
    let base = match attempt {
      1 => 100
      2 => 200
      3 => 400
      4 => 800
      5 => 1600
      6 => 3200
      _ => 5000
    }
    let delay = retry_backoff_millis(attempt)
    assert_true(delay >= base * 80 / 100)
    assert_true(delay <= base * 120 / 100)
  }
}

///|
test "retry backoff caps at five seconds for large retry counts" {
  for attempt in [7, 8, 50, 1000, 2147483647] {
    let delay = retry_backoff_millis(attempt)
    assert_true(delay >= 4000)
    assert_true(delay <= 5000)
  }
}

///|
test "retry backoff treats non-positive attempts as the first retry" {
  assert_eq(retry_backoff_millis(1), retry_backoff_millis(0))
  assert_eq(retry_backoff_millis(1), retry_backoff_millis(-5))
}
