// Tests for the span-specific parameters exposed to custom samplers.

///|
test "custom sampler sees name kind attributes and links" {
  let seen_name : Ref[String] = Ref("")
  let seen_kind : Ref[@api.SpanKind?] = Ref(None)
  let seen_route : Ref[String?] = Ref(None)
  let seen_links : Ref[Int] = Ref(0)
  let sampler = @sdk.Sampler::new("ParameterSampler", fn(parameters) {
    seen_name.val = parameters.name
    seen_kind.val = Some(parameters.kind)
    seen_route.val = match parameters.attributes.get("http.route") {
      Some(@sdk.StringValue(route)) => Some(route)
      _ => None
    }
    seen_links.val = parameters.links.length()
    @sdk.sampling_decision_record_and_sample()
  })
  let provider = @sdk.TracerProviderSdk::new(service_name="sampler-parameters").with_sampler(
    sampler,
  )
  let tracer = provider.get_tracer("sampler-parameters")
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("http.route", @sdk.StringValue("/health"))
  let link = @sdk.SpanLink::new(
    @api.span_context(
      Array::make(16, 7),
      Array::make(8, 8),
      @api.TRACE_FLAGS_SAMPLED,
    ),
  )
  let span = tracer.start_span(
    "GET /health",
    kind=@api.SpanKind::Server,
    attributes=attributes,
    links=[link],
  )
  assert_eq(seen_name.val, "GET /health")
  assert_eq(seen_kind.val, Some(@api.SpanKind::Server))
  assert_eq(seen_route.val, Some("/health"))
  assert_eq(seen_links.val, 1)
  assert_true(span.is_recording())
  span.end()
}

///|
test "custom sampler decision controls recording and sampling" {
  let sampler = @sdk.Sampler::new("DropHealthSampler", fn(parameters) {
    if parameters.attributes.contains("health.check") {
      @sdk.sampling_decision_drop()
    } else {
      @sdk.sampling_decision_record_and_sample()
    }
  })
  let provider = @sdk.TracerProviderSdk::new(service_name="drop-health").with_sampler(
    sampler,
  )
  let tracer = provider.get_tracer("drop-health")
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("health.check", @sdk.BoolValue(true))
  let span = tracer.start_span("health", attributes=attributes)
  assert_false(span.is_recording())
  assert_false(span.context().is_sampled())
  span.end()
}

///|
test "should_sample supplies empty span-specific parameters" {
  let name : Ref[String?] = Ref(None)
  let kind : Ref[@api.SpanKind?] = Ref(None)
  let attribute_count : Ref[Int] = Ref(-1)
  let link_count : Ref[Int] = Ref(-1)
  let sampler = @sdk.Sampler::new("LegacySampler", fn(parameters) {
    name.val = Some(parameters.name)
    kind.val = Some(parameters.kind)
    attribute_count.val = parameters.attributes.length()
    link_count.val = parameters.links.length()
    @sdk.sampling_decision_record_and_sample()
  })
  let trace_id = Array::make(16, 1)
  let decision = sampler.should_sample(None, trace_id)
  assert_true(decision.is_sampled)
  assert_eq(name.val, Some(""))
  assert_eq(kind.val, Some(@api.SpanKind::Internal))
  assert_eq(attribute_count.val, 0)
  assert_eq(link_count.val, 0)
}

///|
test "parent_based forwards parameters to the selected delegate" {
  let root_name : Ref[String?] = Ref(None)
  let sampled_name : Ref[String?] = Ref(None)
  let root = @sdk.Sampler::new("Root", fn(parameters) {
    root_name.val = Some(parameters.name)
    @sdk.sampling_decision_record_and_sample()
  })
  let sampled = @sdk.Sampler::new("Sampled", fn(parameters) {
    sampled_name.val = Some(parameters.name)
    @sdk.sampling_decision_record_only()
  })
  let sampler = @sdk.Sampler::parent_based(
    root,
    remote_parent_sampled=sampled,
  )
  let parameters : @sdk.SamplingParameters = {
    parent: None,
    trace_id: Array::make(16, 2),
    name: "root-span",
    kind: @api.SpanKind::Internal,
    attributes: Map([]),
    links: [],
  }
  assert_true(sampler.should_sample_parameters(parameters).is_sampled)
  assert_eq(root_name.val, Some("root-span"))
  let remote = @api.span_context(
    Array::make(16, 3),
    Array::make(8, 4),
    @api.TRACE_FLAGS_SAMPLED,
    is_remote=true,
  )
  let child_decision = sampler.should_sample_parameters({
    ..parameters,
    parent: Some(remote),
    name: "child-span",
  })
  assert_true(child_decision.is_recorded)
  assert_false(child_decision.is_sampled)
  assert_eq(sampled_name.val, Some("child-span"))
}
