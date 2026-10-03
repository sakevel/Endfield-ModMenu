-- ModMenu: Mail browser and GameSetting configuration panels.
do
    if not _G.ZMLModMenu then
        local mod = { mount = function() end, phase = nil, active = nil, browser = nil, config = nil }
        _G.ZMLModMenu = mod
        local api
        local function report(event, detail)
            mod.state, mod.error = event, detail
            if api then api.report("mod-menu", event) end
            if detail then pcall(function() logger.error("ZML Mod Menu:", tostring(detail)) end) end
        end
        local ready, failure = xpcall(function()
            local chunk, err = loadstring(LuaManagerInst:LoadLua("ZML/Api"), "@ZML/Api")
            assert(chunk, err); api = chunk(); assert(api.api_version == 1, "Loader API mismatch")
            assert(api.config_menu_version == 1, "Exclusive config menus require Loader 0.3 or newer")
            local Model = __ZML_MODEL__
            local function theme() return Model.theme(api.mod("mod-menu").values) end
            local Native = (__ZML_NATIVE__)(api, theme, report)
            local U, hide = CS.UnityEngine, Native.hide
            local CtrlBase = require_ex("UI/Panels/Base/UICtrl").UICtrl
            local Browser = HL.Class("ZMLModBrowserCtrl", CtrlBase)
            local Config = HL.Class("ZMLModConfigCtrl", CtrlBase)
            Browser.s_messages = HL.StaticField(HL.Table) << {}
            Config.s_messages = HL.StaticField(HL.Table) << {}
            Browser.zml = HL.Field(HL.Any)
            Config.zml = HL.Field(HL.Any)
            local renderBrowser, renderConfig, refresh, openConfig, back
            local function state()
                return { styles = { images = setmetatable({}, {__mode="k"}), fonts = setmetatable({}, {__mode="k"}) },
                    queued = false, query = "", tag = "全部", items = {}, message = "", disposals = {} }
            end
            local function cleanup(self)
                local s = self.zml
                if s and s.dispose then local dispose = s.dispose; s.dispose = nil; pcall(dispose) end
            end
            local function failPage(self, event, err)
                report(event, err)
                self:_StartCoroutine(function()
                    coroutine.step()
                    if self.m_phase and PhaseManager:GetTopPhaseId() == self.m_phase.phaseId then PhaseManager:PopPhase(self.m_phase.phaseId) end
                end)
            end
            refresh = function(self, fn)
                local s = self.zml; if not s or s.queued then return end
                s.queued = true
                self:_StartCoroutine(function()
                    coroutine.step(); s.queued = false
                    if not self.m_isClosed then
                        local ok, err = xpcall(function() fn(self) end, debug.traceback)
                        if not ok then failPage(self, "render_error", err) end
                    end
                end)
            end
            back = function(self)
                if self.panelId == mod.config.id then
                    local phase = self.m_phase
                    phase:RemovePhasePanelItem(phase:_GetPanelPhaseItem(mod.config.id))
                    UIManager:Show(mod.browser.id)
                elseif self.m_phase and PhaseManager:GetTopPhaseId() == self.m_phase.phaseId then
                    PhaseManager:PopPhase(self.m_phase.phaseId)
                end
            end
            openConfig = function(self, id)
                local item = assert(api.mod(id), "Mod is not loaded")
                if item.config_menu == "none" then return end
                Native.ensureAsset(mod.config)
                self.m_phase:CreateOrShowPhasePanelItem(mod.config.id, { id = id })
                report("config_open")
            end
            local function detail(self)
                local s, v = self.zml, self.view
                local item = api.mod(s.selected)
                if not item then hide(v.mailContentNode); return end
                v.mailContentNode.gameObject:SetActive(true)
                v.contentNodeState:SetState("default")
                Native.label(v.mailName, item.name)
                Native.label(v.senderNameTxt, item.authors ~= "" and item.authors or "未提供作者")
                hide(v.sendTimeTxt)
                -- Configure mail content layout
                Native.label(v.contentTxt, item.description ~= "" and item.description or "此模组未提供简介。")
                local configurable = item.config_menu ~= "none"
                v.getBtn.gameObject:SetActive(true)
                Native.buttonLabel(v.getBtn, configurable and "模组配置" or "无配置菜单")
                Native.bind(v.getBtn, function() openConfig(self, item.id) end, configurable)
                s.detailBadges = s.detailBadges or {}
                -- Retrieve sender node parent transform
                local sender = v.sendTimeTxt.rectTransform.parent
                Native.badges(self, s.detailBadges, sender, {
                    {text=item.version ~= "" and ("v" .. item.version) or "版本未声明", full=true},
                    {text="已加载"}, {text=item.id}
                }, 0, 44, math.max(sender.rect.width, v.sendTimeTxt.rectTransform.rect.width), 32)
            end
            local function mailCell(self, object, index)
                local s = self.zml; local item = s.items[index]; if not item then return end
                local cell = s.getCell(object)
                Native.label(cell.title, item.name)
                for _, key in ipairs({"item", "expireTime", "star", "redDot", "readMask"}) do hide(cell[key]) end
                if not cell.zmlBg then
                    local prefab = self:LoadGameObject("Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/Mail/Default_MailCellBg.prefab")
                    assert(Native.exists(prefab), "Native mail cell background missing")
                    local bg = U.Object.Instantiate(prefab, cell.dynamicBg, false); bg:SetActive(true)
                    cell.zmlBg = bg:GetComponent("UIAnimationWrapper")
                    cell.zmlIcon = cell.senderIcon.sprite
                end
                local icon = Native.icon(item)
                local selected = item.id == s.selected
                cell.animator:SetBool("IsSelected", selected)
                cell.senderAvatar:SetState(selected and "Select" or "UnSelect")
                if icon then Native.metadataIcon(cell.senderIcon, icon)
                else cell.senderIcon.sprite = cell.zmlIcon end
                if cell.zmlBg then
                    if selected then cell.zmlBg:PlayInAnimation() else cell.zmlBg:PlayOutAnimation() end
                end
                -- Position version and tag badges in row metadata area
                cell.zmlBadges = cell.zmlBadges or {}
                local entries = {{text=item.version ~= "" and ("v" .. item.version) or "版本未声明", full=true}}
                if theme().show_tags then for _, tag in ipairs(item.tags) do entries[#entries+1] = {text=tag} end end
                local line = cell.expireTime.rectTransform
                Native.badges(self, cell.zmlBadges, line.parent, entries, line.anchoredPosition.x,
                    -line.anchoredPosition.y - 16, line.rect.width, 32)
                Native.bind(cell.button, function()
                    s.selected = item.id; detail(self)
                    self.view.mailList:UpdateShowingCells(function(i, obj) mailCell(self, obj, i + 1) end)
                    Native.style(self)
                end)
                cell.button.onIsNaviTargetChanged = function(isTarget, changed)
                    if isTarget and not changed and s.selected ~= item.id then
                        s.selected = item.id; refresh(self, renderBrowser)
                    end
                end
                -- List height remains controlled by the native virtualized list.
                Native.style(self)
            end
            renderBrowser = function(self)
                local s, v = self.zml, self.view
                local mods = api.mods(); s.items = Model.filter(mods, s.query, s.tag)
                local found = false; for _, item in ipairs(s.items) do if item.id == s.selected then found = true end end
                if not found then s.selected = s.items[1] and s.items[1].id end
                Native.title(v, "模组菜单")
                hide(v.listTitleTxt); hide(v.listCountText)
                v.mailListNode.gameObject:SetActive(true)
                v.emptyNode.gameObject:SetActive(#s.items == 0)
                if #s.items == 0 then
                    local labels = v.emptyNode.gameObject:GetComponentsInChildren(typeof(CS.TMPro.TMP_Text), true)
                    for i = 0, labels.Length - 1 do Native.label(labels[i], "没有匹配的模组") end
                end
                Native.buttonLabel(v.delReadBtn, "标签：" .. s.tag)
                v.mailList:UpdateCount(#s.items)
                v.mailList:UpdateShowingCells(function(i, obj) mailCell(self, obj, i + 1) end)
                detail(self); Native.style(self)
            end
            Browser.OnCreate = HL.Override(HL.Any) << function(self)
                local ok, err = xpcall(function()
                    self.zml = state(); local s, v = self.zml, self.view
                    Native.requireView(v, {"mailList", "mailContentNode", "mailName", "contentTxt", "btnClose", "getBtn", "getAllBtn", "delReadBtn"})
                    Native.title(v, "模组菜单")
                    hide(v.getBtn)
                    Native.buttonLabel(v.getBtn, "模组配置")
                    for _, key in ipairs({"loadingNode", "rewardsNode", "delBtn", "expireTxt", "filterBtn", "helpBtn", "lostAndFoundBtn", "lostAndFoundRedDot", "lostAndFoundMax", "lostAndFoundNum", "getAllBtnRedDot", "monthlyPassBtnNode", "previewWebNode", "gachaPoolNode", "gachaWeaponPoolNode", "sendDecoIcon"}) do hide(v[key]) end
                    s.getCell = UIUtils.genCachedCellFunction(v.mailList)
                    v.mailList.onUpdateCell:RemoveAllListeners()
                    v.mailList.onUpdateCell:AddListener(function(object, index)
                        local good, error = xpcall(function() mailCell(self, object, index + 1) end, debug.traceback)
                        if not good then failPage(self, "list_error", error) end
                    end)
                    Native.bind(v.btnClose, function() back(self) end)
                    self:BindInputPlayerAction("common_back", function() back(self) end)
                    Native.buttonLabel(v.getAllBtn, "菜单外观")
                    Native.bind(v.getAllBtn, function() openConfig(self, "mod-menu", true) end)
                    Native.bind(v.delReadBtn, function()
                        local tags = Model.tags(api.mods()); local index = 1
                        for i, tag in ipairs(tags) do if tag == s.tag then index = i end end
                        s.tag = tags[index % #tags + 1]; refresh(self, renderBrowser)
                    end)
                    -- Retain Mail panel shell and scroll list geometry
                    local header = Native.browserHeader(self)
                    s.search, s.searchRoot = Native.search(self, header, "", "搜索模组", 40, 0,
                        math.max(220, v.mailList.transform.rect.width - 80), function(value)
                            s.query = value; refresh(self, renderBrowser)
                        end, 128)
                end, debug.traceback)
                if not ok then failPage(self, "browser_error", err) end
            end
            Browser.OnShow = HL.Override() << function(self)
                if not self.zml then return end
                mod.active = self
                local ok, err = xpcall(function() renderBrowser(self) end, debug.traceback)
                if ok then report("page_open") else failPage(self, "page_error", err) end
                -- Adjust search bar layout to panel column width
                self:_StartCoroutine(function()
                    coroutine.step()
                    if self.m_isClosed then return end
                    Native.resizeInput(self.zml.searchRoot, self.view.mailList.transform.rect.width - 80)
                end)
            end
            Browser.OnHide = HL.Override() << function(self)
                if mod.active == self then mod.active = nil end
            end
            Browser.OnClose = HL.Override() << function(self)
                if mod.active == self then mod.active = nil end; report("page_returned")
            end
            local function save(self, item, field, value)
                local ok, err, restart = api.set(item.id, field.key, value)
                self.zml.message = ok and (restart and "已保存 · 需要重启客户端" or "已保存并应用") or ("保存失败：" .. tostring(err))
                if self.zml.status then Native.label(self.zml.status, self.zml.message) end
                if ok then report("config_saved") else refresh(self, renderConfig) end
                return ok, err, restart
            end
            local function initControl(self, item, field, cell)
                local control, values = cell.itemControl, assert(api.get(item.id))
                local value = values[field.key]
                if field.type == "bool" then
                    control.toggle:InitCommonToggle(function(v) save(self, item, field, v) end, value == "true", true, {"开启", "关闭"})
                elseif field.type == "number" then
                    control.slider:ClearComponent(); hide(control.sliderIconNode)
                    control.sliderFillArea.gameObject:SetActive(true)
                    control.slider.minValue, control.slider.maxValue = field.min, field.max
                    control.slider.wholeNumbers, control.slider.snapStep, control.slider.stepValue = false, true, field.step
                    control.slider.interactable = field.max > field.min
                    control.slider:SetValueWithoutNotify(tonumber(value), false)
                    Native.label(control.sliderValueText, value)
                    control.slider.onValueChanged:AddListener(function(v)
                        local steps = math.floor((v - field.min) / field.step + 0.5)
                        local n = math.max(field.min, math.min(field.max, field.min + steps * field.step))
                        local nextValue = string.format("%.6g", n)
                        if api.mod(item.id).values[field.key] ~= nextValue then save(self, item, field, nextValue) end
                        Native.label(control.sliderValueText, nextValue)
                    end)
                elseif field.type == "enum" then
                    local chosen = 1; for i, option in ipairs(field.options) do if option == value then chosen = i end end
                    control.dropdown:ClearComponent(); control.sizeStateCtrl:SetState("Normal")
                    control.dropdown:Init(function(index, option)
                        option:SetText(field.options[index + 1]); option:SetState("Normal")
                    end, function(index) save(self, item, field, field.options[index + 1]) end)
                    control.dropdown.onValidateSelectCell = nil
                    control.dropdown.onToggleOptList:AddListener(function(active)
                        if active then
                            Native.dropdown(self.view, cell, control)
                        end
                    end)
                    self:_StartCoroutine(function()
                        coroutine.step(); if not self.m_isClosed and self.zml.item == item.id then control.dropdown:Refresh(#field.options, chosen - 1, false) end
                    end)
                else
                    -- String field with native settings pill surface
                    hide(control.buttonIcon); hide(control.button)
                    local component, root = Native.settingInput(self, cell.view.controlNode, value, field.label,
                        function(v) save(self, item, field, v) end, field.max_length)
                    self.zml.stringInputs[#self.zml.stringInputs + 1] = root
                end
            end
            local function schema(self, item)
                local s, v = self.zml, self.view
                s.cells:Refresh(#item.config.fields, function(cell, index)
                    local f = item.config.fields[index]
                    local kind = f.type == "bool" and GEnums.SettingItemType.Toggle or f.type == "number" and GEnums.SettingItemType.Slider or f.type == "enum" and GEnums.SettingItemType.Dropdown or GEnums.SettingItemType.Button
                    local configs = {}
                    for type, template in pairs({ [GEnums.SettingItemType.Toggle] = v.settingItemControls.toggleSetting,
                        [GEnums.SettingItemType.Slider] = v.settingItemControls.sliderSetting,
                        [GEnums.SettingItemType.Dropdown] = v.settingItemControls.dropDownSetting,
                        [GEnums.SettingItemType.Button] = v.settingItemControls.buttonSetting }) do
                        configs[type] = { template = template.gameObject, initializer = function(c) initControl(self, item, f, c) end }
                    end
                    cell:InitGameSettingItemCell({ settingId = "zml_" .. f.key, settingText = f.label .. (f.restart and "  [重启]" or ""),
                        settingGroupTitle = index == 1 and item.config.title or "", settingRedDot = "", settingItemType = kind }, configs)
                    cell.view.itemText.richText = true
                    local label = f.label:gsub("<", "＜"):gsub(">", "＞") .. (f.restart and "  [重启]" or "")
                    cell.view.itemText.text = f.description ~= "" and (label .. "\n<size=75%>" .. f.description:gsub("<", "＜"):gsub(">", "＞") .. "</size>") or label
                    local height = (index == 1 and item.config.title ~= "") and s.rowHeight or s.rowHeight - s.titleHeight
                    height = height * (theme().compact and 0.9 or 1)
                    UIUtils.setSizeDeltaY(cell.rectTransform, height)
                    s.height = s.height + height + (index > 1 and v.config.SETTING_ITEM_VERTICAL_SPACE or 0)
                    local pos = cell.rectTransform.anchoredPosition
                    cell.rectTransform.anchoredPosition = U.Vector2(pos.x, -s.height)
                    if index > 1 then s.height = s.height + v.config.SETTING_ITEM_TITLE_PADDING_TOP * 0.25 end
                end)
                if #item.config.fields == 0 then
                    Native.text(self, v.viewContent, "此模组没有声明标准配置字段。", 20, 40, 800, 70, 24)
                end
                UIUtils.setSizeDeltaY(v.viewContent, math.max(s.height + 110, 180))
            end
            local function complex(self, item)
                local s, v = self.zml, self.view
                local entry, err = api.config_entry(item.id); assert(entry, err)
                assert(entry.presentation == nil or entry.presentation == "full", "Unknown custom presentation")
                local full = entry.presentation == "full"
                local parent = full and v.gameObject.transform or v.viewContent
                if full then U.Canvas.ForceUpdateCanvases() end
                local width = full and parent.rect.width or math.max(600, parent.rect.width)
                local height = full and parent.rect.height or 700
                assert(width > 0 and height > 0, "Custom panel layout is not ready")
                local hidden = {}
                local function restoreShell()
                    for _, child in ipairs(hidden) do
                        if Native.exists(child.object) then child.object:SetActive(child.active) end
                    end
                    hidden = {}; s.fullPresentation = nil
                end
                if full then
                    -- Hide menu shell on close
                    for i = 0, parent.childCount - 1 do
                        local child = parent:GetChild(i).gameObject
                        -- Preserve input lifecycle nodes for common_back binding
                        if child:GetComponentsInChildren(typeof(U.UI.Graphic), true).Length > 0 then
                            hidden[#hidden + 1] = {object=child, active=child.activeSelf}
                            child:SetActive(false)
                        end
                    end
                    s.fullPresentation = true
                end
                local allocated, root = pcall(Native.node, parent, "ZML.CustomConfig", 0, 0, width, height)
                if not allocated then restoreShell(); error(root) end
                s.customRoot = root
                root.gameObject.layer = full and v.btnClose.gameObject.layer or parent.gameObject.layer
                local subscriptions = {}
                local function unsubscribeAll() for _, unsubscribe in ipairs(subscriptions) do pcall(unsubscribe) end end
                local context = { api = 1, parent = root, mod = api.mod(item.id), width = width, height = height, presentation = full and "full" or "embedded",
                    get = function() return api.get(item.id) end,
                    set = function(key, value) return save(self, item, {key=key}, value) end,
                    panel = function(parent, name, x, y, w, h, color)
                        local rect = Native.node(parent, name, x, y, w, h)
                        if color then local image = rect.gameObject:AddComponent(typeof(U.UI.Image)); image.color = color end
                        return rect
                    end,
                    text = function(...) return Native.text(self, ...) end,
                    button = function(...) return Native.button(self, ...) end,
                    input = function(...) return Native.input(self, ...) end,
                    back = function() back(self) end, refresh = function() refresh(self, renderConfig) end,
                    subscribe = function(fn) local un = api.subscribe(item.id, fn); subscriptions[#subscriptions + 1] = un; return un end,
                }
                local ok, result = xpcall(function()
                    local cleanup = entry.create(context)
                    assert(cleanup == nil or type(cleanup) == "function", "create(context) must return function or nil"); return cleanup
                end, debug.traceback)
                if not ok then unsubscribeAll(); restoreShell(); U.Object.DestroyImmediate(root.gameObject); s.customRoot = nil; error(result) end
                s.dispose = function()
                    unsubscribeAll()
                    if result then pcall(result) end
                    -- Deactivate editor when panel is hidden
                    if Native.exists(root) then root.gameObject:SetActive(false) end
                    restoreShell()
                end
                if not full then UIUtils.setSizeDeltaY(v.viewContent, 780) end
            end
            renderConfig = function(self)
                cleanup(self)
                local s, v = self.zml, self.view
                if s.customRoot then U.Object.DestroyImmediate(s.customRoot.gameObject); s.customRoot = nil end
                if s.status then U.Object.DestroyImmediate(s.status.gameObject); s.status = nil end
                s.cells:Refresh(0)
                -- Clean up previous string control instances
                for _, object in ipairs(s.stringInputs or {}) do if Native.exists(object) then U.Object.DestroyImmediate(object) end end
                s.stringInputs = {}; s.height = 0
                local item = assert(api.mod(s.item), "Selected Mod unavailable")
                Native.cleanSettingsFooter(v)
                Native.title(v, "模组配置"); Native.label(v.tabTitleTxt, item.name)
                local tabs = api.mods(); s.tabs:Refresh(#tabs, function(tab, index)
                    local candidate = tabs[index]; local icon = Native.icon(candidate)
                    if icon then
                        Native.metadataIcon(tab.defaultIcon, icon)
                        Native.metadataIcon(tab.selectedIcon, icon)
                    end
                    hide(tab.redDot); tab.toggle.onValueChanged:RemoveAllListeners(); tab.toggle.checkIsValueValid = nil
                    tab.toggle.isOn = candidate.id == item.id
                    tab.toggle.interactable = candidate.config_menu ~= "none"
                    tab.toggle.onValueChanged:AddListener(function(on)
                        if on then s.item, s.message = candidate.id, ""; refresh(self, renderConfig) end
                    end)
                end)
                if item.config_menu == "custom" then
                    local ok, err = xpcall(function() complex(self, item) end, debug.traceback)
                    if not ok then
                        s.customRoot = Native.node(v.viewContent, "ZML.ConfigError", 0, 0, 900, 220)
                        Native.text(self, s.customRoot, "自定义配置错误：\n" .. tostring(err), 0, 0, 860, 210, 22)
                        UIUtils.setSizeDeltaY(v.viewContent, 330); report("custom_config_error", err)
                    end
                else schema(self, item) end
                if not s.fullPresentation and s.message ~= "" then
                    s.status = Native.text(self, v.viewContent, s.message, 20,
                        math.max(50, v.viewContent.sizeDelta.y - 70), math.max(600, v.viewContent.rect.width - 40), 55, 20)
                end
                Native.style(self)
            end
            Config.OnCreate = HL.Override(HL.Any) << function(self, arg)
                local ok, err = xpcall(function()
                    self.zml = state(); local s, v = self.zml, self.view
                    s.item = arg.id
                    Native.requireView(v, {"btnClose", "tabs", "settingItemCell", "settingItemControls", "viewContent", "tabTitleTxt", "resetBtn", "saveBtn"})
                    for _, key in ipairs({"deviceNode", "psDeviceNode", "xboxDeviceNode", "loadNode", "mobileNotchPaddingNode", "customizeGamepadBtn"}) do hide(v[key]) end
                    s.cells, s.tabs = UIUtils.genCellCache(v.settingItemCell), UIUtils.genCellCache(v.tabs.tabCell)
                    s.rowHeight, s.titleHeight = v.settingItemCell.transform.rect.height, v.settingItemCell.view.titleNode.rect.height
                    Native.bind(v.btnClose, function() back(self) end)
                    self:BindInputPlayerAction("common_back", function() back(self) end)
                    v.bottomNode.gameObject:SetActive(true); v.bottomNodeStateCtrl:SetState("Video")
                    Native.cleanSettingsFooter(v)
                    Native.buttonLabel(v.saveBtn, "返回详情"); Native.bind(v.saveBtn, function() back(self) end)
                    Native.buttonLabel(v.resetBtn, "恢复默认")
                    Native.bind(v.resetBtn, function()
                        local item = api.mod(s.item)
                        for _, field in ipairs(item.config.fields) do
                            local good, error = api.set(item.id, field.key, field.default)
                            if not good then s.message = "恢复失败：" .. tostring(error); refresh(self, renderConfig); return end
                        end
                        s.message = "已恢复默认设置"; report("defaults_restored"); refresh(self, renderConfig)
                    end)
                end, debug.traceback)
                if not ok then failPage(self, "config_error", err) end
            end
            Config.OnShow = HL.Override() << function(self)
                if not self.zml then return end
                mod.active = self
                local ok, err = xpcall(function() renderConfig(self) end, debug.traceback)
                if ok then report("native_config_open") else failPage(self, "config_error", err) end
            end
            Config.OnHide = HL.Override() << function(self) cleanup(self); if mod.active == self then mod.active = nil end end
            Config.OnClose = HL.Override() << function(self) cleanup(self); if mod.active == self then mod.active = nil end end
            HL.Commit(Browser); HL.Commit(Config)
            local Base = require_ex("Phase/Core/PhaseBase").PhaseBase
            local Page = HL.Class("PhaseZMLModMenu", Base)
            Page.s_messages = HL.StaticField(HL.Table) << {}
            Page._InitAllPhaseItems = HL.Override() << function(self)
                local ok, err = xpcall(function()
                    Native.ensureAsset(mod.browser)
                    Page.Super._InitAllPhaseItems(self)
                end, debug.traceback)
                if not ok then
                    report("native_panel_error", err)
                    self:_StartCoroutine(function() coroutine.step(); if PhaseManager:GetTopPhaseId() == self.phaseId then PhaseManager:PopPhase(self.phaseId) end end)
                end
            end
            HL.Commit(Page)
            local moduleName = "Phase/ZMLModMenu/PhaseZMLModMenu"
            hg.loadedModules[moduleName] = { name = moduleName, env = { PhaseZMLModMenu = Page } }
            hg.loadedModuleNameList[#hg.loadedModuleNameList + 1] = moduleName
            api.subscribe("mod-menu", function(key)
                local active = mod.active
                if active then
                    if key == "density" or key == "show_tags" then
                        refresh(active, active.panelId == mod.config.id and renderConfig or renderBrowser)
                    else Native.style(active) end
                end
                report("appearance_applied")
            end)
            mod.mount = function(controller)
                local initialSize = controller.view.scrollViewContent.sizeDelta
                local groupObject, attached = nil, false
                local success, err = xpcall(function()
                    assert(controller.m_btnData[93] == nil, "Mod slot 93 is already occupied")
                    if not mod.phase then
                        mod.browser = Native.register("ZMLModBrowser", PanelId.Mail, Browser)
                        mod.config = Native.register("ZMLModConfig", PanelId.GameSetting, Config)
                        local manager, id = PhaseManager, 1
                        for other in pairs(manager.m_cfgs) do id = math.max(id, other + 1) end
                        local data = { name = "ZMLModMenu", panels = {mod.browser.id}, isSimpleUIPhase = false, fov = UIManager:GetUICameraFOV() }
                        manager.m_cfgs[id] = setmetatable({ id = id, name = data.name, data = data }, { __index = data })
                        manager.phaseIds[data.name], manager.phaseId2Names[id] = id, data.name; mod.phase = id
                    end
                    local parent, rows = controller.view.rightList, {}
                    for i = 0, parent.childCount - 1 do local row = parent:GetChild(i); if row.name:sub(1, 5) == "Group" then rows[#rows + 1] = row end end
                    assert(#rows > 1, "Native menu row contract changed")
                    local dy = rows[2].anchoredPosition.y - rows[1].anchoredPosition.y
                    groupObject = U.Object.Instantiate(rows[1].gameObject, parent, false); groupObject.name = "GroupZMLModMenu"
                    local row = groupObject.transform
                    for i = row.childCount - 1, 0, -1 do U.Object.DestroyImmediate(row:GetChild(i).gameObject) end
                    row.anchoredPosition = U.Vector2(rows[1].anchoredPosition.x, rows[#rows].anchoredPosition.y + dy)
                    local copy = U.Object.Instantiate(controller.view.gameToolBtn.gameObject, row, false)
                    copy.name = "ZMLModMenuButton"; copy:SetActive(true)
                    local view = Utils.wrapLuaNode(copy)
                    assert(view.btn and view.text, "Native ESC button contract changed")
                    view.text.text = "模组菜单"
                    for _, key in ipairs({"lockIcon", "forbidIcon", "redDot"}) do hide(view[key]) end
                    if not Native.watchIcon(view, api.mod("mod-menu")) then report("button_icon_unavailable") end
                    controller.m_btnData[93] = { view = view, phaseId = mod.phase, needRefreshUnlock = false, needShowRedDot = false }; attached = true
                    controller.view.scrollViewContent.sizeDelta = U.Vector2(initialSize.x, initialSize.y + math.abs(dy) * parent.localScale.y)
                    report("button_attached")
                end, debug.traceback)
                if not success then
                    if attached then controller.m_btnData[93] = nil end
                    controller.view.scrollViewContent.sizeDelta = initialSize
                    if Native.exists(groupObject) then U.Object.DestroyImmediate(groupObject) end
                    report("button_error", err)
                end
            end
            report("controller_loaded")
        end, debug.traceback)
        if not ready then report("bootstrap_error", failure) end
    end
end
