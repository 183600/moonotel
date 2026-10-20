// White-box tests for request-target path/query splitting. Fragments are not
// part of the path or query components, even though they are not normally
// sent in an HTTP request target.

///|
test "split_path_query_drops_fragment_before_query" {
  assert_eq(
    split_path_query("http://example.com/items?q=1#frag"),
    ("/items", "q=1"),
  )
  assert_eq(
    split_path_query("https://example.com/items?q=1#frag"),
    ("/items", "q=1"),
  )
  assert_eq(split_path_query("/items?q=1#frag"), ("/items", "q=1"))
  assert_eq(split_path_query("/items#frag"), ("/items", ""))
  assert_eq(split_path_query("http://example.com/items#frag"), ("/items", ""))
  assert_eq(split_path_query("http://example.com#frag"), ("/", ""))
  assert_eq(split_path_query("#frag"), ("/", ""))
}

///|
test "split_path_query_drops_fragment_without_a_query" {
  assert_eq(split_path_query("/items?#frag"), ("/items", ""))
  assert_eq(split_path_query("http://example.com/?#frag"), ("/", ""))
  assert_eq(split_path_query("http://example.com?q=1#frag"), ("/", "q=1"))
}
