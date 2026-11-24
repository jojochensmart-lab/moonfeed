# MoonFeed 可复现验收

## 0.3.1 发布验收（当前）

0.3.1 在 0.3.0 基线上加入实体显式栈与累计资源预算、NDATA/默认值声明校验、multipart/related 和未知 charset 语义修复，以及 v0.10.22 弃用警告迁移。公开接口兼容，默认/JS 各 222 项测试，三版工具链（v0.10.14/v0.10.18/v0.10.22）验证零编译警告。矩阵为 25 PASS / 2 PARTIAL，不宣称完整 RFC 4287。

发布 gate：正式版本元数据与 CLI 对齐 -> 官方打包且排除申报书/凭据/缓存 -> 三版完整回归 -> 安全快进 main -> 最新 main CI 成功 -> 官方 publish 一次 -> 仓库外执行 `moon add joanna/moonfeed` 并确认精确 0.3.1 -> 默认、wasm-gc、JS 的公共 API smoke。参考 [0.3.1 发布说明](RELEASE_0.3.1.md)；以下旧轮次记录仅作为历史证据。

## 0.3.0 发布验收（历史）

0.3.0 汇集此前未发布的功能及 RSS/XML 专项修复，源码功能基线为 `1882818`。版本准备只更新版本元数据、CLI 版本常量/对应断言、安装验证脚本及技术文档；解析业务逻辑保持不变。发布顺序为本地回归与包审计、版本提交及对应成功 CI、官方 moon publish、仓库外 registry 安装复现。实际包文件数、发布时间及最终 HEAD 以真实交付记录为准。

完整版本内容与边界见 [RELEASE_0.3.0](RELEASE_0.3.0.md)。以下专项轮的“本轮不发布”属于当时的历史操作边界；当时授权发布的是 0.3.0，不覆盖旧版本。

## 2026-11-23 正式 RSS/XML 专项整改与最终交付

基线为 `9f9b407`，开始时默认目标 160/160、check/build 通过。专项修复先完成本地验证，最终交付重新独立审计后提交、普通推送并核验对应 HEAD 的 CI；不得将旧 HEAD 的 CI 或 registry 0.2.0 当作本轮修复证据。本轮不发布 Mooncakes。

- 仅 description、仅 title、两者都有且无 guid/link 的 RSS item 均可解析；来源标识缺失用 `id = ""`，URL 缺失用 `None`，不伪造 ID。
- 缺少 title 和 description 的 item（即使有 guid/link）继续按字段路径拒绝。公开 raw 模型和直接 normalize 同样保持此约束。
- 共享 XML Reader 统一拒绝根外文本、引用、CDATA、第二个根和无根文档；合法根外空白、注释、PI 可用，非法或未闭合的尾随标记会失败。
- 当前源码默认和 JS 各 180/180，原 160 项保留，新增 20 项；两处旧 RSS 不合规范的错误预期已更正。check/build 双目标、六示例双目标、CLI 正反 smoke 通过；无第三方依赖。
- 完整说明、复现输入及测试分布见 [RSS20_FORMAL_ACCEPTANCE_FIX](RSS20_FORMAL_ACCEPTANCE_FIX.md)。旧安装验收继续只证明已发布 0.2.0 可调用，不证明 registry 已含本修复；本轮不重新发布。

## 源码与 registry 证据的版本边界

- 当前发布版本为 `joanna/moonfeed@0.3.1`，包含完整 RSS/XML 修复、JSON 附件及公开类型增量；需由实际 registry 查询、安装和调用确认发布成功。
- 已发布的 0.2.0 是历史基线，不含此次增量。源码测试结果不能冒充 registry 安装验证，历史 GitHub Actions 也不能替代发布提交的远端验证。

当前本地工具链：Moon CLI 0.1.20261028 / moonc v0.10.18+6c83a7f62，Node.js v24.22.3。源码最低要求仍为 MoonBit v0.10.14；CI 使用官方 latest 并输出版本。

## 源码完整验收

