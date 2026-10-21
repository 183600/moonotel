// Whitebox test for the retry backoff helper in `client.mbt`.

///|
test "retry backoff stays within its deterministic jitter band" {
  for attempt = 1; attempt <= 3; attempt = attempt + 1 {
    let base = 100 * attempt
    let delay = retry_backoff_millis(attempt)
    assert_true(delay >= base * 80 / 100)
    assert_true(delay <= base * 120 / 100)
  }
}
