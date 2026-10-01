# MoonFeed

面向 MoonBit 生态的多格式 Feed 解析与规范化基础库。目标是把 RSS、Atom 和
JSON Feed 转换为统一的 `Feed` / `FeedItem` 模型。当前完成第一阶段：JSON Feed
1.1 的基础解析、规范化和结构化错误处理，不含网络抓取。

## 支持状态

| 格式 / 能力 | 当前状态 |
| --- | --- |
| JSON Feed 1.1 | partial / initial support，详见下方字段范围 |
| RSS 2.0 | planned |
| Atom 1.0 | planned |
| 格式自动检测、日期解析、CLI | planned |
| Mooncakes 发布 | 尚未发布 |

实现依据：[JSON Feed 1.1 规范](https://www.jsonfeed.org/version/1.1/)。

## 安装与运行

验证工具链：`moon 0.1.20260703`、`moonc v0.10.3+16975d007`，默认后端为
`wasm-gc`。本库仅使用 MoonBit 标准库，无第三方运行依赖。

本阶段未发布到 Mooncakes，请从源码使用：

```sh
git clone https://github.com/jojochensmart-lab/moonfeed.git
cd moonfeed
moon check
moon test
moon build
moon run examples/basic
```

模块名称为 `joanna/moonfeed`，采用当前 Mooncakes 账号命名空间；GitHub 项目属于
`jojochensmart-lab`。这两个名称不必相同。发布前可能调整模块名，请勿假定已经可以
通过 `moon add joanna/moonfeed` 从注册中心安装。

若在另一个本地项目中使用，可在共同父目录创建 `moon.work`：

```moonbit
members = ["moonfeed", "myapp"]
```

在 `myapp/moon.mod` 的依赖中加入：

```moonbit
import { "joanna/moonfeed@0.1.0" }
```

工作区会使用本地源码。参见 [MoonBit 本地依赖文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#dependency-management)。

## 最小示例

在使用方的 `moon.pkg` 中加入：

```moonbit
import { "joanna/moonfeed" }
```

```moonbit
test {
  let feed = @moonfeed.parse_json_feed(
    #|{"version":"https://jsonfeed.org/version/1.1","title":"News","items":[]}
  )
  assert_eq(feed.title, "News")
  assert_eq(feed.items.length(), 0)
}
```

## API 与错误处理

公共入口 `@moonfeed.parse_json_feed(String)` 返回
`@model.Feed`，并可能抛出 `@jsonfeed.ParseError`。
需要显式声明类型或匹配错误时，额外导入：

```moonbit
import {
  "joanna/moonfeed/src/model",
  "joanna/moonfeed/src/jsonfeed",
}
```

```moonbit
fn load(input : String) -> @model.Feed raise @jsonfeed.ParseError {
  @moonfeed.parse_json_feed(input)
}
```

错误类型：`InvalidJson(message)`、`MissingField(path)`、
`InvalidType(path, expected)`、`UnsupportedVersion(version)`、
`InvalidValue(path, message)`。字段路径示例：`$.items[0].id`。
完整的错误匹配和条目遍历见 [可运行示例](examples/basic/main.mbt)。

## 字段与规范化行为

Feed 支持 `version`、`title`、`description`、`home_page_url`、`feed_url`、
`authors`、`language`、`items`。仅接受版本 URL
`https://jsonfeed.org/version/1.1`；版本用于校验，不存入统一模型。

Item 支持 `id`、`title`、`url`、`external_url`、`summary`、`content_text`、
`content_html`、`date_published`、`date_modified`、`authors`、`tags`、`language`。
作者支持 `name`、`url`、`avatar`。

- `tags` 映射到 `categories`；日期映射到 `published` / `updated`，保留原字符串。
- 缺失的可选字符串为 `None`；空字符串与缺失值不同；缺失集合为空数组。
- Item 未声明 `authors` 时继承 Feed 作者；显式空数组保持为空，覆盖 Feed 作者。
- Item 未声明 `language` 时继承 Feed 语言；保留输入中的条目、作者和标签顺序。
- `version`、`title`、`items` 必须存在；Item 需要非空字符串 `id`，以及至少一种内容。
- 重复 Item ID、已支持字段类型错误（包括显式 `null`）会拒绝整个 Feed，不返回部分结果。
- 数字 ID 不做自动转换。本阶段采用严格策略，尚未实现规范建议的宽容恢复行为。

**明确限制：** 尚不解析附件、旧版 `author`、分页、图标、图片、hubs 和扩展字段；
这些字段被忽略。`Attachment` 与 `FeedLink` 已定义，Item 的 `attachments`
当前始终为空。Feed 的 `categories` 为空，`updated` 为 `None`，不会从条目推断。
日期、URL 和语言标签只验证字符串类型，不验证其格式；HTML 原样保留，未进行清洗。
本 API 接收完整字符串，不提供流式解析或 HTTP 请求。

## 开发与测试

```sh
moon info
moon fmt
moon check
moon test
moon build
```

当前 15 个行为测试覆盖最小 Feed、完整字段、多条目、作者继承和覆盖、tags、
纯文本、HTML、Unicode、非法 JSON、缺失必填字段、错误类型、重复 ID 与扩展忽略。
`fixtures/` 中的样本以 MoonBit 原始字符串保存，测试直接引用，避免依赖文件系统
和重复复制 JSON。生成的 `.mbti` 文件纳入版本管理以便审查公共接口变化。

## Roadmap

- 第一阶段：统一模型、JSON Feed 1.1 基础解析与规范化、测试、文档、CI。
- 后续：补全 JSON Feed 附件与兼容策略、RFC 3339 日期处理。
- 后续：RSS 2.0 与 Atom 1.0 解析、格式检测及更多真实样本。
- 后续：CLI、性能与兼容性验证、Mooncakes 发布。

本次工作止于第一阶段。结构与设计取舍见 [ARCHITECTURE](docs/ARCHITECTURE.md)。

## License

[Apache-2.0](LICENSE).