```sh
moon version
moonc -v
node scripts/verify.mjs
```

Windows 已打开终端若仍继承旧环境，先在该进程设置：

```powershell
$env:MOON_HOME = 'D:\MoonBit'
$env:PATH = 'D:\MoonBit\bin;' + $env:PATH
node scripts/verify.mjs
```

该脚本运行默认与 JS 的 check/test/build、moon tree，再运行六个示例的两个目标。CLI 验证文件与 stdin、BOM/中文、字段映射、精确整数输出、help/version；错误输入必须 stderr 有消息、stdout 空且退出码 2。CI 复用 `--cli-only` 分支，在自身 check/test/build 后运行 CLI 检查。

```sh
moon info
moon fmt
moon fmt --check
```

`moon info` 使用主工具链更新接口；格式化命令必须在 v0.10.14 工具链环境执行，以保持源码最低语法。实测 v0.10.18 格式器会自动迁移 Int 为 Int32，后者会使 v0.10.14 编译报类型不存在。本轮保留 Int 写法，使用 v0.10.14 格式器通过检查，并在最低版本默认/JS 各通过 180 项测试，check/build 双目标通过。主工具链仍为 v0.10.18；没有降级 moon.pkg、引入兼容层或提高最低版本。生成 mbti 中的 Int32 是新编译器的接口显示，源码需保持可被最低版本解析。

## 示例对应验收路径

| 命令 | 断言与用途 |
| --- | --- |
| `moon run examples/basic` | JSON Feed 自动入口与错误分类 |
| `moon run examples/jsonfeed` | JSON 附件、语言与 UTC 日期 |
| `moon run examples/rss` | RSS CDATA、guid、enclosure、日期与自动入口等价 |
| `moon run examples/atom_feed` | 任意 Atom 前缀、扩展隔离、XML Base、作者继承 |
| `moon run examples/atom` | 默认与任意前缀的独立 Entry 逐字段等价 |
| `moon run examples/errors` | 缺失字段与非 Feed 输入的 typed error |

附加 `--target js` 可独立复核 JS 示例。`inspect`/`normalize` 只输出统一 Feed；独立 Entry 请使用文档 API。

## 新项目 registry 安装验收

```sh
node scripts/verify-registry.mjs D:/DevCache/Temp/moonfeed-install-review
```

目标目录必须不存在且在仓库外；脚本不会覆盖既有目录。它使用正式 `moon new` 和不带版本的 `moon add joanna/moonfeed`，随后必须断言 manifest 锁定 `joanna/moonfeed@0.3.1`，不复制库源码、不设置 moon.work、不使用 GitHub/path dependency；正常使用 registry 的下载与缓存机制。

写入调用方自己的 14 个 smoke 测试，覆盖 RSS 仅正文/仅标题/无 guid-link/多条目、根外文本等 XML 非法结构、合法 Misc、Atom Feed/独立 Entry、JSON Feed/附件、类型导出、探测/日期及错误处理，补充实体资源预算、非法声明与 MIME 语义断言，再执行默认、wasm-gc 与 JS 的 check/test/build 和依赖树。`moon.pkg` 的仅测试导入使用 `for "test"`；0.3.0 导出 FeedFormat，可显式使用 `@moonfeed.FeedFormat::Rss`，避免与根 ParseError 的同名 Rss 构造器混淆。

历史 0.2.0 首次 clean install 目录为 `D:\DevCache\Temp\moonfeed-registry-review-20261101T152144Z`，四项测试在 wasm-gc/JS 各 4/4，check/build 通过；这不能替代 0.3.0 的新安装证据。新项目初始化可能提示 Windows 无权建立 README 符号链接；只要初始化返回成功且检查/编译通过，无需修改系统安全策略。

## 包清单与个人材料

```sh
moon package --list
moon package
```

`.moonignore` 精确排除根目录 `申报书.md`、`docs/申报书final.md` 和仍在 Git 中追踪的旧路径 `docs/HACKATHON_RESUBMISSION_FINAL.md`。应确认所有原件路径都不出现在包清单，也不复制其内容到公开技术材料。功能实现对照表是脱敏的技术审计，原件内容未改动。

