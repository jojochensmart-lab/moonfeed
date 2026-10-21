# MoonFeed 十月黑客松整改说明

## 初审问题与第一阶段修复

组委会指出，Atom 元素必须按 namespace URI 与 local name 识别；只改变前缀的等价文档应产生等价结果，项目也应明确完整 RFC 4287 兼容的终点。

第一阶段在 src/xmlmini 增加 namespace-aware 事件接口，处理默认 namespace、任意前缀、继承与重绑定、保留前缀、无前缀属性及重复展开属性。Atom parser 和格式检测按展开名称匹配，隔离其他 namespace 的同名 title/entry。第一阶段基线从 81 项增至 88 项测试，提交 a15dbd9 的 [CI 已通过](https://github.com/jojochensmart-lab/moonfeed/actions/runs/39571610848)。

## 第二阶段实际代码改动

本阶段以 a15dbd9 为基线，重新验证了 88/88 测试、check/build，并记录了未跟踪申报书.md 的 SHA-256。该文件保持原样且不纳入整改提交。

新增 parse_atom_document / parse_atom_document_with_base，返回独立的 FeedDocument 或 EntryDocument。Atom 专用模型保留 feed/entry ID、source、贡献者、email、全部链接、分类 scheme/label、rights、generator、icon/logo、内容类型和扩展树。独立 entry 不包装成虚构 feed。既有 parse_atom / parse 的 Feed 返回类型保持兼容；它们保留历史常用字段规范化行为，不被宣传为完整 RFC 校验器。

XML Base 在每个节点继承与覆盖，支持调用方提供检索 URI。相对地址按 RFC 3986 组件拆分、路径合并、点路径段消除和重组实现；支持 ../、./、绝对路径、authority、查询、片段、空引用，以及 XML Base 的空值、片段和 LEIRI 空格。IRIReference 同时保留 raw、resolved 和 is_absolute。Atom ID 保持原始字符身份，不参与基地址拼接。

新的文档入口校验 feed/entry 必需字段、单值数量、结构、作者存在及 entry -> source -> feed 继承、alternate 链接约束、缺少 content 时的 alternate、外部或 Base64 content 的 summary 要求，以及日期格式。text/html/xhtml、其他文本和 XML MIME 内容、外部 src 和 Base64 解码均有结果断言。xml:lang 支持继承、覆盖和空值重置。

AtomDate 保留原始日期、小数精度、-00:00 标记和闰秒标记；支持年 0000 与已公告正闰秒。Unix 秒保留 POSIX 语义，精确身份需同时查看原始值和标记。闰秒表引用 IANA/IERS 公共领域数据，后续公告需要维护。

## 真实运行证据

当前本地使用 MoonBit 0.1.20260920 / moonc v0.10.14+7d59c7ec9，moon check 无警告、moon test 117/117、moon build 和两个示例通过。原有 88 个测试未修改或删除，新增 29 个有针对性的规范/边界测试，包含 RFC 4287 §1.1 正式 Feed 示例和 RFC 3986 §5.4 解析向量。

运行 moon run examples/atom，默认 namespace 与 x: 前缀的独立 Entry 文档逐字段比较 ID、标题、日期、作者、链接和正文，并输出：

~~~text
Equivalent Entry Documents: PASS
urn:entry:demo
../article
https://example.org/article
~~~

[Atom 文档测试](../atom_document_test.mbt) 和 [可运行示例](../examples/atom/main.mbt) 是代码证据。[GitHub Actions](https://github.com/jojochensmart-lab/moonfeed/actions/workflows/ci.yml?query=branch%3Amain) 对 main 执行 check/test/build、两个示例和 CLI smoke；以对应提交的成功运行作为远端证据，不能用历史 CI 代替新提交验证。

## 完整兼容终点与尚未完成项

最终目标是 RFC 4287 Feed Document 与 Entry Document 的解析和语义处理。本次已补齐独立 Entry、XML Base、标准元数据访问和核心 MUST 数量/存在条件，并未达到无条件完整兼容。

[兼容矩阵](ATOM_RFC4287_COMPLIANCE.md) 当前为 18 PASS、8 PARTIAL、1 FAIL。关键剩余点包括：完整 Atom 相关 XML 1.0 序列化与规范化、namespace URI 词法验证、完整 IRI/IPv6/IPvFuture/LEIRI 规则、语言标签语法、旧式 email/MIME 词法与链接等价比较，以及后续闰秒公告维护。既有统一模型入口仍是历史兼容的规范化入口，需单独制定严格校验的版本迁移策略。

后续按上述顺序完善代码和独立规范向量，每项只有实现且有测试后才调整状态。当前材料足以证明本轮实质整改和明确路线，尚不能据此宣称完整 RFC 4287 兼容或保证重新审核通过。本阶段未发布 Mooncakes，Git main 的新增 API 尚不在已发布 0.1.2 中。
