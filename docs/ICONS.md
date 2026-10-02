# 图标设计与导出说明

本文档说明 Endfield-ModMenu 的图标规范与导出流程。

---

## 图标规范

- **模组列表 / 详情页图标** (`mod/icon.png`)：
  256×256 透明 RGBA PNG，遵循终末地工业几何风格设计（灰白分层 + 亮黄点缀色）。
  精确色板包含：`#313131` / `#808080` / `#b4b4b4` / `#ffffff` / `#ffef00`。
- **ESC 主菜单按钮单色图标** (`mod/watch-icon.png`)：
  用于游戏 ESC 主菜单右侧列表入口，保持白色单色遮罩与原生深灰着色（`#313131`），以适配游戏原生按钮控件。

---

## 导出与构建

可通过附带的脚本从高分辨率源图导出优化后的发行图标：

```powershell
# 导出模组列表图标
./tools/export-icon.ps1 -Source assets/icon-source.png -Destination mod/icon.png

# 导出 ESC 单色蒙版图标
./tools/export-icon.ps1 -Source assets/watch-icon-source.png -Destination mod/watch-icon.png -Monochrome
```
