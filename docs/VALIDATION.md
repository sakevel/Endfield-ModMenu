# 测试与验证指南

本文档介绍 Endfield-ModMenu（模组菜单）的测试与功能验证体系。

---

## 自动化测试

项目包含 Native C++ 测试以及 Lua UI 行为测试：

```powershell
ctest --test-dir build -C Release --output-on-failure
```

### 测试套件说明

- **PatchTests (`tests/patch_tests.cpp`)**：
  - 验证对原生 `UI/Panels/Watch/WatchCtrl` 脚本的修补逻辑。
  - 验证在 `BuildData` 与 `_SnapshotRightList` 之间挂载模组入口按钮的锚点准确性。
  - 确保重入或异常输入时安全回滚。

- **PluginTests (`tests/plugin_tests.cpp`)**：
  - 验证 Native 插件导出符号 `ZML_PluginV1`。
  - 验证模组图标资源加载与单色遮罩生成逻辑。

- **LuaBehaviorTests (`tests/lua_behavior_tests.py` / `tests/native_menu_mock.lua`)**：
  - 模拟游戏 UI 环境，测试模组列表渲染、搜索与筛选。
  - 测试标准设置控件（Toggle、Slider、Dropdown、Input）的数据绑定与保存回调。
  - 验证自定义配置页面工厂的生命周期管理。

---

## 手动与实机验证项

在游戏内加载模组时，可检查以下交互：

1. **ESC 主菜单入口**：
   - 按 `ESC` 打开主菜单，右侧功能列表中显示「模组菜单」按钮。
   - 点击按钮可正常打开模组列表面板。

2. **模组列表与详情**：
   - 列表中能正确显示各模组的名称、版本、作者及标签。
   - 顶部搜索框能按名称或标签进行即时筛选。

3. **配置项修改**：
   - 在详情页点击「模组配置」，修改开关或滑块数值后，配置即时保存生效。
   - 点击「恢复默认」可将当前模组的配置重置为初始值。
