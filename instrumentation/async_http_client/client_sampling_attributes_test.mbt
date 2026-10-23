// The HTTP semantic conventions require `http.request.method`, `url.full` and
// the server attributes to be available at span creation time so samplers can
// use them. The client instrumentation must pass them to the sampler instead
// of setting them only after the span has started.

///|
async test "client passes request attributes to samplers" {
  let seen : Ref[Map[String, @sdk.AttributeValue]] = Ref(Map([]))
  let called : Ref[Bool] = Ref(false)
  let sampler = @sdk.Sampler::new("ClientRequestAttributes", fn(parameters) {
    if !called.val {
      called.val = true
      seen.val = parameters.attributes.copy()
    }
    @sdk.sampling_decision_record_and_sample()
  })
  let provider = @sdk.TracerProviderSdk::new(
    service_name="client-sampler-attributes",
  ).with_sampler(sampler)
  let tracer = provider.get_tracer("client-sampler-attributes")
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        conn.send_response(200, "OK")
      })
    }
    let url = "http://127.0.0.1:\{port}/sampled?q=1&X-Amz-Signature=secret"
    let (response, _body) = @async_http_client.get(url, tracer~)
    assert_eq(response.code, 200)
    assert_true(called.val)
    let attributes = seen.val
    assert_eq(
      attributes.get(@sdk.HTTP_REQUEST_METHOD),
      Some(@sdk.StringValue("GET")),
    )
    assert_eq(
      attributes.get(@sdk.URL_FULL),
      Some(
        @sdk.StringValue(
          "http://127.0.0.1:\{port}/sampled?q=1&X-Amz-Signature=REDACTED",
        ),
      ),
    )
    assert_eq(attributes.get(@sdk.URL_PATH), Some(@sdk.StringValue("/sampled")))
    assert_eq(
      attributes.get(@sdk.URL_QUERY),
      Some(@sdk.StringValue("q=1&X-Amz-Signature=REDACTED")),
    )
    assert_eq(attributes.get(@sdk.URL_SCHEME), Some(@sdk.StringValue("http")))
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
      Some(@sdk.StringValue("127.0.0.1")),
    )
    assert_eq(
      attributes.get(@sdk.SERVER_PORT),
      Some(@sdk.IntValue(port.to_int64())),
    )
    // A GET has no request body, so the size attribute is omitted.
    assert_eq(attributes.get(@sdk.HTTP_REQUEST_BODY_SIZE), None)
  }
}
