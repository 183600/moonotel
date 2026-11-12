# MoonBit OpenTelemetry Tracing MVP 设计

> 文档定位：README 面向使用者，本文档面向维护者，记录项目目标、分层设计、
> 关键取舍、测试策略与后续里程碑。文中的路径和包名按当前仓库结构书写；若
> 与源码或 README 不一致，以源码和 README 为准。

## 1. 目标与范围

本项目提供一个可集成、可测试、尽量贴近 OpenTelemetry 规范的 **Tracing
MVP**，重点覆盖一条完整的链路：业务代码创建 span，SDK 采样与处理，W3C
上下文传播，OTLP/HTTP 导出，以及 `moonbitlang/async/http` 的自动埋点。

- **模块与入口**：模块名为 `183600/moonotel`，根包作为 facade，使用
  `@moonotel` 导入。
- **协议范围**：Tracing；使用 W3C Trace Context 与 Baggage 传播，使用
  OTLP/HTTP 导出 protobuf 或 JSON。
- **运行目标**：纯 API、Context、Propagation、SDK 和同步 OTLP 编码器面向
  所有目标；真实 HTTP 传输、async runtime 和 HTTP 埋点面向 native+wasm。
- **集成方式**：既可以直接使用 SDK，也可以通过 facade 的 `setup` 或
  `@async_runtime.setup` 完成一次性初始化。

非目标：

- 不实现完整的 Metrics、Logs SDK；
- 不实现 gRPC 传输；
- 不尝试拦截用户直接调用的任意 `TaskGroup::spawn_bg`；
- 不追求与所有语言 SDK 的 `TraceIdRatioBased` 逐位一致。

## 2. 分层架构

| 层 | 包 | 职责 |
| --- | --- | --- |
| API | `api/` | `SpanContext`、`SpanKind`、`StatusCode` 等纯数据与校验 |
| Context | `context/` | 不可变 `Context`、baggage、当前上下文存储 |
| Propagation | `propagation/` | W3C `traceparent` / `tracestate`、`baggage`、carrier 与全局 propagator |
| SDK | `sdk/` | provider、tracer、span、采样、ID 生成、processor、resource、环境配置 |
| Async runtime | `async_runtime/` | 后台 flush、context-aware spawn、异步 OTLP `setup` |
| Export | `exporter/otlp/` | OTLP 编码、响应解析、可注入 transport 的同步导出 |
| Export | `exporter/otlp_async/` | 基于 `moonbitlang/async/http` 的生产传输、重试、超时、gzip |
| Instrumentation | `instrumentation/async_http_server/` | 服务端 `run_server` 包装与请求 span |
| Instrumentation | `instrumentation/async_http_client/` | 客户端请求 helper 与请求 span |
| Instrumentation | `instrumentation/http_header_capture/` | 请求/响应 header 捕获与脱敏 |
| Facade | 根包 `otel.mbt` | 常用类型 re-export、全局 provider、`setup` |

设计约束：

- API 层不引入网络或异步依赖，便于在任意目标上复用。
- Context 与 SDK 解耦；SDK 只消费 `Context` 提供的当前 span 与 baggage。
- Exporter 与传输分离。同步 exporter 接受注入的 `Transport`，便于测试和替换；
  异步 exporter 单独承载真实网络行为。
- Instrumentation 只依赖公开 API/SDK，不把 HTTP 细节反向带进核心包。
- 平台相关能力集中在 `async_runtime`、`exporter/otlp_async` 和 HTTP 埋点包中。

## 3. 目录结构

```text
183600/moonotel/
  moon.mod
  moon.pkg
  otel.mbt                     # facade、setup、全局 provider
  api/
    span_context.mbt
    span_kind.mbt
    status.mbt
  context/
    context.mbt                # 不可变 Context 与 baggage
    context_storage.mbt        # 当前上下文存储
  propagation/
    w3c_trace_context.mbt
    tracestate.mbt
    baggage.mbt
    text_map_carrier.mbt
    propagator.mbt
    context_propagation.mbt
  sdk/
    tracer_provider.mbt
    tracer.mbt
    span.mbt
    sampler.mbt
    id_generator.mbt
    span_limits.mbt
    span_processor.mbt
    simple_span_processor.mbt
    batch_span_processor.mbt
    batch_config.mbt
    resource.mbt
    semconv.mbt
    env_parse.mbt
  async_runtime/
    runtime.mbt                # spawn、flush loop、异步 setup
    exporter.mbt
  exporter/
    otlp/
      otlp_exporter.mbt        # 配置、重试、transport 抽象
      encoder.mbt              # protobuf 编码
      json_encoder.mbt
      response_decoder.mbt
      json_response_decoder.mbt
      protobuf_writer.mbt
      utf8_encode.mbt
    otlp_async/
      client.mbt               # 真实 HTTP 传输、Retry-After、gzip
  instrumentation/
    async_http_server/
    async_http_client/
    http_header_capture/
  examples/
    demo_server/
    demo_client/
    demo_otlp/
  scripts/
    check-hygiene.sh
```

