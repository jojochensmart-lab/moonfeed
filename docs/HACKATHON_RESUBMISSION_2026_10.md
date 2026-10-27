# MoonFeed 十月黑客松重新申报材料

## 项目名称与定位

**MoonFeed：面向 MoonBit 的 RSS 2.0、Atom 1.0 与 JSON Feed 1.1 统一解析与规范化工具库。**

项目为 MoonBit 应用提供订阅内容解析、统一模型、日期处理和命令行检查能力。Atom 另提供保留标准元数据的 Feed/Entry 文档 API。源码采用 Apache-2.0，无第三方包依赖。项目不承担 HTTP 下载和内容渲染。

仓库：[jojochensmart-lab/moonfeed](https://github.com/jojochensmart-lab/moonfeed)。本轮实现提交：[8dd897c](https://github.com/jojochensmart-lab/moonfeed/commit/8dd897c1b2969a754cbfb005bf3ca03aef46b44d)。

## 实际使用场景

1. **GitHub Release / 开源项目版本监控。** 上层应用获取项目的 releases.atom 文本，交给 MoonFeed 解析，读取条目 ID、版本标题、发布时间和发布说明链接。应用持久化 ID 与更新日期后比较前后结果，决定是否通知用户。MoonFeed 负责解析和日期规范化，抓取、调度、去重策略及通知由应用实现；不会把 Atom ID 当 HTTP URL 重写。
2. **多格式技术资讯聚合。** 上层程序获取不同站点的 RSS、Atom 或 JSON Feed，以统一 parse 入口生成 Feed/FeedItem，按 UTC 日期排序，并展示作者、正文和附件。需要保留 Atom source、贡献者、全部链接或扩展节点时改用文档 API；统一模型缺少的字段不会被宣传为已保留。
3. **AI Agent / RAG 内容源接入。** 调用方抓取订阅文本后，使用 MoonFeed 提取正文、来源链接、ID 和日期，按条目送入清洗、切分和索引流程。Atom 文档 API 允许检索地址参与相对 IRI 解析并保留 raw/resolved，便于后续来源追溯。MoonFeed 不实现模型调用、向量库或 HTML 内容清洗，也不会自动下载 content src。

RSS enclosure 及已有 Apple Podcasts/iTunes 核心元数据可用于列出节目附件和时长；不把当前支持范围扩大成完整 Podcast/Media RSS 标准兼容。

## 初审意见与实际整改

| 初审意见 | 已完成的实现与证据 |
| --- | --- |
| XML namespace 语义缺失 | 内部 reader 维护默认/前缀 namespace 的继承、重绑定和空默认值；Atom 通过 URI + local name 匹配元素，区分无前缀属性、保留前缀和重复展开属性。外部 namespace 的同名节点不能冒充 Atom。实现见 [76c87ce](https://github.com/jojochensmart-lab/moonfeed/commit/76c87ce) 和 [第一轮验收](https://github.com/jojochensmart-lab/moonfeed/commit/a15dbd967aefb7d1d365e32d4000ae74c75f504f)。 |
| 前缀变化后的等价性 | 默认 namespace、任意合法前缀及 supplementary Unicode 前缀均有结果断言。examples/atom 逐字段比较独立 Entry 的 ID、标题、日期、作者、链接与正文；namespace 名按解码后的字符串精确比较，不进行大小写或百分号 URL 规范化。 |
| Atom 完整标准兼容终点不明确 | 最终目标明确为 RFC 4287 Feed Document 与独立 Entry Document 的解析和语义处理。第二轮补齐独立 Entry、XML Base、作者/source/内容/数量约束和专用元数据；第三轮继续补齐语言语法、XML 规范化与声明、IRI 和 MIME/email 边界。所有已知缺口写入[兼容矩阵](https://github.com/jojochensmart-lab/moonfeed/blob/main/docs/ATOM_RFC4287_COMPLIANCE.md)，未宣称完整兼容。 |

第二轮实现提交：[0362ca2](https://github.com/jojochensmart-lab/moonfeed/commit/0362ca2)，审计提交：[abd8a16](https://github.com/jojochensmart-lab/moonfeed/commit/abd8a16245f9c2cdcf298dfd063486f3d5f2209d)。历史 CI：[第一轮](https://github.com/jojochensmart-lab/moonfeed/actions/runs/39571610848)、[第二轮](https://github.com/jojochensmart-lab/moonfeed/actions/runs/39581266513)。这些历史结果不替代本轮验证。

## 本轮技术完成度

- 严格文档入口按 RFC3066 分段验证 xml:lang/hreflang 语法，保留继承、覆盖、空值清除和原始大小写；不冒充在线语言注册表校验。
- XML reader 正确区分物理行尾、字面属性空白与字符引用，验证 XML 声明字段/顺序/严格位置和名称，跳过一般处理指令，保持 namespace 字符串身份。
- IRI 增加 IPv6、嵌入 IPv4、IPvFuture 和 Unicode/private-use 上下文校验；继续按 RFC3986 组件算法处理相对引用。
- MIME 支持注释、折行、quoted 参数、参数顺序及大小写规则；未知参数值保留大小写和意义。修复带注释 text MIME 被错误当作 binary、进而要求 summary 的问题。email 增加非法折行诊断。
- 原有 117 个测试未修改或删除；目前总计 141 项，默认目标和 JS 均为 141/141。新增 22 个独立规范向量及 2 项 XML Base/闰秒边界回归。check/build 无警告，无依赖，两个现有示例与 CLI detect/inspect/normalize smoke 通过。最新 CI 应以本轮对应提交的 Actions 结果为准。

本轮实现 CI：[8dd897c 的运行](https://github.com/jojochensmart-lab/moonfeed/actions/runs/39628836015) 已 success，check、137 tests、build、两个示例和 CLI smoke 均通过。后续文档提交的最终验收可从 [main 的 Actions](https://github.com/jojochensmart-lab/moonfeed/actions/workflows/ci.yml?query=branch%3Amain) 查看。不得用不同 HEAD 的失败/成功结果替代对应代码的验证。

## 完整兼容终点与剩余工作

兼容矩阵目前为 **23 PASS、4 PARTIAL、0 FAIL**。这表示语言语法 FAIL 已有实现和正反测试，不能据此折算“完成百分比”或宣称权威认证。

完整兼容之前仍需按优先级完成：

1. RFC 3986 namespace URI-reference、RFC 3987 Atom IRI 组件/IP-literal 与 XML Base LEIRI 路径均有实现和边界向量。XML reader 明确拒绝 DOCTYPE，内部/外部 DTD、声明实体及 DTD 默认属性不支持，因此 A05 仍未完成。
2. RFC 2822 可由 XML 1.0 表示的 addr-spec、obsolete local/domain 与折叠形式已有实现和结果断言。剩余 MIME 注册参数等价规则、若干 MIME 边缘语法及相应诊断仍需补齐。
3. 闰秒表已按 IERS Bulletin C72 核验，并建立公告后的人工维护流程与未公告日期拒绝测试；仍需随之后公告持续维护。全部规范性缺口闭环后，再评估无条件完整兼容声明。

Atom Publishing Protocol、完整 XML Schema 验证器、C14N、通用 XML 工具链和签名验证不是本项目的兼容终点。当前材料用于呈现真实整改与可复核路线，不能承诺组委会一定通过。若复审硬性要求完整 RFC 4287，仍应先完成上述标准缺口。

## 复核与版本边界

- [标准测试](https://github.com/jojochensmart-lab/moonfeed/blob/main/atom_conformance_test.mbt)、[独立 fixtures](https://github.com/jojochensmart-lab/moonfeed/tree/main/fixtures/atom/conformance)、[原 Atom 文档测试](https://github.com/jojochensmart-lab/moonfeed/blob/main/atom_document_test.mbt)、[Atom 示例](https://github.com/jojochensmart-lab/moonfeed/tree/main/examples/atom)。
- [兼容矩阵](ATOM_RFC4287_COMPLIANCE.md)、[九项缺口审计](ATOM_ROUND3_AUDIT.md)、[API 兼容与迁移](API_COMPATIBILITY.md)。
- 本地最低工具链为 MoonBit v0.10.14；运行 moon check / moon test / moon test --target js / moon build / moon tree，独立测试可运行 moon test --filter 'conformance*'。
- [Mooncakes joanna/moonfeed@0.1.2](https://mooncakes.io/docs/joanna/moonfeed@0.1.2) 是已有发布记录对应版本，**不包含前两轮和本轮新增的 Atom 文档 API/标准修复**。评审本轮应使用上述 Git 提交。发布状态沿用已有发布验收记录；本轮未发布、未改版本，也未重新执行 registry 安装，不以源码整改冒充新发布验收。
- 本材料另行创建，原有未跟踪的申报书.md 保持原样且未纳入提交。

## 最终交付材料与第四轮复核（2026-10-22）

本地最新申报稿不纳入公开仓库，因为原件含报名个人信息。第四轮之后，本轮补齐 namespace URI 的 IP-literal 校验、RFC 3987 IRI 各组件字符规则及 RFC 2822 obsolete addr-spec 实例；A03、A08、A13 和闰秒公告 A15 均为 PASS。默认和 JS 测试均为 141/141。当前矩阵为 23 PASS / 4 PARTIAL / 0 FAIL；A05、A20、A23、A27 仍未闭环，项目不宣称完整 RFC 4287 兼容。详细证据见 [兼容矩阵](ATOM_RFC4287_COMPLIANCE.md)、[闰秒维护流程](LEAP_SECONDS.md) 与 [XML 解析范围](XML_PARSING_SCOPE.md)。

Mooncakes `0.2.0` 已发布，包含 Atom document API。新项目通过 registry 安装到精确版本，并完成 check/build 与 JSON/RSS/Atom Feed/Entry smoke。最新 CI 与 registry 证据见下方。

## 发布页 README 快照说明

joanna/moonfeed@0.2.0 registry 元数据和新项目安装均已确认正确；该版本归档中的 README 是安装验证之前制作的快照，仍包含“0.2.0 待闭环”的旧措辞。GitHub main README 已在验证成功后更新为正式 moon add joanna/moonfeed 安装说明。此问题限于 README 快照；不影响包代码、metadata 或实际安装。本轮不立即发布新的补丁版本，避免仅为 README 快照追加发布。
