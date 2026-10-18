// Stable attribute keys from the OpenTelemetry semantic conventions.
// Only the keys needed by the MVP HTTP instrumentation are listed.

///|
pub const HTTP_REQUEST_METHOD : String = "http.request.method"

///|
pub const HTTP_RESPONSE_STATUS_CODE : String = "http.response.status_code"

///|
pub const HTTP_REQUEST_BODY_SIZE : String = "http.request.body.size"

///|
pub const HTTP_RESPONSE_BODY_SIZE : String = "http.response.body.size"

///|
pub const HTTP_ROUTE : String = "http.route"

///|
pub const URL_FULL : String = "url.full"

///|
pub const URL_SCHEME : String = "url.scheme"

///|
pub const URL_PATH : String = "url.path"

///|
pub const URL_QUERY : String = "url.query"

///|
pub const SERVER_ADDRESS : String = "server.address"

///|
pub const SERVER_PORT : String = "server.port"

///|
pub const CLIENT_ADDRESS : String = "client.address"

///|
pub const USER_AGENT_ORIGINAL : String = "user_agent.original"

///|
pub const NETWORK_PROTOCOL_NAME : String = "network.protocol.name"

///|
pub const NETWORK_PROTOCOL_VERSION : String = "network.protocol.version"

///|
pub const ERROR_TYPE : String = "error.type"

///|
pub const SERVICE_NAME : String = "service.name"

///|
pub const SERVICE_VERSION : String = "service.version"

///|
pub const DEPLOYMENT_ENVIRONMENT : String = "deployment.environment"

///|
pub const TELEMETRY_SDK_NAME : String = "telemetry.sdk.name"

///|
pub const TELEMETRY_SDK_LANGUAGE : String = "telemetry.sdk.language"

///|
pub const TELEMETRY_SDK_VERSION : String = "telemetry.sdk.version"

///|
pub const EXCEPTION_TYPE : String = "exception.type"

///|
pub const EXCEPTION_MESSAGE : String = "exception.message"

///|
pub const EXCEPTION_STACKTRACE : String = "exception.stacktrace"
