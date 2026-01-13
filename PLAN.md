下面给你一份**可以直接开干的“MoonBit OpenTelemetry Tracing + OTLP/HTTP exporter + async/http 自动埋点”项目实现方案**（按“两个人能做完、还能做得像样”来裁剪范围），目标是做出一个在生产里“能用、好用、好集成”的 **Tracing MVP**。

---

## 0. 项目定义（你要发布到 mooncakes 的“一个具体项目”）

**项目名（建议）：** `yourname/otel`（模块名），对外主入口包：`yourname/otel`  
**首发范围（MVP）：** Tracing（不做 Metrics/Logs 的完整 SDK，但预留接口）  
**导出协议：** **OTLP/HTTP + protobuf**（先不做 gRPC，原因：规范允许 SDK 只支持一种传输时优先 `http/protobuf`）   
**传播协议：** **W3C Trace Context**（`traceparent` / `tracestate`）   
**首发自动埋点：** `moonbitlang/async/http` 的 HTTP Client + Server（最能立刻产生生态影响）  
**多后端策略：** Native 先做到“很好用”，同时用 **virtual package** 给 JS/Wasm 留好替换点 

MoonBit 包发布结构上：一个模块 `moon.mod.json`，内部多个 package（每个 package 一个 `moon.pkg.json`），符合 MoonBit 官方的包管理/发布方式。

---

## 1) 总体架构（分层 + 你真正要写的包）

你要把项目拆成 4 层，避免以后返工：

### A. API 层（稳定、轻依赖）
对标 OTel Trace API：`TracerProvider / Tracer / Span / SpanContext / Context`  
- `yourname/otel/api`：只放接口与基本数据结构（**不做网络、不做 async**）
- `yourname/otel/context`：当前上下文管理（在 MoonBit 里要特别认真做）

OTel 规范里对 `SpanContext` 的要求：TraceId 16 bytes、SpanId 8 bytes、支持 hex/binary 取值、`IsValid` 等。

### B. SDK 层（可配置：采样、处理器、ID 生成）
- `yourname/otel/sdk`
  - `Sampler`（AlwaysOn/AlwaysOff/ParentBased+Ratio）
  - `IdGenerator`（随机 TraceId/SpanId）
  - `SpanProcessor`（Simple + Batch）
  - `TracerProviderSdk`（全局 provider，创建 tracer）

采样与 SpanProcessor 的关系、`IsRecording` / `Sampled` 的语义、内置 sampler 行为等，都在 SDK 规范里定义得很清楚。

### C. Exporter 层（OTLP/HTTP + protobuf）
- `yourname/otel/exporter/otlp_http`
  - OTLP 配置（endpoint、headers、compression、timeout）
  - OTLP TraceService 请求：HTTP POST 到 `/v1/traces`，body 是 `ExportTraceServiceRequest` protobuf 

OTLP proto 文件来源用官方仓库 `open-telemetry/opentelemetry-proto`（这是“正源”，别自己手写 proto）。

MoonBit 侧 protobuf 编码就用 `moonbitlang/protobuf`：社区实践里已经用 `@protobuf.Write::write(...)` 把消息写到 buffer 再输出。

### D. Instrumentation 层（让别人“一行启用”）
- `yourname/otel/instrumentation/async_http_client`
- `yourname/otel/instrumentation/async_http_server`

`moonbitlang/async/http` 已经有 HTTP client/server；`@http.run_server` 会为每个连接开 task 并并发处理。  
另外 async 库在 2025-12 的更新里明确提到 HTTP client/server API 的增强（代理、server callback 改进等），你做埋点能紧跟这些能力。

---

## 2) 目录结构（可以直接照抄开仓）

