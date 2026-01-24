// Distributed tracing scenario tests - simulating complex real-world distributed systems

test "cross_service_trace_propagation" {
  // Simulate trace propagation across multiple services
  let trace_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10]
  
  let gateway_span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let auth_span_id = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18]
  let user_span_id = [0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28]
  
  let gateway_ctx = span_context(trace_id, gateway_span_id, 1)
  let auth_ctx = span_context(trace_id, auth_span_id, 1)
  let user_ctx = span_context(trace_id, user_span_id, 1)
  
  assert_true(gateway_ctx.is_valid())
  assert_true(auth_ctx.is_valid())
  assert_true(user_ctx.is_valid())
  
  assert_eq(gateway_ctx.trace_id_hex(), auth_ctx.trace_id_hex())
  assert_eq(auth_ctx.trace_id_hex(), user_ctx.trace_id_hex())
  
  assert_false(gateway_ctx.span_id_hex() == auth_ctx.span_id_hex())
  assert_false(auth_ctx.span_id_hex() == user_ctx.span_id_hex())
}

test "async_job_tracing" {
  // Simulate tracing of async job processing
  let job_trace_id = [0x4a, 0x4f, 0x42, 0x20, 0x54, 0x52, 0x41, 0x43, 0x45, 0x20, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36]
  
  let submit_span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let process_span_id = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18]
  let complete_span_id = [0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28]
  
  let submit_ctx = span_context(job_trace_id, submit_span_id, 1)
  let process_ctx = span_context(job_trace_id, process_span_id, 1)
  let complete_ctx = span_context(job_trace_id, complete_span_id, 1)
  
  assert_true(submit_ctx.is_sampled())
  assert_true(process_ctx.is_sampled())
  assert_true(complete_ctx.is_sampled())
}

test "batch_request_tracing" {
  // Simulate batch request with multiple operations
  let batch_trace_id = [0x42, 0x41, 0x54, 0x43, 0x48, 0x20, 0x52, 0x45, 0x51, 0x55, 0x45, 0x53, 0x54, 0x20, 0x31, 0x32]
  
  let mut batch_spans = []
  let mut i = 0
  while i < 10 {
    let span_id = [i, i+1, i+2, i+3, i+4, i+5, i+6, i+7]
    let ctx = span_context(batch_trace_id, span_id, 1)
    batch_spans = batch_spans + [ctx]
    i = i + 1
  }
  
  assert_eq(batch_spans.length(), 10)
  
  let mut all_valid = true
  let mut i = 0
  while i < batch_spans.length() {
    let sc = batch_spans[i]
    if not(sc.is_valid()) {
      all_valid = false
    }
    i = i + 1
  }
  
  assert_true(all_valid)
}

test "circuit_breaker_tracing" {
  // Simulate circuit breaker state transitions
  let cb_trace_id = [0x43, 0x49, 0x52, 0x43, 0x55, 0x49, 0x54, 0x20, 0x42, 0x52, 0x45, 0x41, 0x4b, 0x45, 0x52, 0x20]
  
  let closed_span_id = [0x43, 0x4c, 0x4f, 0x53, 0x45, 0x44, 0x31, 0x32]
  let open_span_id = [0x4f, 0x50, 0x45, 0x4e, 0x31, 0x32, 0x33, 0x34]
  let half_open_span_id = [0x48, 0x41, 0x4c, 0x46, 0x31, 0x32, 0x33, 0x34]
  
  let closed_ctx = span_context(cb_trace_id, closed_span_id, 1)
  let open_ctx = span_context(cb_trace_id, open_span_id, 1)
  let half_open_ctx = span_context(cb_trace_id, half_open_span_id, 1)
  
  assert_true(closed_ctx.is_valid())
  assert_true(open_ctx.is_valid())
  assert_true(half_open_ctx.is_valid())
}

