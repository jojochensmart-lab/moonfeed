# Atom API 兼容与版本策略

## 0.3.1 安全与规范修复

最终审查进一步限制 charset 的大小写规则：仅对已核验的六类媒体类型折叠值，未知/私有类型同名参数保持原大小写。这避免过度合并 alternate 链接；原始属性不变，没有公开 API 变化。见 [最终审查](MAINTENANCE_0.3.1_FINAL_REVIEW.md)。

公开函数、模型字段、错误 variant 和 Eq/Debug trait 能力保持；mbti 中 derive 标记改为相同的显式 pub impl，不是删除 trait。v0.10.14 不支持 #derive，新版编译器又弃用旧语法，因此采用三版共有的显式 trait 实现，并保留旧公开 equal/not_equal/to_repr 方法和结构化诊断。整数扩展使用同值 to_int64，最低版本仍为 v0.10.14。

email 新接收规范允许的 quoted CR/LF，原始字符串保留；MIME 不随之接受裸换行。已知注册参数的大小写等价会使以前漏检的 alternate 组合报重复。XML/CLI 对非法 DTD 词法和非法 UTF-8 字节更严格；合法 BOM 由 XML Reader 只消费一次，重复 BOM 不会被多层剥离而误接受；Unicode、字符引用和属性值按 XML 规范处理。String API 不增加字节编码转换或外部实体读取。

0.3.1 矩阵为 25 PASS / 2 PARTIAL / 0 FAIL，222 项测试；正式 0.3.0 的历史 24/3/0 与 180 项记录不变。源码验证与 registry 安装证据分开，见 [剩余缺口审计](RFC4287_REMAINING_GAPS_AUDIT.md)。

2026-11-24 安全整改不增加公开参数、错误 variant 或模型字段；共享 Reader 的预算状态均为私有字段。XML 输入、展开和输出现在有累计资源限制，达到上限返回现有 Malformed/InvalidXml 包装，可能拒绝此前接受的超大输入。非法参数实体 NDATA、默认值实体声明顺序和 multipart/related 参数错误被明确拒绝；重复 alternate 中的内嵌媒体类型大小写现在按规范等价。原始 link 属性仍保留。这是校验与安全行为收紧，不是公开签名变更；限制数值见 [安全整改](SECURITY_0.3.1_FIX.md)。

## 0.3.0 RSS/XML 正式验收整改与版本边界

公开函数签名、错误 variant、模型字段及类型均未变化。`FeedItem.id` 保持 `String`，RSS 的来源 guid 优先、非空 link 回退策略保持不变；两者缺失时由错误改为 `id = ""` 表示没有来源标识，缺少 link 的 `url` 仍是 `None`，raw `Item.guid/link` 仍是 `None`。空字符串不是生成 ID，也不保证唯一；应用去重前应检查非空，身份策略由应用决定，不得把 channel link 当条目链接。JSON Feed/Atom 的 ID 要求不变。

RSS parse_raw 与公开 normalize 都检查 title/description 至少存在一个；只有 guid 或只有 link 的 item 仍不合法。共享 Reader/NamespaceReader 新增文档级结构校验，完整读取到 Eof 时拒绝根外文本/引用/CDATA、多个根或无根文档，合法空白、注释和 PI 保留。曾把事件 Reader 当作片段 tokenizer 的调用方应提供完整 XML 文档；轻量 detect_format 不是全文校验。

原 160 项保留，20 项新测试合计默认/JS 各 180/180。两处与 RSS 规范冲突的旧预期已更正并加强具体字段/错误路径断言。RFC 4287 仍为 24 PASS / 3 PARTIAL / 0 FAIL。详见 [专项整改报告](RSS20_FORMAL_ACCEPTANCE_FIX.md)；这些修复及此前的功能增量纳入 0.3.0，0.2.0 不包含。发布 gate 与新项目安装复现见 [0.3.0 发布说明](RELEASE_0.3.0.md)。

| 入口 | 返回与文档种类 | 校验与信息保留 |
| --- | --- | --- |
| `parse(input)` | 统一 `Feed`；自动探测 JSON Feed/RSS/Atom Feed | 历史格式规范化行为，不是完整 Atom validator |
| `parse_atom(input)` | 统一 `Feed`；只接受 Atom Feed 根节点 | 历史常用字段，无法表达的元数据不保留；不包装独立 Entry |
| `parse_atom_document(input)` | `AtomDocument`，区分 FeedDocument/EntryDocument | 执行已实现的严格规则；保留 source/person/link/category/rights/content 和扩展树 |
| `parse_atom_document_with_base(input, document_uri)` | 同上，带绝对检索地址 | 用检索地址和逐层 xml:base 解析引用；raw 与 resolved 均可访问 |

