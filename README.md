# MoonFeed

面向 MoonBit 生态的多格式 Feed 解析与规范化基础库，把 RSS、Atom 和 JSON Feed 转换为统一的 `Feed` / `FeedItem` 模型。

## 支持状态

| 格式 / 能力 | 当前状态 |
| --- | --- |
| JSON Feed 1.1 | supported / initial stable |
| RSS 2.0 | supported / initial stable |
| RSS Podcast extensions | Apple Podcasts/iTunes core metadata supported |
| Atom 1.0 | Feed/Entry 文档入口与统一模型入口；完整兼容状态见下方矩阵 |
| Auto detection | supported |
| Date normalization | supported；保留原始字符串并提供 UTC Unix 秒 |
| CLI | supported |
| Mooncakes 发布 | `joanna/moonfeed@0.1.2` |

## Requirements

- MoonBit >= v0.10.14
- 当前开发验证使用 MoonBit `0.1.20260920` / `moonc v0.10.14+7d59c7ec9`。
- GitHub Actions 使用官方 `latest` 安装渠道并输出实际版本；本地开发验证固定使用 v0.10.14，CI 实际版本每次需结合日志确认。
- RSS 与 Atom XML 解析使用 MoonFeed 内部 `src/xmlmini` reader，不依赖第三方 XML registry 包。Atom 元素按 namespace URI 与 local name 识别；RFC 4287 尚未完整实现，详见 [兼容矩阵](docs/ATOM_RFC4287_COMPLIANCE.md)。