每个 package 自带 `moon.pkg`，测试文件与被测包放在同一目录。示例与测试不是
公开 API 的一部分，但需要在 CI 中持续编译和运行。

## 4. Context 与传播

### 4.1 不可变 Context

`Context` 是一条不可变链，保存父链、当前 `SpanContext` 以及 baggage 更新。
所有修改操作返回新的 `Context`，已有引用不会看到后续变化。显式传递
`Context` 永远是最可靠的传播方式。

```moonbit
let root = @context.root()
let parent = root.with_span(span.context())
@context.with_context(parent, fn() {
  // 这里创建的 span 默认以 parent 为父
})
```

ambient 上下文默认存放在一个进程级槽位中，适合同步单流代码。并发任务如果
交错执行 `attach` / `detach`，必须显式传递 `Context`，或通过
`@context.set_context_storage` 安装与运行时匹配的存储实现。

`attach` 返回旧上下文，`detach` 恢复它；`with_context` 在作用域结束时自动
恢复。SDK 的 `start_span_with_context` 会从传入的 `Context` 或当前上下文
推导父 span。

Baggage 语义：

- 空更新（`with_baggage(Map([]))` 或 `without_baggage()`）隐藏外层上下文中的
  全部值，同时保留之后新增的值；
- 空名称按 OpenTelemetry Baggage API 的要求忽略；
- 一次非空更新如果名称全部无效，则上下文保持不变；
- W3C baggage 属性通过 `BaggageEntry` 携带，与传播包中的 header 类型区分。

### 4.2 跨任务传播

`async_runtime` 提供 `spawn`、`spawn_bg` 和 `spawn_flush_loop`：前两者在子
任务入口安装捕获的 `Context`，退出时恢复；后者周期性调用 batch processor 的
`tick()`，并在任务组退出时 `force_flush()`。这套机制只覆盖通过 helper
创建的任务，不拦截任意 `TaskGroup::spawn_bg` 调用。

### 4.3 W3C Trace Context 与 Baggage

- header 名称大小写不敏感；重复的 `tracestate` / `baggage` 按 HTTP 字段规则
  合并；重复的 `traceparent` 视为歧义并忽略。
- `traceparent` 按规范校验版本、长度、全零 ID 与字段；version `00` 要求
  小写 hex，未来版本接受大小写混合。
- 随机 trace ID 生成器设置 W3C Level 2 random 标志，子 span 继承父标志。
- `tracestate` 保持 512 字符以内的推荐上限，超限时按整项丢弃，先删超过
  128 字符的项，再从右侧删除。
- 复用 carrier 时，如果新上下文没有有效 span 或可见 baggage，注入逻辑会清除
  旧的对应 header，避免旧 trace 或旧 baggage 泄漏。
- baggage 解析与格式化限制为 64 个成员和 8192 字节，超出部分整项丢弃。

## 5. SDK 设计

### 5.1 SpanContext 与 ID

`SpanContext` 在构造时记录有效性。ID 视图按只读契约暴露；如果底层数组被外部
缩短或清零，消费方会把上下文视为无效：

- 创建子 span 时改为新 root；
- 无属性的 link 被丢弃，有属性或 tracestate 的 link 保留；
- 不写出全零 `traceparent`；
- 复制型访问器和 hex 访问器把异常长度的 ID 显示为全零 ID。

OTLP 编码器在导出时再次检查 live ID，避免把已失效的 span 序列化成畸形
`traceId` / `spanId`。

### 5.2 采样

SDK 提供 `always_on`、`always_off`、`record_only`、`trace_id_ratio_based`
与 `parent_based(root)`。默认策略是 `parent_based(always_on)`。

- 采样决策分为 `DROP`、`RECORD_ONLY`、`RECORD_AND_SAMPLE`。
- ratio sampler 使用 trace ID 最右侧 8 字节做确定性阈值比较，避免时间戳等
  前缀影响结果。
- `TraceIdRatioBased` 的具体算法并非规范统一，跨语言不保证逐位一致。
- `always_record(root)` 将原本会 DROP 的 span 提升为 RECORD_ONLY，让本地
  processor 仍能看到数据，但不向外导出。

### 5.3 记录型 span

`SpanSdk` 负责属性、事件、link、状态和异常记录：

- 空属性键直接忽略，不计入 dropped 计数；
- 属性、事件、link 数量与属性值长度受 `SpanLimits` 约束；
- 超出限制时增加对应的 dropped 计数；
- `end()` 之后访问器仍返回快照；
- HTTP 埋点和 `Tracer::with_span` 使用统一的异常记录语义：`exception` 事件、
  `error.type` 属性与 `Error` 状态；已经设置为 `Ok` 的状态不会被覆盖。