“严格”表示执行[矩阵](ATOM_RFC4287_COMPLIANCE.md)已实现的规则，不表示所有 XML/IRI/旧式邮件语法都已覆盖。旧入口和新入口可能对同一输入给出不同结果：`fixtures/atom/conformance/vectors.mbt` 的 legacy_feed 含相对 ID、无作者/内容链接和非规范语言标签，旧入口可规范化，严格入口返回字段错误。该差异有独立测试证明。

0.2.0 阶段的严格入口新增 xml:lang/hreflang 语法和 MIME/link 等价校验；原 117 个测试保持不变。共享 XML reader 的行尾与属性空白规范化修复适用于所有 XML 入口，因此含字面 CR 或属性 TAB 的输入值可能由之前的非规范值变为 XML 规范值。字符引用保留原字符。严格入口要求 XML 声明紧接文档开始（可有 BOM）；旧入口继续接受历史上的声明前导空白。有效声明字段语法与一般 PI 处理共用。

## 迁移示例

需要统一阅读器模型的现有调用者可继续用 parse/parse_atom。需要独立 Entry、标准元数据或精确诊断的调用者，改用文档入口并匹配 FeedDocument/EntryDocument；检查每个链接的 raw、resolved、is_absolute，不把相对地址误当绝对地址。ID 始终保留字符身份，不能用 URL 规范化后的值做去重键。

可运行迁移例为 `moon run examples/atom`。日期精确身份使用 AtomDate.raw、fractional_digits、leap_second；Unix 秒只表示 POSIX 时间。

## 0.2.0 历史发布记录

0.2.0 发布时，新 API 增加独立 Feed/Entry 结果类型并保留原有 `parse` / `parse_atom` 签名和返回类型；共享 namespace reader 对非法 URI-reference 输入的拒绝属于解析错误收紧。该精确版本曾在新项目通过 registry 安装，并完成 check/build 与 JSON、RSS、Atom Feed、Entry smoke。0.2.0 archive 内的 README 是发布前快照，仍提及 0.1.2/候选状态；其 manifest 与实际 API 一致。这是历史证据，不代表 0.3.0 的实际安装结果。
## 2026-11-01 开发审计（后纳入 0.3.0）

Original normalization/document function signatures, public model layouts and error variants are unchanged. The root now additionally re-exports Feed, FeedItem, Author, Attachment, FeedLink, Podcast types and FeedFormat, so clients may annotate results without internal imports. Use `@moonfeed.FeedFormat::Rss` to avoid the same-named ParseError wrapper constructor. These aliases are source additions, not features retroactively present in the released 0.2.0 package.

Supported behavior changes: JSON attachments now map into the existing model instead of being discarded; malformed attachment fields are rejected atomically. The explicit JSON parser accepts a leading BOM, consistent with parse. RSS ignores foreign-default-namespace core collisions, recognizes an empty default namespace and itunes bindings by element scope, and rejects text/CDATA outside the root. Historical undeclared itunes extensions remain ignored. RSS channel language is inherited by its items. Inherited legacy Atom author arrays are copied to avoid cross-item mutations. Oversized date numbers cannot overflow into valid values. XML errors retain the underlying reason without changing error types.

CLI item JSON has an additive `language` key; the release aligns `--version` with module 0.3.0. Clients comparing an exact JSON key set should account for that addition. Email DEL is accepted in permitted RFC 2822 contexts; obsolete quoted CR/LF remains unsupported, so matrix A13 is PARTIAL. This was the historical 160-test review, later extended to 180. These changes are included in 0.3.0; final Git/CI and registry evidence must match the delivered release.
### Formatter/minimum-version evidence

The v0.10.18 formatter automatically migrates source Int to Int32, which v0.10.14 cannot parse. The minimum-version check caught this before delivery. Source keeps Int, formatting uses the existing v0.10.14 formatter, and tests pass 160/160 on both targets with both v0.10.14 and v0.10.18. Main development validation remains v0.10.18; no package configuration downgrade, compatibility shim or minimum-version increase was introduced. Generated interface alias display changes do not change runtime layouts.
