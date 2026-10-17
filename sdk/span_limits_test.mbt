// Tests for span collection limits: attribute/event/link counts, per
// event/link attribute counts, value length truncation, the dropped-item
// counters carried into SpanData, and the OTEL_SPAN_* environment variables.

struct LimitsExporter {
  spans : Array[@sdk.SpanData]
}

pub impl @sdk.SpanExporter for LimitsExporter with export_spans(self, spans) {
  for data in spans {
    self.spans.push(data)
  }
  @sdk.ExportSuccess
}

pub impl @sdk.SpanExporter for LimitsExporter with shutdown(self) {
  let _ = self
}

fn limits_provider(
  exporter : &@sdk.SpanExporter,
  limits : @sdk.SpanLimits
) -> @sdk.TracerProviderSdk {
  @sdk.TracerProviderSdk::new(service_name="limits")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_limits(limits)
    .with_span_processor(@sdk.SimpleSpanProcessor::new(exporter))
}

fn limit_test_span(limits : @sdk.SpanLimits) -> @sdk.SpanSdk {
  let exporter : LimitsExporter = { spans: [], }
  let tracer = limits_provider(exporter, limits).get_tracer("limits")
  tracer.start_root_span("op")
}

fn valid_context(seed : Int) -> @api.SpanContext {
  @api.span_context(Array::make(16, seed + 1), Array::make(8, seed + 1), 1)
}

fn clear_limit_env() -> Unit {
  let names = [
    "OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_SPAN_EVENT_COUNT_LIMIT",
    "OTEL_SPAN_LINK_COUNT_LIMIT",
    "OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_LINK_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT",
    "OTEL_ATTRIBUTE_COUNT_LIMIT",
    "OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT",
  ]
  for name in names {
    @env.unset_env_var(name)
  }
}

test "span_limits_defaults_match_the_specification" {
  let limits = @sdk.SpanLimits::new()
  assert_eq(limits.attribute_count_limit(), 128)
  assert_eq(limits.event_count_limit(), 128)
  assert_eq(limits.link_count_limit(), 128)
  assert_eq(limits.event_attribute_count_limit(), 128)
  assert_eq(limits.link_attribute_count_limit(), 128)
  assert_eq(limits.attribute_value_length_limit(), -1)
}

test "span_limits_unlimited_drops_nothing" {
  let limits = @sdk.SpanLimits::unlimited()
  let span = limit_test_span(limits)
  for i = 0; i < 300; i = i + 1 {
    span.set_attribute("k" + i.to_string(), @sdk.StringValue("v"))
    span.add_event("e" + i.to_string())
    span.add_link(@sdk.SpanLink::new(valid_context(i)))
  }
  assert_eq(span.attributes().length(), 300)
  assert_eq(span.events().length(), 300)
  assert_eq(span.links().length(), 300)
  assert_eq(span.dropped_attributes_count(), 0)
  assert_eq(span.dropped_events_count(), 0)
  assert_eq(span.dropped_links_count(), 0)
}

test "attributes_beyond_the_default_limit_are_dropped_and_counted" {
  let span = limit_test_span(@sdk.SpanLimits::new())
  for i = 0; i < 130; i = i + 1 {
    span.set_attribute("k" + i.to_string(), @sdk.StringValue("v"))
  }
  assert_eq(span.attributes().length(), 128)
  assert_eq(span.dropped_attributes_count(), 2)
  span.end()
}

test "overwriting_an_attribute_does_not_count_against_the_limit" {
  let span = limit_test_span(@sdk.SpanLimits::new(attribute_count_limit=2))
  span.set_attribute("a", @sdk.StringValue("1"))
  span.set_attribute("b", @sdk.StringValue("2"))
  span.set_attribute("a", @sdk.StringValue("3"))
  span.set_attribute("c", @sdk.StringValue("4"))
  assert_eq(span.attributes().length(), 2)
  assert_eq(span.attributes().get("a"), Some(@sdk.StringValue("3")))
  assert_eq(span.dropped_attributes_count(), 1)
}

test "set_attributes_respects_the_attribute_count_limit" {
  let span = limit_test_span(@sdk.SpanLimits::new(attribute_count_limit=3))
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  for i = 0; i < 10; i = i + 1 {
    attributes.set("k" + i.to_string(), @sdk.IntValue(i.to_int64()))
  }
  span.set_attributes(attributes)
  assert_eq(span.attributes().length(), 3)
  assert_eq(span.dropped_attributes_count(), 7)
}

test "zero_attribute_count_limit_drops_every_attribute" {
  let span = limit_test_span(@sdk.SpanLimits::new(attribute_count_limit=0))
  span.set_attribute("a", @sdk.StringValue("1"))
  assert_eq(span.attributes().length(), 0)
  assert_eq(span.dropped_attributes_count(), 1)
}