```text
yourname-otel/
  moon.mod.json

  otel/                       # 对外主入口：re-export 常用 API
    moon.pkg.json
    otel.mbt

  api/
    moon.pkg.json
    tracer_provider.mbt
    tracer.mbt
    span.mbt
    span_context.mbt
    attributes.mbt
    status.mbt

  context/
    moon.pkg.json
    context.mbt               # immutable Context
    context_storage.mbt       # 当前 coroutine 的 Context 管理

  propagation/
    moon.pkg.json
    w3c_trace_context.mbt     # traceparent/tracestate 注入/提取
    text_map_carrier.mbt      # 抽象 header 读写接口

  sdk/
    moon.pkg.json
    tracer_provider_sdk.mbt
    tracer_sdk.mbt
    span_sdk.mbt
    sampler.mbt
    id_generator.mbt
    span_processor.mbt
    batch_span_processor.mbt
    simple_span_processor.mbt
    resource.mbt              # service.name 等

  exporter/
    otlp_http/
      moon.pkg.json
      otlp_config.mbt
      exporter.mbt
      encoder_otlp.mbt        # SDK span -> OTLP proto model
      http_client.mbt         # 封装 @http.post 调用与重试

  proto/
    # 由 opentelemetry-proto 生成的 MoonBit 代码（建议 commit 进仓库）
    # e.g. opentelemetry/proto/collector/trace/v1/trace_service.mbt ...

  instrumentation/
    async_http_server/
      moon.pkg.json
      server.mbt              # run_server wrapper / request loop wrapper
    async_http_client/
      moon.pkg.json
      client.mbt              # get/post wrapper

  examples/
    demo_server/
      moon.pkg.json
      main.mbt

  tests/
    w3c_trace_context_test.mbt
    otlp_encoder_test.mbt
```

---

## 3) 关键难点 1：MoonBit 的“当前上下文”怎么做（最核心）

OTel 在语言 SDK 里通常有一个 “Context Storage”（thread-local / async-local）。MoonBit 的 async 运行时是 coroutine + structured concurrency。  
而 `moonbitlang/async` 内部能拿到当前 coroutine：`@coroutine.current_coroutine()`（TaskGroup 源码里就这么用）。

**因此建议你做一个：`Coroutine -> Context` 的映射表**，实现“每个 coroutine 一份当前 Context”。

### 3.1 Context 模型（不可变）
```moonbit
// context/context.mbt
struct Context {
  parent : Context?
  span_context : @otel_api.SpanContext?
  // 预留：baggage、任意 key/value
}

pub fn root() -> Context { ... }
pub fn with_span(self : Context, sc : @otel_api.SpanContext) -> Context { ... }
pub fn span_context(self : Context) -> @otel_api.SpanContext? { ... }
```

### 3.2 ContextStorage（可变：current/get/set）
```moonbit
// context/context_storage.mbt
// 全局表：Coroutine -> Ref[Context]
let table : Map[@coroutine.Coroutine, Ref[Context]] = ...

pub fn get_current() -> Context {
  let coro = @coroutine.current_coroutine()
  match table.get(coro) {
    Some(r) => r.val
    None => {
      let r = @ref.new(@Context.root())
      table.set(coro, r)
      r.val
    }
  }
}

// attach 返回 token（旧值），detach 恢复
pub fn attach(ctx : Context) -> Context {
  let old = get_current()
  set_current(ctx)
  old
}

pub fn detach(old : Context) -> Unit { set_current(old) }

pub fn with_context[X](ctx : Context, f : () -> X) -> X {
  let old = attach(ctx)
  defer detach(old)
  f()
}
```

### 3.3 “跨 task 传播”的策略（你做不到 100% 自动，但能做到 90% 实用）
因为用户可能直接用 `TaskGroup.spawn_bg`，你没法拦截它内部的 `@coroutine.spawn`。  
所以你要提供 **可选的“otel-aware spawn”**：

- `@otel_async.spawn_bg(group, f)`：捕获父 ctx，在子 task 一开始 `attach` 再执行 `f`
- `@otel_http.run_server(...)`：在每个连接 task 的入口就 attach（server side span）

这足以让“HTTP server/client + 业务 handler”这条链路天然能串起来（最关键）。

---

## 4) 关键难点 2：W3C Trace Context 的实现（traceparent/tracestate）

规范要求：Trace Context propagator 必须按 W3C Trace Context Level 2 解析/校验并传播 `traceparent` / `tracestate`。  
`traceparent` v00 的格式：`version-trace-id-parent-id-trace-flags`，trace-id 全 0 无效，parent-id 全 0 无效，非法要忽略。

你实现两个函数就够用：

- `inject(ctx, carrier)`：把当前 `SpanContext` 写入 header
- `extract(carrier) -> Context`：从 header 读，生成 remote `SpanContext`，返回 `Context.with_span(...)`

**工程建议：**
- 解析 `traceparent` 的时候，不要用正则（慢且难 debug）；用固定位置切片 + hex 校验。
- `tracestate` 第一版可以“原样透传字符串”，不做 key/value 解析（以后再补完整合规的增删改），因为 OTLP/SpanContext 里 tracestate 本身就是 string/list 概念。

