# Atom API 兼容与版本策略

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

## 发布版本评估

Mooncakes 最新发布版本为 `0.2.0`。新 API 增加独立 Feed/Entry 结果类型并保留原有 `parse` / `parse_atom` 签名和返回类型；共享 namespace reader 对非法 URI-reference 输入的拒绝属于解析错误收紧。根包接口没有 breaking change。精确版本已在新项目通过 `moon add joanna/moonfeed` 从 registry 安装，生成 `joanna/moonfeed@0.2.0` 依赖声明，并完成 check/build 与 JSON、RSS、Atom Feed、Entry smoke。0.2.0 archive 内的 README 是发布前快照，仍提及 0.1.2/候选状态；GitHub README 已在 clean install 后更正，registry metadata、manifest 和实际 API 一致。此处只影响发布说明文字，不影响包内容和调用。未来若改变旧 parser 的宽松行为，须单独评估兼容性和迁移策略。
## 2026-11-01 Unreleased compatibility review

Original normalization/document function signatures, public model layouts and error variants are unchanged. The root now additionally re-exports Feed, FeedItem, Author, Attachment, FeedLink, Podcast types and FeedFormat, so clients may annotate results without internal imports. Use `@moonfeed.FeedFormat::Rss` to avoid the same-named ParseError wrapper constructor. These aliases are source additions, not features retroactively present in the released 0.2.0 package.

Supported behavior changes: JSON attachments now map into the existing model instead of being discarded; malformed attachment fields are rejected atomically. The explicit JSON parser accepts a leading BOM, consistent with parse. RSS ignores foreign-default-namespace core collisions, recognizes an empty default namespace and itunes bindings by element scope, and rejects text/CDATA outside the root. Historical undeclared itunes extensions remain ignored. RSS channel language is inherited by its items. Inherited legacy Atom author arrays are copied to avoid cross-item mutations. Oversized date numbers cannot overflow into valid values. XML errors retain the underlying reason without changing error types.

CLI item JSON now has an additive `language` key and `--version` agrees with module 0.2.0. Clients comparing an exact JSON key set should account for that addition. Email DEL is accepted in permitted RFC 2822 contexts; obsolete quoted CR/LF remains unsupported, so matrix A13 is PARTIAL. Test count 160, defaults/JS pass; these changes remain Unreleased; final Git/CI evidence must match the delivered commit. See FINAL_DELIVERY_AUDIT.md for the 0.3.0 recommendation.
### Formatter/minimum-version evidence

The v0.10.18 formatter automatically migrates source Int to Int32, which v0.10.14 cannot parse. The minimum-version check caught this before delivery. Source keeps Int, formatting uses the existing v0.10.14 formatter, and tests pass 160/160 on both targets with both v0.10.14 and v0.10.18. Main development validation remains v0.10.18; no package configuration downgrade, compatibility shim or minimum-version increase was introduced. Generated interface alias display changes do not change runtime layouts.