test "events_beyond_the_limit_are_dropped_and_counted" {
  let span = limit_test_span(@sdk.SpanLimits::new(event_count_limit=5))
  for i = 0; i < 8; i = i + 1 {
    span.add_event("e" + i.to_string())
  }
  assert_eq(span.events().length(), 5)
  assert_eq(span.dropped_events_count(), 3)
  assert_eq(span.events()[0].name, "e0")
  assert_eq(span.events()[4].name, "e4")
}

test "event_attributes_beyond_the_limit_are_dropped_and_counted_on_the_event" {
  let span = limit_test_span(@sdk.SpanLimits::new(event_attribute_count_limit=2))
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  for i = 0; i < 5; i = i + 1 {
    attributes.set("k" + i.to_string(), @sdk.StringValue("v"))
  }
  span.add_event("ev", attributes=attributes)
  assert_eq(span.events().length(), 1)
  assert_eq(span.events()[0].attributes.length(), 2)
  assert_eq(span.events()[0].dropped_attributes_count, 3)
  assert_eq(span.dropped_events_count(), 0)
}

test "links_beyond_the_limit_are_dropped_and_counted" {
  let span = limit_test_span(@sdk.SpanLimits::new(link_count_limit=4))
  for i = 0; i < 10; i = i + 1 {
    span.add_link(@sdk.SpanLink::new(valid_context(i)))
  }
  assert_eq(span.links().length(), 4)
  assert_eq(span.dropped_links_count(), 6)
}

test "links_at_span_creation_are_subject_to_the_limit" {
  let exporter : LimitsExporter = { spans: [], }
  let provider = limits_provider(
    exporter,
    @sdk.SpanLimits::new(link_count_limit=3),
  )
  let tracer = provider.get_tracer("limits")
  let links : Array[@sdk.SpanLink] = []
  for i = 0; i < 6; i = i + 1 {
    links.push(@sdk.SpanLink::new(valid_context(i)))
  }
  let span = tracer.start_span("op", links=links)
  assert_eq(span.links().length(), 3)
  assert_eq(span.dropped_links_count(), 3)
}

test "invalid_links_are_ignored_without_counting_as_dropped" {
  let span = limit_test_span(@sdk.SpanLimits::new(link_count_limit=3))
  span.add_link(@sdk.SpanLink::new(@api.invalid_span_context()))
  assert_eq(span.links().length(), 0)
  assert_eq(span.dropped_links_count(), 0)
}

test "link_attributes_beyond_the_limit_are_dropped_and_counted_on_the_link" {
  let span = limit_test_span(@sdk.SpanLimits::new(link_attribute_count_limit=1))
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("a", @sdk.StringValue("1"))
  attributes.set("b", @sdk.StringValue("2"))
  span.add_link(@sdk.SpanLink::new(valid_context(1), attributes=attributes))
  assert_eq(span.links().length(), 1)
  assert_eq(span.links()[0].attributes.length(), 1)
  assert_eq(span.links()[0].dropped_attributes_count, 1)
}

test "attribute_value_length_limit_truncates_strings" {
  let span = limit_test_span(
    @sdk.SpanLimits::new(attribute_value_length_limit=3),
  )
  span.set_attribute("s", @sdk.StringValue("abcdef"))
  span.set_attribute("arr", @sdk.StringArrayValue(["abcdef", "xy"]))
  span.set_attribute("i", @sdk.IntValue(123456L))
  assert_eq(span.attributes().get("s"), Some(@sdk.StringValue("abc")))
  assert_eq(
    span.attributes().get("arr"),
    Some(@sdk.StringArrayValue(["abc", "xy"])),
  )
  assert_eq(span.attributes().get("i"), Some(@sdk.IntValue(123456L)))
}

test "attribute_value_length_limit_never_splits_a_surrogate_pair" {
  let span = limit_test_span(
    @sdk.SpanLimits::new(attribute_value_length_limit=3),
  )
  span.set_attribute("emoji", @sdk.StringValue("ab😀c"))
  assert_eq(span.attributes().get("emoji"), Some(@sdk.StringValue("ab😀")))
}

test "zero_attribute_value_length_limit_produces_empty_strings" {
  let span = limit_test_span(
    @sdk.SpanLimits::new(attribute_value_length_limit=0),
  )
  span.set_attribute("s", @sdk.StringValue("abc"))
  assert_eq(span.attributes().get("s"), Some(@sdk.StringValue("")))
}

test "value_length_limit_applies_to_event_and_link_attributes" {
  let span = limit_test_span(
    @sdk.SpanLimits::new(attribute_value_length_limit=2),
  )
  let attributes : Map[String, @sdk.AttributeValue] = Map([])
  attributes.set("k", @sdk.StringValue("abcdef"))
  span.add_event("ev", attributes=attributes)
  span.add_link(@sdk.SpanLink::new(valid_context(1), attributes=attributes))
  assert_eq(span.events()[0].attributes.get("k"), Some(@sdk.StringValue("ab")))
  assert_eq(span.links()[0].attributes.get("k"), Some(@sdk.StringValue("ab")))
}

