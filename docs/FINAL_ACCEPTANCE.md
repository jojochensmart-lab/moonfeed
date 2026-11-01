# MoonFeed 可复现验收

## 两套证据的版本边界

- 已发布 `joanna/moonfeed@0.2.0`：从 registry 新建项目安装，验证已发布 API 可调用。
- 当前源码工作区：含本轮 Unreleased 改进。源码测试结果不能冒充新发布版本，历史 GitHub Actions 也不能替代最终交付提交的远端验证。

当前本地工具链：Moon CLI 0.1.20261028 / moonc v0.10.18+6c83a7f62，Node.js v24.22.1。源码最低要求仍为 MoonBit v0.10.14；CI 使用官方 latest 并输出版本。

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

`moon info` 使用主工具链更新接口；格式化命令必须在 v0.10.14 工具链环境执行，以保持源码最低语法。实测 v0.10.18 格式器会自动迁移 Int 为 Int32，后者会使 v0.10.14 编译报类型不存在。本轮已恢复 Int 写法，使用 v0.10.14 格式器通过检查，并在最低版本默认/JS 各通过 160 项测试。主工具链仍为 v0.10.18；没有降级 moon.pkg、引入兼容层或提高最低版本。生成 mbti 中的 Int32 是新编译器的接口显示，源码需保持可被最低版本解析。

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

目标目录必须不存在；脚本不会覆盖既有目录。它使用正式 `moon new` 和 `moon add joanna/moonfeed@0.2.0`，不复制仓库源码、不设置 moon.work、不使用 GitHub/path dependency；正常使用 registry 的下载与缓存机制。

写入调用方自己的四个 smoke 测试，依次验证 JSON Feed、RSS enclosure、Atom Feed/独立 Entry、格式/日期/异常处理，再执行默认 wasm-gc 与 JS 的 check/test/build 和依赖树。`moon.pkg` 的仅测试导入应使用 `for "test"`；0.2.0 的 FeedFormat 可在推断上下文用 `is Rss` 匹配，不能误用根 ParseError 的同名 Rss 构造器。本轮源码另重导出了 FeedFormat，可显式使用 `@moonfeed.FeedFormat::Rss`。

本轮真实首次 clean install 目录为 `D:\DevCache\Temp\moonfeed-registry-review-20261101T152144Z`：新工具链 registry 中此前没有 MoonFeed 包，正常下载精确 0.2.0，四项测试在 wasm-gc/JS 各 4/4，check/build 通过。新项目初始化曾提示 Windows 无权建立 README 符号链接，但初始化返回成功，编译和调用不受影响；没有修改权限或系统安全策略。

## 包清单与个人材料

```sh
moon package --list
moon package
```

`.moonignore` 精确排除根目录 `申报书.md`、`docs/申报书final.md` 和仍在 Git 中追踪的旧路径 `docs/HACKATHON_RESUBMISSION_FINAL.md`。应确认所有原件路径都不出现在包清单，也不复制其内容到公开技术材料。功能实现对照表是脱敏的技术审计，原件内容未改动。

## 本轮验收结论与人工事项

本轮源码默认/JS 各 160/160；原 147 项保留，新增 13 项针对性测试。六示例双目标及 CLI 正反 smoke 通过，依赖树为空；无公开 API 删除或模型字段布局变更。新增功能与校验收紧见 CHANGELOG 和 API_COMPATIBILITY。

RFC 矩阵为 24 PASS / 3 PARTIAL / 0 FAIL：XML 输入覆盖、任意注册 MIME 参数等价、历史 email quoted CR/LF 仍未完整。DTD validity 验证与联网抓取不应混同为 Atom 消费器的必需功能。若评审要求完整 RFC，须先约定并完成这些标准边界。

申报技术状态已同步到独立的 [终审申报补充说明](终审申报补充说明.md)，原件保持不变。本次已获授权提交、普通推送并核验最新 HEAD 的 CI；实际 hash/run URL/结果记录在最终交付报告。后续发布仍需统一候选版本、完成对应 CI、取得发布授权，并从 registry 精确安装复现；本轮不执行 Mooncakes 发布。


最终实际 ZIP 清单检查：两份申报书原件均为 0 条命中；解析器、xmlmini、示例与验收脚本均实际存在。这个 ZIP 只是本地 package 验收产物，没有上传 registry。Registry 调用样例单独保存在 `scripts/registry-smoke.mbt.txt`，不占用库的测试数量。


## 本轮文件清单

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
