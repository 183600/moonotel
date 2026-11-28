// The transport trims response `Content-Length` and accepts only ASCII
// digits, so the instrumentation must drop values such as `+5` and `1_0`
// before `send_response` sees them and aborts the response.

///|
test "parse_content_length rejects values above the Int64 range" {
  assert_eq(
    parse_content_length("9223372036854775807"[:]),
    Some(9223372036854775807L),
  )
  assert_eq(parse_content_length("9223372036854775808"[:]), None)
  assert_eq(parse_content_length("18446744073709551615"[:]), None)
  assert_eq(parse_content_length("18446744073709551616"[:]), None)
}

///|
test "wire_response_headers rejects content-length the transport rejects" {
  for
    value in [
      "+5", "-5", "1_0", "0x5", "", " 5 5 ",
    ] {
    let headers : @http.Headers = Map([
      (@http.CaseInsensitiveString("Content-Length"), value),
    ])
    let wire = wire_response_headers(headers, @http.Get, 200, true)
    assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
    assert_eq(
      wire.get(@http.CaseInsensitiveString("transfer-encoding")),
      Some("chunked"),
    )
    let empty_wire = wire_response_headers(headers, @http.Get, 200, false)
    assert_eq(
      empty_wire.get(@http.CaseInsensitiveString("content-length")),
      Some("0"),
    )
  }
}

///|
test "wire_response_headers accepts transport content-length grammar" {
  for value in ["5", " 5 ", "05", "0"] {
    let headers : @http.Headers = Map([
      (@http.CaseInsensitiveString("Content-Length"), value),
    ])
    let wire = wire_response_headers(headers, @http.Get, 200, true)
    assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), Some(value))
    assert_eq(wire.get(@http.CaseInsensitiveString("transfer-encoding")), None)
  }
}

///|
test "wire_response_headers accepts content-length trimmed by the transport" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "5\r\n"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), Some("5"))
  assert_eq(wire.get(@http.CaseInsensitiveString("transfer-encoding")), None)
}

///|
test "wire_response_headers rejects negative content-length" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "-1"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
  let empty_wire = wire_response_headers(headers, @http.Get, 200, false)
  assert_eq(
    empty_wire.get(@http.CaseInsensitiveString("content-length")),
    Some("0"),
  )
}

///|
test "wire_response_headers rejects malformed content-length" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "not-a-number"),
  ])
  let wire = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  assert_eq(
    wire.get(@http.CaseInsensitiveString("transfer-encoding")),
    Some("chunked"),
  )
}

///|
test "wire_response_headers drops content-length on 1xx and 204 responses" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "7"),
  ])
  for status_code in [199, 204] {
    let wire = wire_response_headers(headers, @http.Get, status_code, false)
    assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  }
  let not_modified = wire_response_headers(headers, @http.Get, 304, false)
  assert_eq(
    not_modified.get(@http.CaseInsensitiveString("content-length")),
    Some("7"),
  )
}

///|
test "wire_response_headers drops content-length on successful CONNECT" {
  let headers : @http.Headers = Map([
    (@http.CaseInsensitiveString("Content-Length"), "7"),
  ])
  for status_code in [200, 299] {
    let wire = wire_response_headers(headers, @http.Connect, status_code, false)
    assert_eq(wire.get(@http.CaseInsensitiveString("content-length")), None)
  }
  let failed = wire_response_headers(headers, @http.Connect, 400, true)
  assert_eq(
    failed.get(@http.CaseInsensitiveString("content-length")),
    Some("7"),
  )
  let succeeded_get = wire_response_headers(headers, @http.Get, 200, true)
  assert_eq(
    succeeded_get.get(@http.CaseInsensitiveString("content-length")),
    Some("7"),
  )
}

///|
async test "respond drops content-length values rejected by the transport" {
  for pair in [("+5", "hello"), ("1_0", "0123456789")] {
    let (value, body) = pair
    @async.with_task_group() <| group => {
      let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
      let port = server.addr.port()
      group.spawn_bg(no_wait=true) <| () => {
        run_server_on(server, call => {
          let headers : Map[String, String] = Map([
            ("Content-Length", value),
          ])
          call.respond(200, body~, headers~)
        })
      }
      let connection = @socket.Tcp::connect(
        @socket.Addr::parse("127.0.0.1:\{port}"),
      )
      connection.write(
        "GET /cl HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n",
      )
      let response = @async.with_timeout(5000, () => {
        connection.read_all().text()
      })
      connection.close()
      assert_true(response.contains("200 OK"))
      assert_true(response.contains(body))
      assert_false(response.to_lower().contains("content-length: \{value}"))
    }
  }
}
