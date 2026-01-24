// Integration tests for SpanContext with real-world scenarios

test "web_request_trace_scenario" {
  // Simulate a web request trace from gateway to service
  let gateway_trace_id = [72, 69, 76, 76, 79, 32, 87, 79, 82, 76, 68, 32, 87, 79, 82, 76]
  let gateway_span_id = [71, 65, 84, 69, 87, 65, 89, 95]
  let gateway_context = span_context(gateway_trace_id, gateway_span_id, 1)
  
  assert_true(gateway_context.is_valid())
  assert_true(gateway_context.is_sampled())
  assert_eq(gateway_context.trace_id_hex(), "48454c4c4f20574f524c4420574f524c")
  assert_eq(gateway_context.span_id_hex(), "474154455741595f")
}

test "microservice_chain_trace" {
  // Simulate trace across multiple microservices
  let service_names = ["AUTH", "USER", "PAY", "NOTIF", "LOG"]
  let service_count = service_names.length()
  
  let mut trace_chains = []
  let mut base_trace = 100
  let mut i = 0
  while i < service_count {
    let trace_id = [base_trace, base_trace+1, base_trace+2, base_trace+3, base_trace+4, base_trace+5, base_trace+6, base_trace+7, base_trace+8, base_trace+9, base_trace+10, base_trace+11, base_trace+12, base_trace+13, base_trace+14, base_trace+15]
    let span_id = [base_trace+16, base_trace+17, base_trace+18, base_trace+19, base_trace+20, base_trace+21, base_trace+22, base_trace+23]
    let flags = if i == 0 { 1 } else { 3 }
    let sc = span_context(trace_id, span_id, flags)
    trace_chains = trace_chains + [sc]
    base_trace = base_trace + 32
    i = i + 1
  }
  
  assert_eq(trace_chains.length(), 5)
  
  let mut all_valid = true
  let mut i = 0
  while i < trace_chains.length() {
    let sc = trace_chains[i]
    if not(sc.is_valid()) {
      all_valid = false
    }
    i = i + 1
  }
  
  assert_true(all_valid)
}

test "database_operation_trace" {
  // Simulate database query tracing
  let db_trace_id = [68, 66, 32, 81, 85, 69, 82, 89, 32, 83, 69, 76, 69, 67, 84, 32]
  let query_span_id = [81, 85, 69, 82, 89, 49, 50, 51]
  let select_span_id = [83, 69, 76, 69, 67, 84, 49, 50]
  
  let query_context = span_context(db_trace_id, query_span_id, 1)
  let select_context = span_context(db_trace_id, select_span_id, 1)
  
  assert_true(query_context.is_valid())
  assert_true(select_context.is_valid())
  assert_eq(query_context.trace_id_hex(), select_context.trace_id_hex())
  assert_false(query_context.span_id_hex() == select_context.span_id_hex())
}

test "api_gateway_scenario" {
  // Simulate API Gateway handling multiple requests
  let gateway_id = [71, 87, 65, 89, 32, 49, 50, 51]
  let requests = ["GET /users", "POST /orders", "DELETE /cache", "PUT /profile"]
  let mut handled_requests = []
  
  let mut request_id = 200
  let mut i = 0
  while i < requests.length() {
    let trace_id = [request_id, request_id+1, request_id+2, request_id+3, request_id+4, request_id+5, request_id+6, request_id+7, request_id+8, request_id+9, request_id+10, request_id+11, request_id+12, request_id+13, request_id+14, request_id+15]
    let span_id = [request_id+16, request_id+17, request_id+18, request_id+19, request_id+20, request_id+21, request_id+22, request_id+23]
    let sc = span_context(trace_id, span_id, 1)
    handled_requests = handled_requests + [(requests[i], sc)]
    request_id = request_id + 32
    i = i + 1
  }
  
  assert_eq(handled_requests.length(), 4)
  
  // Verify all contexts are valid
  let mut all_valid = true
  let mut i = 0
  while i < handled_requests.length() {
    let (_, sc) = handled_requests[i]
    if not(sc.is_valid()) {
      all_valid = false
    }
    i = i + 1
  }
  
  assert_true(all_valid)
}

test "cache_layer_trace" {
  // Simulate cache hit/miss scenarios
  let cache_trace_id = [67, 65, 67, 72, 69, 32, 72, 73, 84, 32, 77, 73, 83, 83, 32, 48]
  let hit_span_id = [72, 73, 84, 49, 50, 51, 52, 53]
  let miss_span_id = [77, 73, 83, 83, 49, 50, 51, 52]
  
  let hit_context = span_context(cache_trace_id, hit_span_id, 1)
  let miss_context = span_context(cache_trace_id, miss_span_id, 1)
  
  assert_true(hit_context.is_valid())
  assert_true(miss_context.is_valid())
  assert_eq(hit_context.trace_id_hex(), miss_context.trace_id_hex())
}

test "load_balancer_scenario" {
  // Simulate load balancer distributing requests
  let lb_trace_id = [76, 66, 32, 68, 73, 83, 84, 82, 73, 66, 85, 84, 69, 32, 82, 69]
  let backends = ["Backend1", "Backend2", "Backend3"]
  let mut backend_contexts = []
  
  let mut backend_id = 300
  let mut i = 0
  while i < backends.length() {
    let trace_id = [backend_id, backend_id+1, backend_id+2, backend_id+3, backend_id+4, backend_id+5, backend_id+6, backend_id+7, backend_id+8, backend_id+9, backend_id+10, backend_id+11, backend_id+12, backend_id+13, backend_id+14, backend_id+15]
    let span_id = [backend_id+16, backend_id+17, backend_id+18, backend_id+19, backend_id+20, backend_id+21, backend_id+22, backend_id+23]
    let sc = span_context(trace_id, span_id, i % 2)
    backend_contexts = backend_contexts + [(backends[i], sc)]
    backend_id = backend_id + 32
    i = i + 1
  }
  
  assert_eq(backend_contexts.length(), 3)
}

