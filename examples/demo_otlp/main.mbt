// End-to-end OTLP demo: an instrumented HTTP server and the instrumented
// client run in the same process, and every finished span is exported to an
// OTLP/HTTP collector from a background task (`@async_runtime.setup`).
//
// Start a collector that speaks OTLP/HTTP on :4318 (for example the
// OpenTelemetry Collector or Jaeger all-in-one), then run:
//
//   moon run examples/demo_otlp --target native
//
// The endpoint and headers can be changed with the standard
// `OTEL_EXPORTER_OTLP_*` environment variables (see README.md). When no
// collector is reachable the demo prints the response, the failed exports
// are ignored and the process exits; an unreachable endpoint is not an
// error for the application.

///|
async fn main {
  @async.with_task_group(group => {
    let provider = @async_runtime.setup(group, service_name="demo-otlp")
    let tracer = provider.get_tracer("demo-otlp")
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    group.spawn_bg(no_wait=true) <| () => {
      @server.run_server_on(
        server,
        call => {
          match call.path() {
            "/hello" => call.respond(200, body="hello from the OTLP demo")
            _ => call.respond(404, body="not found")
          }
        },
        tracer~,
      )
    }
    let (response, body) = @client.get(
      "http://127.0.0.1:\{port}/hello",
      tracer~,
    )
    println("GET /hello -> \{response.code}: \{body.text()}")
  })
  @sdk.shutdown_global_tracer_provider()
}
