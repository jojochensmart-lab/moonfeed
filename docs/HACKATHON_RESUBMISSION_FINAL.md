# MoonFeed：面向 MoonBit 的多格式 Feed 解析与规范化工具库

## 基本信息

- 项目名称：MoonFeed：面向 MoonBit 的多格式 Feed 解析与规范化工具库
- 参赛者：陈依堃
- 联系方式：个人联系方式保留在报名原件中，不随公开仓库材料发布
- GitHub 仓库：[jojochensmart-lab/moonfeed](https://github.com/jojochensmart-lab/moonfeed)
- Mooncakes 模块：`joanna/moonfeed`；已发布版本为 `0.2.0`，已由全新 registry 项目安装验证
- 项目方向：MoonBit 生态基础库 / 信息订阅与内容解析基础设施
- 是否为移植项目：否
- 许可证：Apache-2.0

## 项目简介

MoonFeed 为 MoonBit 应用解析 JSON Feed 1.1、RSS 2.0 和 Atom 1.0，并将常见字段映射到统一的 `Feed` / `FeedItem` 模型。它解决应用重复实现格式识别、XML/JSON 字段提取、作者/链接/正文/日期转换的问题。项目还提供 Atom 专用文档 API，以保留 Feed 与独立 Entry 文档的区别和标准元数据。

MoonFeed 接收调用方已取得的文本，不负责 HTTP 抓取、HTML 自动发现或内容渲染。项目没有虚构下载量、第三方用户或生产部署案例。

## 项目背景与生态需求

MoonBit 应用接入订阅内容时，需要面对不同的 XML 与 JSON 结构、字段名称、作者继承、日期格式和链接语义。Atom 元素还必须通过 namespace URI 与 local name 识别；只检查 `feed`、`entry` 或 `title` 这样的本地名称，可能把外部扩展节点当成 Atom 标准字段。MoonFeed 将这些工作集中在一个 MoonBit 库中，让阅读器、版本监控和内容导入程序可以复用解析与规范化逻辑。

## 核心功能与实际支持范围

- **JSON Feed 1.1**：解析常用 feed/item 字段、作者与语言继承、tags 和日期，并校验支持字段类型及必需值。
- **RSS 2.0**：解析 channel/item 核心字段、作者、分类、guid/link、enclosure 和日期；保留部分 RSS 原始字段，并单独提供 Apple Podcasts/iTunes 常用 metadata 解析入口。
- **Atom 1.0**：保留历史 `parse_atom` 与统一 `parse` 的 Feed 规范化行为；`parse_atom_document` 返回不同的 Feed Document 或 Entry Document，不把独立 entry 伪装成 feed。
- **统一数据模型与格式识别**：`detect_format(...)` 识别格式，`parse(...)` 自动分发；常用标题、作者、链接、正文、分类、日期和附件映射到 `Feed` / `FeedItem`。
- **Atom 文档元数据**：严格文档入口可访问 source、contributor、email、全部 links/categories、rights、generator、icon/logo、content 结构及 namespace-expanded 扩展树；仍未覆盖的规则见兼容矩阵。
- **日期处理**：保留输入日期原文；可解析时提供 UTC Unix 秒。Atom 专用日期类型保留小数位、`-00:00` 和闰秒标记。
- **CLI**：`detect`、`inspect`、`normalize` 可在 Node.js 环境运行。
- **XML 实现**：RSS 与 Atom 使用 MoonFeed 内部 `src/xmlmini` reader，无第三方 XML registry 依赖。

## Atom namespace 初审问题与修复

初审关注 Atom 按 namespace 识别的问题。项目调整为按 `(namespace URI, local name)` 匹配标准元素，并由 XML reader 维护默认 namespace、前缀绑定、作用域继承/重绑定、默认 namespace 清空及保留前缀规则。无前缀属性不继承默认 namespace；重复的展开属性会报 XML 错误。扩展 namespace 中同名的 `feed`、`entry`、`title` 不会被识别为 Atom 字段。

默认 namespace 和任意合法前缀有等价测试，逐字段比较独立 Entry 的 ID、标题、日期、作者、链接和内容；另有前缀作用域、属性 namespace、保留绑定、扩展隔离和非法输入断言。新一轮 A03 用例继续检查 namespace URI-reference 的 scheme、authority、userinfo/port、percent escape 和 bracket 位置。namespace URI 仍按属性实体解码后的原始字符串精确比较，不执行大小写、百分号或点路径规范化。

## RFC 4287 兼容目标与边界

项目的 Atom 最终目标是 RFC 4287 Atom Syndication Format 的 Feed Document 和独立 Entry Document 解析及语义处理，涵盖必需字段、单值数量、作者继承、source、person、category、link、XML Base、language、text/content construct、日期、扩展元素与 typed errors。Atom Publishing Protocol 不属于项目范围。

当前兼容矩阵为 **19 PASS / 8 PARTIAL / 0 FAIL**。PASS 表示矩阵中具体列出的要求有代码和测试证据，不等于完整标准认证。项目没有宣称完整兼容 RFC 4287。仍未完全实现的主要边界有：XML DTD 与内部声明实体/DTD 默认属性，完整 URI/IRI/LEIRI 及 IP-literal 词法，历史 email/MIME 语法和部分注册 MIME 参数等价规则，以及依赖这些规则的全量诊断覆盖。具体状态和每项测试路径见 [RFC 4287 兼容矩阵](ATOM_RFC4287_COMPLIANCE.md)。

闰秒表来自公开 IANA/IERS 数据。本材料核对至 2026-10-22：IERS Bulletin C 72（2026-07-06）确认 2026 年 12 月没有新增闰秒，并说明 UTC-TAI 自 2017-01-01 起为 -37 秒。闰秒表仍需随未来公告人工维护；程序不联网自动更新，也不接受未经公告的未来闰秒。

## 应用场景

1. **多源技术资讯阅读器**：解析不同站点的 RSS、Atom 或 JSON Feed，生成统一条目后由上层应用排序和展示。下载、存储和界面由调用方负责。
2. **开源项目版本跟踪器**：读取 releases Feed 中的稳定 ID、版本标题、发布时间和链接，由应用保存状态并决定何时通知。
3. **内容导入与检索管线**：将 Feed 条目交给调用方的文本清洗、切分和索引流程；Atom 文档 API 可保留原始与解析后链接。MoonFeed 不实现 AI 推理或下载 `content src`。

以上为基于当前 API 的应用示例，不代表已有真实用户或上线案例。

## 工程验证和版本边界

- 仓库：[https://github.com/jojochensmart-lab/moonfeed](https://github.com/jojochensmart-lab/moonfeed)
- 最低工具链：MoonBit v0.10.14；本地使用项目内 v0.10.14，CI 使用官方 latest 并打印实际版本。
- 本轮新增 1 项 namespace URI 组件测试，当前总数 138；默认与 JS 目标均为 138/138。CI 对提交 687123f 的运行 39703833171 为 success，check/test/build、示例和 CLI smoke 全部通过。
- CI 检查 `moon check`、`moon test`、`moon build`、两个示例和 CLI smoke。历史 CI 只证明其对应提交，不替代本轮最新 HEAD 的运行。
- Mooncakes 0.2.0 已发布并由全新 registry 项目安装；旧版 0.1.2 不含 Atom 文档 API 和本轮 namespace URI 修复。Registry 归档 README 仍含发布前候选措辞；GitHub main README 已改为正式安装说明。元数据与代码包正确，本轮不因这处 README 快照差异立即发布补丁版本。
- 原有 117 项测试保留，规范测试从 20 项增至 21 项；这些独立测试不是官方完整认证套件。

## 下一阶段计划

1. 评估并补齐 Atom 需要的 XML 1.0 / DTD 边界，配套独立规范向量。
2. 完成 RFC 3986 namespace URI 与 RFC 3987 LEIRI/IP-literal 的完整词法覆盖。
3. 增加历史 email/MIME 语法及参数等价规则的测试，继续审查 MUST 与 SHOULD 的处理。
4. 明确闰秒公告的维护检查流程，并保持 Atom/RSS/JSON Feed 回归和跨目标构建。
5. 所有规范性缺口关闭且得到可复现证据后，再考虑完整 RFC 4287 兼容声明。

## 许可证

Apache License 2.0，见 [LICENSE](../LICENSE)。
