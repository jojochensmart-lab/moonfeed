# MoonFeed 0.3.1 最终代码审查

日期：2026-11-24；维护分支 `maintenance/0.3.1`。本轮将累计维护改动提交到该分支并验证其精确 HEAD 的 GitHub CI；模块和 CLI 版本仍为 0.3.0，不执行 Mooncakes 发布，不改 main 或历史提交。

## A：累计实体预算

Reader 创建一次 XmlBudget，NamespaceReader 仅包装同一个 Reader；DOCTYPE EntityValue、属性默认值校验/应用、属性、文本和 CDATA 使用共享预算，不会在嵌套或跨事件处重置。每个引用收费，空帧收费；实体展开和声明依赖图均使用显式栈。循环依赖有错误，资源耗尽后继续读取仍返回固定资源错误。外部实体不读取。

最终审查新增 Reader 的合法前向空实体用例：声明一次引用，属性与文本分别需要两次引用；预算 5 精确通过，预算 4 在文本处明确失败。NamespaceReader 对同一路径也失败，验证 wrapper 不会重置预算。既有空/指数展开、深度、循环、输出字节、工作量及声明阶段数字引用的独立安全测试保留。

该审查不将工作计数宣传为整个进程的硬 CPU/内存配额；计费范围和安全边界见 [安全整改报告](SECURITY_0.3.1_FIX.md)。没有扩大实体支持范围。

## B：合法前向引用

对照 [XML 1.0 §4.1 Entity Declared / No Recursion、§4.2、§5.1](https://www.w3.org/TR/REC-xml/)，实体声明依赖在内部子集读完后检查。通用实体在声明中引用后声明的实体仍可用；首次声明绑定不变。默认值在读取 ATTLIST 时检查其依赖，不能用最终实体表掩盖不允许的声明顺序。

`declarations_test.mbt` 断言合法前向引用后的属性与正文确为 v，并同时覆盖非法默认值顺序、未使用声明及 standalone 情况。新增的小预算用例也使用前向引用，证明没有通过全面禁用前向引用获得安全性。非验证型不等于忽略内部子集；部分声明顺序还涉及有效性约束，本实现不声称进行完整 DTD 实例验证。

## C：MIME 参数与修复

发现原实现对所有名为 charset 的参数值小写，包括未知私有类型，可能使不同 alternate 组合误判重复。根据 [RFC 2045 §5.1](https://www.rfc-editor.org/rfc/rfc2045.html#section-5.1)，值通常敏感，例外需有参数语义依据，不能仅凭参数名全局折叠。

现在只对以下核验范围折叠 charset 值：text/plain（[RFC 2046 §4.1.2](https://www.rfc-editor.org/rfc/rfc2046.html#section-4.1.2)）、text/html（[RFC 2854 §2](https://www.rfc-editor.org/rfc/rfc2854.html#section-2)）、application/xml 与 text/xml（[RFC 7303](https://www.rfc-editor.org/rfc/rfc7303.html)）、application/atom+xml（[RFC 4287 §7](https://www.rfc-editor.org/rfc/rfc4287.html#section-7)）、application/xhtml+xml（[RFC 3236 §2](https://www.rfc-editor.org/rfc/rfc3236.html#section-2)）。此有限表不是所有 text/+xml 或任意注册类型语义的完整实现；未涵盖类型采用保守值比较，仍属 A20 PARTIAL。

保留类型/子类型/参数名大小写不敏感、quoted 值解码及参数次序规则。已核验的 Atom type、text/plain format/delsp 和 external-body 例外保留。multipart/related 仅将内嵌 type/subtype 归一化；boundary/profile/start/start-info 等值不整体小写，原始属性完整保留。重复已知 related 单值参数拒绝，未知重复参数仍保留次数，未借本轮扩展为完整现代注册参数验证器。

新增公共 API 测试验证未知/private 值不同的两个链接被保留，而六类已核验 charset 的大小写变体仍报精确重复链接错误；原有 boundary、profile、未知参数、entry/feed、flowed/fixed 正反用例保留。

## 验证与兼容

原维护基线 218 项不删除、不降低断言；新增 4 项，总计 222 项。生成接口共 19 份保持兼容；本轮新增函数与状态均为私有实现。原 0.3.0 的 derive 标记转成等价显式 pub impl，保留方法、trait、错误 variant 与布局，最低工具链仍为 v0.10.14。

三版完整回归命令：分别设置进程 MOON_HOME 后执行 `node scripts/verify.mjs`。验收覆盖默认/JS check/test/build、六示例双目标、CLI 正反与 UTF-8/实体安全 smoke、无第三方依赖。原始日志及汇总存放在本地 `_build/final031/`，不提交构建产物。最终交付报告应引用提交后的精确 HEAD 和实际 CI URL，不能复用旧 0.3.0 的 CI 证明本分支。

| Moonc | 默认 | JS | check/build 双目标、六示例双目标、CLI | warning |
| --- | ---: | ---: | --- | ---: |
| v0.10.14+7d59c7ec9 | 222/222 | 222/222 | PASS | 0 |
| v0.10.18+6c83a7f62 | 222/222 | 222/222 | PASS | 0 |
| v0.10.22+124d61d05 | 222/222 | 222/222 | PASS | 0 |

现有 workflow 的 push 仅匹配 main；维护分支使用已经配置的 workflow_dispatch 运行同一套检查，不改变安装方式或跳过步骤。

RFC 矩阵仍为 **25 PASS / 2 PARTIAL / 0 FAIL**。本地达标且最新提交 CI 通过后，建议进入 0.3.1 正式发布准备；版本更新、包审计、Mooncakes 发布及 registry 全新安装属于下一轮确认范围。

申报书原件与用户有意的重命名不暂存、不上传；提交仅包含技术源码、测试、生成接口和相关技术文档。不使用 force push，不创建 merge commit，不重写历史。
