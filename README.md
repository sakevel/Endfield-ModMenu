# Endfield Mod Menu / 模组菜单

适用于《明日方舟：终末地》的游戏内模组管理与配置菜单。在游戏 ESC 主菜单中添加原生风格的模组入口，方便在游戏内查看模组状态与调整配置。

## 功能特性

- **原生风格界面**：基于游戏原生 UI 组件与交互逻辑构建，视觉风格与游戏原生界面保持统一。
- **配置即时生效**：支持修改模组设置（开关、数值滑块、下拉选择、文本输入等），修改后即时保存并支持热重载。
- **自定义配置扩展**：支持高级模组扩展自定义配置界面（如 ESC 菜单整理模组的拖拽排序界面）。
- **外观个性化**：支持自定义模组菜单背景不透明度、列表密度、是否显示标签等外观选项。

---

## 使用方法

1. 确保已安装并配置好 Endfield-ModLoader。
2. 正常启动游戏后，按 `ESC` 键打开游戏主菜单，点击右侧的「模组菜单」按钮。
3. 在模组列表中点击任意模组查看详情或调整配置。

---

## 构建与安装

### 构建

```powershell
.\tools\build.ps1
.\tools\package.ps1
```

构建产物位于 `build/package/Release/mod-menu`。

### 安装

退出游戏后，通过 ModLoader 的安装工具进行安装：

```powershell
..\Endfield-ModLoader\tools\install-mod.ps1 -ModPackage .\build\package\Release\mod-menu
```

用户的个性化配置保存在 `%LOCALAPPDATA%\EndfieldModLoader\mods\mod-menu\config.ini`。
