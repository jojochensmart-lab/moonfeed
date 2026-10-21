# 第三轮 Atom 规范缺口审计

基线：`abd8a16245f9c2cdcf298dfd063486f3d5f2209d`，2026-10-21 重新执行 check / test / build / tree：117/117、0 warning、无依赖，main 与 origin/main 一致。矩阵当时为 18 PASS、8 PARTIAL、1 FAIL。下表逐项记录这九行的原始缺口和本轮处置，不把修复计划算作实现。

规范链接：[RFC 4287](https://www.rfc-editor.org/rfc/rfc4287)、[RFC 3066](https://www.rfc-editor.org/rfc/rfc3066#section-2.1)、[XML 1.0](https://www.w3.org/TR/REC-xml/)、[Namespaces](https://www.w3.org/TR/xml-names/)、[RFC 3987](https://www.rfc-editor.org/rfc/rfc3987#section-2.2)、[RFC 2045](https://www.rfc-editor.org/rfc/rfc2045#section-5.1)、[RFC 2822](https://www.rfc-editor.org/rfc/rfc2822#section-3.4.1)。

| 原行 / 章节与规范要求 | 原实现及证据 | 具体原缺口 | 本轮修复 / 后续方案 | API 影响 | 难度与风险 |
| --- | --- | --- | --- | --- | --- |
| A03 / Namespaces §§2.1–2.3, 3：绑定值 MUST 是 URI-reference 或空值；比较必须逐字符，不能规范化 | xmlmini/reader.mbt 的 build_namespace_element；原 namespace scope/reserved/expanded duplicate 测试 | 未验证普通 namespace URI 词法 | namespace_uri.mbt 拒绝空白、非 URI 字符、坏百分号和多个片段；conformance namespace identity/lexical 两组测试证明字符引用解码后精确比较。完整 authority、scheme/path 组合语法仍待补齐 | 原签名不变；非法绑定拒绝更早 | 中；共用 reader，需 RSS 回归 |
| A05 / RFC §2, XML §§2.2, 2.8, 2.11, 3.3.3：Atom 文档 MUST well-formed XML；处理输入行尾和属性规范化 | xmlmini/reader.mbt；原 malformed XML/Unicode/name 测试 | 声明 grammar/位置、PI、CRLF、属性空白未处理；DTD/实体未实现 | 已实现声明字段顺序/值/位置、一般 PI 跳过、XML Name、行尾及属性规范化；新增四组相关规范测试及 malformed 测试。DTD/internal entity/声明属性默认值和类型仍不支持 | 内部构造器新增可选 strict_declaration；旧入口保留前导空白兼容。根 API 不变 | 高；字符引用与字面空白必须分开处理 |
| A08 / RFC §2、RFC 3987 §2.2、XML Base §3：Atom IRI MUST 满足 grammar，解析相对地址必须用作用域 base | atom/iri.mbt；RFC3986 normal/abnormal 向量、Unicode/百分号测试 | IP-literal 只做粗检；Unicode/private-use 上下文及 LEIRI 不完整 | 新增 ip_literal.mbt：IPv6 压缩/组数/嵌入 IPv4、IPvFuture、ucschar 和 query-only private-use 范围；两组 conformance 正反例。完整 LEIRI 转义边界仍需独立向量 | 返回 raw/resolved 不变，ID 不参与规范化 | 高；错误拒绝和过度拒绝均有风险 |
| A10 / RFC §2、§4.2.7.4、XML §2.12、RFC3066 §2.1：xml:lang 应符合语言标签语法或空值；hreflang MUST 为语言标签；标签比较不区分大小写 | parser.mbt 仅继承 raw language；原 inheritance/reset 测试 | 完全没有标签语法诊断 | language.mbt 分段检查 1–8 ASCII 字母主标签和 1–8 字母数字子标签；允许 private/historic 标签，xml:lang 空值清除，hreflang 空值拒绝；三组 conformance 及 scoped fixture 证明。校验语法，不在线判断注册含义 | 只接入严格文档入口；旧 parse/parse_atom 不新增语言校验 | 低；避免把现代 registry 规则错误套入 RFC3066 |
| A13 / RFC §3.2.3、RFC2822 §3.4.1/§4：email MUST 是 addr-spec；obsolete 输入不能简单当非法 | email.mbt；原 quoted/comment/domain literal 测试 | obs 控制字符与所有 FWS 组合覆盖不足；注释深度 32 | 新增折行校验，拒绝裸 CR/LF、无后续 WSP 的 CRLF；conformance email folding 正反例。完整 obsolete productions 和资源限制的兼容策略仍需补齐 | 严格 person 校验收紧；旧 normalization 不调用此校验 | 中；历史 grammar 复杂 |
| A15 / RFC §3.3、RFC3339 §5.7：date-time MUST 合 grammar，闰秒受实际公告限制 | date.mbt 内嵌 IANA/IERS 表；原已公告/未公告闰秒测试 | 未来表更新没有自动维护；负闰秒未发生也未建模 | 本轮保留已测试的语义，不伪造未来公告；下一步对官方表增设更新核验，明确负闰秒策略 | 无 | 中；Unix 秒与精确时间身份不能混淆 |
| A20 / RFC §§4.1.1–4.1.2、4.2.7：默认 rel=alternate，简单 relation 等价 IANA URI；MUST NOT 重复相同 type/hreflang alternate | document.mbt strict_links；原 literal duplicate/rel/length 测试 | 缺语言比较和 MIME 等价处理 | 新增大小写无关 hreflang、MIME essence/参数名、quoted 值、顺序无关参数多重集比较；charset 值大小写无关，未知参数保留大小写和全部值；conformance 证明。不猜测所有注册 MIME 参数的特殊比较语义，暂留 PARTIAL | 保留原属性字符串；严格 API 拒绝更多重复 alternate | 中；不能忽略有意义的参数或 normalize href |
| A23 / RFC §§4.1.3.1、4.2.7.3、RFC2045 §5.1：type MUST 合 MIME syntax；composite content 禁止，但 link type 不受此禁令 | document.mbt 原 token/quoted 参数 parser；原 XML/text/Base64/composite 测试 | comments/FWS 和比较未覆盖，token 字符范围过窄 | media.mbt 按 ASCII token/tspecials、CFWS、quoted-pair 解析并保留原值；summary 分类也使用解析后的 essence，修复带注释 MIME 被当 binary 的问题。新增 MIME 三组断言；obsolete RFC822 CTL/折行边界仍保留 PARTIAL | API 签名不变，合法带注释媒体类型从拒绝变为接受 | 中；内容分类和 summary 条件必须一起修正 |
| A27 / RFC 所有已实现 normative constraints：执行 MUST/MUST NOT，不能把 SHOULD 升格为拒绝 | document.mbt typed errors；原 required/singleton/author/content 测试 | 全部 grammar 缺口意味着无法宣称完整 typed error 覆盖 | 新增规范反例匹配具体变体/字段路径，空标题、扩展、重复版本 ID 和缺 self link 的旧合法用例保留；其余状态随 A03/A05/A08/A13/A15/A20/A23 | 兼容边界另见 API_COMPATIBILITY.md | 高；依赖上面各项，而非增加一个宽泛 catch 即完成 |

## 独立验证边界

原 117 个测试文件不修改。新增 `atom_conformance_test.mbt` 和 `fixtures/atom/conformance/`，分别存放断言与可审阅输入。测试依据公开规范而非另一个实现的输出；没有宣称这是 W3C 官方完整测试套件，也没有获得第三方认证。C14N、XML Schema、AtomPub、签名验证和网络下载不属于本轮解析职责。