---

## 5) 关键难点 3：Span SDK、采样、处理器（做对“性能与正确性”）

### 5.1 SpanContext 与采样位
SDK 里你要维护两个概念：  
- `Span.IsRecording`：是否记录 attributes/events（降低开销）  
- `TraceFlags.Sampled`：是否导出（并向下游传播）  

采样器按规范需要支持 `DROP / RECORD_ONLY / RECORD_AND_SAMPLE`。

**MVP sampler：**
- AlwaysOn：永远 RECORD_AND_SAMPLE   
- AlwaysOff：永远 DROP   
- ParentBased(root=AlwaysOn)：如果 parent sampled -> sampled，否则按 root 策略（MVP 先写死 root=AlwaysOn/Ratio）   
- TraceIdRatioBased(p)：用 traceId 的前 8 bytes 转成整数做阈值比较（跨语言一致）

### 5.2 SpanProcessor
做两个：
- `SimpleSpanProcessor(exporter)`：span end 就 export（适合 demo/test）
- `BatchSpanProcessor(exporter)`：队列 + 定时 flush（生产默认）

`moonbitlang/async` 有 async queue、timeout、取消机制，你可以用它的 TaskGroup/取消语义写一个很稳的后台 flush loop。  
另外 async 库更新里提到 `aqueue` 支持固定长度、满了可选择阻塞/覆盖/丢弃（非常适合 exporter backpressure 策略）。

---

## 6) OTLP/HTTP Exporter：从 Span 到 HTTP POST /v1/traces

### 6.1 协议硬要求（你必须照着做）
OTLP/HTTP：  
- trace 默认 path 是 `/v1/traces`，POST body 是 protobuf `ExportTraceServiceRequest`   
- 成功响应 HTTP 200；partial success 也 HTTP 200，但有 `partial_success`，并且 **client 不得重试**   
- Content-Type：binary protobuf 用 `application/x-protobuf`；JSON protobuf 用 `application/json` 

Exporter 配置（建议你支持这些 env var，和别的语言一致）：  
- `OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`  
- `OTEL_EXPORTER_OTLP_PROTOCOL`（至少支持 `http/protobuf`）  
- `OTEL_EXPORTER_OTLP_HEADERS`  
- `OTEL_EXPORTER_OTLP_COMPRESSION=gzip|none`（MVP 可以先只实现 none，把 gzip 预留）  

### 6.2 Proto 生成路线（务实做法）
- 把 `open-telemetry/opentelemetry-proto` 作为 git submodule 或直接拷贝需要的 `.proto`（只拷 trace + common + resource）。  
- 用 “moonbit protoc”（社区文章里就提到“moonbit protoc”在实践中可用）生成 MoonBit 代码，生成结果 **commit 进仓库**，避免用户装生成器。  
- 编码用 `moonbitlang/protobuf`：像示例那样 `@protobuf.Write::write(msg, writer)`。  

---

## 7) async/http 自动埋点：你要怎么“真的让人愿意用”

### 7.1 Server 端（@http.run_server）
`@http.run_server(addr, callback(conn, addr))`，每个连接一个 task 并发处理，conn 类型是 `@http.ServerConnection`，里面循环 `read_request()`。  

你要做一个 wrapper（伪代码）：

```moonbit
pub async fn run_server_with_otel(
  addr : @socket.Addr,
  handler : async (req : @http.Request, conn : @http.ServerConnection) -> Unit
) -> Unit {
  @http.run_server(addr, fn(conn, peer_addr) {
    // 每个连接 task：循环请求
    for {
      let req = conn.read_request()
      // 1) extract traceparent -> parent ctx
      let parent_ctx = @w3c.extract_from_request(req)

      // 2) start SERVER span
      let span = tracer.start_span(
        name = "HTTP " + req.meth.to_string(),   // MVP 命名
        kind = Server,
        parent = parent_ctx
      )
      defer span.end()

      // 3) set semconv attrs（方法、url、status 等）
      // 4) attach ctx，执行用户 handler
      @ctx.with_context(parent_ctx.with_span(span.context()), fn() {
        handler(req, conn)
      })
    }
  })
}
```

