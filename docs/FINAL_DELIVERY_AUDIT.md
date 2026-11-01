# 终审交付审计

审计日期：2026-11-02。基线为 2a3fc7b；本轮收束上一轮已实现改进，完成材料同步、回归、包清单审阅与 Git/CI 交付。没有新增解析功能或扩大项目定位。

## 三个 PARTIAL 的规范性与交付判断

| 项目 | 规范性判断 | 本轮处置和验收风险 |
| --- | --- | --- |
| A05：XML 输入覆盖 | Atom 需要处理 XML；当前 reader 不消费所有合法 XML 序列化。完整 DTD 有效性验证并非非验证型 XML 处理器的强制要求，但这不能消除实体替换、参数实体等输入覆盖限制。 | 保留 PARTIAL。常见 Feed 输入、命名空间、声明/实体/CDATA/默认属性及错误路径已有证据；全面 DTD/外部资源设计超出这次交付收尾。禁止以“无需 DTD validator”为由宣称完整 XML 兼容。 |
| A13：历史 email quoted CR/LF | RFC 4287 的 atom:email 引用 RFC 2822 addr-spec。历史 quoted-pair 中的 CR/LF 可由 XML 字符引用表示，拒绝这些合法输入属于真实规范缺口。 | 保留 PARTIAL，保持准确的字段错误和已存在边界测试。当前注释/折行扫描器与 MIME 共用；终审收尾不通过全局放宽换行检查来掩盖缺口，也不无测试地重写扫描器。 |
| A20：注册 MIME 参数等价 | alternate type/hreflang 唯一性需要考虑媒体类型定义的参数语义；通用大小写规则不能覆盖所有注册类型。 | 保留 PARTIAL。charset/external-body 等已知规则和顺序/quoted 值有测试；任意类型的参数语义并未全部实现。无需运行时联网加载注册表，但也不能宣称未知参数都能正确判等。 |

以上三项不是“非规范性问题”。它们阻止无条件完整 RFC 声明；对于申报书已经披露边界的常用 Feed 解析交付，可进入终审预验收。尚无新的组委会硬性验收细则，无法替组委会断言这些缺口一定不影响通过。

参考：[RFC 4287](https://www.rfc-editor.org/rfc/rfc4287)、[XML 1.0 §5.1](https://www.w3.org/TR/REC-xml/#proc-types)、[RFC 2822 §4.1](https://www.rfc-editor.org/rfc/rfc2822#section-4.1)、[兼容矩阵](ATOM_RFC4287_COMPLIANCE.md)。矩阵保持 24 PASS / 3 PARTIAL / 0 FAIL；本轮没有为数字调整行为或增加测试数量。

## 申报材料同步和保护

本地 docs/申报书final.md 与根目录申报书.md 均作为原件保护，以 SHA-256 比较确认未改动。用户已有的“旧路径删除、新中文路径未跟踪”状态保留，不纳入本次提交。

新增 [终审申报补充说明](终审申报补充说明.md)，以有证据的数据同步测试数、实际工具链、矩阵、DTD 边界及已发布/Unreleased 区别；无姓名、联系方式或应用成绩虚构。README、CHANGELOG、兼容说明和验收材料保持同一口径。

打包排除覆盖三个原始路径：根目录申报书.md、docs/申报书final.md、docs/HACKATHON_RESUBMISSION_FINAL.md。最后一个路径仍在基线 Git 中追踪；只检查本地重命名后的 ZIP 会漏掉干净 checkout 的打包风险，故一并排除。新增的无个人信息技术对照表和补充说明可以进入包。

## Mooncakes 版本决策

**建议下一次发布 0.3.0，本轮仅提交和验证 CI，不执行发布。**

本批改动既有缺陷修正，也有向调用方可见的能力增加：JSON Feed attachments 从忽略变为实际映射，根模块新增公共类型导出，CLI 增加 language 输出。它们不只是内部 bug fix，采用 minor 版本能更清楚地传达功能变化。原函数签名和模型布局保留，但新增字段校验和 CLI 输出键可能影响依赖宽松行为或精确键集的调用方，迁移说明必须保留。

0.2.1 适用于单独交付兼容性修复的 patch；不建议把当前整批功能增量都隐含在 patch 中。SemVer 对 0.y.z 尚不作稳定 API 保证，这里采用 minor 是项目的保守沟通策略，不把它写成规范强制。[SemVer 2.0.0](https://semver.org/lang/zh-CN/)

现有 moon.mod/CLI 版本仍为 0.2.0，用 Unreleased 明确区分 Git 源码和已发布 archive；不修改已发布 0.2.0 的内容。

下一次真正发布仍需要：明确授权并统一修改模块/CLI/CHANGELOG 的新版本，候选包与双目标验证、对应 HEAD 的 GitHub CI 成功，确认实际包排除原件且文件齐全，再执行一次正式发布。尚不存在的新版本无法提前从 registry 安装；发布成功后必须在新项目安装精确版本，验证本次新增功能，才能宣布发布闭环。本轮 0.2.0 的安装 smoke 不冒充未来 0.3.0 的证据。

## 验收及 Git/CI 证据规则

本轮本地使用 D:\MoonBit 的 Moon CLI 0.1.20261028 / moonc v0.10.18+6c83a7f62。`node scripts/verify.mjs` 复现双目标 check/test/build、160 项测试、六个示例双目标及 CLI 正反 smoke；`scripts/verify-registry.mjs` 验证精确发布包 0.2.0。无第三方依赖。

提交时仅显式加入本轮技术文件，排除原件及原有重命名增删；使用普通 push，同步后必须本地 HEAD 与 origin/main 相同。GitHub Actions 必须按完整 headSha 匹配，检查 check/test/build、JS、六个示例及 CLI 的实际结论。最新 run URL、工具链和提交 hash 在最终交付报告中记录；本文件不会提前预写 CI 成功。