### 5.4 Processor

`SpanProcessor` 定义 `on_start`、`on_end`、`shutdown`、`force_flush` 生命周期。

- `SimpleSpanProcessor` 在 span end 时立即导出，适合示例和测试。
- `BatchSpanProcessor` 使用有界队列；`on_end` 只入队，导出失败单独计数。
- 有效导出批大小不超过队列大小，因此同步 processor 通常在批次满时立即导出。
- 队列溢出是防御路径：覆盖最旧的 span 并计入 `dropped_spans()`。
- 同步导出发生在结束 span 的线程或 `tick()` 的调用者上；异步场景由
  `async_runtime` 的后台 flush 循环承担。
- 定时 flush 依赖 `tick()` 或 span 完成触发，安静的应用需要主动调用
  `tick()`，或使用 async runtime helper。

`TracerProviderSdk` 管理 processor 列表和每个 processor 的 shutdown 状态。
provider 的 `with_*` 方法返回副本，避免修改已共享的 provider。关闭 provider
时先 drain batch processor，再关闭 exporter，保证正在结束的 span 不丢失。

### 5.5 全局 provider 与 setup

facade 提供进程级 provider 的安装、获取、强制 flush 和关闭。`setup` 负责从
环境与显式参数构造 resource、sampler、span limits、exporter 与 processor：

- 选择 OTLP 但未提供 transport 时，回退到 console exporter（除非已选择
  console），避免 span 静默丢失；
- 选择 `none` 时不安装 exporter；
- 显式 headers 按名称大小写不敏感地覆盖环境 headers，其余环境 headers 保留；
- `@async_runtime.setup` 接受同一组覆盖项，并把导出任务与 flush 绑定到传入的
  task group。

## 6. OTLP/HTTP 导出

### 6.1 编码与响应

OTLP 编码器为 protobuf 和 JSON 各自实现，响应解析器分别处理二进制和 JSON
响应。编码时按 resource、scope、span 分组，写入 ID、时间、属性、事件、link、
状态和 flags；JSON 响应解析支持 `partial_success`。导出前的 live ID 校验
会跳过结构已损坏的 span，link 只丢弃损坏的 ID 字段。

### 6.2 配置

