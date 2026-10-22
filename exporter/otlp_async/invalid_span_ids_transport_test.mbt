// The async exporters must also avoid a request when every span in the batch
// has malformed live IDs and the encoder therefore produces no body.

///|
fn malformed_id_span() -> @sdk.SpanData {
  {
    ..test_span_data(),
    name: "otlp-async-malformed-ids",
    span_context: @api.span_context([7], [9], @api.TRACE_FLAGS_SAMPLED),
  }
}

///|
async test "async exporter skips the request when every span has malformed ids" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    let requests : Ref[Int32] = Ref(0)
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_request, _body, conn) => {
        requests.val = requests.val + 1
        conn.send_response(200, "OK")
      })
    }
    let config = @otlp.OtlpHttpConfig::new(endpoint="http://127.0.0.1:\{port}")
    let result = @otlp_async.export_spans(config, [malformed_id_span()])
    assert_true(result.is_success())
    let exporter = @otlp_async.OtlpHttpAsyncExporter::new(config)
    let batch_result = exporter.export_batch([malformed_id_span()])
    assert_true(batch_result.is_success())
    // Give a wrongly issued request a chance to reach the server before
    // checking that none was sent.
    @async.sleep(50)
    assert_eq(requests.val, 0)
  }
}
