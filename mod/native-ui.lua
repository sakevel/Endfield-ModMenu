-- Native prefab adapter; no game scripts/assets are embedded in the package.
-- The loader stays UI-agnostic. This module belongs exclusively to mod-menu.
return function(api, theme, report)
    local N, U = {}, CS.UnityEngine
    local watchData = __ZML_WATCH_ICON__
    local function exists(o) return o ~= nil and NotNull(o) end
    local function hide(o) if o then o.gameObject:SetActive(false) end end
    N.hide, N.exists = hide, exists
    function N.clone(template, parent, name, referencesOnly)
        local object = U.Object.Instantiate(template.gameObject or template, parent, false)
        object.name = name or "ZML.NativeControl"; object:SetActive(true)
        -- Standalone native widgets can be authored on Default layer, while
        -- their panel copies use UI. Inherit the owning panel's culling layer.
        local transforms = object:GetComponentsInChildren(typeof(U.Transform), true)
        for i = 0, transforms.Length - 1 do transforms[i].gameObject.layer = parent.gameObject.layer end
        if referencesOnly then
            -- Utils.wrapLuaNode would instantiate the Gem inventory LuaWidget.
            -- Bind presentation refs only; no native business controller is run.
            local reference = object:GetComponent("LuaReference")
            assert(reference, "Native presentation reference missing")
            local view = {}; reference:BindToLua(view)
            return view, object
        end
        return Utils.wrapLuaNode(object), object
    end
    function N.place(rect, parent, x, y, w, h)
        rect:SetParent(parent, false)
        rect.anchorMin, rect.anchorMax, rect.pivot = U.Vector2(0, 1), U.Vector2(0, 1), U.Vector2(0, 1)
        rect.anchoredPosition, rect.sizeDelta, rect.localScale = U.Vector2(x, -y), U.Vector2(w, h), U.Vector3.one
    end
    function N.node(parent, name, x, y, w, h)
        local object = U.GameObject(name); local rect = object:AddComponent(typeof(U.RectTransform))
        N.place(rect, parent, x, y, w, h); return rect
    end
    function N.label(label, value)
        label.richText, label.text = false, tostring(value or "")
    end
    function N.buttonLabel(button, title)
        local labels = button.gameObject:GetComponentsInChildren(typeof(CS.TMPro.TMP_Text), true)
        local best
        for i = 0, labels.Length - 1 do
            local label = labels[i]; local name = label.gameObject.name:lower()
            if not name:find("key") and not name:find("hint") and (not best or label.fontSize > best.fontSize) then best = label end
        end
        assert(best, "Native button label missing"); N.label(best, title)
    end
    function N.bind(button, callback, enabled)
        button.onClick:RemoveAllListeners(); button.interactable = enabled ~= false
        if callback then button.onClick:AddListener(function()
            local ok, err = xpcall(callback, debug.traceback)
            if not ok then report("interaction_error", err) end
        end) end
    end
    function N.register(name, sourceId, class)
        local manager = UIManager
        assert(not manager.ids[name], "Panel name is occupied: " .. name)
        local source = assert(manager.m_panelConfigs[sourceId], "Native source panel missing")
        local data = assert(getmetatable(source).__index, "Native panel config contract changed")
        local own = {}; for k, v in pairs(data) do own[k] = v end
        own.clearScreen, own.hideCamera, own.freezeWorld = true, true, true
        local id = 1; for other in pairs(manager.m_panelConfigs) do id = math.max(id, other + 1) end
        local cfg = setmetatable({ id = id, name = name, ctrlClass = class,
            modelClass = require_ex("UI/Panels/Base/UIModel").UIModel }, { __index = own })
        manager.ids[name], manager.m_names[id], manager.m_panelConfigs[id] = id, name, cfg
        return { id = id, source = sourceId, name = name }
    end
    function N.ensureAsset(info)
        -- Preload a native asset into OUR panel's cache slot only. UIManager then
        -- owns instantiation, LuaPanel, camera, input, sorting, animation and LRU.
        -- Preload into panel cache
        local manager = UIManager
        if manager.m_panel2Handle[info.id] then return end
        local path = manager:_GetPanelAssetPathAndType(info.source)
        local asset, key = manager.m_resourceLoader:LoadI18NAsset(path, typeof(U.GameObject))
        assert(exists(asset) and key and key >= 0, "Native prefab unavailable: " .. info.name)
        local _, ownType = manager:_GetPanelAssetPathAndType(info.id)
        manager.m_panel2Handle[info.id] = { key, ownType }
        report("native_prefab_loaded")
    end
    function N.requireView(view, keys)
        for _, key in ipairs(keys) do assert(view[key], "Native prefab contract missing: " .. key) end
    end
    function N.title(view, title)
        if view.commonTitle then
            local root = view.commonTitle.view or view.commonTitle
            if root.titleTxt then N.label(root.titleTxt, title) end
        end
        -- GameSetting's decorative title isn't a root LuaReference field.
        -- Replace instance title
        local labels = view.gameObject:GetComponentsInChildren(typeof(CS.TMPro.TMP_Text), true)
        for i = 0, labels.Length - 1 do
            local label = labels[i]
            if label.text == "设置" or label.text == "邮箱" or label.text == "SETTINGS" or label.text == "MAIL" then N.label(label, title) end
        end
    end
    function N.browserHeader(ctrl)
        -- Hide visible inbox heading
        -- section (including fraction/decorations), retaining the section geometry.
        local title = ctrl.view.listTitleTxt.rectTransform
        local header = title.parent.parent
        assert(header.name == "ListInboxNode", "Native inbox header contract changed")
        for i = 0, header.childCount - 1 do hide(header:GetChild(i)) end
        hide(ctrl.view.listCountText)
        return header
    end
    function N.cleanSettingsFooter(view)
        -- GameSetting's Video state localizes TipsText to the graphics-reset
        -- Hide graphics reset hint
        local labels = view.bottomNode.gameObject:GetComponentsInChildren(typeof(CS.TMPro.TMP_Text), true)
        for i = 0, labels.Length - 1 do
            if labels[i].gameObject.name == "TipsText" then hide(labels[i]) end
        end
    end
    function N.style(ctrl)
        local style, t = ctrl.zml.styles, theme()
        local images = ctrl.view.gameObject:GetComponentsInChildren(typeof(U.UI.Image), true)
        for i = 0, images.Length - 1 do
            local image = images[i]; local base = style.images[image]
            if not base then base = image.color; style.images[image] = base end
            if image.rectTransform.rect.width >= 1000 and image.rectTransform.rect.height >= 700 then
                image.color = U.Color(base.r, base.g, base.b, base.a * t.opacity)
            end
        end
        local labels = ctrl.view.gameObject:GetComponentsInChildren(typeof(CS.TMPro.TMP_Text), true)
        for i = 0, labels.Length - 1 do
            local label = labels[i]; local base = style.fonts[label]
            if not base then base = label.fontSize; style.fonts[label] = base end
            label.fontSize = base * t.scale
        end
        for input, base in pairs(style.inputs or {}) do
            if exists(input) then input.pointSize = base * t.scale else style.inputs[input] = nil end
        end
    end
    function N.dropdown(view, cell, control)
        cell.rectTransform:SetAsLastSibling()
        local popup, clip = control.dropDownListRectTransform, view.scrollView.transform
        local bottom = clip:InverseTransformPoint(control.rectTransform:TransformPoint(U.Vector3(0, control.rectTransform.rect.yMin - popup.rect.height, 0)))
        local down = bottom.y >= clip.rect.yMin
        local edge = down and 1 or 0
        popup.pivot = U.Vector2(0.5, edge)
        popup.anchorMin, popup.anchorMax, popup.anchoredPosition = U.Vector2(0, edge), U.Vector2(1, edge), U.Vector2.zero
        control.layoutStateCtrl:SetState(down and "Downward" or "Upward")
        control.topMask.gameObject:SetActive(not down); control.bottomMask.gameObject:SetActive(down)
        control.dropDownListMask.padding = down and view.config.DROPDOWN_LIST_MASK_PADDING_DOWNWARD or view.config.DROPDOWN_LIST_MASK_PADDING_UPWARD
        control.dropdown:ScrollToSelected()
    end
    N.icons = {}
    local function decodeIcon(data)
        local texture
        local ok, sprite = pcall(function()
            assert(data, "Icon data unavailable")
            texture = U.Texture2D(2, 2)
            assert(U.ImageConversion.LoadImage(texture, CS.System.Convert.FromBase64String(data)), "PNG decode failed")
            return U.Sprite.Create(texture, U.Rect(0, 0, texture.width, texture.height), U.Vector2(0.5, 0.5))
        end)
        if ok then return { sprite = sprite, texture = texture } end
        if texture then U.Object.Destroy(texture) end
        return false
    end
    function N.icon(item)
        if N.icons[item.id] ~= nil then return N.icons[item.id] end
        local result = false
        if item.icon ~= "" then
            local ok, data = pcall(api.icon_data, item.id)
            if ok then result = decodeIcon(data) end
        end
        N.icons[item.id] = result; return result
    end
    function N.metadataIcon(image, icon)
        image.sprite = icon.sprite
        image.color = U.Color(1, 1, 1, 1) -- Set default white tint
        image.preserveAspect = true
    end
    function N.watchIcon(view, item)
        -- Retain native icon geometry
        if not exists(view.icon) then return false end
        if not item then hide(view.icon); return false end
        if N.watchSprite == nil then N.watchSprite = decodeIcon(watchData) end
        local icon = N.watchSprite
        if not icon then hide(view.icon); return false end
        view.icon.sprite = icon.sprite
        view.icon.color = U.Color(49 / 255, 49 / 255, 49 / 255, 1)
        view.icon.preserveAspect, view.icon.raycastTarget = true, false
        view.icon.gameObject:SetActive(true)
        return true
    end
    function N.searchTemplate(ctrl)
        local state = ctrl.zml
        if not exists(state.inputTemplate) then
            local path = UIManager:_GetPanelAssetPathAndType(PanelId.WikiSearch)
            local prefab = ctrl.loader:LoadI18NAsset(path, typeof(U.GameObject)); assert(exists(prefab), "Native search input unavailable")
            local root = U.Object.Instantiate(prefab, ctrl.view.transform, false)
            root.name = "ZML.InputTemplate"; root:SetActive(false); state.inputRoot = root
            local view = {}; root:GetComponent("LuaReference"):BindToLua(view)
            state.inputTemplate = assert(view.inputField, "WikiSearch input reference missing")
            state.searchTemplate = assert(view.searchNode, "WikiSearch search group missing")
        end
        return state.searchTemplate, state.inputTemplate
    end
    function N.search(ctrl, parent, value, hint, x, y, w, commit, limit)
        -- Retain SearchNode: its icon, background and input are one native group.
        -- Cloning InputField alone leaves a 164-unit decoration/gutter mismatch.
        local search, template = N.searchTemplate(ctrl)
        local object = U.Object.Instantiate(search.gameObject, parent, false)
        object.name = "ZML.NativeInput"; object:SetActive(true)
        local component = object:GetComponentInChildren(template:GetType(), true)
        assert(component, "Native input type mismatch")
        N.place(object.transform, parent, x, y, w, 100)
        local rect = component.transform
        rect.anchorMin, rect.anchorMax, rect.pivot = U.Vector2(0, 0.5), U.Vector2(1, 0.5), U.Vector2(1, 0.5)
        rect.anchoredPosition, rect.sizeDelta = U.Vector2.zero, U.Vector2(-164, 50)
        component.onValueChanged:RemoveAllListeners(); component.onEndEdit:RemoveAllListeners(); component.onSubmit:RemoveAllListeners()
        component.onFocused:RemoveAllListeners()
        component.characterLimit, component.text = limit or 128, value or ""
        if component.placeholder then
            local label = component.placeholder:GetComponent(typeof(CS.TMPro.TMP_Text))
            if label then N.label(label, hint) end
        end
        component.onEndEdit:AddListener(function(v)
            local ok, err = xpcall(function() commit(v) end, debug.traceback)
            if not ok then report("input_error", err) end
        end)
        return component, object
    end
    function N.input(ctrl, parent, value, hint, x, y, w, commit, limit, layout)
        -- Settings has no text editor. Borrow only WikiSearch's input behavior,
        -- not SearchNode or its icon/gutter. Present it on the native settings pill.
        local _, template = N.searchTemplate(ctrl)
        local setting = assert(ctrl.view.settingItemControls.buttonSetting, "Settings input surface unavailable")
        local images = setting.gameObject:GetComponentsInChildren(typeof(U.UI.Image), true)
        local surface
        for i = 0, images.Length - 1 do
            if images[i].gameObject.name == "NormalBG" then
                assert(not surface, "Settings input surface ambiguous"); surface = images[i]
            end
        end
        assert(surface and exists(surface.sprite) and surface.transform.childCount == 0,
            "Settings input surface contract changed")
        local text = assert(setting.buttonText, "Settings input typography unavailable")
        local baseSize = ctrl.zml.styles.fonts[text] or text.fontSize
        local rect = N.node(parent, "ZML.SettingsInput", x, y, w, 64)
        if layout then
            -- Position setting cell relative to native row layout
            rect.anchorMin, rect.anchorMax, rect.pivot = layout.anchorMin, layout.anchorMax, layout.pivot
            rect.sizeDelta, rect.localScale = layout.sizeDelta, layout.localScale
            rect.anchoredPosition = U.Vector2.zero
        end
        local object = rect.gameObject
        local ok, component = xpcall(function()
            local editor = U.Object.Instantiate(template.gameObject, rect, false)
            editor.name = "ZML.SettingsEditor"; editor:SetActive(true)
            local input = assert(editor:GetComponent(template:GetType()), "Native input type mismatch")
            -- Hide background images while preserving text and viewport
            local oldImages = editor:GetComponentsInChildren(typeof(U.UI.Image), true)
            for i = 0, oldImages.Length - 1 do oldImages[i].enabled = false; oldImages[i].raycastTarget = false end
            local background = U.Object.Instantiate(surface.gameObject, rect, false)
            background.name = "ZML.SettingsInputBackground"; background:SetActive(true)
            background.transform:SetAsFirstSibling()
            local image = assert(background:GetComponent(typeof(U.UI.Image)), "Settings input image missing")
            image.enabled, image.raycastTarget = true, true
            -- Retain native sprite and 9-slice styling
            input.targetGraphic, input.colors = image, setting.button.colors
            input.transition = U.UI.Selectable.Transition.ColorTint
            local function stretch(r, inset)
                r.anchorMin, r.anchorMax, r.pivot = U.Vector2(0, 0), U.Vector2(1, 1), U.Vector2(0.5, 0.5)
                r.anchoredPosition, r.sizeDelta, r.localScale = U.Vector2.zero, U.Vector2(-inset, 0), U.Vector3.one
            end
            stretch(background.transform, 0); stretch(editor.transform, 0)
            stretch(assert(input.textViewport, "Native input viewport missing"), 40)
            local function typography(label)
                label.font, label.fontSize, label.color = text.font, baseSize * theme().scale, text.color
                label.richText, label.enableAutoSizing = false, false
                label.alignment = CS.TMPro.TextAlignmentOptions.Left
                stretch(label.rectTransform, 0)
                ctrl.zml.styles.fonts[label] = baseSize
            end
            input.pointSize, input.richText = baseSize * theme().scale, false
            typography(assert(input.textComponent, "Native input text missing"))
            if input.placeholder then
                local placeholder = input.placeholder:GetComponent(typeof(CS.TMPro.TMP_Text))
                if placeholder then typography(placeholder); N.label(placeholder, hint) end
            end
            input.onValueChanged:RemoveAllListeners(); input.onEndEdit:RemoveAllListeners(); input.onSubmit:RemoveAllListeners()
            input.onFocused:RemoveAllListeners()
            input.characterLimit, input.text = limit or 128, value or ""
            input.onEndEdit:AddListener(function(v)
                local saved, err = xpcall(function() commit(v) end, debug.traceback)
                if not saved then report("input_error", err) end
            end)
            local transforms = object:GetComponentsInChildren(typeof(U.Transform), true)
            for i = 0, transforms.Length - 1 do transforms[i].gameObject.layer = parent.gameObject.layer end
            ctrl.zml.styles.inputs = ctrl.zml.styles.inputs or {}
            ctrl.zml.styles.inputs[input] = baseSize
            return input
        end, debug.traceback)
        if not ok then U.Object.DestroyImmediate(object); error(component) end
        return component, object
    end
    function N.settingInput(ctrl, parent, value, hint, commit, limit)
        -- Align row dimensions with settings pill layout
        local setting = assert(ctrl.view.settingItemControls.toggleSetting, "Settings input layout unavailable")
        local layout = setting.gameObject.transform
        assert(layout.anchorMin and layout.anchorMax and layout.pivot and layout.sizeDelta and layout.localScale,
            "Settings input layout contract changed")
        return N.input(ctrl, parent, value, hint, 0, 0, 0, commit, limit, layout)
    end
    function N.resizeInput(object, width)
        -- Defer input width adjustment until initial layout completes
        if exists(object) and width > 164 then
            local size = object.transform.sizeDelta
            object.transform.sizeDelta = U.Vector2(width, size.y)
        end
    end
    function N.textWidth(text, size)
        -- Estimate label width based on text length
        local width = 0
        for i = 1, #text do
            local b = text:byte(i)
            if b < 128 then width = width + size * 0.7
            elseif b >= 192 then width = width + size end
        end
        return width
    end
    function N.badges(ctrl, cache, parent, entries, x, y, width, height)
        -- Gem tag presentation badge
        if not exists(ctrl.zml.badgeTemplate) then
            local asset = ctrl:LoadGameObject("Assets/Beyond/DynamicAssets/Gameplay/UI/Prefabs/WeaponInfo/Widget/GemCustomizationBoxTagCell.prefab")
            assert(exists(asset), "Native metadata badge unavailable")
            ctrl.zml.badgeTemplate = asset
        end
        local cursor, used = x, 0
        for index, entry in ipairs(entries) do
            local badge = cache[index]
            if not badge then
                local view, object = N.clone(ctrl.zml.badgeTemplate, parent, "ZML.MetadataBadge", true)
                N.requireView(view, {"name", "stateController"})
                badge = {view=view, object=object, color=view.name.color}; cache[index] = badge
                -- Tag badge styling
                local buttons = object:GetComponentsInChildren(typeof(U.UI.Button), true)
                for i = 0, buttons.Length - 1 do buttons[i].onClick:RemoveAllListeners(); buttons[i].enabled = false end
                local graphics = object:GetComponentsInChildren(typeof(U.UI.Graphic), true)
                for i = 0, graphics.Length - 1 do graphics[i].raycastTarget = false end
            end
            local label = badge.view.name
            badge.view.stateController:SetState("normal")
            N.label(label, entry.text); label.fontSize = 22
            label.color = badge.color
            ctrl.zml.styles.fonts[label] = 22
            label.raycastTarget = false
            label.enableAutoSizing = false
            label.overflowMode = entry.full and CS.TMPro.TextOverflowModes.Overflow or CS.TMPro.TextOverflowModes.Ellipsis
            local size = 22 * theme().scale
            local desired = math.max(label:GetPreferredValues(entry.text).x * theme().scale, N.textWidth(entry.text, size)) + 24
            local remaining = x + width - cursor
            if remaining < 48 then break end
            local w = math.min(math.max(64, desired), entry.full and remaining or (entry.max_width or 200), remaining)
            badge.object:SetActive(true)
            N.place(badge.object.transform, parent, cursor, y, w, height)
            local r = label.rectTransform
            r.anchorMin, r.anchorMax, r.pivot = U.Vector2(0, 0.5), U.Vector2(1, 0.5), U.Vector2(0.5, 0.5)
            r.anchoredPosition, r.sizeDelta = U.Vector2.zero, U.Vector2(-20, height)
            cursor, used = cursor + w + 8, index
        end
        for i = used + 1, #cache do cache[i].object:SetActive(false) end
    end
    function N.button(ctrl, parent, title, x, y, w, callback, enabled)
        local view, object = N.clone(ctrl.view.settingItemControls.buttonSetting, parent)
        N.place(object.transform, parent, x, y, w, 64)
        N.label(view.buttonText, title); hide(view.buttonIcon); view.stateCtrl:SetState("NormalState")
        N.bind(view.button, callback, enabled); return object, view
    end
    function N.text(ctrl, parent, value, x, y, w, h, size, color)
        local object = U.Object.Instantiate(ctrl.view.settingItemCell.view.itemText.gameObject, parent, false)
        object.name = "ZML.NativeText"; object:SetActive(true); N.place(object.transform, parent, x, y, w, h)
        local label = object:GetComponent(typeof(CS.TMPro.TMP_Text)); N.label(label, value)
        label.raycastTarget = false; if size then label.fontSize = size end; if color then label.color = color end
        return label
    end
    return N
end
