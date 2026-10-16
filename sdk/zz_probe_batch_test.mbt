struct ProbeExporter {
  names : Array[String]
}

pub impl @sdk.SpanExporter for ProbeExporter with export_spans(self, spans) {
  for data in spans {
    self.names.push(data.name)
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for ProbeExporter with shutdown(self) {
  let _ = self
}

fn probe_span(name : String) -> @sdk.SpanData {
  {
    name,
    span_context: @api.span_context(
      @api.bytes_from_hex("4bf92f359d1e75b7618a2d1f3c4e5a6b").unwrap(),
      @api.bytes_from_hex("00f067aa0ba902b7").unwrap(),
      1,
    ),
    parent_span_id: [],
    kind: @api.SpanKind::Internal,
    start_time_unix_nano: 1L,
    end_time_unix_nano: 2L,
    attributes: Map::new(),
    events: [],
    status: @api.StatusCode::Unset,
    status_description: "",
    resource: Map::new(),
    scope_name: "scope",
    scope_version: "",
  }
}

fn probe_names_equal(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

test "probe_batch_queue_matches_model" {
  let exporter : ProbeExporter = { names: [] }
  let max_queue = 3
  let batch_size = 2
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=max_queue,
    max_export_batch_size=batch_size,
  )
  let model_queue : Array[String] = []
  let model_exported : Array[String] = []
  for i = 0; i < 12; i = i + 1 {
    let name = "s" + i.to_string()
    processor.on_end(probe_span(name))
    model_queue.push(name)
    while model_queue.length() > max_queue {
      let _ = model_queue.remove(0)
    }
    if model_queue.length() >= batch_size {
      let mut taken = 0
      while taken < batch_size && model_queue.length() > 0 {
        model_exported.push(model_queue.remove(0))
        taken = taken + 1
      }
    }
    assert_eq(processor.queue_size(), model_queue.length())
    assert_true(probe_names_equal(exporter.names, model_exported))
  }
  processor.force_flush()
  while model_queue.length() > 0 {
    model_exported.push(model_queue.remove(0))
  }
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, model_exported))
}

test "probe_batch_queue_larger_batch_matches_model" {
  let exporter : ProbeExporter = { names: [] }
  let max_queue = 5
  let batch_size = 7
  let processor = @sdk.BatchSpanProcessor::new(
    exporter,
    max_queue_size=max_queue,
    max_export_batch_size=batch_size,
  )
  let model_queue : Array[String] = []
  let model_exported : Array[String] = []
  for i = 0; i < 12; i = i + 1 {
    let name = "t" + i.to_string()
    processor.on_end(probe_span(name))
    model_queue.push(name)
    while model_queue.length() > max_queue {
      let _ = model_queue.remove(0)
    }
    if model_queue.length() >= batch_size {
      let mut taken = 0
      while taken < batch_size && model_queue.length() > 0 {
        model_exported.push(model_queue.remove(0))
        taken = taken + 1
      }
    }
    assert_eq(processor.queue_size(), model_queue.length())
    assert_true(probe_names_equal(exporter.names, model_exported))
  }
  processor.force_flush()
  while model_queue.length() > 0 {
    model_exported.push(model_queue.remove(0))
  }
  assert_eq(processor.queue_size(), 0)
  assert_true(probe_names_equal(exporter.names, model_exported))
}