test "retry_mechanism_tracing" {
  // Simulate retry attempts with same trace ID
  let retry_trace_id = [0x52, 0x45, 0x54, 0x52, 0x59, 0x20, 0x41, 0x54, 0x54, 0x45, 0x4d, 0x50, 0x54, 0x20, 0x31, 0x32]
  
  let attempt1_span_id = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
  let attempt2_span_id = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18]
  let attempt3_span_id = [0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28]
  
  let attempt1_ctx = span_context(retry_trace_id, attempt1_span_id, 1)
  let attempt2_ctx = span_context(retry_trace_id, attempt2_span_id, 1)
  let attempt3_ctx = span_context(retry_trace_id, attempt3_span_id, 1)
  
  assert_eq(attempt1_ctx.trace_id_hex(), attempt2_ctx.trace_id_hex())
  assert_eq(attempt2_ctx.trace_id_hex(), attempt3_ctx.trace_id_hex())
  
  assert_false(attempt1_ctx.span_id_hex() == attempt2_ctx.span_id_hex())
  assert_false(attempt2_ctx.span_id_hex() == attempt3_ctx.span_id_hex())
}

test "fan_out_tracing" {
  // Simulate fan-out pattern (one request, multiple parallel operations)
  let fan_trace_id = [0x46, 0x41, 0x4e, 0x20, 0x4f, 0x55, 0x54, 0x20, 0x50, 0x41, 0x54, 0x54, 0x45, 0x52, 0x4e, 0x20]
  
  let parent_span_id = [0x50, 0x41, 0x52, 0x45, 0x4e, 0x54, 0x31, 0x32]
  
  let mut child_spans = []
  let mut i = 0
  while i < 5 {
    let child_span_id = [0x30 + i, 0x31 + i, 0x32 + i, 0x33 + i, 0x34 + i, 0x35 + i, 0x36 + i, 0x37 + i]
    let child_ctx = span_context(fan_trace_id, child_span_id, 1)
    child_spans = child_spans + [child_ctx]
    i = i + 1
  }
  
  assert_eq(child_spans.length(), 5)
  
  let mut all_sampled = true
  let mut i = 0
  while i < child_spans.length() {
    let ctx = child_spans[i]
    if not(ctx.is_sampled()) {
      all_sampled = false
    }
    i = i + 1
  }
  
  assert_true(all_sampled)
}

test "fan_in_tracing" {
  // Simulate fan-in pattern (multiple sources, one result)
  let fanin_trace_id = [0x46, 0x41, 0x4e, 0x20, 0x49, 0x4e, 0x20, 0x50, 0x41, 0x54, 0x54, 0x45, 0x52, 0x4e, 0x20, 0x20]
  
  let source1_span_id = [0x53, 0x31, 0x53, 0x50, 0x41, 0x4e, 0x31, 0x32]
  let source2_span_id = [0x53, 0x32, 0x53, 0x50, 0x41, 0x4e, 0x31, 0x32]
  let source3_span_id = [0x53, 0x33, 0x53, 0x50, 0x41, 0x4e, 0x31, 0x32]
  let result_span_id = [0x52, 0x45, 0x53, 0x55, 0x4c, 0x54, 0x31, 0x32]
  
  let s1_ctx = span_context(fanin_trace_id, source1_span_id, 1)
  let s2_ctx = span_context(fanin_trace_id, source2_span_id, 1)
  let s3_ctx = span_context(fanin_trace_id, source3_span_id, 1)
  let result_ctx = span_context(fanin_trace_id, result_span_id, 1)
  
  assert_true(s1_ctx.is_valid())
  assert_true(s2_ctx.is_valid())
  assert_true(s3_ctx.is_valid())
  assert_true(result_ctx.is_valid())
}

test "message_queue_tracing" {
  // Simulate message queue publishing and consumption
  let mq_trace_id = [0x4d, 0x45, 0x53, 0x53, 0x41, 0x47, 0x45, 0x51, 0x20, 0x54, 0x52, 0x41, 0x43, 0x45, 0x20, 0x20]
  
  let publish_span_id = [0x50, 0x55, 0x42, 0x4c, 0x49, 0x53, 0x48, 0x31]
  let consume1_span_id = [0x43, 0x4f, 0x4e, 0x53, 0x55, 0x4d, 0x45, 0x31]
  let consume2_span_id = [0x43, 0x4f, 0x4e, 0x53, 0x55, 0x4d, 0x45, 0x32]
  
  let publish_ctx = span_context(mq_trace_id, publish_span_id, 1)
  let consume1_ctx = span_context(mq_trace_id, consume1_span_id, 1)
  let consume2_ctx = span_context(mq_trace_id, consume2_span_id, 1)
  
  assert_eq(publish_ctx.trace_id_hex(), consume1_ctx.trace_id_hex())
  assert_eq(publish_ctx.trace_id_hex(), consume2_ctx.trace_id_hex())
}

