# MoonFeed 0.3.1 实体安全与规范修复

> 本文件记录 218 项测试时的安全整改结果；后续 [最终提交审查](MAINTENANCE_0.3.1_FINAL_REVIEW.md)增加四项测试并修复未知类型 charset 过度归一化。当前维护分支为 222 项测试。本文中的“未提交”和旧 HEAD 是当时状态，提交/CI 交付以最新分支及最终审查记录为准。

日期：2026-11-24。分支 `maintenance/0.3.1`，HEAD 仍为 `360fe6d45e0d18f70d477ca346aaafc1aa98271b`。这是未提交、未发布的维护工作区。`moon.mod`、CLI 正式版本及 registry 0.3.0 不变；不以该版本的历史 CI 冒充维护分支证据。

## 根因与资源模型

原递归展开仅限制路径深度和输出字符数。无环的空字符串实体重复引用，既不触发循环检查，也不增加输出，仍会产生指数级调用量。

`src/xmlmini/budget.mbt` 现在使用显式 `EntityFrame` 栈、一个输出 builder 和私有 `XmlBudget`。没有实体展开的宿主递归，也不在每层构建、拷贝完整展开结果。每个引用先收费，空替换帧也收费；资源错误固定为现有 `Malformed(message)`，RSS/Atom 保留其 `InvalidXml` 包装。预算失败会锁定 Reader，继续读取仍报同一个资源错误。

| 限制 | 默认上限 | 精确定义 |
| --- | ---: | --- |
| 实体路径深度 | 32 | 同时活动的命名实体帧，不包括最外层值帧；第 33 层在入栈前拒绝 |
| 引用次数 | 65,536 | Reader 生命周期内每次 EntityValue 处理或值解码遇到的 `&...;`，包括命名、预定义和数字引用；跨声明/值/属性/节点累计。同一默认值在语法校验、解码校验和实际应用中会分别计费，不因重复阶段返还预算 |
| 工作量 | 16,777,216 | 首次读取预付规范化输入字符数；每个解码帧预付 `String.length()+1`（UTF-16 code units，空帧也为 1），DTD 值/依赖扫描、图节点/边和默认属性遍历额外收费。单位是算法预算，不是毫秒、CPU 指令或内存字节 |
| 产生的 UTF-8 字节 | 8,388,608 | 累计文本、属性解码、默认值校验/应用和 CDATA 的真实 UTF-8 宽度，在写入输出 builder 前检查；不包括元素名、注释、PI 或对象开销，不等于整个进程内存上限 |
| 单值字符数 | 1,048,576 | 保留原解码值的字符上限；不是 1 MiB 字节数，不能替代全局预算 |
| XML 输入字节 | 16,777,216 | String 对应 UTF-8 字节，包含开头 BOM 和规范化前 CR/LF；过大输入在首个 read_event 返回错误，构造函数签名不变 |
| XML 元素嵌套 | 256 | 共享 Reader 在开始标签处检查，限制后续树处理的深度；DTD content model 仍使用原有独立嵌套限制 |

预算是产品安全策略，不是判断 XML 标准合法性的数值规则。它可能拒绝合法但超大的文档；调用者应处理 typed error。资源配置仅为内部实现，白盒测试使用小阈值，不新增公共 API。默认值校验本身也消耗预算，随后实际应用不会重置预算。输入 String 已由调用者分配；CLI 主机读取、模型结构/宿主运行时还有自己的分配开销，不能将这里的字节计数宣传为整进程硬内存限制。

## 内部 DTD 与声明规则

