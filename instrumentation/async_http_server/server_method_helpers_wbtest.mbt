// Every HTTP request method must map to the semantic-convention HTTP method
// attribute and to the request line's method spelling.

///|
test "http_method_helpers_cover_every_request_method" {
  let cases : Array[(@http.RequestMethod, String)] = [
    (@http.RequestMethod::Get, "GET"),
    (@http.RequestMethod::Head, "HEAD"),
    (@http.RequestMethod::Post, "POST"),
    (@http.RequestMethod::Put, "PUT"),
    (@http.RequestMethod::Delete, "DELETE"),
    (@http.RequestMethod::Connect, "CONNECT"),
    (@http.RequestMethod::Options, "OPTIONS"),
    (@http.RequestMethod::Trace, "TRACE"),
    (@http.RequestMethod::Patch, "PATCH"),
  ]
  for pair in cases {
    let (request_method, name) = pair
    assert_eq(http_method_name(request_method), name)
    assert_eq(method_attribute_value(request_method), @sdk.StringValue(name))
  }
}
