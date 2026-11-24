# MoonFeed 0.3.1

版本日期：2026-11-24。模块 `joanna/moonfeed@0.3.1`，许可证 Apache-2.0，最低 MoonBit v0.10.14。旧 0.3.0 保留，不覆盖、不删除。

## 修复内容

1. XML 通用实体展开改为显式帧栈和一个输出 builder，避免宿主递归及逐层结果复制。
2. 共享 Reader 累计预算覆盖声明、默认属性、属性值、文本和 CDATA：实体深度 32、引用 65,536 次、工作量 16,777,216 单位、输出 UTF-8 字节 8 MiB；另有 16 MiB 输入、256 层元素及原单值 1,048,576 字符上限。空实体也收费，超限为稳定 typed error，不依赖超时；外部资源不加载。精确计费与内存边界见 [安全整改](SECURITY_0.3.1_FIX.md)。
3. 拒绝参数实体的非法 NDATA 声明，区分 parsed/unparsed 外部实体及禁止的引用。
4. 校验属性默认值实体引用时机与适用的声明完整性、循环依赖，保留合法通用实体前向引用和首次声明绑定。
5. 修复 multipart/related 内嵌 type/subtype 等价，验证必需 type/boundary、边界语法和重复已知单值参数；保留不同 boundary/opaque 值、未知参数次数及原始属性。
6. charset 值不再对未知/私有类型全局小写；仅在六个已核验注册类型中折叠，避免错误合并 alternate 链接。
7. 13 处 derive 和两处整数转换迁移为三版通用写法，Moonc v0.10.22 的原 15 处弃用源位置警告归零；不屏蔽警告、不提高最低版本。

同时保留维护阶段已完成的 quoted email CR/LF、XML BOM/DTD 词法/属性规范化和 CLI 严格 UTF-8 修复。RSS、Atom Feed、独立 Entry、JSON Feed、附件、日期、自动探测、Podcast 核心扩展及 CLI 原功能保留。

## 兼容与限制

19 份公开接口的签名、模型布局、错误 variant 和 trait 能力兼容；derive 在接口中的表现改为等价显式 pub impl。校验更严格、超大输入可能触发资源上限，调用者应处理原有 XML 错误；数字上限是实现安全策略，不是 XML 合法性的定义。

RFC 4287 仍为 **25 PASS / 2 PARTIAL / 0 FAIL**。完整内部标记实体、参数实体及更广 XML 序列化覆盖仍未实现；全部注册 MIME 类型的默认值/别名/特殊语义未覆盖。不得宣传完整 RFC 4287 或通用 XML/MIME 验证器。参见 [兼容矩阵](ATOM_RFC4287_COMPLIANCE.md)。

## 使用与复现

```sh
moon add joanna/moonfeed
```

确认消费方 moon.mod 声明 `joanna/moonfeed@0.3.1`。需要显式固定时使用 `moon add joanna/moonfeed@0.3.1`。

源码验收：分别设置所需工具链 MOON_HOME 后运行 `node scripts/verify.mjs`，覆盖默认/JS check/test/build、六示例双目标、CLI 正反及安全 smoke。三版目标测试各 222/222，0 warning，无第三方依赖。

仓库外验收：`node scripts/verify-registry.mjs <全新目录>`，必须真实从 registry 安装，而非 path/GitHub/workspace。消费方 14 项独立 smoke 覆盖 RSS 正文及可选身份、合法/非法 XML、空实体预算、声明错误、MIME 等价与私有 charset、Atom Feed/Entry、JSON/附件、探测/日期；默认、wasm-gc、JS 均 check/test/build。

包由官方 `moon package` 生成并逐文件对照 Git 发布快照。发布只在精确 main HEAD 的 CI 通过、包审计和账号权限确认后执行；成功与否以 registry 实际查询和安装记录为准，不以本说明代替发布证据。发布时间、最终提交、CI URL、ZIP 数量和 SHA-256 记录于最终交付报告。申报书原件排除在提交和发布包之外。
