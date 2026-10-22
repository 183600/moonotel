// `@async_runtime.setup` layers its explicit `headers` argument over the
// standard OTLP header environment variables, exactly like the synchronous
// facade `setup`. This is an end-to-end check through the real HTTP transport.

///|
async test "async setup merges programmatic and environment headers" {
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_HEADERS",
    "async-env-only=1,async-shared=environment",
  )
  @env.set_env_var(
    "OTEL_EXPORTER_OTLP_TRACES_HEADERS",
    "async-signal-only=2,async-shared=signal",
  )
  defer {
    @env.unset_env_var("OTEL_EXPORTER_OTLP_HEADERS")
    @env.unset_env_var("OTEL_EXPORTER_OTLP_TRACES_HEADERS")
  }
  @async.with_task_group() <| outer => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let seen : Ref[Map[String, String]?] = Ref(None)
    outer.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, body, connection) => {
        let _ = body.read_all()
        let headers : Map[String, String] = Map([])
        for name, value in request.headers {
          headers.set(name.to_string(), value)
        }
        seen.val = Some(headers)
        connection.send_response(200, "OK")
      })
    }
    @async.with_task_group() <| group => {
      let provider = @async_runtime.setup(
        group,
        service_name="async-header-merge",
        endpoint="http://127.0.0.1:\{port}",
        headers=Map([
          ("Async-Shared", "programmatic"),
          ("async-programmatic", "3"),
        ]),
        install_global=false,
      )
      provider.get_tracer("async-header-merge").start_root_span("op").end()
      let mut waited = 0
      while seen.val is None && waited < 5000 {
        @async.sleep(20)
        waited = waited + 20
      }
      assert_true(seen.val is Some(_))
      let headers = seen.val.unwrap()
      assert_eq(headers.get("async-env-only"), Some("1"))
      assert_eq(headers.get("async-signal-only"), Some("2"))
      assert_eq(headers.get("Async-Shared"), Some("programmatic"))
      assert_eq(headers.get("async-shared"), None)
      assert_eq(headers.get("async-programmatic"), Some("3"))
    }
  }
}