HTTP span 的语义规范（span 生命周期、重试/重定向、header 捕获风险等）在 semconv 文档里写得很细；MVP 至少做 method、status、url/route、error。  

### 7.2 Client 端（@http.get / @http.post）
MoonBit async 文章示例里直接 `@http.get(url)`。  

你要提供：
- `otel_http.get(url, headers?, ...)`
- `otel_http.post(url, body, headers?, ...)`

实现要点：
- start CLIENT span
- inject `traceparent` 到 request headers
- 记录 status code、异常、耗时
- span end 要保证在 response header 可用后结束（body 是否完全读完要按你 wrapper 的行为说明，避免用户误解），semconv 也提醒了这一点。  

---

## 8) 配置与“开箱即用”的初始化方式（决定口碑）

做一个单入口初始化（最重要）：

```moonbit
// yourname/otel/otel.mbt
pub fn init(
  service_name : String,
  endpoint? : String,
  headers? : Map[String, String],
  sampler? : Sampler,
  batch? : BatchConfig
) -> Unit
```

默认行为建议：
- sampler：ParentBased(root=AlwaysOn)（符合 OTel 默认）  
- exporter：读取 OTEL_EXPORTER_OTLP_* env var（不传就默认 `http://localhost:4318`，并 POST `/v1/traces`）  
- processor：BatchSpanProcessor（队列满了先丢 oldest 或丢 newest，你要写清楚）  

---

## 9) 两个人怎么分工（8 周出 v0.1.0）

### 第 1-2 周：核心骨架（Dev A 主）
- API 包：SpanContext/Span/Tracer/TracerProvider
- ContextStorage（Coroutine -> Context）
- W3C traceparent 注入/提取（含单测：合法/非法、全 0、大小写等）  

### 第 3-4 周：SDK（Dev A 主）
- TracerProviderSdk + SpanSdk
- Sampler（AlwaysOn/Off/ParentBased/Ratio）  
- SimpleSpanProcessor

### 第 3-5 周：OTLP Exporter（Dev B 主）
- 引入 opentelemetry-proto + 生成 MoonBit proto
- OTLP/HTTP exporter（POST /v1/traces，Content-Type，错误处理）  
- OTEL_EXPORTER_OTLP_* 配置解析   

### 第 6-7 周：Batch Processor + async/http 埋点（两人合）
- BatchSpanProcessor（后台 flush loop；取消/超时处理要稳）  
- async/http server + client instrumentation（最小 semconv）

### 第 8 周：工程化收尾
- examples：demo server + demo client
- 文档：如何接入 OTel Collector（只要能在 Jaeger/Tempo 里看到 trace 就成功）
- 发布 mooncakes：`moon publish`

---

## 10) 测试方案（让别人信你“可用”的关键）

1. **单元测试（纯逻辑）**
   - traceparent 解析/格式化（对照 W3C 格式）  
   - sampler（ratio 的边界值、parent-based 逻辑）  

2. **集成测试（本地起 Collector）**
   - 用 docker 起一个 OTel Collector（接收 OTLP/HTTP 4318）
   - 跑 demo，检查 collector 收到 spans（可以先只断言 HTTP 200 + 无错误）

3. **契约测试（OTLP 请求正确性）**
   - 构造一个 span -> encode -> 检查发到 `/v1/traces` 的 protobuf message 字段存在（traceId/spanId、name、start/end time）

---

## 11) 风险与规避（你现在就要决定的“工程策略”）

- **风险：上下文无法对所有 spawn 自动传播**  
  规避：把“HTTP instrumentation + otel-aware spawn wrapper”做到极致，让 80% 使用场景无需手工传 ctx。

- **风险：proto 生成链不稳定**  
  规避：生成结果 commit；CI 里加一个“proto 未更新”检查即可。

- **风险：API 变动（MoonBit/async 仍在演进）**  
  规避：用 virtual package 把“时间/随机数/http 发送”抽象出来，未来换实现不破 API。  

---

如果你按这个方案做，v0.1.0 的“杀手级体验”应该是：

- `@otel.init(...)` 一行启用  
- `@otel_http.run_server_with_otel(...)` / `@otel_http.get(...)` 直接带 trace  
- 默认 OTLP/HTTP 发到 Collector（`/v1/traces`），在 Jaeger/Tempo 里能看到完整链路   

你接下来只要照这个拆包、把 API 形状定死，就能开始写第一版了。
