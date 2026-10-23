// `HeaderCapture::from_env` caches by variable but must notice when the
// environment value changes or is removed, otherwise a process that
// reconfigures capture at runtime would keep the old selection forever.

///|
test "from_env refreshes after the variable changes or is unset" {
  let variable = "MOONOTEL_TEST_HEADER_CAPTURE_CACHE"
  @env.set_env_var(variable, "x-one")
  defer @env.unset_env_var(variable)
  let first = @http_header_capture.HeaderCapture::from_env(variable)
  assert_true(first.captures("x-one"))
  assert_false(first.captures("x-two"))
  @env.set_env_var(variable, "x-two")
  let second = @http_header_capture.HeaderCapture::from_env(variable)
  assert_true(second.captures("x-two"))
  assert_false(second.captures("x-one"))
  @env.unset_env_var(variable)
  let third = @http_header_capture.HeaderCapture::from_env(variable)
  assert_false(third.is_enabled())
}
