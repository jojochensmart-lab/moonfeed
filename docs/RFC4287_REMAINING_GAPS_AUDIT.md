# RFC 4287 剩余缺口审计与 0.3.1 维护准备

> 2026-11-24 后续：本文件保留首轮维护的 196 项测试与三项缺口审计记录。最终安全审计发现的问题已按 [安全整改报告](SECURITY_0.3.1_FIX.md)修复，当前为 218 项测试，矩阵仍是 25 PASS / 2 PARTIAL。当前证据与发布建议以该报告为准；尚未提交、推送或发布。

审计基线：正式 0.3.0 / Git `360fe6d45e0d18f70d477ca346aaafc1aa98271b`；维护分支 `maintenance/0.3.1`。本轮不提交、不推送、不发布，模块版本及已发布 0.3.0 保持不变。申报书原件与有意重命名状态保留。

## A05：XML 输入覆盖

**条款与范围。** [RFC 4287 §2](https://www.rfc-editor.org/rfc/rfc4287#section-2)要求 Atom 是良构 XML。[XML 1.0 §5.1](https://www.w3.org/TR/REC-xml/#proc-types)区分验证型与非验证型处理器：非验证型也必须检查所读取的文档及内部子集的良构性，处理已经读取的声明，落实实体替换、属性规范化与默认值。完整 DTD 有效性验证不是必需；这不能用来免除内部实体替换的要求。

**实际实现和复现。** 阅读 `src/xmlmini/reader.mbt`、`dtd.mbt`、namespace reader、RSS/Atom 文档循环及 CLI 字节读取：

| 检查 | 基线实际行为 | 本轮实现及证据 |
| --- | --- | --- |
| 声明/BOM/Unicode | Feed 入口自行移除 BOM，直接 Reader 却将其当根外文本 | XML BOM 统一只由 Reader 消费一次；UTF-8 声明、补充平面名称、中文、U+10FFFF 有事件值断言；重复 BOM 在显式/统一入口均拒绝，XML 1.1 不新增支持 |
| 字节输入 | CLI 的 Node UTF-8 字符串读取静默替换非法字节 | 文件与 stdin 使用 fatal UTF-8 decoder；真实 CLI smoke 拒绝过长编码、代理项、越界码点、截断和 0xFF，并允许真正编码的 U+FFFD |
| 字符和引用 | Reader 的 take/numeric 校验正确，但 DTD 的独立游标跳过了未使用声明中的非法字符/引用 | 整个读入 DOCTYPE 范围检查 XML Char；未使用实体及属性默认值的引用语法、数值字符合法性也校验 |
| DTD 词法 | 任意 ATTLIST 类型、空/嵌套枚举、非法 PUBLIC 字符、任意 ELEMENT/NOTATION 内容会被跳过 | 校验属性类型与枚举、PubidChar、ELEMENT EMPTY/ANY/混合/分组内容语法、NOTATION 的 SYSTEM/PUBLIC 形式；不升级为 DTD 实例有效性验证 |
| 实体与属性 | EntityValue 中字符引用推迟解析，间接 TAB 在属性中未规范化；tokenized pass 还误折叠直接字符引用 TAB | 按 [XML §4.5](https://www.w3.org/TR/REC-xml/#intern-replacement)在声明读取时处理字符引用，通用实体引用留到使用时；按 [§3.3.3](https://www.w3.org/TR/REC-xml/#AVNormalize)区分字面/实体替换空白与直接字符引用，末步只折叠 #x20 |
| 注释/PI/文档结构 | 已有正常/错误路径校验及单根状态机 | 原测试全保留，合法 Misc、根外文本/CDATA/引用/双根与错误诊断继续回归 |
| namespace 与 feed 集成 | URI/local-name 与作用域已实现 | 新增 Reader 及 RSS/独立 Entry 的 BOM/内部实体具体值测试；原 Atom namespace/Feed/Entry 测试保留 |

**仍缺失。** 内部通用实体产生标记时仍明确拒绝，而非插入 XML 事件流；参数实体引用仍整体拒绝，没有实现非验证型处理器跳过未读参数实体后的声明处理规则；实体读取仍有深度/大小安全限制。外部实体/子集不会联网加载。String API 本身没有字节编码探测，CLI 当前只接受 UTF-8，不提供任意编码转换。

**修复边界。** 本轮补强已读取输入的校验与值保真，保持 typed XML errors。引入实体输入帧、实体边界良构性及完整替换事件流属于下一步架构工作，不能把纯字符串插入当成符合标准的实现。禁止外部资源加载是主动安全策略；内部标记替换缺失则是真实兼容缺口，两者不能混为一谈。

**测试。** `src/xmlmini/maintenance_test.mbt` 七项独立测试加 `maintenance031_test.mbt` 集成测试；所有断言检查具体事件、属性、字符或类型错误。原 entity 深度/大小、循环、外部资源禁止及 namespace 测试保留。A05 保持 **PARTIAL**。

## A13：email quoted CR/LF

**条款。** [RFC 4287 §3.2.3](https://www.rfc-editor.org/rfc/rfc4287#section-3.2.3)引用 [RFC 2822 §3.4.1](https://www.rfc-editor.org/rfc/rfc2822#section-3.4.1) 的 addr-spec。RFC 2822 §§3.2.2–3.2.5、4.1 的 quoted-pair/obs-qp 可出现在 qcontent、ccontent、dcontent；被反斜线引用的 CR/LF 可以由 XML 字符引用表达。FWS 则要求 CRLF 后跟 WSP。XML 不允许的 C0 字符不能借此接受。

**根因与代码。** `src/atom/email.mbt::validate_email` 原先先调用共享 MIME `header_characters`，在语法上下文判定前拒绝所有非折行 CR/LF。旧 `review_regression_test.mbt` 固定了一个规范允许却被拒绝的样例。

**实现。** email 先限制 ASCII/XML 可表达字符，再由 mail_word、mail_cfws、domain-literal 逐上下文处理转义；mail_fws 单独检查未引用的折行。原始 email 字符串原样保留，不删换行、不去掉反斜线。MIME 仍走自己的严格 header 校验。裸 CR/LF、无效控制符、未完成转义仍拒绝。

**证据。** 新测试覆盖 Feed 作者与贡献者、quoted local-part、注释、domain literal 的 CR/LF、合法折行与引号/反斜线；负向覆盖裸行、原子位置 DEL、NUL/C0、未完成引号与 MIME 中同样转义。旧不支持测试改为具体成功值断言，保留其原 MIME 负向断言。既有 obsolete local/domain、深注释、DEL 和 person 数量约束测试继续保留。该明确缺口关闭，A13 改为 **PASS**；不声称支持 RFC 6532 国际化 email。

## A20：注册 MIME 参数等价

**条款。** RFC 4287 §§4.1.1–4.1.2 的 alternate 链接组合数量约束及 §4.2.7.3 的媒体类型语义依赖 [RFC 2045 §5.1](https://www.rfc-editor.org/rfc/rfc2045#section-5.1)。类型、子类型、参数名大小写不敏感；参数值通常敏感，例外由各注册规范定义。quoted-string 的引号和 quoted-pair 不属于参数值。不能把任意值小写，也不能只比较原始属性字符串。

**实际代码。** `src/atom/media.mbt` 的 parse_media_type/same_media_type 已处理 token、CFWS、quoted-pair、参数次序、charset，以及 RFC 2046 message/external-body 的已知例外；缺少 [RFC 5023 §12.1](https://www.rfc-editor.org/rfc/rfc5023#section-12.1) 的 Atom type 值、[RFC 3676 §3](https://www.rfc-editor.org/rfc/rfc3676#section-3) 的 text/plain format/delsp 值例外，使语义相同的 alternate 组合漏报重复。

**实现。** 仅针对对应 essence 和参数名加入已核验的值大小写规则；保留所有原始属性及重复参数出现次数，以多重集匹配顺序变化，避免 Map 最后写入覆盖。不同 entry/feed、flowed/fixed、大小写不同 boundary/profile、未知类型的同名 type 参数仍区别。注册规范特有的重复参数约束没有被虚构为全局规则。

**证据。** 新独立测试分别断言注册参数等价导致精确 `entry.link[1]` 错误、真正不同值保留两个链接、quoted/顺序/大小写、重复次数及不同重复值、非法参数路径；原 2045/2046 测试全保留。

**仍缺失与结论。** 有限例外表不能证明任意 IANA/私有媒体类型的所有参数语义、默认值或注册约束。没有运行时抓取注册表，也没有假定未知参数全局不敏感。A20 保持 **PARTIAL**；下一步应选定可审计的注册范围或设计明确的语义策略接口，再评估兼容性，不能用一个通用字符串算法声称覆盖整个注册空间。

## 弃用警告与 API

v0.10.22 的 15 处源位置：13 个 derive 声明、2 个 Int64::from_int。隔离探针证明 `#derive(Eq, @debug.Debug)` 在 v0.10.14 语法错误，不能直接批量迁移，也不提高最低版本。

13 个类型改为显式公开 Eq/Debug trait 实现，使用三版标准库共有的结构化 Repr 构造器，保留构造器名、字段、顺序和原公开转发方法。两个整数转换改为 to_int64，仍为同值扩展。没有关闭 warning、屏蔽诊断或引入依赖。生成 mbti 的差异只是 derive 标记变成同样的 pub impl 声明；公开函数、错误 variant 与模型字段不变。测试核对类型错误的完整调试字符串及值相等/不相等语义。

## 回归与发布边界

原 180 项保留，新增 16 项，共 196 项；旧 email 已知缺口测试转为成功断言，原 MIME 断言保留。另有真实 CLI UTF-8 字节 smoke，不计入 MoonBit 测试数。

验证使用独立 v0.10.14、D:\MoonBit v0.10.18、项目忽略目录的官方 v0.10.22；编译器归档 SHA256 已核验，没有改变全局安装或 PATH。完整结果及日志见维护验收记录。registry 新项目只能证明已发布 0.3.0，不能冒充未发布 0.3.1；维护代码用本地三版双目标回归证明。

| 实际工具链 | 默认测试 | JS 测试 | check/build、六示例双目标、CLI smoke | 编译 warning |
| --- | ---: | ---: | --- | ---: |
| v0.10.14 / moon 0.1.20260920 | 196/196 | 196/196 | PASS | 0 |
| v0.10.18 / moon 0.1.20261028 | 196/196 | 196/196 | PASS | 0 |
| v0.10.22 / moon 0.1.20261119 | 196/196 | 196/196 | PASS | 0 |

最终三版回归已包含 BOM 所有权修正、非法 UTF-8 文件/stdin 的真实进程测试，以及合法 U+FFFD 保真测试。原始日志为 `_build/maintenance031-v0.10.14.log`、`maintenance031-v0.10.18.log`、`maintenance031-v0.10.22.log`；汇总为 `_build/maintenance031-validation.json`。19 个生成接口规范化对比（derive 视为同样的 pub impl）通过。

仓库外新项目 `D:\DevCache\Temp\moonfeed-031-baseline-140ec3b449af44a69e6cc5419386867d` 使用正式 `moon add joanna/moonfeed`，manifest 为 0.3.0；正常使用 registry 缓存，默认 wasm-gc 与 JS 的 check/test/build 通过，调用方各 10/10。它不使用 workspace/path/GitHub 依赖，不包含候选维护源码。初始化的 Windows README 符号链接权限提示不影响编译，未修改系统安全策略。

维护矩阵为 **25 PASS / 2 PARTIAL / 0 FAIL**。原 0.3.0 的 24/3/0 记录不变。此版本可作为兼容性修复候选供人工审阅，但不能宣传“完整 RFC 4287”或“27 PASS”。剩余架构/注册语义范围应另行决定；本轮不提交、推送、发布。
