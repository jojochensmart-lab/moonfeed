# RSS 2.0 正式验收专项整改

日期：2026-11-23。基线提交：`9f9b4073bbc52f41c26a3ae2ef84fdaceac04c4c`。

本报告记录专项修复、独立审计与可复现本地验证。最终 GitHub 交付须在审计及回归通过后提交、普通推送，并检查与该完整 HEAD 一致的 Actions 结果；本地通过不能代替远端结果。registry 已发布包仍是 0.2.0，本修复属于 Unreleased，本轮不发布 Mooncakes。

## 正式反馈与标准依据

组委会原始问题：

> 合法 RSS 2.0 条目仅有正文、没有 guid 和 link 时会解析失败，而根元素后追加非空文本却被接受，合法与非法输入均存在误判，影响订阅源解析兼容性。

[RSS 2.0 的 item 规则](https://www.rssboard.org/rss-specification#hrelementsOfLtitemgt)规定：title 或 description 至少存在一个；guid 和 link 均可选。[XML 1.0 §2.1、§2.8](https://www.w3.org/TR/REC-xml/#sec-well-formed)规定完整文档只有一个文档元素，外围 Misc 仅含合法注释、处理指令与 XML 空白，不含普通文本、CDATA 或字符/实体引用。

验收输入须同时满足 channel 的 title、link、description 必需规则。本报告 XML 边界集成测试使用完整 channel，避免把 channel 缺少 link/description 的语义错误误当成尾随文本校验结果。

## 根因一：统一模型映射强加 RSS 不存在的身份要求

`src/rss/parser.mbt` 的 parse_item 已允许可选 guid/link，并检查 title/description 至少存在一项。raw `Item.guid : Guid?`、`Item.link : String?` 也没有非空身份要求。

真正的误拒绝发生于 `src/rss/normalize.mbt` 的 item_id：缺少 guid 且无非空 link 时抛出 `InvalidRequiredField("channel.item[0].id", "guid or link is required for a stable item identity")`。这把统一模型 `FeedItem.id : String` 的历史设计偏好误当成了 RSS 必需字段。parse_rss、统一 parse、Podcast 包装及 CLI 最终都调用该映射，因此合法条目在 raw 解析之后失败。旧测试甚至固定了这个错误行为。

修改后：

- guid 存在时仍精确保留 guid 值、raw isPermaLink；有 guid 和 link 时 guid 优先且 url 保留 link。
- guid 缺失时仍以非空 link 作为统一 id；不把 guid 自动充作 url。
- 两者缺失时仍成功，统一 `id = ""` 表示来源身份缺失，缺少 link 时 `url = None`。raw guid/link 保持 `None`。
- 不用序号、随机数、channel URL、正文或哈希生成假 ID。多个缺少身份的 item 可以共存且保持输入顺序，空 ID 不能作唯一去重键。
- parse_item 原有 title/description 必需规则保留；公开 Channel/Item 可手动构造，因此直接 normalize 也补上同一内容存在检查。只有 guid、只有 link 或两者都有但没有标题/正文的条目继续报 `channel.item[n].title|description`。

## 根因二：Reader 只有标签配对状态，没有落实完整文档边界

修复前 `src/xmlmini/reader.mbt` 能配对标签，却会：

- 将根前后的普通字符都作为 Text 事件返回；将根外 CDATA 作为 CData 返回。
- 在已有根结束后再次接受 Start/Empty；无根文档也可到达 Eof。
- NamespaceReader 只是封装相同 Reader，因而继承这些缺口。

必须区分当前源码与反馈对象：本次基线的 RSS/Atom 文档 builder 已另行检查根外文本和根数，普通 `INVALID` 尾随文本在这两个完整解析入口已被拒绝；本次未在当前 RSS 入口重现该误接受。直接 Reader/NamespaceReader 测试仍确实重现。不能据此声称所有层此前都正确，也不能把已经拒绝的 RSS 输入写成新的失败复现。

本次把文档规则落到共享 Reader，沿用 document_element_seen 和 tags 栈判断状态：

| 状态 | 处理 |
| --- | --- |
| 尚未见根且 tags 空 | 允许现有 prolog 声明规则、合法注释/PI、字面 XML 空白；拒绝普通字符和 CDATA |
| tags 非空 | 继续解析子元素、Text、CDATA、实体及现有注释/PI |
| 已见根且 tags 空 | 只接受合法 Misc；新元素或普通文本/引用/CDATA 报错 |
| 输入结束 | 标签必须配对且已经有一个根；否则报错 |

文档外字符在实体解码前检查，`&#32;` 不能因解码为空格绕过规则；不使用 Unicode trim 判断 XML 空白。注释和 PI 一直走已有语法校验器，尾随未闭合标记或非法注释不会被忽略。RSS/Atom builder 的检查保留作为防线，没有 RSS 专用字符串截断或过滤。

完整文档校验要求调用者读取到 Eof；detect_format 是前缀分类器，不能证明剩余输入合法。原有 XML 声明严格/历史宽松入口策略不变。

## 可复现测试与具体结果

新增 20 项独立测试：

| 文件 | 新增项数 | 断言 |
| --- | ---: | --- |
| `rss_formal_acceptance_test.mbt` | 9 | 正文/标题/两者、可选身份与原始字段、guid 优先/link 回退、多条目顺序、缺少核心内容拒绝、直接 normalize 约束、RSS Misc、Atom Feed/任意前缀独立 Entry 与错误边界 |
| `src/xmlmini/document_test.mbt` | 10 | Reader 与 NamespaceReader 的具体事件、根前/根后文本、双根、无根、CDATA/引用/非 XML 空白、未闭合标记、非法注释和 PI |
| `cli/main_wbtest.mbt` | 1 | 规范化 JSON 中 id 为空、url/title 为 null、正文精确保留 |

修复前新 RSS 专项 9 项中 5 项失败：四项合法身份缺失用例及直接 normalize 内容校验。XML 专项筛选的 11 项（含一个已有用例）中 6 项失败，证明共享 Reader 缺口。修复后全部通过。

原 160 项测试用例未删除、未跳过。`rss_test.mbt` 的两处错误预期做规范修正：旧 title-only 误拒绝测试改成成功且断言 title/id/url；旧必需字段错误场景改用只有 guid 的条目，并加强到精确 title|description 字段路径，不再把合法条目当负例。

核心输入及输出：

```xml
<rss version="2.0"><channel>
  <title>News</title><link>https://example.org/</link><description>Feed</description>
  <item><description>这是一条新闻正文</description></item>
</channel></rss>
```

解析得到一个 item：`id = ""`，`url = None`，`title = None`，`summary/content_html = Some("这是一条新闻正文")`；显式入口、统一入口、raw + normalize、Podcast 包装结果一致。

上面完整文档之前或之后追加 `INVALID` 均返回 `InvalidXml("character data outside document element")`；统一入口的尾随文本返回封装后的 `Rss(InvalidXml(...))`。空白、`<!-- valid trailing comment -->`、`<?audit complete?>` 保留同一 Feed 解析结果。双根、未闭合标签、非法注释/PI 均拒绝。只有 guid/link 的 item 报内容字段错误。

`scripts/verify.mjs` 另启动真实 CLI 进程，通过 stdin 验证仅正文/仅标题、四种合法文档外围、缺少内容与非法 XML 的退出行为：成功输出正确 JSON；错误退出码 2、stdout 空、stderr 有解析原因。这些 smoke 不计入 180 项库测试。

## 工程与跨格式验证

工具链：`D:\MoonBit`，Moon CLI `0.1.20261028 (e1e1f15)`，moonc `v0.10.18+6c83a7f62`。

```powershell
$env:MOON_HOME = 'D:\MoonBit'
$env:PATH = 'D:\MoonBit\bin;' + $env:PATH
moon test --filter '*formal*'
moon test -p joanna/moonfeed/src/xmlmini
node scripts/verify.mjs
```

| 检查 | 结果 |
| --- | --- |
| 默认 check / test / build | PASS，180/180，0 compiler warning |
| JS check / test / build | PASS，180/180，0 compiler warning |
| 六个既有示例，默认及 JS | PASS |
| CLI 文件/stdin/Unicode/BOM/JSON 输出/错误 smoke + 新增 RSS/XML smoke | PASS |
| RSS/Podcast、Atom Feed/Entry、namespace、扩展隔离、CDATA、实体、日期、JSON Feed | 原有完整回归及专项断言 PASS |
| moon tree | `(no dependencies)` |
| 最低版本 v0.10.14 check/test/build，默认及 JS | PASS，180/180（两个目标）；现有项目内工具链，无全局变动 |
| moon info 与最低版本 moon fmt / moon fmt --check | PASS；生成的公开 mbti 无差异 |

最终交付轮本地验收日志保存为 `_build/rss-formal-delivery-source.log`，最低版本日志为 `_build/rss-formal-delivery-minimum.log`（构建目录不提交）。历史 CI 不证明本次修复，远端交付需核对实际 Actions headSha 和步骤结果。未执行 registry 安装或发布；既有 0.2.0 安装证据不能用于宣称新修复已经发布。

## 兼容性、文档与保护

公开 API 签名、模型字段类型和错误 variant 不变，RSS id 非空不再是可假设的前提；读取空 ID 的消费方应使用自身的身份策略。JSON Feed 和 Atom 的必需 ID 规则不变。Reader 现在要求完整单根文档，不能当 XML 片段 tokenizer 使用。

RFC 4287 矩阵保持 24 PASS / 3 PARTIAL / 0 FAIL。只记录共享 XML 校验及 Atom 回归证据，不把 RSS 可选 guid/link 问题算作 Atom 兼容度提升，也不把剩余 XML 序列化缺口写成完成。

同步 README、CHANGELOG、FINAL_ACCEPTANCE、API_COMPATIBILITY、ARCHITECTURE、XML_PARSING_SCOPE、功能实现对照表及 Atom 测试证据。申报书原件及其有意重命名状态完整保留；没有修改模块名、版本、依赖、CI 或许可，不发布 Mooncakes。仅暂存 17 个本轮技术文件，原件不进入此次提交。

## 最终交付独立审计

重新逐项阅读实现、两处旧测试差异和 20 项新测试，检查如下：

| 审计项 | 代码与自动化证据 |
| --- | --- |
| 仅正文、仅标题通过公共 API | parse_rss、统一 parse、raw + normalize、Podcast 包装的具体字段断言 |
| 可选身份不造成条目丢失 | normalize 与 Podcast 包装均遍历有序数组，不按 id 建索引或去重；混合四条目的数量、次序、重复正文和空 ID 均有断言 |
| 不伪造 guid/link | id 为空、url/raw guid/link 缺失断言；guid/link 存在时保留优先级、值与 isPermaLink |
| XML 规则由共享 Reader 执行 | 独立 document_test 直接完整消费 Reader/NamespaceReader 到 Eof，校验具体事件和 XmlError；不依赖 RSS builder |
| 合法与非法文档外围区分 | 根前后空白、注释、PI 成功；普通文本、CDATA、引用、双根、未闭合/非法标记拒绝 |
| 跨格式兼容 | Atom Feed、任意前缀独立 Entry、扩展节点、CDATA/实体的专项断言，以及全部已有 JSON/RSS/Atom 测试 |
| API 和测试完整性 | 原 160 项保留，两处错误旧预期按 RSS 规范纠正；公开 mbti 无变更，新增 20 项 |

多个无来源 ID 的条目不能被消费方用空字符串作为唯一 Map 键，否则会在消费方发生覆盖；库不自动创建替代身份。此行为与迁移注意事项已同步 README/API_COMPATIBILITY。

建议向组委会提交具体交付 commit、对应成功 CI 和本报告进行专项复验。版本建议为 0.3.0：单看本次缺陷修复可视为 patch，但 main 还包含已记录的未发布附件映射、公开类型重导出及 CLI 输出改进，整体候选更适合 minor。0.x 的这一选择是项目版本策略；严格 XML 拒绝范围与 RSS 空 ID 语义需在发布说明中明确。没有修改版本号或执行 publish。
