// The HTTP semantic conventions require the request method, URL components and
// server attributes to be available at span creation time so samplers can use
// them. The server instrumentation must pass them to the sampler instead of
// setting them only after the span has started.

///|
async test "server passes request attributes to samplers" {
  let seen : Ref[Map[String, @sdk.AttributeValue]] = Ref(Map([]))
  let called : Ref[Bool] = Ref(false)
  let sampler = @sdk.Sampler::new("ServerRequestAttributes", fn(parameters) {
    if !called.val {
      called.val = true
      seen.val = parameters.attributes.copy()
    }
    @sdk.sampling_decision_record_and_sample()
  })
  let provider = @sdk.TracerProviderSdk::new(
    service_name="server-sampler-attributes",
  ).with_sampler(sampler)
  let tracer = provider.get_tracer("server-sampler-attributes")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @async_http_server.run_server_on(
        server,
        call => call.respond(200, body="ok"),
        tracer~,
      )
    }
    let connection = @socket.Tcp::connect(
      @socket.Addr::parse("127.0.0.1:\{port}"),
    )
    connection.write(
      "POST /sampled?q=1&sig=secret HTTP/1.1\r\nHost: example.com:8080\r\nUser-Agent:   agent/1  \t\r\nContent-Length: 3\r\nConnection: close\r\n\r\nabc",
    )
    let _ = @async.with_timeout(5000, () => connection.read_all().text())
    connection.close()
    @async.sleep(50)
    assert_true(called.val)
    let attributes = seen.val
    assert_eq(
      attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("POST")),
    )
    assert_eq(attributes.get(@sdk.URL_SCHEME), Some(@sdk.StringValue("http")))
    assert_eq(attributes.get(@sdk.URL_PATH), Some(@sdk.StringValue("/sampled")))
    assert_eq(
      attributes.get(@sdk.URL_QUERY),
      Some(@sdk.StringValue("q=1&sig=REDACTED")),
    )
    assert_eq(
      attributes.get(@sdk.NETWORK_PROTOCOL_NAME),
      Some(@sdk.StringValue("http")),
    )
    assert_eq(
      attributes.get(@sdk.NETWORK_PROTOCOL_VERSION),
      Some(@sdk.StringValue("1.1")),
    )
    assert_eq(
      attributes.get(@sdk.SERVER_ADDRESS),
      Some(@sdk.StringValue("example.com")),
    )
    assert_eq(attributes.get(@sdk.SERVER_PORT), Some(@sdk.IntValue(8080L)))
    assert_eq(
      attributes.get(@sdk.USER_AGENT_ORIGINAL),
      Some(@sdk.StringValue("agent/1")),
    )
    assert_eq(
      attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE),
      Some(@sdk.IntValue(3L)),
    )
  }
}
