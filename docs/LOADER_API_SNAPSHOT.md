# Mod API v1

每个 Mod 一个目录，最少包括 `mod.ini` 与 x64 DLL：

```ini
[mod]
id=my-mod
name=My Mod
library=MyMod.dll
enabled=true
api=1
```

id 只能使用小写 ASCII 字母、数字、`.-_`；所有 Mod id 必须唯一。`library` 只能是本目录 DLL 文件名，不允许绝对路径、子目录、`..` 或通过链接跳出包根目录。无效 manifest 使预检失败；禁用 Mod 不加载 DLL。manifest 最长 16 KiB，不接受重复或未知键。

DLL 导出 `extern "C" __declspec(dllexport) const ZmlPlugin* ZML_PluginV1()`，返回静态结构。严格匹配 `size`、`abi=1` 和 manifest id。具体定义见 `include/zml_plugin.h`。

`start(host)` 在附加到 IL2CPP 的工作线程上执行一次。返回 1 成功，0 失败。Mod 可以读取 `mod_directory` 的自身数据，将状态写到 `state_directory`，使用 `log` 写诊断；**不能在此操作 Unity UI**。`host` 和其路径在进程生命周期内有效。原生 DLL 是受信任插件，不是安全沙箱。

`transform_lua(owner, path, callback, userdata)` 仅初始化期间注册，path 为无 `.lua` 的游戏模块路径。回调在游戏调用 `LuaManager.LoadLua` 的原线程执行。对于当前 UI 控制器，该线程为游戏主线程。不要从回调执行游戏 Lua，因为当前模块尚未执行。

转换回调输入 UTF-8 **明文 Lua**，长度由参数给出；不是以 NUL 终止的约定。读取完毕后，要么返回 0（不改），要么恰好调用一次 sink，交付完整源码并返回 1。sink 同步复制输出；输出不能为空、有 NUL 或超过 768 KiB。输入缓冲只在回调中有效。回调不得向 DLL 边界抛异常，不应阻塞或开线程操作 Unity。

运行时统一识别/解密 `Base64 + XXTEA`，转换后保持原封装；明文源也支持。二进制/字节码、解密失败或超限的数据保持原样。Mod id 按字典序执行，后续 Mod 看见前面的成功结果；拒绝/无效输出不产生部分更新。需在 Mod 自己的转换里检查锚点唯一性、已有补丁标记和接口契约。

初始化失败将撤销该 Mod 的注册。v1 不尝试卸载失败的 DLL，也不热卸载成功 DLL；避免已有线程/回调及 Windows loader lock 清理风险。修改 Lua 或启用状态之后必须重启客户端。

参考 `mods/mod-menu/mod.cpp`，它只依赖本项目 SDK 与 Win32/STL；不是 Better-Endfield ModuleApi 兼容模块。其 Lua 文件是独立实现，游戏控制器源码来自当前运行的客户端，不嵌入历史游戏脚本。

## v0.2 元数据／公共 Lua API

Native ABI 仍为 1，原插件结构不变。示例现在是 `mods/mod-menu`。菜单是普通 Mod，加载器不硬编码它的 id、UI 或页面；加载器只提供成功加载的 registry、配置服务和命名入口。

```ini
[mod]
id=my-mod
name=我的模组
version=1.0.0
description=模组简介
authors=作者名
tags=工具,界面
icon=assets/icon.png
config=schema.ini
config_entry=config-entry.lua
library=MyMod.dll
enabled=true
api=1
```

新增字段均可选。tags 逗号分隔、去重、最多 16 个。icon 仅支持 PNG（≤64 KiB、尺寸≤512×512），config 为 INI（≤64 KiB），config_entry 为 Lua（≤128 KiB）。三种资源允许本 Mod 下的子目录，但规范化后必须仍在本目录内；拒绝绝对路径、`..`、不匹配扩展名、越界链接和缺失文件。文本为 UTF-8。

只有 `start(host)` 成功的 Mod 发布进 registry。禁用／失败的 Mod 不显示成“已加载”。初始化期间校验 schema、图标及 entrypoint 源码；Lua entrypoint 的返回契约在第一次打开时校验。Mod 启用及列表是启动时快照，非 DLL 热加载。

在游戏主线程加载公共 API：

```lua
local fn, err = loadstring(LuaManagerInst:LoadLua("ZML/Api"), "@ZML/Api")
assert(fn, err)
local ZML = fn()
local mods = ZML.mods()
```

