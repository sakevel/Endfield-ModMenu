# 原生模组菜单 UI 适配

本文档记录 Endfield-ModMenu 对游戏原生 Prefab 与 UI 组件的复用与适配机制。

---

## 1. 原生 Prefab 复用设计

为保证与游戏原生界面在视觉与动效上的高度一致，模组菜单复用了游戏原生界面的结构与组件：

| 模块 | 复用的原生 Prefab | 用途与适配方式 |
|---|---|---|
| **模组列表** | `Common/MailPanel.prefab` | 复用原生邮件列表的虚拟滚动组件、单元格选中动效、图标展示与操作按钮。 |
| **配置面板** | `Settings/GameSettingPanel.prefab` | 复用原生游戏设置的分类标签栏（Tabs）、设置项单行控件（GameSettingItemCell）及底部按钮区。 |
| **搜索与输入** | `Wiki/WikiPanel.prefab` (WikiSearch) | 复用百科界面的搜索框控件与圆角背景。 |
| **元数据标签** | `WeaponInfo/Widget/GemCustomizationBoxTagCell.prefab` | 复用原生带边框的 Tag 小控件，用于展示版本号与模组标签。 |

---

## 2. 界面架构与生命周期

- **独立面板注册**：
  模组菜单在 UIManager 中注册自定义的 `ZMLModBrowser`（模组列表）与 `ZMLModConfig`（模组配置）PanelId，并使用自定义控制器承载逻辑。
- **资源预加载**：
  在面板创建前，通过内部资源加载机制预先缓存对应的原生 Prefab 资产，交由 UIManager 统一管理相机的渲染层级、输入事件与动画过渡。
- **返回与关闭处理**：
  配置页面返回时关闭配置面板并恢复模组列表；模组列表按 `ESC` 或返回键时触发 `PopPhase` 退出主菜单。

---

## 3. 关键节点与排版处理

- **详情页发件人与元数据行 (`detail`)**：
  由于 `senderNode` 为包装后的 Lua 节点而非原生 `RectTransform`，适配层通过 `sendTimeTxt.rectTransform.parent` 取得实际的父容器 Rect，从而准确计算模组版本和标签 Badge 的排版坐标。
- **自适应搜索框定宽 (`resizeInput`)**：
  在 `OnCreate` 阶段由于布局尚未完成，搜索框宽度可能会被误测为最小宽度。因此在 `OnShow` 后延迟一帧，根据实际排版后的列表宽度重新计算搜索框宽度。
- **自定义配置工厂扩展 (`presentation="full"`)**：
  当第三方模组声明全屏自定义配置模式时，宿主面板隐藏自身的视觉外壳（保留按键监听与生命周期），为第三方模组提供整屏画布参考尺寸与 Unity 原生控件绘制支持。