实现依据：[JSON Feed 1.1 规范](https://www.jsonfeed.org/version/1.1/) 和 [RSS 2.0 规范](https://www.rssboard.org/rss-specification)。

## 安装与运行

从 Mooncakes 安装已发布的 `0.1.2`：

```sh
moon add joanna/moonfeed@0.1.2
```

本次新增的 `parse_atom_document` 等 Atom 文档 API 目前仅在 Git main，尚未发布到 Mooncakes；已发布 `0.1.2` 不包含这些新增 API。

也可以从 GitHub 源码运行和开发：

```sh
git clone https://github.com/jojochensmart-lab/moonfeed.git
cd moonfeed
moon --version
moonc -v
moon check
moon test
moon build
moon run examples/basic
```

模块名称为 `joanna/moonfeed`，对应 Mooncakes 账号 `joanna`；GitHub 项目属于 `jojochensmart-lab`。发布版本可在 [Mooncakes](https://mooncakes.io/docs/joanna/moonfeed) 查看。

## CLI

从仓库源码运行 CLI（需要 Node.js；当前提供 MoonBit/Node.js 运行入口，不提供独立 native executable）：

```sh
moon run cli --target js -- detect fixtures/rss/full.xml
moon run cli --target js -- inspect fixtures/atom/full.xml
moon run cli --target js -- normalize fixtures/jsonfeed/full.json
```

`inspect` 最多显示前 5 条；`normalize` 输出统一 Feed JSON：Feed 包含 `title`、`description`、链接、语言、作者、分类和条目；条目包含 id、标题、URL、summary/content、发布日期与更新日期、作者、分类和 attachments。可选值为 `null`，集合为空时为 `[]`；日期保留原始字符串并附带 UTC Unix 秒。路径使用 `-` 可从 stdin 读取。命令错误写入 stderr 并以状态码 2 退出；成功返回 0。

示例概要：

```text
Format: RSS 2.0
Title: Example Feed
Items: 2
```
## 当前限制

MoonFeed 只解析传入的 JSON/XML 文本或文件，不抓取远程 URL，也不做 HTML autodiscovery。RSS 的 Apple Podcasts/iTunes 扩展支持常用节目与单集元数据；Media RSS 等其他扩展尚未纳入统一模型。Atom 不支持 AtomPub。Git main 的 Atom 文档 API 已支持独立 Entry、XML Base 和专用元数据；完整 XML 1.0、LEIRI、namespace URI 及部分历史 email/MIME 词法规则仍有缺口，因此不宣称完整 RFC 4287 兼容。详见 [ARCHITECTURE](docs/ARCHITECTURE.md) 和 [RFC 4287 兼容矩阵](docs/ATOM_RFC4287_COMPLIANCE.md)。

## API 示例

在使用方的 `moon.pkg` 中加入：

```moonbit
import { "joanna/moonfeed" }
```

统一入口会按内容识别 JSON Feed 1.1、RSS 2.0 或 Atom 1.0：

```moonbit
let feed = @moonfeed.parse(input)
```

也可以显式调用 `parse_json_feed`、`parse_rss` 或 `parse_atom`。统一 `parse` 的错误保留检测错误或对应格式 parser 的 typed error。

解析 JSON Feed：

```moonbit
test {
  let feed = @moonfeed.parse_json_feed(
    #|{"version":"https://jsonfeed.org/version/1.1","title":"News","items":[]}
  )
  assert_eq(feed.title, "News")
}
```

解析 RSS 2.0：

```moonbit
test {
  let feed = @moonfeed.parse_rss(
    #|<rss version="2.0"><channel><title>News</title><link>https://example.org/</link><description>Updates</description></channel></rss>
  )
  assert_eq(feed.title, "News")
  assert_eq(feed.home_page_url, Some("https://example.org/"))
}
```

显式入口和统一入口都返回统一的 `Feed` 模型，并保留 typed errors。完整错误匹配见 [可运行示例](examples/basic/main.mbt)。

## JSON Feed 1.1

支持 `version`、`title`、`description`、`home_page_url`、`feed_url`、`authors`、`language`、`items`，以及条目的 `id`、`title`、`url`、`external_url`、`summary`、`content_text`、`content_html`、`date_published`、`date_modified`、`authors`、`tags` 和 `language`。

`tags` 映射到 `categories`；日期映射到 `published` / `updated`，保留原字符串。条目作者和语言支持继承。当前对支持字段采用严格类型检查，重复 ID、缺少必填字段和无内容条目会拒绝整个 Feed。

## RSS 2.0

支持 RSS 2.0 的 channel 核心字段：`title`、`link`、`description`、`language`、`pubDate`、`lastBuildDate`、`managingEditor`、`webMaster`、重复 `category`、`generator`、`docs`、`ttl`、基础 `image` 和 `item`。

支持 item 字段：`title`、`link`、`description`、`author`、重复 `category`、`comments`、`enclosure`、`guid`、`pubDate` 和 `source`。解析由 MoonFeed 内部 `src/xmlmini` reader 完成，支持 XML 声明、注释、CDATA、五种基础实体、十进制和十六进制数字实体、原样保留的带前缀名称、空白、自闭合元素和 enclosure 属性。

- channel `link` → `Feed.home_page_url`；channel `category` → `Feed.categories`。
- channel `lastBuildDate` 优先、否则 `pubDate` → `Feed.updated`；选中的原始字符串保留，成功解析时另提供 Feed.updated_at。item pubDate 映射到 published / published_at。
- item `guid` → `FeedItem.id`；缺失 guid 时使用非空 `link`；两者都缺失时返回 `InvalidRequiredField`，不生成随机 ID。
- item `description` → `summary` 和 `content_html`；RSS 不声明内容是否为 HTML，因此保留同一原始值。
- item `author` → 单个 `Author.name`；item `category` → `FeedItem.categories`。
- `enclosure` 的 `url`、`type`、`length` → `Attachment.url`、`mime_type`、`size_in_bytes`。

RSS 错误包括 `InvalidXml`、`UnsupportedRssVersion`、`MissingChannel`、channel 必填字段错误、`InvalidEnclosure` 和带字段路径的 `InvalidRequiredField`。

## RSS Podcast extensions

`parse(...)` 和 `parse_rss(...)` 会把 RSS 单集的 `itunes:duration` 映射到对应 enclosure 的 `Attachment.duration_in_seconds`。需要读取更多 Podcast 专用字段时，使用 `parse_podcast_rss(...)`，它返回 `{ feed, show, episodes }`，不会改变格式通用的 `Feed` / `FeedItem` 类型。

```moonbit
let podcast = @moonfeed.parse_podcast_rss(input)
let show_author = podcast.show.author
let categories = podcast.show.categories
let first_episode = podcast.episodes[0]
let duration = first_episode.duration_in_seconds
```

当前识别 RSS 根元素或 channel 上声明的标准 `itunes` namespace URI，并保留 `itunes:` 前缀。节目元数据包括 author、owner、subtitle、summary、explicit、image、category/subcategory、type、complete 和 new-feed-url；单集元数据包括 subtitle、summary、image、duration、episode/season number、episode type、explicit 和 block。显式标记接受 `yes` / `true`、`no` / `false` 与 `clean`，并规范化为 Bool。

时长接受 `SS`、`MM:SS` 和 `HH:MM:SS`，其中多段格式的秒字段以及三段格式的分钟字段须在 0–59 范围内。无效时长、布尔值或分类属性会返回带字段路径的 RSS typed error。Podcast API 目前只认标准 `itunes:` 前缀和其官方 namespace URI，不解析任意前缀绑定；嵌套分类支持一层子分类。

`itunes:duration` 示例：`01:02:03` 会规范化为 3723 秒，并同时出现在 `podcast.episodes[0].duration_in_seconds` 与 `podcast.feed.items[0].attachments[0].duration_in_seconds` 中。

## Atom 1.0

### Atom 文档与标准校验入口（Git main）

使用 `parse_atom_document(input)` 解析 Feed Document 或独立 Entry Document。结果是 `AtomDocument::FeedDocument` 或 `AtomDocument::EntryDocument`，两种根节点保持各自语义。需要提供检索地址时使用 `parse_atom_document_with_base(input, document_uri)`。相关类型已从根模块导出，只需 import `joanna/moonfeed`。

```moonbit
test {
  let document = @moonfeed.parse_atom_document(
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.org/news/"><id>urn:entry:demo</id><title>MoonFeed</title><updated>2026-10-20T12:00:00Z</updated><author><name>MoonBit</name></author><link href="../article"/><content>Hello</content></entry>
  )
  match document {
    @moonfeed.AtomDocument::EntryDocument(entry) => {
      assert_eq(entry.metadata.id, Some("urn:entry:demo"))
      assert_eq(entry.metadata.links[0].href.raw, "../article")
      assert_eq(entry.metadata.links[0].href.resolved, "https://example.org/article")
      assert_eq(entry.content.unwrap().value, "Hello")
    }
    _ => fail("expected Entry Document")
  }
}
```

文档 API 校验已实现的 RFC 4287 必需字段、单值数量、作者存在与继承、结构、链接和正文约束。它保留 ID、全部 link/category 属性、source、author/contributor、email、rights、generator、icon/logo；text/html/xhtml/XML/其他 MIME 内容、外部 `src` 和 Base64 解码均有专用结构。`metadata.raw` 等展开名称树保留扩展元素、属性和顺序，不承诺原始前缀或字节级 XML 往返。

`IriReference` 区分 `raw`、`resolved` 和 `is_absolute`。基地址按 XML Base 作用域和 RFC 3986 算法计算，支持查询、片段、空值与 LEIRI；未提供绝对基地址时，相对结果会明确标为非绝对。ID 保留原始字符身份，不参与基地址解析。未提供类型的外部 content 保留 `media_type = None`。

`AtomDate` 保留原始字符串、完整小数位、`-00:00` 与闰秒标记，并提供 POSIX Unix 秒；已公告正闰秒和年 0000 有测试。闰秒在 POSIX 秒上与随后一秒重合，精确身份需同时查看标记与原始值。闰秒表需随未来 IERS 公告维护。

严格文档入口已校验 RFC 3066 语言标签语法、`hreflang` 和 alternate 链接组合；`xml:lang` 支持继承、覆盖、空值清除，保留原大小写，不查询语言注册表。XML reader 处理行尾与属性字面空白规范化，字符引用保留原字符；严格入口验证 XML 声明位置和字段，普通处理指令被跳过。IRI 增加 IPv6/IPvFuture 与 Unicode/private-use 范围校验；MIME 支持注释、折行、quoted 参数和保留参数意义的比较。

运行 `moon run examples/atom` 可验证默认 namespace 与任意前缀的独立 Entry 得到等价结果。迁移与版本策略见 [API_COMPATIBILITY](docs/API_COMPATIBILITY.md)，独立测试见 [conformance fixtures](fixtures/atom/conformance/README.md)。完整支持边界、已知缺口见 [兼容矩阵](docs/ATOM_RFC4287_COMPLIANCE.md)。

### 现有统一模型入口与迁移

`parse_atom` 和统一 `parse` 保持原来的 `Feed` 返回类型与历史常用字段规范化行为，只接受 Feed 根节点，不能用来返回独立 Entry。它们保留原有宽松输入行为，不是完整 RFC 校验器；要求本阶段校验或完整 Atom 元数据的调用方应迁移到上述文档入口。新入口会拒绝旧入口可能接受的相对 ID、缺少作者/内容链接、无效可选日期等输入，错误仍为带字段路径的 Atom typed error。

通过 `parse_atom` 解析 Atom 1.0 并规范化到统一模型。支持 feed 的 id/title/subtitle/updated、作者、category 和 self/alternate link，以及 entry 的 id/title/updated/published、作者继承、category、summary、content 和 enclosure link。category 的 term 映射到 categories；日期保留原始字符串，成功解析后另提供 updated_at / published_at。Atom 的 required updated 必须可解析。

- feed rel=self 映射到 Feed.feed_url；rel=alternate 或未指定 rel 映射到 Feed.home_page_url。
- entry rel=alternate 或未指定 rel 映射到 FeedItem.url；rel=enclosure 映射到 Attachment 的 href、type、title、length。
- entry 没有 author 时继承 feed authors；entry 自己声明 author 时使用 entry authors。Atom contributors 不并入 authors。
- text（含缺省 type）写入 content_text；html 写入 content_html；xhtml 提取可读文本后写入 content_html。
- Feed id、rights、generator、icon/logo、作者 email、contributors、entry rights/source，以及未知 rel 链接目前没有统一模型字段，因此解析后不保留。扩展节点被忽略。
- Atom 标准元素必须属于 `http://www.w3.org/2005/Atom`，并按展开名称（namespace URI + local name）匹配。默认命名空间和任意合法前缀等价；同 local name 的其他 namespace 扩展节点不会被当作 Atom 字段。
- 内部 XML reader 支持默认/显式前缀绑定、作用域继承与重绑定、默认 namespace 清空、XML 保留前缀规则、无前缀属性不继承默认 namespace，以及重复展开属性检测。它仍是 Feed 专用子集 reader，不是完整 XML 处理器。
- 上述统一模型映射会丢弃模型中没有对应槽位的信息；需要 source、完整链接/分类或扩展数据时使用新的文档 API。它已经补齐独立 Entry、XML Base 和元数据访问，但仍不能宣称完整 RFC 4287 兼容。

最小调用：@moonfeed.parse_atom("<feed xmlns=\"http://www.w3.org/2005/Atom\"><id>urn:news</id><title>News</title><updated>2026-10-01T12:00:00Z</updated><entry><id>post-1</id><title>First post</title><updated>2026-10-01T12:00:00Z</updated><summary>Hello</summary></entry></feed>")，返回统一 Feed，条目 id 为 post-1。

```moonbit
test {
  let feed = @moonfeed.parse_atom(
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:news</id><title>News</title><updated>2026-10-01T12:00:00Z</updated><entry><id>post-1</id><title>First post</title><updated>2026-10-01T12:00:00Z</updated><summary>Hello</summary></entry></feed>
  )
  assert_eq(feed.items[0].id, "post-1")
}
```
## Date normalization

本节描述现有统一模型和通用日期 API 的行为。新的 Atom 文档 API 使用上文的 `AtomDate`，提供更严格的 Atom 日期检查和额外信息。

The existing published / updated fields retain the source date values produced by each format parser. When valid, adjacent published_at / updated_at fields contain a DateTime with the original raw string and normalized unix_seconds (Int64). Compare instants with DateTime::compare; serialize the integer value as needed.

This instant is 2002-10-02T13:00:00Z, represented as UTC Unix seconds. The public parse_datetime, parse_rfc3339, and parse_rss_datetime functions are available. For example:

~~~moonbit
let date = @moonfeed.parse_rss_datetime("Wed, 02 Oct 2002 13:00:00 GMT")
assert_eq(date.raw, "Wed, 02 Oct 2002 13:00:00 GMT")
assert_eq(date.unix_seconds, 1033563600L)
~~~

RFC 3339 accepts a required Z or numeric ±HH:MM offset. RSS dates accept an optional abbreviated English weekday, GMT / UTC, and numeric ±HHMM or ±HH:MM offsets. Other timezone abbreviations are rejected rather than guessed. Fractional seconds are validated and truncated to whole seconds. Leap seconds and years outside 0001–9999 are unsupported.

Malformed optional JSON Feed and RSS dates, and Atom published, do not reject the feed: their raw value remains available and the parsed field is None. Atom feed/entry updated is required and invalid values return a path-bearing typed Atom error.

## 开发与测试

```sh
moon info
moon fmt
moon check
moon test
moon build
```

当前共有 137 个行为测试：本轮原有 117 项保持不变，新增 20 项独立规范测试，覆盖语言、XML 声明/规范化、namespace、IRI、MIME/email 和 API 兼容边界。默认与 JS 目标均通过。此前 Atom 文档、XML Base、结构/作者/内容约束、日期及 RFC 正式向量均保留。RSS、JSON Feed、日期及 CLI 回归均保留。可运行示例为 `moon run examples/basic` 与 `moon run examples/atom`。

黑客松初审整改记录见 [HACKATHON_REVIEW_RESPONSE](docs/HACKATHON_REVIEW_RESPONSE.md)，重新申报草稿见 [十月重新申报材料](docs/HACKATHON_RESUBMISSION_2026_10.md)。矩阵当前为 19 PASS / 8 PARTIAL / 0 FAIL；仍不宣称完整 RFC 4287 兼容。

## Roadmap

- 已完成：统一模型、JSON Feed 1.1、RSS 2.0、Atom 1.0、RSS Podcast 核心扩展、测试、文档、CI 和 Mooncakes `joanna/moonfeed@0.1.2` 发布。
- 当前优先：补齐 Atom 相关 XML 1.0、剩余 LEIRI/namespace URI/历史 email/MIME 规则与闰秒维护，按已记录的 API 迁移策略，逐项完成 RFC 4287 兼容矩阵。

当前支持 JSON Feed 1.1、RSS 2.0 与 Atom 1.0。设计取舍见 [ARCHITECTURE](docs/ARCHITECTURE.md)。

## License

[Apache-2.0](LICENSE).
