// The entry package re-exports the semantic-convention attribute keys and the
// context-storage hook, so that users of `@otel` do not need to depend on the
// `sdk` and `context` packages directly.

///|
test "facade_exposes_the_semantic_convention_keys" {
  assert_eq(@otel.HTTP_REQUEST_METHOD, "http.request.method")
  assert_eq(@otel.HTTP_RESPONSE_STATUS_CODE, "http.response.status_code")
  assert_eq(@otel.HTTP_REQUEST_BODY_SIZE, "http.request.body.size")
  assert_eq(@otel.HTTP_RESPONSE_BODY_SIZE, "http.response.body.size")
  assert_eq(@otel.HTTP_ROUTE, "http.route")
  assert_eq(@otel.HTTP_REQUEST_HEADER_PREFIX, "http.request.header.")
  assert_eq(@otel.HTTP_RESPONSE_HEADER_PREFIX, "http.response.header.")
  assert_eq(@otel.URL_FULL, "url.full")
  assert_eq(@otel.URL_SCHEME, "url.scheme")
  assert_eq(@otel.URL_PATH, "url.path")
  assert_eq(@otel.URL_QUERY, "url.query")
  assert_eq(@otel.SERVER_ADDRESS, "server.address")
  assert_eq(@otel.SERVER_PORT, "server.port")
  assert_eq(@otel.CLIENT_ADDRESS, "client.address")
  assert_eq(@otel.CLIENT_PORT, "client.port")
  assert_eq(@otel.USER_AGENT_ORIGINAL, "user_agent.original")
  assert_eq(@otel.NETWORK_PROTOCOL_NAME, "network.protocol.name")
  assert_eq(@otel.NETWORK_PROTOCOL_VERSION, "network.protocol.version")
  assert_eq(@otel.ERROR_TYPE, "error.type")
  assert_eq(@otel.SERVICE_NAME, "service.name")
  assert_eq(@otel.SERVICE_VERSION, "service.version")
  assert_eq(@otel.DEPLOYMENT_ENVIRONMENT, "deployment.environment")
  assert_eq(@otel.EXCEPTION_TYPE, "exception.type")
  assert_eq(@otel.EXCEPTION_MESSAGE, "exception.message")
  assert_eq(@otel.EXCEPTION_STACKTRACE, "exception.stacktrace")
}

///|
test "facade_exposes_the_context_storage_hook" {
  let slot : Ref[String] = Ref("root")
  let backend : @otel.ContextStorage = {
    current: () => @otel.Context::root().with_value("backend", slot.val),
    set: context => {
      slot.val = match context.value("backend") {
        Some(value) => value
        None => "<none>"
      }
    },
  }
  let previous = @otel.set_context_storage(backend)
  defer @otel.set_context_storage(previous) |> ignore
  assert_eq(@otel.current_context().value("backend"), Some("root"))
  let token = @otel.attach(
    @otel.Context::root().with_value("backend", "inner"),
  )
  assert_eq(@otel.current_context().value("backend"), Some("inner"))
  @otel.detach(token)
  assert_eq(@otel.current_context().value("backend"), Some("root"))
}
