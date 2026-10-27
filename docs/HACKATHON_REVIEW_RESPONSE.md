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

## 第二阶段运行证据

第二阶段本地使用 MoonBit 0.1.20260920 / moonc v0.10.14+7d59c7ec9，moon check 无警告、moon test 117/117、moon build 和两个示例通过。原有 88 个测试未修改或删除，新增 29 个有针对性的规范/边界测试，包含 RFC 4287 §1.1 正式 Feed 示例和 RFC 3986 §5.4 解析向量。

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

第二阶段矩阵为 18 PASS、8 PARTIAL、1 FAIL；第三轮后的当前结果及剩余项见下文。既有统一模型入口仍保留历史兼容行为，迁移策略已经另行记录。

后续按上述顺序完善代码和独立规范向量，每项只有实现且有测试后才调整状态。当前材料足以证明本轮实质整改和明确路线，尚不能据此宣称完整 RFC 4287 兼容或保证重新审核通过。第三轮完成时尚未发布 Mooncakes；现有 registry 0.1.2 仍不含 Git main 新增 API，本轮候选版本另行核验。

## 第三轮：语言与 XML / IRI / MIME 边界

基线 abd8a16 经重新运行验证为 117/117、0 warning、无依赖。实现提交 [8dd897c](https://github.com/jojochensmart-lab/moonfeed/commit/8dd897c1b2969a754cbfb005bf3ca03aef46b44d) 增加 RFC3066 语言标签语法和 hreflang 校验、XML 行尾/属性值规范化、声明语法/顺序/严格位置、一般 PI 和名称校验、namespace 字符串词法边界、IPv6/IPvFuture 与 Unicode IRI 范围，以及 MIME 注释/折行/参数比较和 email 折行诊断。带注释 text MIME 的 summary 分类错误已修复。

原 117 个测试没有修改或删除，另增 20 个独立规范测试；默认与 JS 均为 137/137，check/build、两个示例、CLI smoke 通过。fixtures 与断言分离，反例匹配具体错误路径。[本轮实现 CI](https://github.com/jojochensmart-lab/moonfeed/actions/runs/39628836015) 已 success，check、137 tests、build、两个示例和 CLI smoke 全部通过；最终文档 HEAD 的 CI 需另核对 main 最新运行。

第三轮当时的矩阵为 **19 PASS、8 PARTIAL、0 FAIL**。该阶段的 namespace URI/LEIRI、DTD/internal entity 等 XML 边界、历史 email/MIME productions、注册参数等价规则、闰秒维护与完整诊断覆盖仍待闭环。不能据该阶段结果宣称完整 RFC4287 兼容。[九项审计](ATOM_ROUND3_AUDIT.md) 逐项记录原缺口、规范、代码、测试、修复和风险。

[API_COMPATIBILITY](API_COMPATIBILITY.md) 说明旧入口保留宽松统一模型，新文档入口执行已实现的严格规则；版本未改，未执行 Mooncakes 发布。新建 [重新申报材料](HACKATHON_RESUBMISSION_2026_10.md)，包含三类实际应用场景、初审逐项回应、提交/CI/测试证据和明确剩余计划。原申报书.md 的 SHA256 保持 9018ED564BF0CDCB3F32028ADF415592E30A7489FD0B9B30218441FF8EBE5AEF，未修改或提交。

## 最终交付复核：namespace URI-reference 与发布防护

第四轮复核针对 A03 增加 URI-reference 结构校验：检查 scheme 语法、相对首路径段冒号、authority 的 userinfo/host/port 布局、百分号转义和方括号位置，并以正反输入断言验证。namespace 名仍按 XML 属性实体解码后的原字符串精确比较，不做 URL 大小写、百分号或点路径规范化。由于完整 IP-literal 与所有 URI path productions 尚未覆盖，A03 仍标为 PARTIAL，不宣称完整 namespace URI 词法兼容。

发布预审发现未跟踪的 `申报书.md` 会进入默认 Mooncakes 包清单。新增 `.moonignore` 沿用项目构建输出排除项，并显式排除该本地材料；发布前重新审阅包清单，确认其中没有申报书原件或联系方式。申报书原件 SHA-256 在编辑前核验，姓名和联系方式只在本地报名文件保留。

本轮提交 `687123f` 的默认/JS 测试均为 138/138，GitHub Actions run 39703833171 success。Mooncakes 已正式发布 `joanna/moonfeed@0.2.0`，旧版 0.1.2 不含 Atom 文档 API；registry 新项目安装并运行 JSON/RSS/Atom Feed/独立 Entry、detect 和 date smoke 均通过。

## 第五轮：URI IP-literal、邮件注释与闰秒维护（2026-10-27）

在第四轮基础上，将 RFC 3986 IP-literal 校验提取到 `src/xmlmini/ip_literal.mbt`，供 namespace URI 与 Atom IRI 路径共用。补充 IPv4-embedded IPv6、IPvFuture 与非法压缩组测试；namespace URI 对应的 A03 从 PARTIAL 调整为 PASS。`src/atom/iri.mbt` 现在按 scheme、userinfo、host、port、path、query、fragment 分别验证 RFC 3987 字符集合，增加 Unicode 范围与 private-use 上下文向量，并保持 XML Base 的 LEIRI 字符和组件解析行为；A08 有实现与正反测试，调整为 PASS。

删除 email CFWS 注释解析器人为设置的 32 层嵌套上限，并增加 64 层注释结果断言。新增 RFC 2822 obsolete local/domain 形式与折叠空白的具体结果测试；可由 XML 1.0 表示的 addr-spec 形式均纳入实现和测试，A13 调整为 PASS。

依据 IERS Bulletin C72（2026-07-06）复核闰秒表：截至 2026-10-27，公告没有新增 2026 年末闰秒，现有表仍覆盖全部已公告正闰秒。新增未公告候选日期拒绝测试和 [闰秒维护流程](LEAP_SECONDS.md)，A15 调整为 PASS。流程要求在新公告发布后人工复核和更新，不进行运行时联网。

XML 子集 reader 对所有 DOCTYPE 明确报错，不解析内部/外部子集、声明实体或 DTD 默认属性；这项边界和安全取舍记录于 [XML 解析范围](XML_PARSING_SCOPE.md)。该策略没有实现 RFC 所需的完整 XML 1.0/DTD 处理，A05 仍为 PARTIAL。

本轮默认与 JS 目标各 141 项测试通过；其中原 117 项保持不变，22 项为 Atom 独立规范向量，另有 XML Base 与闰秒边界回归。完整结果与最新 CI 对应提交将在该提交推送后补记。当前矩阵为 **23 PASS、4 PARTIAL、0 FAIL**；A05、A20、A23、A27 仍为 PARTIAL，完整 RFC 4287 兼容声明仍不成立。

## Mooncakes README 快照

0.2.0 registry 元数据（module/version/license/repository/description）与精确依赖安装正常，包内 Atom document API 已实际调用。由于要求先通过全新安装再更新 README，已发布 archive 中保留了发布前的候选版本措辞；GitHub main README 已更正。此项是归档说明文字的时间差，不影响 API 或 metadata；本轮按不因小型 README 快照问题立即发补丁版的既定原则记录并停止。
