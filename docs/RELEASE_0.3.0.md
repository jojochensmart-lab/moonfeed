# MoonFeed 0.3.0

模块：`joanna/moonfeed@0.3.0`。许可证：Apache-2.0。最低 MoonBit：v0.10.14。

本版本汇集此前 main 的功能增量及正式验收整改，不修改既有 parser 签名或统一模型字段类型。0.2.0 不包含这些增量。

## 发布内容

- RSS 2.0 仅 description、仅 title 或两者都有的 item 不再因为缺少可选 guid/link 被拒绝。已有 guid 优先、非空 link 回退；来源身份缺失时 `id = ""`，缺少链接时 `url = None`，不生成假 ID。title/description 至少存在一个的校验保留。
- 共享 XML Reader/NamespaceReader 检查完整单根文档：拒绝根前后文本、第二个根、根外 CDATA 和引用；合法 XML 空白、注释、处理指令继续接受，尾随非法或未闭合标记会报错。
- JSON Feed 1.1 附件映射到已有 Attachment，保留有序 URL、MIME、标题、UInt64 字节数和时长，并校验类型与数值范围。
- 根包导出 Feed、FeedItem、Author、Attachment、FeedLink、Podcast 类型和 FeedFormat。CLI 版本同步为 0.3.0，规范化 JSON 保留 item language。
- 包含 RSS namespace/语言、Atom 继承数组、日期溢出、XML 错误原因保留及受限内部 DTD 等此前未发布改进。
- 库测试 180 项，保留原 160 项并新增 20 项专项回归；六个示例覆盖三格式、独立 Entry、自动识别和错误处理。

## 安装与评审复现

```sh
moon add joanna/moonfeed
```

确认使用方 `moon.mod` 中为 `joanna/moonfeed@0.3.0`。需要精确指定时使用 `moon add joanna/moonfeed@0.3.0`。

仓库提供独立调用方测试模板及安装脚本：

```sh
node scripts/verify-registry.mjs D:/DevCache/Temp/moonfeed-030-install
```

目录必须不存在且位于仓库外。脚本使用官方 moon new / moon add，不使用 workspace、源码复制或 path/GitHub 依赖；检查 latest 安装声明精确落在 0.3.0，再写入调用方自己的 10 项 smoke，执行默认 wasm-gc 和 JS 的 check/test/build。样例覆盖正文/标题独立 RSS、可选身份、多条目、合法/非法 XML 边界、Atom Feed/Entry、JSON Feed 及附件、公开类型、日期和探测。

源码验收为 `node scripts/verify.mjs`，包括双目标 180 项测试、六示例及 CLI 正反 smoke。最低版本另行验证。发布需要先核对对应 GitHub HEAD 的 CI 成功，再执行一次正式 moon publish；registry 查询及实际安装结果单独记录，不能用源码通过代替安装验证。

## 兼容性与边界

空 RSS ID 表示缺少来源身份，不保证唯一。库保留有序条目数组，不按空 ID 去重；调用方不能将空字符串直接作为唯一索引键。XML 事件 Reader 用于完整文档，完整校验需消费到 Eof，不能当多根片段 tokenizer；detect_format 仍是前缀分类器。

RFC 4287 矩阵保持 **24 PASS / 3 PARTIAL / 0 FAIL**：XML 输入覆盖、历史 email quoted CR/LF、任意注册 MIME 参数等价仍有边界，不宣称完整兼容。参见 [兼容矩阵](ATOM_RFC4287_COMPLIANCE.md)。

本地 v0.10.18 和最低 v0.10.14 为零编译警告；官方 latest CI 的 v0.10.22 会提示现有 derive 及整数转换写法弃用，属于另行披露的维护事项，不在此次版本准备中迁移业务源码或抑制警告。

## 包内容审计

使用官方 moon package，从发布 commit 的独立 Git 快照构建并检查实际 ZIP：应包含解析器、模型、xmlmini、CLI、fixtures、六示例、README、LICENSE 和必要资源；不得包含申报原件、.git、凭据、临时文件或构建缓存。逐文件字节比对快照与 ZIP，再从 registry 下载的实际模块复核发布内容。`.moonignore` 排除三个申报书原件路径；原始材料及工作区有意重命名状态不进入发布提交。

包文件数量、最终 commit、对应 Actions、实际 registry 发布时间和安装目录以本轮实际交付报告为准，不预写不存在的结果。