test "graphql_resolver_tracing" {
  // Simulate GraphQL resolver tracing
  let gql_trace_id = [0x47, 0x52, 0x41, 0x50, 0x48, 0x51, 0x4c, 0x20, 0x51, 0x55, 0x45, 0x52, 0x59, 0x20, 0x20, 0x20]
  
  let query_span_id = [0x51, 0x55, 0x45, 0x52, 0x59, 0x20, 0x31, 0x32]
  let resolver1_span_id = [0x52, 0x45, 0x53, 0x31, 0x20, 0x20, 0x31, 0x32]
  let resolver2_span_id = [0x52, 0x45, 0x53, 0x32, 0x20, 0x20, 0x31, 0x32]
  
  let query_ctx = span_context(gql_trace_id, query_span_id, 1)
  let resolver1_ctx = span_context(gql_trace_id, resolver1_span_id, 1)
  let resolver2_ctx = span_context(gql_trace_id, resolver2_span_id, 1)
  
  assert_true(query_ctx.is_sampled())
  assert_true(resolver1_ctx.is_sampled())
  assert_true(resolver2_ctx.is_sampled())
}

test "event_sourcing_tracing" {
  // Simulate event sourcing pattern
  let es_trace_id = [0x45, 0x56, 0x45, 0x4e, 0x54, 0x20, 0x53, 0x4f, 0x55, 0x52, 0x43, 0x45, 0x20, 0x20, 0x20, 0x20]
  
  let event1_span_id = [0x45, 0x56, 0x45, 0x4e, 0x54, 0x31, 0x20, 0x20]
  let event2_span_id = [0x45, 0x56, 0x45, 0x4e, 0x54, 0x32, 0x20, 0x20]
  let event3_span_id = [0x45, 0x56, 0x45, 0x4e, 0x54, 0x33, 0x20, 0x20]
  
  let event1_ctx = span_context(es_trace_id, event1_span_id, 1)
  let event2_ctx = span_context(es_trace_id, event2_span_id, 1)
  let event3_ctx = span_context(es_trace_id, event3_span_id, 1)
  
  assert_true(event1_ctx.is_valid())
  assert_true(event2_ctx.is_valid())
  assert_true(event3_ctx.is_valid())
}