test "span_data_carries_the_dropped_counts_to_exporters" {
  let exporter : LimitsExporter = { spans: [], }
  let provider = limits_provider(
    exporter,
    @sdk.SpanLimits::new(
      attribute_count_limit=1,
      event_count_limit=1,
      link_count_limit=1,
    ),
  )
  let tracer = provider.get_tracer("limits")
  let span = tracer.start_root_span("op")
  span.set_attribute("a", @sdk.StringValue("1"))
  span.set_attribute("b", @sdk.StringValue("2"))
  span.add_event("e1")
  span.add_event("e2")
  span.add_link(@sdk.SpanLink::new(valid_context(1)))
  span.add_link(@sdk.SpanLink::new(valid_context(2)))
  span.end()
  assert_eq(exporter.spans.length(), 1)
  let data = exporter.spans[0]
  assert_eq(data.attributes.length(), 1)
  assert_eq(data.events.length(), 1)
  assert_eq(data.links.length(), 1)
  assert_eq(data.dropped_attributes_count, 1)
  assert_eq(data.dropped_events_count, 1)
  assert_eq(data.dropped_links_count, 1)
}

test "span_limits_from_env_reads_the_standard_variables" {
  clear_limit_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "5")
  @env.set_env_var("OTEL_SPAN_EVENT_COUNT_LIMIT", "6")
  @env.set_env_var("OTEL_SPAN_LINK_COUNT_LIMIT", "7")
  @env.set_env_var("OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT", "8")
  @env.set_env_var("OTEL_LINK_ATTRIBUTE_COUNT_LIMIT", "9")
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "10")
  let limits = @sdk.SpanLimits::from_env()
  clear_limit_env()
  assert_eq(limits.attribute_count_limit(), 5)
  assert_eq(limits.event_count_limit(), 6)
  assert_eq(limits.link_count_limit(), 7)
  assert_eq(limits.event_attribute_count_limit(), 8)
  assert_eq(limits.link_attribute_count_limit(), 9)
  assert_eq(limits.attribute_value_length_limit(), 10)
}

test "span_limits_from_env_ignores_malformed_values" {
  clear_limit_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "-3")
  @env.set_env_var("OTEL_SPAN_EVENT_COUNT_LIMIT", "abc")
  @env.set_env_var("OTEL_SPAN_LINK_COUNT_LIMIT", "")
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "  ")
  let limits = @sdk.SpanLimits::from_env()
  clear_limit_env()
  assert_eq(limits.attribute_count_limit(), 128)
  assert_eq(limits.event_count_limit(), 128)
  assert_eq(limits.link_count_limit(), 128)
  assert_eq(limits.attribute_value_length_limit(), -1)
}

test "span_specific_variables_take_precedence_over_generic_ones" {
  clear_limit_env()
  @env.set_env_var("OTEL_ATTRIBUTE_COUNT_LIMIT", "9")
  @env.set_env_var("OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT", "11")
  let generic = @sdk.SpanLimits::from_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "3")
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "4")
  let specific = @sdk.SpanLimits::from_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "")
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", " ")
  let empty_specific = @sdk.SpanLimits::from_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "oops")
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT", "-1")
  let malformed_specific = @sdk.SpanLimits::from_env()
  clear_limit_env()
  assert_eq(generic.attribute_count_limit(), 9)
  assert_eq(generic.attribute_value_length_limit(), 11)
  assert_eq(specific.attribute_count_limit(), 3)
  assert_eq(specific.attribute_value_length_limit(), 4)
  assert_eq(empty_specific.attribute_count_limit(), 9)
  assert_eq(empty_specific.attribute_value_length_limit(), 11)
  assert_eq(malformed_specific.attribute_count_limit(), 9)
  assert_eq(malformed_specific.attribute_value_length_limit(), 11)
}

test "provider_reads_span_limits_from_the_environment_by_default" {
  clear_limit_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "2")
  let provider = @sdk.TracerProviderSdk::new(service_name="env-limits")
    .with_sampler(@sdk.Sampler::always_on())
  clear_limit_env()
  assert_eq(provider.span_limits().attribute_count_limit(), 2)
  let span = provider.get_tracer("env-limits").start_root_span("op")
  span.set_attribute("a", @sdk.StringValue("1"))
  span.set_attribute("b", @sdk.StringValue("2"))
  span.set_attribute("c", @sdk.StringValue("3"))
  assert_eq(span.attributes().length(), 2)
  assert_eq(span.dropped_attributes_count(), 1)
}

test "explicit_span_limits_override_the_environment" {
  clear_limit_env()
  @env.set_env_var("OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT", "2")
  let provider = @sdk.TracerProviderSdk::new(service_name="env-limits")
    .with_sampler(@sdk.Sampler::always_on())
    .with_span_limits(@sdk.SpanLimits::new(attribute_count_limit=4))
  clear_limit_env()
  let span = provider.get_tracer("env-limits").start_root_span("op")
  for i = 0; i < 6; i = i + 1 {
    span.set_attribute("k" + i.to_string(), @sdk.StringValue("v"))
  }
  assert_eq(span.attributes().length(), 4)
  assert_eq(span.dropped_attributes_count(), 2)
}
