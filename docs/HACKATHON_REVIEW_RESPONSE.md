# MoonFeed 黑客松初审整改说明

## 初审指出的问题

组委会指出，Atom 1.0 的 namespace 语义是标准要求。仅凭 `feed`、`entry`、`title` 等 local name 识别元素，会把其他 vocabulary 的同名扩展节点误当成 Atom 字段；等价 Feed 只改变前缀时，也可能产生不同结果。初审还要求项目说明 RFC 4287 的完整兼容终点，并用标准条目、测试和公开文档支撑兼容承诺。

## 原因分析

原实现建立在保留原始 QName 的轻量 XML reader 上，Atom 字段提取曾按未加前缀名称或固定 `atom:` 写法筛选。reader 不解析前缀绑定和作用域，因此无法区分相同 local name 的不同 namespace，也无法正确接纳任意合法 Atom 前缀。

## 已完成的代码修复

- 在 `src/xmlmini` 增加 namespace-aware event API，输出 namespace URI 与 local name 组成的展开名称；旧事件接口保留给 RSS。
- 按节点作用域继承和重绑定前缀，支持默认 namespace 清空；对未声明前缀、保留 `xml`/`xmlns` 绑定和重复展开属性返回 XML 错误。
- 确保无前缀属性不继承默认 namespace，并按 XML namespace 读取 `xml:lang`。
- Atom parser 与自动格式探测都按 Atom namespace URI 和 local name 匹配。格式探测接受任意前缀；扩展 namespace 中的同名节点不会参与 Atom 字段映射。

## 命名空间等价案例

新增测试使用同一 Feed Document 的默认 namespace 与 `x:` 前缀两种编码。实际解析结果逐字段比较标题、更新时间、作者、完整条目、条目 ID、发布时间原文和 UTC Unix 秒，结果相同。另有测试覆盖任意前缀、子树前缀重绑定、默认 namespace 清空、父级作用域恢复、错误 namespace、扩展同名 `title` / `entry`、属性 namespace 和重复展开属性。

## 验证结果

项目原有基线是 81 个测试通过。本次新增 7 个测试，总计 88/88 通过；`moon check` 无警告，`moon build` 通过。测试使用项目内 MoonBit v0.10.14。RSS 与 JSON Feed 的原有回归用例均保留并通过。CI 状态将在本地修改安全推送后更新；本文件不预先宣称 CI 已通过。

## 完整兼容目标与当前缺口

项目最终目标是支持 RFC 4287 Atom Feed Document 和 Entry Document 的解析及语义处理。当前修复解决 namespace 展开名称匹配，但不代表完整 RFC 兼容。Entry Document、`xml:base` 相对 IRI、person construct 全量校验、link 的完整语义、category `scheme`/`label`、content `src` 与媒体类型、source、扩展数据保留，以及完整 RFC 3339 和结构/cardinality 验证仍需实现。Feed ID 目前校验后不保留，因为统一模型没有该字段。

逐条状态、对应测试和待办见 [ATOM_RFC4287_COMPLIANCE.md](ATOM_RFC4287_COMPLIANCE.md)。该表把已测的 namespace 匹配与尚未实现的规范能力分开标为 PASS / PARTIAL / FAIL；不以文档替代代码验收。

## 后续计划

按兼容矩阵先完成 Feed/Entry 结构及 person/link/category/construct 规则，再增加 `xml:base` 与扩展元数据模型，最后支持独立 Entry Document。每一项只有在实现并有对应测试后才调整兼容状态。当前版本不宣称“100% 兼容”或“完全通过验收”。
