// The entry package re-exports the semantic-convention attribute keys and the
// context-storage hook, so that users of `@moonotel` do not need to depend on the
// `sdk` and `context` packages directly.

///|
test "facade_exposes_the_semantic_convention_keys" {
  assert_eq(@moonotel.HTTP_REQUEST_METHOD, "http.request.method")
  assert_eq(@moonotel.HTTP_RESPONSE_STATUS_CODE, "http.response.status_code")
  assert_eq(@moonotel.HTTP_REQUEST_BODY_SIZE, "http.request.body.size")
  assert_eq(@moonotel.HTTP_RESPONSE_BODY_SIZE, "http.response.body.size")
  assert_eq(@moonotel.HTTP_ROUTE, "http.route")
  assert_eq(@moonotel.HTTP_REQUEST_HEADER_PREFIX, "http.request.header.")
  assert_eq(@moonotel.HTTP_RESPONSE_HEADER_PREFIX, "http.response.header.")
  assert_eq(@moonotel.URL_FULL, "url.full")
  assert_eq(@moonotel.URL_SCHEME, "url.scheme")
  assert_eq(@moonotel.URL_PATH, "url.path")
  assert_eq(@moonotel.URL_QUERY, "url.query")
  assert_eq(@moonotel.SERVER_ADDRESS, "server.address")
  assert_eq(@moonotel.SERVER_PORT, "server.port")
  assert_eq(@moonotel.CLIENT_ADDRESS, "client.address")
  assert_eq(@moonotel.CLIENT_PORT, "client.port")
  assert_eq(@moonotel.USER_AGENT_ORIGINAL, "user_agent.original")
  assert_eq(@moonotel.NETWORK_PROTOCOL_NAME, "network.protocol.name")
  assert_eq(@moonotel.NETWORK_PROTOCOL_VERSION, "network.protocol.version")
  assert_eq(@moonotel.ERROR_TYPE, "error.type")
  assert_eq(@moonotel.SERVICE_NAME, "service.name")
  assert_eq(@moonotel.SERVICE_VERSION, "service.version")
  assert_eq(@moonotel.DEPLOYMENT_ENVIRONMENT, "deployment.environment")
  assert_eq(@moonotel.EXCEPTION_TYPE, "exception.type")
  assert_eq(@moonotel.EXCEPTION_MESSAGE, "exception.message")
  assert_eq(@moonotel.EXCEPTION_STACKTRACE, "exception.stacktrace")
}

///|
test "facade_exposes_the_context_storage_hook" {
  let slot : Ref[String] = Ref("root")
  let backend : @moonotel.ContextStorage = {
    current: () => @moonotel.Context::root().with_value("backend", slot.val),
    set: context => {
      slot.val = match context.value("backend") {
        Some(value) => value
        None => "<none>"
      }
    },
  }
  let previous = @moonotel.set_context_storage(backend)
  defer @moonotel.set_context_storage(previous) |> ignore
  assert_eq(@moonotel.current_context().value("backend"), Some("root"))
  let token = @moonotel.attach(@moonotel.Context::root().with_value("backend", "inner"))
  assert_eq(@moonotel.current_context().value("backend"), Some("inner"))
  @moonotel.detach(token)
  assert_eq(@moonotel.current_context().value("backend"), Some("root"))
}

///|
pub struct FacadeDetector {
  name : String
}

///|
pub fn FacadeDetector::new(name : String) -> FacadeDetector {
  { name, }
}

///|
pub impl @moonotel.ResourceDetector for FacadeDetector with fn detect(self) {
  @moonotel.Resource::new(
    attributes=Map([
      ("detected.by", @moonotel.AttributeValue::StringValue(self.name)),
    ]),
  )
}

///|
pub extend FacadeDetector with @moonotel.ResourceDetector::{detect}

///|
test "facade_exposes_the_resource_detector_extension_point" {
  let detector = FacadeDetector::new("facade")
  let resource = @moonotel.Resource::detect([detector])
  assert_eq(
    resource.get("detected.by"),
    Some(@moonotel.AttributeValue::StringValue("facade")),
  )
}
