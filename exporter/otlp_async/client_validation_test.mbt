// Configuration validation in the async OTLP exporter happens before any
// network request is attempted. Empty batches are a no-op success.

///|
fn validation_span_data() -> @sdk.SpanData {
  {
    name: "validation",
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      @api.TRACE_FLAGS_SAMPLED,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map([], capacity=1),
    events: [],
    links: [],
    dropped_attributes_count: 0,
    dropped_events_count: 0,
    dropped_links_count: 0,
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: @sdk.ResourceAttributes::new(Map([], capacity=1)),
    scope_name: "validation",
    scope_version: "",
  }
}

///|
async test "async_export_batch_rejects_unsupported_protocol_and_compression" {
  let bad_protocol = @otlp_async.OtlpHttpAsyncExporter::new(
    @otlp.OtlpHttpConfig::new(protocol="grpc"),
  )
  match bad_protocol.export_batch([validation_span_data()]) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP protocol"))
    @sdk.ExportSuccess => fail("expected an unsupported-protocol failure")
  }
  let bad_compression = @otlp_async.OtlpHttpAsyncExporter::new(
    @otlp.OtlpHttpConfig::new(compression="deflate"),
  )
  match bad_compression.export_batch([validation_span_data()]) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP compression"))
    @sdk.ExportSuccess => fail("expected an unsupported-compression failure")
  }
}

///|
async test "async_exports_treat_an_empty_batch_as_success" {
  let bad_config = @otlp.OtlpHttpConfig::new(protocol="grpc")
  let exporter = @otlp_async.OtlpHttpAsyncExporter::new(bad_config)
  assert_true(exporter.export_batch([]).is_success())
  // `export_spans` short-circuits an empty batch before validating the config,
  // so even an otherwise unusable protocol cannot fail a no-op export.
  assert_true(@otlp_async.export_spans(bad_config, []).is_success())
}

///|
async test "post_trace_request_validates_protocol_and_compression_first" {
  match @otlp_async.post_trace_request(
    @otlp.OtlpHttpConfig::new(protocol="grpc"),
    b"",
  ) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP protocol"))
    @sdk.ExportSuccess => fail("expected an unsupported-protocol failure")
  }
  match @otlp_async.post_trace_request(
    @otlp.OtlpHttpConfig::new(compression="deflate"),
    b"",
  ) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP compression"))
    @sdk.ExportSuccess => fail("expected an unsupported-compression failure")
  }
}

///|
async test "all_malformed_batches_still_validate_the_configuration" {
  // Encoding an all-malformed batch yields no request body. That short-circuit
  // must not hide an unusable protocol or compression setting: those are
  // configuration errors and must be reported exactly like a normal export.
  let malformed = [{
    ..validation_span_data(),
    span_context: @api.span_context([7], [9], @api.TRACE_FLAGS_SAMPLED),
  }]
  match @otlp_async.export_spans(
    @otlp.OtlpHttpConfig::new(protocol="grpc"),
    malformed,
  ) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP protocol"))
    @sdk.ExportSuccess => fail("expected an unsupported-protocol failure")
  }
  match @otlp_async.export_spans(
    @otlp.OtlpHttpConfig::new(compression="deflate"),
    malformed,
  ) {
    @sdk.ExportFailure(message) =>
      assert_true(message.contains("unsupported OTLP compression"))
    @sdk.ExportSuccess => fail("expected an unsupported-compression failure")
  }
}
