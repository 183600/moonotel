// White-box tests for the `Connection` header `close` token matcher. OWS is
// `SP / HTAB` only (RFC 9110 §5.6.3); CR and LF are not whitespace.

///|
test "has_close_token_matches_case_insensitively_with_ows" {
  assert_true(has_close_token("close"))
  assert_true(has_close_token("CLOSE"))
  assert_true(has_close_token(" close "))
  assert_true(has_close_token("\tclose\t"))
  assert_true(has_close_token("keep-alive, close"))
  assert_true(has_close_token("close ,keep-alive"))
}

///|
test "has_close_token_rejects_cr_and_lf" {
  assert_false(has_close_token("close\r"))
  assert_false(has_close_token("close\n"))
  assert_false(has_close_token("\rclose"))
  assert_false(has_close_token("\nclose"))
  assert_false(has_close_token("clos\re"))
  assert_false(has_close_token("keep-alive"))
  assert_false(has_close_token(""))
}