test "error_propagation_trace" {
  // Simulate error propagation through services
  let error_trace_id = [69, 82, 82, 79, 82, 32, 80, 82, 79, 80, 65, 71, 65, 84, 73, 79]
  let original_span_id = [79, 82, 73, 71, 49, 50, 51, 52]
  let propagated_span_id = [80, 82, 79, 80, 49, 50, 51, 52]
  
  let original_context = span_context(error_trace_id, original_span_id, 1)
  let propagated_context = span_context(error_trace_id, propagated_span_id, 1)
  
  assert_true(original_context.is_valid())
  assert_true(propagated_context.is_valid())
  assert_eq(original_context.trace_id_hex(), propagated_context.trace_id_hex())
  assert_true(original_context.is_sampled())
  assert_true(propagated_context.is_sampled())
}

test "batch_processing_trace" {
  // Simulate batch job processing multiple items
  let batch_trace_id = [66, 65, 84, 67, 72, 32, 80, 82, 79, 67, 69, 83, 83, 32, 74, 79]
  let mut batch_contexts = []
  
  let mut item_id = 400
  let mut i = 0
  while i < 10 {
    let trace_id = [item_id, item_id+1, item_id+2, item_id+3, item_id+4, item_id+5, item_id+6, item_id+7, item_id+8, item_id+9, item_id+10, item_id+11, item_id+12, item_id+13, item_id+14, item_id+15]
    let span_id = [item_id+16, item_id+17, item_id+18, item_id+19, item_id+20, item_id+21, item_id+22, item_id+23]
    let sc = span_context(trace_id, span_id, 1)
    batch_contexts = batch_contexts + [sc]
    item_id = item_id + 32
    i = i + 1
  }
  
  assert_eq(batch_contexts.length(), 10)
  
  // Verify all are valid and sampled
  let mut valid_count = 0
  let mut i = 0
  while i < batch_contexts.length() {
    let sc = batch_contexts[i]
    if sc.is_valid() && sc.is_sampled() {
      valid_count = valid_count + 1
    }
    i = i + 1
  }
  
  assert_eq(valid_count, 10)
}

test "real_world_trace_correlation" {
  // Simulate real-world trace correlation
  let user_session_trace = [85, 83, 69, 82, 32, 83, 69, 83, 83, 73, 79, 78, 32, 49, 50, 51]
  let request_span = [82, 69, 81, 85, 69, 83, 84, 49]
  let auth_span = [65, 85, 84, 72, 49, 50, 51, 52]
  let db_span = [68, 66, 81, 85, 69, 82, 89, 49]
  let cache_span = [67, 65, 67, 72, 69, 49, 50, 51]
  
  let request_context = span_context(user_session_trace, request_span, 1)
  let auth_context = span_context(user_session_trace, auth_span, 1)
  let db_context = span_context(user_session_trace, db_span, 1)
  let cache_context = span_context(user_session_trace, cache_span, 1)
  
  // All should share the same trace ID
  assert_eq(request_context.trace_id_hex(), auth_context.trace_id_hex())
  assert_eq(auth_context.trace_id_hex(), db_context.trace_id_hex())
  assert_eq(db_context.trace_id_hex(), cache_context.trace_id_hex())
  
  // All should be valid
  assert_true(request_context.is_valid())
  assert_true(auth_context.is_valid())
  assert_true(db_context.is_valid())
  assert_true(cache_context.is_valid())
  
  // All should be sampled
  assert_true(request_context.is_sampled())
  assert_true(auth_context.is_sampled())
  assert_true(db_context.is_sampled())
  assert_true(cache_context.is_sampled())
}

test "distributed_transaction_trace" {
  // Simulate distributed transaction across multiple databases
  let transaction_trace = [84, 82, 65, 78, 83, 65, 67, 84, 73, 79, 78, 32, 49, 50, 51, 52]
  let phase1_span = [80, 72, 65, 83, 69, 49, 49, 49]
  let phase2_span = [80, 72, 65, 83, 69, 50, 50, 50]
  let commit_span = [67, 79, 77, 77, 73, 84, 49, 49]
  let rollback_span = [82, 79, 76, 76, 66, 65, 67, 75]
  
  let phase1_context = span_context(transaction_trace, phase1_span, 1)
  let phase2_context = span_context(transaction_trace, phase2_span, 1)
  let commit_context = span_context(transaction_trace, commit_span, 1)
  let rollback_context = span_context(transaction_trace, rollback_span, 1)
  
  assert_true(phase1_context.is_valid())
  assert_true(phase2_context.is_valid())
  assert_true(commit_context.is_valid())
  assert_true(rollback_context.is_valid())
  
  // All should share trace ID for transaction correlation
  assert_eq(phase1_context.trace_id_hex(), phase2_context.trace_id_hex())
  assert_eq(phase2_context.trace_id_hex(), commit_context.trace_id_hex())
  assert_eq(commit_context.trace_id_hex(), rollback_context.trace_id_hex())
}