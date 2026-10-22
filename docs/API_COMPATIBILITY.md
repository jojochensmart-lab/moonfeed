# Atom API 兼容与版本策略

| 入口 | 返回与文档种类 | 校验与信息保留 |
| --- | --- | --- |
| `parse(input)` | 统一 `Feed`；自动探测 JSON Feed/RSS/Atom Feed | 历史格式规范化行为，不是完整 Atom validator |
| `parse_atom(input)` | 统一 `Feed`；只接受 Atom Feed 根节点 | 历史常用字段，无法表达的元数据不保留；不包装独立 Entry |
| `parse_atom_document(input)` | `AtomDocument`，区分 FeedDocument/EntryDocument | 执行已实现的严格规则；保留 source/person/link/category/rights/content 和扩展树 |
| `parse_atom_document_with_base(input, document_uri)` | 同上，带绝对检索地址 | 用检索地址和逐层 xml:base 解析引用；raw 与 resolved 均可访问 |

“严格”表示执行[矩阵](ATOM_RFC4287_COMPLIANCE.md)已实现的规则，不表示所有 XML/IRI/旧式邮件语法都已覆盖。旧入口和新入口可能对同一输入给出不同结果：`fixtures/atom/conformance/vectors.mbt` 的 legacy_feed 含相对 ID、无作者/内容链接和非规范语言标签，旧入口可规范化，严格入口返回字段错误。该差异有独立测试证明。

本轮仅严格入口新增 xml:lang/hreflang 语法和 MIME/link 等价校验；原 117 个测试保持不变。共享 XML reader 的行尾与属性空白规范化修复适用于所有 XML 入口，因此含字面 CR 或属性 TAB 的输入值可能由之前的非规范值变为 XML 规范值。字符引用保留原字符。严格入口要求 XML 声明紧接文档开始（可有 BOM）；旧入口继续接受历史上的声明前导空白。有效声明字段语法与一般 PI 处理共用。

## 迁移示例

需要统一阅读器模型的现有调用者可继续用 parse/parse_atom。需要独立 Entry、标准元数据或精确诊断的调用者，改用文档入口并匹配 FeedDocument/EntryDocument；检查每个链接的 raw、resolved、is_absolute，不把相对地址误当绝对地址。ID 始终保留字符身份，不能用 URL 规范化后的值做去重键。

可运行迁移例为 `moon run examples/atom`。日期精确身份使用 AtomDate.raw、fractional_digits、leap_second；Unix 秒只表示 POSIX 时间。

## 发布版本评估

Mooncakes registry 中最新已发布版本为 `0.1.2`，其中不含 Atom document API。新 API 增加独立 Feed/Entry 结果类型并保留原有 `parse` / `parse_atom` 签名和返回类型；共享 namespace reader 对非法 URI-reference 输入的拒绝属于解析错误收紧。根包接口无 breaking change，因此评估使用递增 minor 版本 `0.2.0`。候选版本只有在 main CI 通过、归档内容审阅、发布成功和全新项目安装 smoke 全通过后才标记为正式发布。未来若改变旧 parser 的宽松行为，须单独评估兼容性和迁移策略。