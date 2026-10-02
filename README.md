# MoonFeed

面向 MoonBit 生态的多格式 Feed 解析与规范化基础库，把 RSS、Atom 和 JSON Feed 转换为统一的 `Feed` / `FeedItem` 模型。

## 支持状态

| 格式 / 能力 | 当前状态 |
| --- | --- |
| JSON Feed 1.1 | supported / initial stable |
| RSS 2.0 | supported / initial stable |
| Atom 1.0 | supported |
| Auto detection | supported |
| 日期统一解析 | planned；当前保留原始字符串 |
| CLI | planned |
| Mooncakes 发布 | 尚未发布 |

## Requirements

- MoonBit >= v0.10.14
- 当前开发验证使用 MoonBit `0.1.20260920` / `moonc v0.10.14+7d59c7ec9`。
- GitHub Actions 使用官方 `latest` 安装渠道并输出实际版本；本地开发验证固定使用 v0.10.14，CI 实际版本每次需结合日志确认。
- RSS 与 Atom XML 解析使用 MoonFeed 内部的 src/xmlmini 子集 reader，不依赖第三方 XML registry 包。

实现依据：[JSON Feed 1.1 规范](https://www.jsonfeed.org/version/1.1/) 和 [RSS 2.0 规范](https://www.rssboard.org/rss-specification)。

## 安装与运行

本库尚未发布到 Mooncakes，请从源码使用：

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

模块名称为 `joanna/moonfeed`，采用当前 Mooncakes 账号命名空间；GitHub 项目属于 `jojochensmart-lab`。发布前可能调整模块名，请勿假定已经可以通过 `moon add joanna/moonfeed` 从注册中心安装。

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
- channel `lastBuildDate` 优先、否则 `pubDate` → `Feed.updated`；两者都保留原始字符串。
- item `guid` → `FeedItem.id`；缺失 guid 时使用非空 `link`；两者都缺失时返回 `InvalidRequiredField`，不生成随机 ID。
- item `description` → `summary` 和 `content_html`；RSS 不声明内容是否为 HTML，因此保留同一原始值。
- item `author` → 单个 `Author.name`；item `category` → `FeedItem.categories`。
- `enclosure` 的 `url`、`type`、`length` → `Attachment.url`、`mime_type`、`size_in_bytes`。

RSS 错误包括 `InvalidXml`、`UnsupportedRssVersion`、`MissingChannel`、channel 必填字段错误、`InvalidEnclosure` 和带字段路径的 `InvalidRequiredField`。

## Atom 1.0

通过 `parse_atom` 解析 Atom 1.0 并规范化到统一模型。支持 feed 的 id/title/subtitle/updated、作者、category 和 self/alternate link，以及 entry 的 id/title/updated/published、作者继承、category、summary、content 和 enclosure link。category 的 term 映射到 categories；日期保留原始字符串。

- feed rel=self 映射到 Feed.feed_url；rel=alternate 或未指定 rel 映射到 Feed.home_page_url。
- entry rel=alternate 或未指定 rel 映射到 FeedItem.url；rel=enclosure 映射到 Attachment 的 href、type、title、length。
- entry 没有 author 时继承 feed authors；entry 自己声明 author 时使用 entry authors。Atom contributors 不并入 authors。
- text（含缺省 type）写入 content_text；html 写入 content_html；xhtml 提取可读文本后写入 content_html。
- Feed id、rights、generator、icon/logo、作者 email、contributors、entry rights/source，以及未知 rel 链接目前没有统一模型字段，因此解析后不保留。扩展节点被忽略。
- namespace 策略接受默认 Atom namespace、无前缀名称和 atom: 前缀；不核验 namespace URI，也不实现通用 namespace engine。

最小调用：@moonfeed.parse_atom("<feed xmlns=\"http://www.w3.org/2005/Atom\"><id>urn:news</id><title>News</title><updated>2026-10-01T12:00:00Z</updated><entry><id>post-1</id><title>First post</title><updated>2026-10-01T12:00:00Z</updated><summary>Hello</summary></entry></feed>")，返回统一 Feed，条目 id 为 post-1。

```moonbit
test {
  let feed = @moonfeed.parse_atom(
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:news</id><title>News</title><updated>2026-10-01T12:00:00Z</updated><entry><id>post-1</id><title>First post</title><updated>2026-10-01T12:00:00Z</updated><summary>Hello</summary></entry></feed>
  )
  assert_eq(feed.items[0].id, "post-1")
}
```
## 开发与测试

```sh
moon info
moon fmt
moon check
moon test
moon build
```

当前共有 53 个行为测试：15 个 JSON Feed、12 个 RSS、5 个 xmlmini、12 个 Atom 和 9 个自动检测/统一入口测试。`fixtures/rss/` 包含最小、完整、多条目和 Podcast 风格的小型自构造样例；不复制第三方商业 Feed。

## Roadmap

- 已完成：统一模型、JSON Feed 1.1、RSS 2.0、Atom 1.0、测试、文档和 CI。
- 后续：日期统一解析、RSS 扩展 namespace、CLI、性能和 Mooncakes 发布。

当前支持 JSON Feed 1.1、RSS 2.0 与 Atom 1.0。设计取舍见 [ARCHITECTURE](docs/ARCHITECTURE.md)。

## License

[Apache-2.0](LICENSE).