- `OTEL_EXPORTER_OTLP_ENDPOINT` 作为 base URL，自动追加 `/v1/traces`；
  已包含 `/v1/traces` 的值不再重复追加。
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` 优先级更高；其值原样使用，但没有 path
  部分时按 OTLP/HTTP 规范发送到根路径 `/`。
- `OTEL_EXPORTER_OTLP_PROTOCOL` 支持 `http/protobuf` 与 `http/json`。
- `OTEL_EXPORTER_OTLP_COMPRESSION` 支持 `none` 与 `gzip`；同步 exporter 拒绝
  gzip，异步 exporter 实现压缩。
- headers、timeout、service name 以及 signal-specific 变量按 OpenTelemetry
  约定读取，signal-specific 变量优先。
- 程序化配置与直接组装公开字段的配置使用同一套归一化逻辑：空白 endpoint 视为
  未设置，空白 protocol/compression 回退到默认值，负数 timeout/retries 有明确
  含义。

### 6.3 请求、重试与超时

- 请求设置 `Content-Type`、`Accept` 和默认 `User-Agent`；用户提供的
  `User-Agent` 优先。
- header 在发送前校验名称和值；`Content-Length`、`Transfer-Encoding` 等
  framing header 由传输层管理，不从配置转发。
- HTTP 200 不重试，但 `partial_success` 作为导出失败上报。
- 可重试状态码为 429/502/503/504；传输失败同样可重试。
- 异步 exporter 支持 `Retry-After`（delta-seconds、HTTP-date、RFC 850、
  asctime，最多 60 秒），否则使用带 jitter 的指数退避（100ms 起，翻倍至
  5 秒上限）。
- 异步 timeout 是覆盖所有尝试和等待的总预算；同步 exporter 由注入的
  transport 负责 deadline。
- 其他 4xx/5xx（包括 500）是终止性失败。

### 6.4 生命周期

exporter 是单次使用的 sink。`OtlpHttpExporter` 在 `shutdown()` 后拒绝所有批次
（包括空批次）；异步 span exporter 关闭队列。shutdown 开始后不再派发
`on_start` / `on_end`，包括在回调内部触发 shutdown 的重入场景。

## 7. HTTP 埋点

HTTP 埋点面向 native+wasm，默认 wasm-gc 目标跳过相关函数体。没有 tracer 时，
wrapper 直接转发请求，不改变调用方行为。

服务端 `run_server` 为每个请求提取父上下文，创建 `Server` span，记录方法、路径、
查询串、服务端地址、客户端地址等属性，并在 handler 执行期间安装上下文。
`set_route` 更新 `http.route` 与 span 名称；`respond` 记录状态码并把 5xx 标为
`Error`；handler 异常记录后重新抛出。`start_span` 显式以该请求 span 为父，
适配并发连接。

客户端 helper 创建 `Client` span，注入当前 trace context 与 baggage，记录方法、
URL、服务端地址/端口和响应状态，并把 4xx/5xx 标为 `Error`。只有带显式 scheme
和 authority 的 URL 才贡献 `server.address` / `server.port`。

URL 会移除 userinfo，并对 HTTP 语义约定列出的敏感查询参数做值脱敏。header
捕获默认关闭，通过 `OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_*` 开启；
捕获值可再通过 sanitize 列表替换为 `[REDACTED]`。通配符会扩大捕获范围，使用前
应确认 `Authorization`、`Cookie` 等值是否可以记录或已经脱敏。

## 8. 测试与 CI

测试分层：

- **单元测试**：每个 package 内的 `*_test.mbt`，覆盖正常路径、边界、错误输入与
  环境变量隔离。
- **白盒测试**：native 相关逻辑使用 `*_wbtest.mbt`，依赖内部实现细节。
- **不变量测试**：编码器、解析器和响应解码器的 fuzz/invariant 测试。
- **facade 完整性**：根包的 re-export、setup、propagator、sampler 和 resource
  通过独立测试校验。
- **文档示例**：`sdk/readme_usage_test.mbt` 保证 README 的 Getting started
  用法可编译并产生预期 span。

提交前运行：

```sh
moon check
moon test
moon check --target native
moon test --target native
bash scripts/check-hygiene.sh
```

CI 同时运行默认与 native 目标，确保 async 埋点和 exporter 不只是被声明，而是
真正编译和测试过。hygiene 脚本阻止临时探针文件与脚手架占位符进入仓库。

## 9. 里程碑

以下阶段用于估算和拆分工作；每一项都应以测试和示例可运行作为完成标准。

1. **核心契约**：`SpanContext`、`Context`、`Tracer`/`Span` API、W3C
   `traceparent` 注入与提取。
2. **SDK 基础**：provider、recording span、sampler、Simple/Batch processor、
   resource、span limits。
3. **导出链路**：protobuf/JSON 编码、响应解析、同步 transport、异步 OTLP
   transport、重试与超时。
4. **自动埋点**：async HTTP server/client、header 捕获、demo server/client。
5. **工程化收尾**：环境变量覆盖、facade setup、native/wasm 检查、CI、文档与
   发布准备。

参考节奏（可按团队规模调整）：

| 周次 | 交付物 |
| --- | --- |
| 1-2 | API、Context、W3C 传播与单元测试 |
| 3-4 | SDK span、sampler、processor |
| 3-5 | OTLP 编码器、配置与 HTTP 导出 |
| 6-7 | Batch/async flush、HTTP 自动埋点与示例 |
| 8 | 文档、CI、发布检查与 v0.1.0 准备 |

## 10. 风险与取舍

- **上下文无法自动传播到所有任务**：以显式 `Context` 为主，辅以
  `async_runtime` 的 context-aware spawn 和 HTTP 埋点，覆盖最常见的请求链路。
- **MoonBit 与 async 生态仍在演进**：平台相关代码集中在少数包中，核心 API
  保持无 I/O、无运行时依赖。
- **protobuf 生成链可能不稳定**：编码器采用仓库内实现并配套响应解析和契约测试，
  避免把生成器变成用户安装依赖。
- **同步与异步导出能力不同**：gzip 和总超时只在异步 exporter 中保证；同步
  exporter 明确拒绝不支持的压缩，避免发送与 header 不一致的 body。
- **batch 队列必须有界**：溢出时覆盖最旧 span 并记录 dropped 计数，优先保证
  调用方延迟可预测。
- **ambient context 的并发限制**：默认存储只适合同步单流；并发场景显式传
  `Context` 或安装 task-aware storage。

## 11. 验收标准

- `examples/demo_server`、`examples/demo_client` 和 `examples/demo_otlp` 可编译
  并演示完整链路。
- W3C 传播与主流实现互通：合法 header 可提取，非法 header 被安全忽略。
- 导出的 OTLP 请求可被标准 Collector 接收，protobuf 与 JSON 路径都有测试覆盖。
- 无 tracer、无 exporter、空批次、关闭后导出、损坏 ID 等边界情况不会 panic。
- 默认与 native 目标均通过 `moon check` / `moon test`，hygiene 检查通过。
- README 的环境变量、默认值与实际行为一致。