这是当前客户端真实的 LoadLua→loadstring 契约，虚拟模块由 runtime 以游戏原封装返回。不覆盖 `require_ex`，不写 `hg.loadedModules` 的公共 API 缓存，不使用 DoString 泵。

- `ZML.mods()`／`ZML.mod(id)`：防修改副本，字段 `id,name,version,description,authors,tags,icon,config,values,has_entry`。`icon` 为空或 `png`，图片数据按需获取。
- `ZML.icon_data(id)`：Base64 PNG 或 `nil,error`。
- `ZML.get(id)`：当前配置 string→string 副本，失败为 `nil,error`。
- `ZML.set(id,key,value)`：`ok,error,restart`；bool／number 自动转字符串，原生按 schema 校验。成功原子写入文件后才更新内存、通知订阅者；写入失败保留旧值。
- `ZML.subscribe(id,fn)`：返回取消订阅函数；`fn(key,value,values,restart)` 在调用 set 的线程执行，每个 listener 独立 pcall。操作 Unity 必须在游戏主线程。没有从文件编辑器自动监视配置变化。
- `ZML.config_entry(id)`：按需执行已注册 Lua 入口，返回 `{api=1,create=function(ctx)...end}`，或 `nil,error`。入口会缓存。
- `ZML.report(id,event)`：只支持成功加载的 id 和有界 ASCII 事件名，写入 runtime.log，不传私人内容。

## 声明式原生配置菜单

使用受限 INI 标记语言，不执行内联代码。最多 64 个字段，按声明顺序显示；key 仅支持小写字母、数字、`_-`。

```ini
[menu]
title=我的模组配置

[field.enabled]
type=bool
label=开启功能
description=立即应用
default=true

[field.amount]
type=number
label=数量
min=0
max=10
step=2
default=2
restart=true

[field.mode]
type=enum
label=工作方式
options=简单|复杂
default=简单

[field.caption]
type=string
label=显示文字
max_length=128
default=演示
```

- bool：原生 CommonToggle，true／false。
- number：原生 GameSetting slider，有限数值、闭区间 min/max、正 step，并校验步长格点。
- enum：原生 GameSetting dropdown，`|` 分隔的唯一选项，最多 32 个。
- string：原生 WikiSearch input；UTF-8 字节长度限制，拒绝 NUL／换行。UI 的 characterLimit 不替代原生字节校验。
- label／description／default／restart：字段元数据。所有 persistable key 必须声明，即使使用自定义页面。

未知／重复键、非法默认值或范围导致该 Mod 初始化失败。保存位置 `%LOCALAPPDATA%\EndfieldModLoader\mods/<id>/config.ini`。无效的已有保存字段单独回退默认值，不把坏数据执行成 Lua。单次字段保存原子替换；“恢复默认”是逐字段保存，不是多字段事务。

## 自定义复杂配置页面

`config_entry` 返回菜单工厂：

```lua
return { api = 1, create = function(ctx)
    local values = assert(ctx.get())
    ctx.text(ctx.parent, "自定义页面", 20, 20, ctx.width - 40, 60, 30)
    ctx.button(ctx.parent, "切换", 20, 120, 350, function()
        local current = assert(ctx.get())
        assert(ctx.set("enabled", current.enabled ~= "true"))
    end)
    return function() -- 可选 cleanup
    end
end }
```

`ctx`：`api=1,parent,mod,width,height,get(),set(key,value),subscribe(fn),back(),refresh()`，以及 `panel(parent,name,x,y,w,h[,color])`、`text(parent,value,x,y,w,h[,size,color])`、`button(parent,title,x,y,w,callback[,enabled])`、`input(parent,value,hint,x,y,w,commit[,limit])`。

坐标是父 RectTransform 的左上原生参考单位。button／text／input 复用当前设置页／百科原生模板；panel 创建布局容器，传 color 才添加 Image。复杂页面也可自己实现 Unity 控件，但不要销毁／修改原生父级和其他 Mod 的对象。返回 nil 或 cleanup；重建／隐藏／关闭时调用 cleanup，ctx.subscribe 自动解除。ctx.refresh 延迟下一帧重建，避免在自己的按钮回调中销毁控件。自建线程、外部订阅及非子对象由 Mod 自己清理。

参考 `examples/config-entry.lua`。自定义入口异常时显示错误并保留“通用配置”切换；不阻断 ESC 返回。不存在安全沙箱，工厂也是可信插件代码。