## 本轮验收结论与人工事项

当前源码默认/JS 各 180/180；上一轮 160 项保留，新增 20 项 RSS/XML 专项测试。六示例双目标及 CLI 正反 smoke 通过，依赖树为空；无公开 API 删除或模型字段布局变更。空 RSS ID 是缺失值，调用方不要将其当唯一键；行为修正与校验收紧见 CHANGELOG 和 API_COMPATIBILITY。

RFC 矩阵为 24 PASS / 3 PARTIAL / 0 FAIL：XML 输入覆盖、任意注册 MIME 参数等价、历史 email quoted CR/LF 仍未完整。DTD validity 验证与联网抓取不应混同为 Atom 消费器的必需功能。若评审要求完整 RFC，须先约定并完成这些标准边界。

上轮申报技术状态已同步到独立的 [终审申报补充说明](终审申报补充说明.md)，原件保持不变。上轮提交 `9f9b407` 已推送并通过 CI；本轮最终交付必须核对新的完整 HEAD、origin/main 与 Actions headSha 一致，并逐项确认 check、默认/JS test/build、示例和 CLI smoke 的结果。后续发布仍需统一候选版本、完成对应 CI、取得发布授权，并从 registry 精确安装复现；当前 GitHub 源码修复不等于 0.2.0 registry 包已更新。


上轮最终实际 ZIP 清单检查：两份申报书原件均为 0 条命中；解析器、xmlmini、示例与验收脚本均实际存在。这个 ZIP 只是本地 package 验收产物，没有上传 registry。Registry 调用样例单独保存在 `scripts/registry-smoke.mbt.txt`，不占用库的测试数量。本轮不以这份旧 ZIP 代替新源码验收。


## 2026-11-02 上轮交付文件清单（历史）

- `.github/workflows/ci.yml`
- `.moonignore`
- `CHANGELOG.md`
- `cli/main_wbtest.mbt`
- `cli/main.mbt`
- `CONTRIBUTING.md`
- `docs/申报书功能实现对照表.md`
- `docs/终审申报补充说明.md`
- `docs/API_COMPATIBILITY.md`
- `docs/ARCHITECTURE.md`
- `docs/ATOM_RFC4287_COMPLIANCE.md`
- `docs/FINAL_ACCEPTANCE.md`
- `docs/FINAL_DELIVERY_AUDIT.md`
- `docs/HACKATHON_RESUBMISSION_2026_10.md`
- `docs/HACKATHON_REVIEW_RESPONSE.md`
- `examples/atom_feed/main.mbt`
- `examples/atom_feed/moon.pkg`
- `examples/atom_feed/pkg.generated.mbti`
- `examples/errors/main.mbt`
- `examples/errors/moon.pkg`
- `examples/errors/pkg.generated.mbti`
- `examples/jsonfeed/main.mbt`
- `examples/jsonfeed/moon.pkg`
- `examples/jsonfeed/pkg.generated.mbti`
- `examples/rss/main.mbt`
- `examples/rss/moon.pkg`
- `examples/rss/pkg.generated.mbti`
- `moonfeed_test.mbt`
- `moonfeed.mbt`
- `pkg.generated.mbti`
- `podcast_test.mbt`
- `README.md`
- `review_regression_test.mbt`
- `rss.mbt`
- `scripts/registry-smoke.mbt.txt`
- `scripts/verify-registry.mjs`
- `scripts/verify.mjs`
- `src/atom/email.mbt`
- `src/atom/media.mbt`
- `src/atom/parser.mbt`
- `src/datetime/parser.mbt`
- `src/datetime/pkg.generated.mbti`
- `src/jsonfeed/parse.mbt`
- `src/model/model.mbt`
- `src/rss/normalize.mbt`
- `src/rss/parser.mbt`
- `src/rss/podcast.mbt`
- `src/xmlmini/pkg.generated.mbti`