依据 [XML 1.0 §4.1 Entity Declared / No Recursion、§4.2 产生式 72/74、§5.1](https://www.w3.org/TR/REC-xml/)，补齐以下确定性错误：

- 参数实体的外部定义不能带 `NDATA`；通用实体的 NDATA 前必须有空白。解析后的 external parsed / unparsed 分开表示和诊断。
- 属性默认值在读取声明时使用当前实体表校验，直接/间接依赖均不得引用尚未声明的实体；即使对应元素未出现也不能跳过。缺少实体、外部引用和非法间接 `<` 有具体错误。
- 内部声明的依赖使用显式三色 DFS 栈校验循环、适用的未声明引用和禁止的 unparsed 引用，按图访问而非展开重复依赖树。依赖从字面 EntityValue 获取，字符引用不被误造为声明依赖。
- 普通通用实体之间合法的前向引用及首次声明绑定保留。外部子集未读时，不在 standalone=no/缺省情况下推断其中没有声明；standalone=yes 仍检查本地声明的完整性。
- 内部标记声明中的参数实体引用是禁止的位置；顶层参数实体引用可能合法，但当前不支持。两者的错误文本明确区分。

合法但未支持的标记实体仍返回 unsupported；外部实体/子集标识符从不解引用，依赖校验也没有引入网络、文件读取或 resolver。完整参数实体、标记替换事件流、DTD 实例有效性和任意编码转换未加入本轮。

## multipart/related

根据 [RFC 2387 §§3.1、3.4](https://www.rfc-editor.org/rfc/rfc2387.html#section-3.1)和 [RFC 2045 §5.1](https://www.rfc-editor.org/rfc/rfc2045.html#section-5.1)，将已解引号的 `type` 参数按内嵌 `type/subtype` 解析并仅归一化这两个名字，拒绝额外参数、分隔符及无效 token。类型识别不区分大小写，外层参数次序不影响等价；原始 Atom link 属性保留。

这个已注册类型要求 type；multipart boundary 的必要性与 1–70 字符语法依据 [RFC 2046 §5.1.1](https://www.rfc-editor.org/rfc/rfc2046.html#section-5.1.1)。已知单值参数 type/boundary/start/start-info 重复时明确报错，不猜测 first/last-wins。未知参数仍保留出现次数，沿用通用多重集比较。

边界、start、start-info 等不整体小写；`Text/HTML` / `text/html` 会判为同一 root type，但不同 boundary、root subtype、opaque 值仍不同。私有类型同名 `type` 参数不套用 related 规则。没有对任意媒体类型的别名、默认值或注册语法作全量语义声明；start 的完整邮件 msg-id 语法等仍属于宽矩阵行未覆盖的专用规则，而不是本轮新增的验证能力。

## 测试与回归

原 196 项测试文件逐一校验 SHA256，不删除、不修改断言。新增 **22 项**：

| 文件 | 数量 | 证据 |
| --- | ---: | --- |
| `src/xmlmini/security_wbtest.mbt` | 10 | 独立安全套件：空引用、空嵌套、指数树小预算提前终止；循环/32 与 33 层；引用/工作/输出预算精确边界；跨属性/节点/默认值累计；输入 BOM/CRLF/Unicode 字节边界；sticky error、禁外部读取和元素深度 |
| `src/xmlmini/declarations_test.mbt` | 6 | NDATA、默认值直接/间接声明顺序、未使用声明、合法前向引用/首次绑定、循环图、standalone、参数位置、unparsed/external 明确错误 |
| `security031_test.mbt` | 6 | 公共 Atom API 验证 related 正反等价、重复/缺失/非法参数与私有类型隔离；RSS、Atom Feed、Entry 的实体具体字段；公共 Entry 对空实体放大返回精确资源错误 |

所有安全测试验证具体字符串、事件、模型字段或确切 `Malformed`/`InvalidXml`，不捕获 panic 作为成功、不依赖超时、不运行攻击规模的样例。20 层指数声明在小预算测试中至多支付指定工作量；公共/CLI 路径由默认引用预算提前终止，不会执行整个指数树。

`scripts/verify.mjs` 增加真实 CLI 进程检查：非法声明退出 2、正常小实体内容为 Safe、空实体放大退出 2 且 stderr 给出引用超限。既有 JSON Feed、RSS、Atom namespace/Feed/Entry、日期、CLI 正反与 UTF-8 用例全保留；NamespaceReader 包装同一个带预算 Reader。

| Moonc | 默认测试 | JS 测试 | check/build 双目标 | 六示例双目标 / CLI smoke | 编译 warning |
| --- | ---: | ---: | --- | --- | ---: |
| v0.10.14+7d59c7ec9 | 218/218 | 218/218 | PASS | PASS | 0 |
| v0.10.18+6c83a7f62 | 218/218 | 218/218 | PASS | PASS | 0 |
| v0.10.22+124d61d05 | 218/218 | 218/218 | PASS | PASS | 0 |

本地日志与汇总：`_build/security031/v0.10.14.log`、`v0.10.18.log`、`v0.10.22.log`、`validation.json`；保护文件和接口核验见同目录记录。复现：为对应工具链设置进程级 MOON_HOME，执行 `node scripts/verify.mjs`。没有更改全局工具链、用户环境变量或执行策略。无第三方依赖。

## 兼容与发布结论

公开签名、模型、错误 variant、trait 和生成接口保持不变；Reader 新增状态均私有。资源上限和非法声明/MIME 重复组合属于行为收紧，不能承诺所有旧的超大/非法输入继续接受。最低 MoonBit 仍为 v0.10.14。

矩阵维持 **25 PASS / 2 PARTIAL / 0 FAIL**：A05 仍缺完整实体/其他 XML 序列化覆盖，A20 仍未覆盖全部注册类型语义。旧审计中的这次具体安全风险、声明误接受及 related 等价遗漏已修复并有独立证据，不靠 PARTIAL 标签忽略它们。

本地质量门槛已满足，建议进入人工审查后的 0.3.1 提交与 CI 验证阶段。尚未有本次改动对应的新远端 CI、发布包或 registry 安装证据；不得直接宣布正式发布完成。仍需获确认后更新版本、提交推送、确认最新 CI、审计包内容，再发布并做 registry 全新安装。本轮没有提交、推送、发布，也未修改两份申报书或原有重命名状态。
