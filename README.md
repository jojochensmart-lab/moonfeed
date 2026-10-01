# MoonFeed

面向 MoonBit 生态的多格式 Feed 解析与规范化基础库，把 RSS、Atom 和 JSON Feed 转换为统一的 `Feed` / `FeedItem` 模型。

## 支持状态

| 格式 / 能力 | 当前状态 |
| --- | --- |
| JSON Feed 1.1 | supported / initial stable |
| RSS 2.0 | supported / initial stable |
| Atom 1.0 | planned |
| 日期统一解析 | planned；当前保留原始字符串 |
| 格式自动检测、CLI | planned |
| Mooncakes 发布 | 尚未发布 |

## Requirements

- MoonBit >= v0.10.14
- 当前开发验证使用 MoonBit `0.1.20260920` / `moonc v0.10.14+7d59c7ec9`。
- GitHub Actions 固定使用同一 v0.10.14 工具链系列；后续兼容的新版本也可能可用，但每次升级都需要重新验证。
- RSS / Atom 的 XML 能力来自 Apache-2.0 许可的 `Milky2018/xml@0.5.0`。

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

两个入口都返回统一的 `Feed` 模型，并抛出各自的 typed error。完整错误匹配见 [可运行示例](examples/basic/main.mbt)。

## JSON Feed 1.1

支持 `version`、`title`、`description`、`home_page_url`、`feed_url`、`authors`、`language`、`items`，以及条目的 `id`、`title`、`url`、`external_url`、`summary`、`content_text`、`content_html`、`date_published`、`date_modified`、`authors`、`tags` 和 `language`。

`tags` 映射到 `categories`；日期映射到 `published` / `updated`，保留原字符串。条目作者和语言支持继承。当前对支持字段采用严格类型检查，重复 ID、缺少必填字段和无内容条目会拒绝整个 Feed。

## RSS 2.0

支持 RSS 2.0 的 channel 核心字段：`title`、`link`、`description`、`language`、`pubDate`、`lastBuildDate`、`managingEditor`、`webMaster`、重复 `category`、`generator`、`docs`、`ttl`、基础 `image` 和 `item`。

支持 item 字段：`title`、`link`、`description`、`author`、重复 `category`、`comments`、`enclosure`、`guid`、`pubDate` 和 `source`。解析由 `Milky2018/xml@0.5.0` 完成，支持 XML 声明、CDATA、实体、命名空间忽略、空白、自闭合元素和 enclosure 属性。

- channel `link` → `Feed.home_page_url`；channel `category` → `Feed.categories`。
- channel `lastBuildDate` 优先、否则 `pubDate` → `Feed.updated`；两者都保留原始字符串。
- item `guid` → `FeedItem.id`；缺失 guid 时使用非空 `link`；两者都缺失时返回 `InvalidRequiredField`，不生成随机 ID。
- item `description` → `summary` 和 `content_html`；RSS 不声明内容是否为 HTML，因此保留同一原始值。
- item `author` → 单个 `Author.name`；item `category` → `FeedItem.categories`。
- `enclosure` 的 `url`、`type`、`length` → `Attachment.url`、`mime_type`、`size_in_bytes`。

RSS 错误包括 `InvalidXml`、`UnsupportedRssVersion`、`MissingChannel`、channel 必填字段错误、`InvalidEnclosure` 和带字段路径的 `InvalidRequiredField`。

## 开发与测试

```sh
moon info
moon fmt
moon check
moon test
moon build
```

当前共有 27 个行为测试，其中 15 个覆盖 JSON Feed，12 个覆盖 RSS 解析、规范化、CDATA、实体、namespace、重复 category、空白、自闭合元素、enclosure、日期和错误路径。`fixtures/rss/` 包含最小、完整、多条目和 Podcast 风格的小型自构造样例；不复制第三方商业 Feed。

## Roadmap

- 已完成：统一模型、JSON Feed 1.1、RSS 2.0 初始稳定切片、测试、文档和 CI。
- 后续：Atom 1.0、格式检测、日期统一解析、RSS 扩展 namespace、CLI、性能和 Mooncakes 发布。

本阶段止于 RSS 2.0，不实现 Atom。设计取舍见 [ARCHITECTURE](docs/ARCHITECTURE.md)。

## License

[Apache-2.0](LICENSE).