test "rate_limiting_tracing" {
  // Simulate rate limiting scenario
  let rl_trace_id = [0x52, 0x41, 0x54, 0x45, 0x20, 0x4c, 0x49, 0x4d, 0x49, 0x54, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let allow_span_id = [0x41, 0x4c, 0x4c, 0x4f, 0x57, 0x20, 0x31, 0x32]
  let deny_span_id = [0x44, 0x45, 0x4e, 0x59, 0x20, 0x31, 0x32, 0x33]
  
  let allow_ctx = span_context(rl_trace_id, allow_span_id, 1)
  let deny_ctx = span_context(rl_trace_id, deny_span_id, 0)
  
  assert_true(allow_ctx.is_sampled())
  assert_false(deny_ctx.is_sampled())
}

test "distributed_transaction_tracing" {
  // Simulate distributed transaction (two-phase commit)
  let tx_trace_id = [0x54, 0x58, 0x20, 0x43, 0x4f, 0x4d, 0x4d, 0x49, 0x54, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let begin_span_id = [0x42, 0x45, 0x47, 0x49, 0x4e, 0x20, 0x31, 0x32]
  let prepare1_span_id = [0x50, 0x52, 0x45, 0x50, 0x31, 0x20, 0x20, 0x20]
  let prepare2_span_id = [0x50, 0x52, 0x45, 0x50, 0x32, 0x20, 0x20, 0x20]
  let commit_span_id = [0x43, 0x4f, 0x4d, 0x4d, 0x49, 0x54, 0x20, 0x20]
  
  let begin_ctx = span_context(tx_trace_id, begin_span_id, 1)
  let prepare1_ctx = span_context(tx_trace_id, prepare1_span_id, 1)
  let prepare2_ctx = span_context(tx_trace_id, prepare2_span_id, 1)
  let commit_ctx = span_context(tx_trace_id, commit_span_id, 1)
  
  assert_eq(begin_ctx.trace_id_hex(), prepare1_ctx.trace_id_hex())
  assert_eq(prepare1_ctx.trace_id_hex(), commit_ctx.trace_id_hex())
}

test "api_versioning_tracing" {
  // Simulate API version handling
  let v1_trace_id = [0x41, 0x50, 0x49, 0x20, 0x56, 0x31, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  let v2_trace_id = [0x41, 0x50, 0x49, 0x20, 0x56, 0x32, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let v1_span_id = [0x56, 0x31, 0x52, 0x45, 0x51, 0x20, 0x31, 0x32]
  let v2_span_id = [0x56, 0x32, 0x52, 0x45, 0x51, 0x20, 0x31, 0x32]
  
  let v1_ctx = span_context(v1_trace_id, v1_span_id, 1)
  let v2_ctx = span_context(v2_trace_id, v2_span_id, 1)
  
  assert_false(v1_ctx.trace_id_hex() == v2_ctx.trace_id_hex())
  assert_true(v1_ctx.is_valid())
  assert_true(v2_ctx.is_valid())
}

test "webhook_delivery_tracing" {
  // Simulate webhook delivery and callback
  let webhook_trace_id = [0x57, 0x45, 0x42, 0x48, 0x4f, 0x4f, 0x4b, 0x20, 0x44, 0x45, 0x4c, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let delivery_span_id = [0x44, 0x45, 0x4c, 0x49, 0x56, 0x45, 0x52, 0x31]
  let callback_span_id = [0x43, 0x41, 0x4c, 0x4c, 0x42, 0x41, 0x43, 0x4b]
  
  let delivery_ctx = span_context(webhook_trace_id, delivery_span_id, 1)
  let callback_ctx = span_context(webhook_trace_id, callback_span_id, 1)
  
  assert_eq(delivery_ctx.trace_id_hex(), callback_ctx.trace_id_hex())
  assert_false(delivery_ctx.span_id_hex() == callback_ctx.span_id_hex())
}

test "health_check_tracing" {
  // Simulate health check requests (often not sampled)
  let health_trace_id = [0x48, 0x45, 0x41, 0x4c, 0x54, 0x48, 0x20, 0x43, 0x48, 0x45, 0x43, 0x4b, 0x20, 0x20, 0x20, 0x20]
  
  let health_span_id = [0x48, 0x45, 0x41, 0x4c, 0x54, 0x48, 0x59, 0x20]
  
  let health_ctx = span_context(health_trace_id, health_span_id, 0)
  
  assert_true(health_ctx.is_valid())
  assert_false(health_ctx.is_sampled())
}

test "background_worker_tracing" {
  // Simulate background worker processing
  let worker_trace_id = [0x57, 0x4f, 0x52, 0x4b, 0x45, 0x52, 0x20, 0x4a, 0x4f, 0x42, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let job1_span_id = [0x4a, 0x4f, 0x42, 0x31, 0x20, 0x20, 0x20, 0x20]
  let job2_span_id = [0x4a, 0x4f, 0x42, 0x32, 0x20, 0x20, 0x20, 0x20]
  let job3_span_id = [0x4a, 0x4f, 0x42, 0x33, 0x20, 0x20, 0x20, 0x20]
  
  let job1_ctx = span_context(worker_trace_id, job1_span_id, 1)
  let job2_ctx = span_context(worker_trace_id, job2_span_id, 1)
  let job3_ctx = span_context(worker_trace_id, job3_span_id, 1)
  
  assert_eq(job1_ctx.trace_id_hex(), job2_ctx.trace_id_hex())
  assert_eq(job2_ctx.trace_id_hex(), job3_ctx.trace_id_hex())
}

test "cache_invalidation_tracing" {
  // Simulate cache invalidation cascade
  let cache_trace_id = [0x43, 0x41, 0x43, 0x48, 0x45, 0x20, 0x49, 0x4e, 0x56, 0x41, 0x4c, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let invalidate_span_id = [0x49, 0x4e, 0x56, 0x41, 0x4c, 0x49, 0x44, 0x31]
  let refresh1_span_id = [0x52, 0x45, 0x46, 0x52, 0x45, 0x53, 0x48, 0x31]
  let refresh2_span_id = [0x52, 0x45, 0x46, 0x52, 0x45, 0x53, 0x48, 0x32]
  
  let invalidate_ctx = span_context(cache_trace_id, invalidate_span_id, 1)
  let refresh1_ctx = span_context(cache_trace_id, refresh1_span_id, 1)
  let refresh2_ctx = span_context(cache_trace_id, refresh2_span_id, 1)
  
  assert_true(invalidate_ctx.is_valid())
  assert_true(refresh1_ctx.is_valid())
  assert_true(refresh2_ctx.is_valid())
}

test "streaming_processing_tracing" {
  // Simulate data stream processing
  let stream_trace_id = [0x53, 0x54, 0x52, 0x45, 0x41, 0x4d, 0x20, 0x44, 0x41, 0x54, 0x41, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let source_span_id = [0x53, 0x4f, 0x55, 0x52, 0x43, 0x45, 0x20, 0x20]
  let process_span_id = [0x50, 0x52, 0x4f, 0x43, 0x45, 0x53, 0x53, 0x20]
  let sink_span_id = [0x53, 0x49, 0x4e, 0x4b, 0x20, 0x20, 0x20, 0x20]
  
  let source_ctx = span_context(stream_trace_id, source_span_id, 1)
  let process_ctx = span_context(stream_trace_id, process_span_id, 1)
  let sink_ctx = span_context(stream_trace_id, sink_span_id, 1)
  
  assert_eq(source_ctx.trace_id_hex(), sink_ctx.trace_id_hex())
  assert_true(source_ctx.is_sampled())
  assert_true(process_ctx.is_sampled())
  assert_true(sink_ctx.is_sampled())
}

test "microservices_mashup_tracing" {
  // Simulate multiple microservices combined
  let mash_trace_id = [0x4d, 0x41, 0x53, 0x48, 0x55, 0x50, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let services = ["SVC1", "SVC2", "SVC3", "SVC4", "SVC5"]
  let mut service_ctxs = []
  let mut i = 0
  while i < services.length() {
    let svc_bytes = string_to_bytes(services[i])
    let span_id = pad_to_8(svc_bytes)
    let ctx = span_context(mash_trace_id, span_id, 1)
    service_ctxs = service_ctxs + [ctx]
    i = i + 1
  }
  
  assert_eq(service_ctxs.length(), 5)
  
  let mut all_valid = true
  let mut i = 0
  while i < service_ctxs.length() {
    if not(service_ctxs[i].is_valid()) {
      all_valid = false
    }
    i = i + 1
  }
  
  assert_true(all_valid)
}

test "trace_parent_child_relationships" {
  // Test that trace context maintains parent-child relationships
  let trace_id = [0x50, 0x41, 0x52, 0x45, 0x4e, 0x54, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let parent_span_id = [0x50, 0x41, 0x52, 0x45, 0x4e, 0x54, 0x20, 0x20]
  let child1_span_id = [0x43, 0x48, 0x49, 0x4c, 0x44, 0x31, 0x20, 0x20]
  let child2_span_id = [0x43, 0x48, 0x49, 0x4c, 0x44, 0x32, 0x20, 0x20]
  
  let parent_ctx = span_context(trace_id, parent_span_id, 1)
  let child1_ctx = span_context(trace_id, child1_span_id, 1)
  let child2_ctx = span_context(trace_id, child2_span_id, 1)
  
  // All share same trace ID
  assert_eq(parent_ctx.trace_id_hex(), child1_ctx.trace_id_hex())
  assert_eq(parent_ctx.trace_id_hex(), child2_ctx.trace_id_hex())
  
  // All have unique span IDs
  assert_false(parent_ctx.span_id_hex() == child1_ctx.span_id_hex())
  assert_false(parent_ctx.span_id_hex() == child2_ctx.span_id_hex())
  assert_false(child1_ctx.span_id_hex() == child2_ctx.span_id_hex())
}

test "multi_region_tracing" {
  // Simulate cross-region request tracing
  let region_trace_id = [0x52, 0x45, 0x47, 0x49, 0x4f, 0x4e, 0x20, 0x52, 0x45, 0x51, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let us_east_span_id = [0x55, 0x53, 0x45, 0x20, 0x20, 0x20, 0x20, 0x20]
  let eu_west_span_id = [0x45, 0x55, 0x57, 0x20, 0x20, 0x20, 0x20, 0x20]
  let ap_south_span_id = [0x41, 0x50, 0x53, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let us_east_ctx = span_context(region_trace_id, us_east_span_id, 1)
  let eu_west_ctx = span_context(region_trace_id, eu_west_span_id, 1)
  let ap_south_ctx = span_context(region_trace_id, ap_south_span_id, 1)
  
  assert_eq(us_east_ctx.trace_id_hex(), eu_west_ctx.trace_id_hex())
  assert_eq(eu_west_ctx.trace_id_hex(), ap_south_ctx.trace_id_hex())
}

test "long_running_operation_tracing" {
  // Simulate long-running operation with checkpoints
  let long_trace_id = [0x4c, 0x4f, 0x4e, 0x47, 0x20, 0x4f, 0x50, 0x20, 0x54, 0x52, 0x41, 0x43, 0x45, 0x20, 0x20, 0x20]
  
  let start_span_id = [0x53, 0x54, 0x41, 0x52, 0x54, 0x20, 0x20, 0x20]
  let cp1_span_id = [0x43, 0x48, 0x4b, 0x50, 0x54, 0x31, 0x20, 0x20]
  let cp2_span_id = [0x43, 0x48, 0x4b, 0x50, 0x54, 0x32, 0x20, 0x20]
  let complete_span_id = [0x44, 0x4f, 0x4e, 0x45, 0x20, 0x20, 0x20, 0x20]
  
  let start_ctx = span_context(long_trace_id, start_span_id, 1)
  let cp1_ctx = span_context(long_trace_id, cp1_span_id, 1)
  let cp2_ctx = span_context(long_trace_id, cp2_span_id, 1)
  let complete_ctx = span_context(long_trace_id, complete_span_id, 1)
  
  assert_true(start_ctx.is_valid())
  assert_true(cp1_ctx.is_valid())
  assert_true(cp2_ctx.is_valid())
  assert_true(complete_ctx.is_valid())
}

test "sampling_propagation_across_services" {
  // Test that sampling decisions propagate correctly
  let trace_id = [0x53, 0x41, 0x4d, 0x50, 0x4c, 0x20, 0x54, 0x52, 0x41, 0x43, 0x45, 0x20, 0x20, 0x20, 0x20, 0x20]
  
  let sampled_span_id = [0x53, 0x41, 0x4d, 0x50, 0x4c, 0x45, 0x44, 0x31]
  let unsampled_span_id = [0x55, 0x4e, 0x53, 0x41, 0x4d, 0x50, 0x4c, 0x31]
  
  let sampled_ctx = span_context(trace_id, sampled_span_id, 1)
  let unsampled_ctx = span_context(trace_id, unsampled_span_id, 0)
  
  assert_true(sampled_ctx.is_sampled())
  assert_false(unsampled_ctx.is_sampled())
}

test "trace_flags_edge_cases" {
  // Test various trace flag values
  let trace_id = [0x46, 0x4c, 0x41, 0x47, 0x53, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]
  let span_id = [0x53, 0x50, 0x41, 0x4e, 0x20, 0x20, 0x20, 0x20]
  
  let flags0 = span_context(trace_id, span_id, 0)
  let flags1 = span_context(trace_id, span_id, 1)
  let flags2 = span_context(trace_id, span_id, 2)
  let flags255 = span_context(trace_id, span_id, 255)
  
  assert_false(flags0.is_sampled())
  assert_true(flags1.is_sampled())
  assert_false(flags2.is_sampled())
  assert_true(flags255.is_sampled())
}

// Helper functions
fn string_to_bytes(s : String) -> Array[Int] {
  let chars = s.to_array()
  let mut bytes = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    bytes = bytes + [char_to_int(c)]
    i = i + 1
  }
  bytes
}

fn char_to_int(c : Char) -> Int {
  c.to_int()
}

fn pad_to_8(bytes : Array[Int]) -> Array[Int] {
  let mut result = bytes
  while result.length() < 8 {
    result = result + [32]
  }
  result
}
