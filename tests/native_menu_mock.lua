-- Behavioral test fixture.
local classes, queue = {}, {}
function flush() local tasks = queue; queue = {}; for _, fn in ipairs(tasks) do fn() end end
function event()
    return { callbacks = {}, RemoveAllListeners = function(self) self.callbacks = {} end,
        AddListener = function(self, fn) self.callbacks[#self.callbacks+1] = fn end,
        Invoke = function(self, ...) local copy = {}; for _, fn in ipairs(self.callbacks) do copy[#copy+1]=fn end; for _, fn in ipairs(copy) do fn(...) end end }
end
function object(name)
    local o = { name = name or "mock", active = true, destroyed = false }
    o.layer=5
    function o:SetActive(v) self.active = v end
    o.gameObject = o; o.transform = o
    o.rect = {width=1000,height=160}; o.sizeDelta={x=1000,y=160}; o.anchoredPosition={x=0,y=0}; o.parent={}
    function o:SetAsLastSibling() self.lastSibling = true end
    function o:SetParent(p) self.parent=p end
    function o:GetComponentsInChildren() return {Length=0} end
    return o
end
function label(value) local o = object(); o.text = value or ""; o.rectTransform = o; o.color={r=.9,g=.9,b=.9,a=1};
    function o:GetPreferredValues(v)return {x=#v*8}end; return o end
function button() local o=object(); o.onClick=event(); return o end
local function stateCtrl() local o=object(); function o:SetState(v) self.value=v end; return o end
local Base = {}
function Base:_StartCoroutine(fn) queue[#queue+1]=fn end
function Base:BindInputPlayerAction(key, fn) self.boundKey, self.boundBack=key,fn end
function Base:LoadGameObject() return object("native-mail-bg") end
HL = { Table={}, Any={}, Number={}, StaticField=function() return setmetatable({}, {__shl=function(_,v)return v end}) end,
    Field=function()return nil end, Override=function()return setmetatable({}, {__shl=function(_,v)return v end})end,
    Class=function(name,base) local t=setmetatable({Super=base}, {__index=base}); classes[name]=t;return t end,
    Commit=function()end }
coroutine.step=function()end
typeof=function(v)return v end
NotNull=function(v)return not v.destroyed end
logger={error=function()end}
local U={}
U.Vector2=function(x,y)return {x=x,y=y}end
U.Vector3=setmetatable({one={x=1,y=1,z=1}}, {__call=function(_,x,y,z)return {x=x,y=y,z=z}end})
U.Vector2=setmetatable({zero={x=0,y=0}}, {__call=function(_,x,y)return {x=x,y=y}end})
U.Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
U.Canvas={ForceUpdateCanvases=function()end}
U.Object={ DestroyImmediate=function(o)o.destroyed=true end, Destroy=function(o)o.destroyed=true end,
    Instantiate=function()local o=object();function o:GetComponent()return {PlayInAnimation=function()end,PlayOutAnimation=function()end}end;return o end }
CS={UnityEngine=U,TMPro={TMP_Text={},TextOverflowModes={Ellipsis=1,Overflow=2}}}
GEnums={SettingItemType={Toggle=1,Slider=2,Dropdown=3,Button=4}}
PanelId={Mail=10,GameSetting=20,WikiSearch=30}
UIConst={PANEL_ASSET_TYPES={Default=0}}
hg={loadedModules={},loadedModuleNameList={}}
local modelClass={}
require_ex=function(path)
    if path=='UI/Panels/Base/UICtrl' then return {UICtrl=Base} end
    if path=='UI/Panels/Base/UIModel' then return {UIModel=modelClass} end
    if path=='Phase/Core/PhaseBase' then return {PhaseBase={_InitAllPhaseItems=function()end}} end
    error(path)
end
UIManager={ ids={},m_names={},m_panelConfigs={},m_panel2Handle={},m_resourceLoader={}, shows={} }
for _, id in ipairs({10,20}) do UIManager.m_panelConfigs[id]=setmetatable({id=id,name='original'..id},{__index={folder='Native',clearScreen=true}}) end
function UIManager:GetUICameraFOV()return 15 end
function UIManager:_GetPanelAssetPathAndType(id)return 'native/'..id,0 end
function UIManager.m_resourceLoader:LoadI18NAsset(path) self.loads=(self.loads or 0)+1;self.path=path;return object('asset'),self.loads end
function UIManager:Show(id)self.shows[id]=true end
PhaseManager={m_cfgs={},phaseIds={},phaseId2Names={},top=1}
function PhaseManager:GetTopPhaseId()return self.top end
function PhaseManager:PopPhase(id)self.popped=id end

-- Test native adapter registration and styling
function verifyNative(N)
    local original=UIManager.m_panelConfigs[10]
    local oldmeta=getmetatable(original).__index
    local p=N.register('test-native',10,{})
    assert(p.id~=10 and original.name=='original10' and getmetatable(original).__index==oldmeta)
    assert(UIManager.m_panelConfigs[p.id].name=='test-native')
    N.ensureAsset(p); N.ensureAsset(p)
    assert(UIManager.m_resourceLoader.loads==1 and UIManager.m_resourceLoader.path=='native/10')
    UIManager.m_panel2Handle[p.id]=nil;N.ensureAsset(p)
    assert(UIManager.m_resourceLoader.loads==2) -- actual LRU eviction path can reload
    assert(not pcall(N.register,'test-native',10,{}))
    assert(not pcall(N.requireView,{},{'missing'}))
    local img={color=U.Color(1,.8,.1,1),rectTransform={rect={width=120,height=60}}}
    local bg={color=U.Color(.8,.8,.8,.8),rectTransform={rect={width=1920,height=1080}}}
    local txt=label();txt.fontSize=24
    local go={GetComponentsInChildren=function(_,type) if type==U.UI.Image then return {Length=2,[0]=img,[1]=bg} else return {Length=1,[0]=txt} end end}
    local ctrl={view={gameObject=go},zml={styles={images={},fonts={}}}}
    N.style(ctrl);N.style(ctrl)
    assert(txt.fontSize==24 and math.abs(bg.color.a-.8*.95)<1e-9)
    assert(ZML.set('mod-menu','font_scale',1.2));N.style(ctrl);N.style(ctrl)
    assert(math.abs(txt.fontSize-28.8)<1e-9)
    assert(not ZML.set('mod-menu','accent','冰蓝')) -- removed from schema and API
    N.style(ctrl);assert(img.color.b==.1 and txt.color.b==.9)
    img.color=U.Color(.7,.7,.7,1);N.style(ctrl);assert(img.color.r==.7)
    assert(ZML.set('mod-menu','font_scale',1));N.style(ctrl);assert(txt.fontSize==24)
    -- Verify inbox branch removal
    local header=object('ListInboxNode');local inbox=object('收件箱');local count=object('1/1')
    header.childCount=2;function header:GetChild(i)return i==0 and inbox or count end
    local listTitle=label();listTitle.parent={parent=header}
    local hv={view={listTitleTxt=listTitle,listCountText=count}}
    assert(N.browserHeader(hv)==header and not inbox.active and not count.active)
    header.name='changed-contract';assert(not pcall(N.browserHeader,hv));header.name='ListInboxNode'
    local tip=label('重置所有性能与画面设置');tip.name='TipsText'
    local action=label('恢复默认');action.name='ButtonText'
    local footer=object();function footer:GetComponentsInChildren()return {Length=2,[0]=tip,[1]=action}end
    N.cleanSettingsFooter({bottomNode=footer})
    assert(not tip.active and action.active and action.text=='恢复默认')
end
U.UI={Image={},Button={},Graphic={},Selectable={Transition={ColorTint=1}}};U.Transform={};U.RectTransform={}
CS.TMPro.TextAlignmentOptions={Left=257}

function verifyNativeIcons(N)
    local decoded=0
    CS.System={Convert={FromBase64String=function(s)assert(s:sub(1,8)=='iVBORw0K');return s end}}
    U.Texture2D=function()return {width=256,height=256}end
    U.ImageConversion={LoadImage=function(_,data)assert(#data>0);decoded=decoded+1;return true end}
    U.Rect=function(x,y,w,h)return {x=x,y=y,width=w,height=h}end
    U.Sprite={Create=function(texture,rect,pivot)assert(rect.width==256 and pivot.x==.5);return {texture=texture}end}
    local own=object('cloned-esc-icon');own.sprite='inherited-cup'
    local original=object('original-game-tools');original.sprite='inherited-cup'
    local item=ZML.mod('mod-menu')
    assert(N.watchIcon({icon=own},item) and own.active and own.sprite~='inherited-cup')
    assert(own.color.r==49/255 and own.color.g==49/255 and own.color.b==49/255 and own.preserveAspect and not own.raycastTarget)
    assert(original.sprite=='inherited-cup' and original.active)
    local first=own.sprite;assert(N.watchIcon({icon=own},item) and own.sprite==first and decoded==1)
    local metadata=N.icon(item)
    assert(metadata and metadata.sprite~=first and decoded==2) -- no shared colorful ESC sprite
    local colored=object();N.metadataIcon(colored,metadata)
    assert(colored.sprite==metadata.sprite and colored.color.r==1 and colored.color.g==1 and colored.color.b==1 and colored.preserveAspect)
    assert(N.icon(item).sprite==metadata.sprite and decoded==2)
    assert(not N.watchIcon({},item)) -- missing native field doesn't touch other controls
    -- Verify icon visibility
end

-- Test search group and badge layout
function verifyNativeControls(N)
    local instantiate=U.Object.Instantiate
    local captured, inputRoot
    local input=object('InputField');input.onValueChanged=event();input.onEndEdit=event();input.onSubmit=event();input.onFocused=event()
    input.placeholder={GetComponent=function()return label()end};function input:GetType()return 'native-input-type'end
    local search=object('SearchNode');local styles={images={},fonts={}}
    local ctrl={zml={inputTemplate=input,searchTemplate=search,styles=styles},view={gameObject=object()}}
    U.Object.Instantiate=function(template)
        captured=template;inputRoot=object('clone-search');function inputRoot:GetComponentInChildren(t)assert(t=='native-input-type');return input end
        return inputRoot
    end
    local committed
    local result, root=N.search(ctrl,object(),'', '搜索模组',40,0,560,function(v)committed=v end,128)
    assert(captured==search and root==inputRoot and result==input)
    assert(root.sizeDelta.y==100 and math.abs(root.sizeDelta.x-560)<1e-9)
    assert(input.sizeDelta.x==-164 and input.anchorMin.x==0 and input.anchorMax.x==1)
    input.onEndEdit:Invoke('测试');assert(committed=='测试')
    N.resizeInput(root,920);assert(root.sizeDelta.x==920)
    N.resizeInput(root,0);assert(root.sizeDelta.x==920) -- skip not-yet-laid-out width
    -- Test config row input cloning
    local oldGameObject=U.GameObject
    local lastContainer
    U.GameObject=function(name)
        local o=object(name);lastContainer=o
        function o:AddComponent(t)assert(t==U.RectTransform);return o end
        return o
    end
    local setting=object('ButtonSetting');setting.button=button();setting.button.colors={normalColor=U.Color(1,1,1,1)}
    setting.buttonText=label();setting.buttonText.font='settings-font';setting.buttonText.fontSize=28
    local surface=object('NormalBG');surface.childCount=0;surface.sprite=object('native-rounded-sprite');surface.type='Sliced';surface.raycastTarget=false
    local originalColor=U.Color(.95,.94,.93,1);surface.color=originalColor
    function setting:GetComponentsInChildren(t)assert(t==U.UI.Image);return {Length=1,[0]=surface}end
    ctrl.view.settingItemControls={buttonSetting=setting}
    local editor,background,square,focus,caption,placeholder,clones
    local brokenViewport=false
    U.Object.Instantiate=function(template,parent)
        clones=clones+1
        if template==input then
            editor=object('cloned-input');editor.parent=parent
            editor.onValueChanged=event();editor.onEndEdit=event();editor.onSubmit=event();editor.onFocused=event()
            editor.onEndEdit:AddListener(function()error('inherited input callback')end)
            function editor:GetType()return 'native-input-type'end
            function editor:GetComponent(t)assert(t=='native-input-type');return editor end
            caption=label();placeholder=label()
            editor.textComponent=caption;editor.textViewport=not brokenViewport and object('TextViewport') or nil
            editor.placeholder={GetComponent=function(_,t)assert(t==CS.TMPro.TMP_Text);return placeholder end}
            square=object('square-background');focus=object('search-focus-image');square.enabled=true;focus.enabled=true
            function editor:GetComponentsInChildren(t)assert(t==U.UI.Image);return {Length=2,[0]=square,[1]=focus}end
            return editor
        end
        assert(template==surface, 'cloned search group or unrelated settings controller')
        background=object('cloned-native-pill');background.color=surface.color;background.sprite=surface.sprite;background.type=surface.type
        function background:SetAsFirstSibling()self.firstSibling=true end
        function background:GetComponent(t)assert(t==U.UI.Image);return background end
        function parent:GetComponentsInChildren(t)
            assert(t==U.Transform);return {Length=5,[0]=parent,[1]=editor,[2]=background,[3]=caption,[4]=placeholder}
        end
        return background
    end
    clones=0
    local owner=object('settings-owner');owner.layer=7
    local saved
    local field,container=N.input(ctrl,owner,'0007','编号',0,0,420,function(v)saved=v end,20)
    assert(clones==2 and field==editor and container==lastContainer and container.name=='ZML.SettingsInput')
    assert(container.sizeDelta.x==420 and container.sizeDelta.y==64)
    assert(editor.sizeDelta.x==0 and editor.anchorMin.x==0 and editor.anchorMax.x==1)
    assert(editor.textViewport.sizeDelta.x==-40 and editor.textViewport.anchorMax.y==1)
    assert(background.sizeDelta.x==0 and background.firstSibling and background.sprite==surface.sprite and background.type=='Sliced')
    assert(background.enabled and background.raycastTarget and not square.enabled and not focus.enabled and not square.raycastTarget)
    assert(editor.targetGraphic==background and editor.colors==setting.button.colors and editor.transition==U.UI.Selectable.Transition.ColorTint)
    assert(caption.font=='settings-font' and caption.fontSize==28 and caption.color==setting.buttonText.color and not caption.richText)
    assert(editor.pointSize==28 and not editor.richText and editor.characterLimit==20 and editor.text=='0007')
    assert(placeholder.text=='编号' and placeholder.alignment==CS.TMPro.TextAlignmentOptions.Left)
    assert(#editor.onEndEdit.callbacks==1 and #editor.onSubmit.callbacks==0 and #editor.onFocused.callbacks==0)
    editor.onEndEdit:Invoke('0012');assert(saved=='0012')
    for _,o in ipairs({container,editor,background,caption,placeholder})do assert(o.layer==7)end
    assert(surface.color==originalColor and not surface.raycastTarget and setting.button.active and not input.destroyed)
    N.resizeInput(container,640);assert(container.sizeDelta.x==640 and editor.sizeDelta.x==0)
    function ctrl.view.gameObject:GetComponentsInChildren(t)
        if t==CS.TMPro.TMP_Text then return {Length=2,[0]=caption,[1]=placeholder}end
        return {Length=0}
    end
    assert(ZML.set('mod-menu','font_scale',1.2));N.style(ctrl);N.style(ctrl)
    assert(math.abs(editor.pointSize-33.6)<1e-9 and math.abs(caption.fontSize-33.6)<1e-9)
    ctrl.zml.styles.fonts[setting.buttonText]=28;setting.buttonText.fontSize=33.6
    local previous=editor
    local second=N.input(ctrl,owner,'验证昵称','昵称',0,0,420,function()end,96)
    N.style(ctrl)
    assert(math.abs(second.pointSize-33.6)<1e-9 and math.abs(caption.fontSize-33.6)<1e-9) -- no double scaling
    previous.destroyed=true;N.style(ctrl);assert(ctrl.zml.styles.inputs[previous]==nil)
    assert(ZML.set('mod-menu','font_scale',1));N.style(ctrl)
    assert(second.pointSize==28 and caption.fontSize==28)
    -- Validate row positioning against pill layout
    local nativeLayout=object('ToggleSetting');nativeLayout.anchorMin=U.Vector2(.5,.5);nativeLayout.anchorMax=U.Vector2(.5,.5)
    nativeLayout.pivot=U.Vector2(.5,.5);nativeLayout.sizeDelta=U.Vector2(600,80);nativeLayout.localScale=U.Vector3.one
    -- Template layout coordinates
    ctrl.view.settingItemControls.toggleSetting=nativeLayout
    owner.rect={width=0,height=0} -- native row has not laid out yet
    local standard,pill=N.settingInput(ctrl,owner,'888888','显示的 UID',function(v)saved=v end,20)
    assert(pill.anchorMin.x==.5 and pill.anchorMin.y==.5 and pill.anchorMax.x==.5 and pill.anchorMax.y==.5)
    assert(pill.pivot.x==.5 and pill.pivot.y==.5 and pill.anchoredPosition.x==0 and pill.anchoredPosition.y==0)
    assert(pill.sizeDelta.x==600 and pill.sizeDelta.y==80 and pill.localScale==nativeLayout.localScale)
    assert(editor.sizeDelta.x==0 and editor.sizeDelta.y==0 and background.sizeDelta.x==0 and background.sizeDelta.y==0)
    owner.rect={width=660,height=100}
    local left=pill.anchorMin.x*owner.rect.width-pill.pivot.x*pill.sizeDelta.x
    local bottom=pill.anchorMin.y*owner.rect.height-pill.pivot.y*pill.sizeDelta.y
    assert(left==30 and bottom==10) -- same centered 600x80 native pill; not 660x64/top-left
    standard.onEndEdit:Invoke('000123');assert(saved=='000123')
    -- Dynamic row width adjustment
    assert(pill.sizeDelta.x==600 and pill.anchorMin.y==.5 and pill.anchoredPosition.y==0)
    -- Stretched native layout also survives late parent sizing unchanged.
    nativeLayout.anchorMin=U.Vector2(0,.5);nativeLayout.anchorMax=U.Vector2(1,.5);nativeLayout.sizeDelta=U.Vector2(-60,80)
    local _,stretched=N.settingInput(ctrl,owner,'0007','编号',function()end,20)
    assert(stretched.anchorMin.x==0 and stretched.anchorMax.x==1 and stretched.sizeDelta.x==-60 and stretched.sizeDelta.y==80)
    assert(stretched.anchorMin.y==.5 and stretched.anchorMax.y==.5 and nativeLayout.anchoredPosition.x==-900)
    ctrl.view.settingItemControls.toggleSetting=nil
    assert(not pcall(N.settingInput,ctrl,owner,'','',function()end,20))
    ctrl.view.settingItemControls.toggleSetting=nativeLayout
    -- Missing/ambiguous native surface is rejected before allocating anything.
    local before=clones
    surface.sprite=nil;assert(not pcall(N.input,ctrl,owner,'','',0,0,300,function()end));assert(clones==before)
    surface.sprite=object('native-rounded-sprite')
    function setting:GetComponentsInChildren()return {Length=2,[0]=surface,[1]=surface}end
    assert(not pcall(N.input,ctrl,owner,'','',0,0,300,function()end));assert(clones==before)
    function setting:GetComponentsInChildren()return {Length=1,[0]=surface}end
    brokenViewport=true
    assert(not pcall(N.input,ctrl,owner,'','',0,0,300,function()end) and lastContainer.destroyed)
    U.GameObject=oldGameObject
    -- Test tag presentation template
    local badgeButton=button();badgeButton.onClick:AddListener(function()error('native inventory listener leaked')end)
    ctrl.zml.badgeTemplate=object('native-tag');local created={}
    U.Object.Instantiate=function()
        local o=object('tag-clone');o.boundView={name=label(),stateController=stateCtrl()}
        function o:GetComponent(t)assert(t=='LuaReference');return {BindToLua=function(_,v)for k,x in pairs(o.boundView)do v[k]=x end end}end
        function o:GetComponentsInChildren(t)
            if t==U.UI.Button then return {Length=1,[0]=badgeButton}end
            if t==U.Transform then return {Length=1,[0]=o}end
            if t==U.UI.Graphic then return {Length=1,[0]=o.boundView.name}end
            return {Length=0}
        end
        created[#created+1]=o;return o
    end
    local cache={}
    N.badges(ctrl,cache,object(),{{text='v1.2.3',full=true},{text='测试'},{text='工具'}},168,76,390,32)
    assert(#cache==3 and #badgeButton.onClick.callbacks==0 and not badgeButton.enabled)
    for _,b in ipairs(cache)do assert(b.object.anchoredPosition.x+b.object.sizeDelta.x<=558);assert(b.view.stateController.value=='normal')end
    local label1=cache[1].view.name
    function ctrl.view.gameObject:GetComponentsInChildren(t)if t==CS.TMPro.TMP_Text then return {Length=1,[0]=label1}end;return {Length=0}end
    N.style(ctrl);assert(label1.color.b==.9 and label1.overflowMode==CS.TMPro.TextOverflowModes.Overflow)
    assert(cache[1].object.sizeDelta.x>=N.textWidth('v1.2.3',22)+24)
    N.badges(ctrl,cache,object(),{{text='other'}},0,0,120,32)
    assert(label1.color.b==.9 and not cache[2].object.active and not cache[3].object.active)
    N.badges(ctrl,cache,object(),{{text=string.rep('very long metadata ',100)},{text='overflow'}},0,0,90,32)
    assert(cache[1].object.sizeDelta.x==90 and not cache[2].object.active)
    U.Object.Instantiate=instantiate
end


-- Render and lifecycle test fixture
MockNative={hide=function(o)if o then o.gameObject:SetActive(false)end end,exists=NotNull,
    watchIcon=function()return true end,
    metadataIcon=function(image,icon)image.sprite=icon.sprite end,
    cleanSettingsFooter=function(v)v.footerTip:SetActive(false)end,
    browserHeader=function(c)c.headerCleared=true;return object('ListInboxNode')end,
    badges=function(c,cache,parent,entries,x,y,w,h)
        for i,e in ipairs(entries)do cache[i]=cache[i]or{object=object(),view={name=label()}};cache[i].view.name.text=e.text;cache[i].full=e.full;cache[i].object.active=true end
        for i=#entries+1,#cache do cache[i].object.active=false end
    end,
    resizeInput=function(o,w)o.width=w end,
    dropdown=function()end,
    register=function(name,source,class)return {id=source+100,source=source,class=class,name=name}end,
    ensureAsset=function()end,requireView=function(v,keys)for _,k in ipairs(keys)do assert(v[k],k)end end,
    title=function(v,title)v.zmlTitle=title end,label=function(l,t)l.text=t;l.richText=false end,
    buttonLabel=function(b,t)b.text=t end,style=function(c)c.styleCalls=(c.styleCalls or 0)+1 end,
    bind=function(b,fn,enabled)b.onClick:RemoveAllListeners();b.interactable=enabled~=false;if fn then b.onClick:AddListener(fn)end end,
    search=function(c,parent,value,hint,x,y,w,fn)local i=object();i.text=value;i.commit=fn;i.kind='search';return i,i end,
    settingInput=function(c,parent,value,hint,fn,limit)
        local i,root=MockNative.input(c,parent,value,hint,0,0,0,fn,limit);i.kind='standard-settings';return i,root
    end,
    input=function(c,parent,value,hint,x,y,w,fn)local i=object();i.text=value;i.commit=fn;i.kind='settings';c.inputs=c.inputs or {};c.inputs[#c.inputs+1]=i;return i,i end,
    icon=function()return false end,node=function()return object()end,
    text=function(_,parent,t)local l=label(t);return l end,
    button=function(c,parent,t,x,y,w,fn)local b=button();b.text=t;b.onClick:AddListener(fn);return b,{button=b}end,
}
Utils={wrapLuaNode=function(o)return o.boundView or o end}
function newControl(kind)
    local o=object()
    o.button=button();o.buttonIcon=object()
    o.toggle={InitCommonToggle=function(self,fn,value)self.change,self.value=fn,value end}
    o.slider={onValueChanged=event(),SetValueWithoutNotify=function(self,v)self.value=v end,
        ClearComponent=function(self)self.onValueChanged:RemoveAllListeners()end}
    o.sliderValueText=label();o.sliderIconNode=object();o.sliderFillArea=object()
    o.dropdown={onToggleOptList=event(),Init=function(self,opt,selected)self.option,self.select=opt,selected end,
        ClearComponent=function(self)self.onToggleOptList:RemoveAllListeners()end,
        Refresh=function(self,n,index)self.count,self.index=n,index end,ScrollToSelected=function()end}
    o.sizeStateCtrl=stateCtrl();o.layoutStateCtrl=stateCtrl()
    return o
end
function row()
    local r=object();r.rectTransform=r
    r.view={titleNode=object(),itemText=label(),controlNode=object()};r.view.titleNode.rect.height=40
    r.controls={}
    function r:InitGameSettingItemCell(data,configs)
        self.data=data;self.view.itemText.text=data.settingText
        assert(configs[1] and configs[2] and configs[3] and configs[4])
        for k in pairs(configs)do if not self.controls[k]then self.controls[k]=newControl(k)end;self.controls[k].active=k==data.settingItemType end
        self.itemControl=self.controls[data.settingItemType];configs[data.settingItemType].initializer(self)
    end
    return r
end
function tab()
    local t=object();t.defaultIcon={};t.selectedIcon={};t.redDot=object();t.toggle={onValueChanged=event()};return t
end
UIUtils={setSizeDeltaY=function(o,y)o.sizeDelta.y=y end,
    genCellCache=function(template)
        local cache={items={}}
        function cache:Refresh(n,fn)
            self.count=n
            for i=1,n do self.items[i]=self.items[i]or(template.isTab and tab()or row());self.items[i].active=true;if fn then fn(self.items[i],i)end end
            for i=n+1,#self.items do self.items[i].active=false end
        end
        return cache
    end,
    genCachedCellFunction=function()return function(o)return o end end,
}
function configView()
    local v={gameObject=object(),transform=object(),btnClose=button(),resetBtn=button(),saveBtn=button(),bottomNode=object(),
        footerTip=label('重置所有性能与画面设置'),
        bottomNodeStateCtrl=stateCtrl(),tabs={tabCell={isTab=true}},settingItemCell=row(),settingItemControls={
            toggleSetting=object(),sliderSetting=object(),dropDownSetting=object(),buttonSetting=object()},
        viewContent=object(),tabTitleTxt=label(),config={SETTING_ITEM_VERTICAL_SPACE=-26,SETTING_ITEM_TITLE_PADDING_TOP=20}}
    local root=v.gameObject;root.transform=root
    root.rect={width=1920,height=1080};root.childCount=4
    root.children={v.viewContent.gameObject,v.bottomNode.gameObject,object("inactive-decoration"),object("input-group")}
    for i=1,3 do root.children[i].GetComponentsInChildren=function(_,t)assert(t==U.UI.Graphic);return {Length=1}end end
    root.children[3]:SetActive(false)
    function root:GetChild(i)return self.children[i+1] end
    for _,child in ipairs(root.children)do child.activeSelf=child.active end
    return v
end
function verifyConfig()
    local C=classes.ZMLModConfigCtrl
    local c=setmetatable({panelId=120,view=configView(),m_isClosed=false},{__index=C})
    c.m_phase={phaseId=1,_GetPanelPhaseItem=function()return {}end,RemovePhasePanelItem=function(self)self.removed=true end}
    c:OnCreate({id='demo'});c:OnShow();flush()
    assert(c.view.zmlTitle=='模组配置' and c.zml.cells.count==4 and c.boundKey=='common_back')
    assert(not c.view.footerTip.active)
    local rows=c.zml.cells.items
    assert(rows[1].itemControl.toggle.value==true)
    rows[1].itemControl.toggle.change(false);assert(ZML.get('demo').enabled=='false')
    rows[2].itemControl.slider.onValueChanged:Invoke(6);assert(ZML.get('demo').amount=='6')
    assert(c.zml.status.text:find('重启'))
    rows[3].itemControl.dropdown.select(1);assert(ZML.get('demo').mode=='复杂')
    local input=c.inputs[#c.inputs];assert(input.kind=='standard-settings');input.commit('新的中文配置');assert(ZML.get('demo').caption=='新的中文配置')
    local oldInputs={table.unpack(c.zml.stringInputs)}
    c.view.resetBtn.onClick:Invoke();flush();flush()
    assert(ZML.get('demo').enabled=='true' and ZML.get('demo').caption=='演示')
    for _,o in ipairs(oldInputs)do assert(o.destroyed)end
    -- Execute the Mod-authored entrypoint, then verify cleanup on rebuild/error.
    local entry=assert(ZML.config_entry('custom-demo'));local originalCreate=entry.create
    local live=0;local subscribe=ZML.subscribe
    ZML.subscribe=function(id,fn)
        live=live+1;local un=subscribe(id,fn);local active=true
        return function()if active then active=false;live=live-1;un()end end
    end
    c.zml.item='custom-demo';c:OnShow();flush();assert(live==1 and c.zml.dispose and c.zml.cells.count==0 and c.zml.entryButton==nil)
    c.zml.item='demo';c:OnShow();flush();assert(live==0 and c.zml.cells.count==4)
    entry.create=function(ctx)ctx.subscribe(function()end);error('fixture custom config failure')end
    c.zml.item='custom-demo';c:OnShow();flush();assert(live==0 and not c.zml.dispose and c.zml.customRoot and c.zml.cells.count==0 and c.zml.entryButton==nil)
    entry.create=originalCreate
    -- Test full host panel layout
    entry.presentation="full"
    local observed,disposed
    entry.create=function(ctx)
        observed=ctx;ctx.subscribe(function()end)
        return function()disposed=true end
    end
    c:OnShow();flush()
    assert(observed.presentation=="full" and observed.width==1920 and observed.height==1080)
    assert(c.zml.fullPresentation and not c.zml.status and live==1)
    for i=1,3 do assert(not c.view.gameObject.children[i].active)end
    assert(c.view.gameObject.children[4].active,"Nonvisual input group must stay active")
    local fullRoot=c.zml.customRoot
    c:OnHide();assert(disposed and live==0 and not fullRoot.active)
    assert(c.view.viewContent.active and c.view.bottomNode.active and not c.view.gameObject.children[3].active)
    entry.create=function(ctx)ctx.subscribe(function()end);error('full config failure')end
    c:OnShow();flush();assert(live==0 and not c.zml.fullPresentation and c.zml.customRoot and c.zml.status)
    assert(c.view.viewContent.active and c.view.bottomNode.active and not c.view.gameObject.children[3].active)
    entry.presentation=nil;entry.create=originalCreate;ZML.subscribe=subscribe
    c.zml.item='demo';c:OnShow();flush()
    c.view.saveBtn.onClick:Invoke();assert(c.m_phase.removed and UIManager.shows[110])
    c:OnClose()
    local appearance=setmetatable({panelId=120,view=configView(),m_isClosed=false,m_phase={phaseId=1}},{__index=C})
    appearance:OnCreate({id='mod-menu'});appearance:OnShow();flush()
    local before=appearance.styleCalls
    assert(ZML.set('mod-menu','opacity',.8));assert(appearance.styleCalls>before)
    assert(ZML.set('mod-menu','density','紧凑'));flush();flush()
    assert(appearance.zml.cells.count==4) -- queued rebuild, no destroy in onClick
    for _,r in ipairs(appearance.zml.cells.items)do
        local active=0;for _,control in pairs(r.controls)do if control.active then active=active+1 end end
        assert(active==1)
    end
    appearance:OnClose()
end
function browserCell()
    local cell=object();cell.title=label();cell.senderIcon={sprite='default'};cell.dynamicBg=object()
    cell.animator={SetBool=function(self,k,v)self[k]=v end};cell.senderAvatar=stateCtrl();cell.button=button()
    for _,k in ipairs({'item','expireTime','star','redDot','readMask'})do cell[k]=object()end
    cell.expireTime.rectTransform=cell.expireTime
    cell.expireTime.anchoredPosition={x=168,y=-92};cell.expireTime.rect.width=390
    return cell
end
function browserView()
    local v={gameObject=object(),transform=object(),btnClose=button(),getBtn=button(),getAllBtn=button(),delReadBtn=button(),mailContentNode=object(),
        mailName=label(),contentTxt=label(),senderNode=object(),senderNameTxt=label(),sendTimeTxt=label(),listTitleTxt=label(),listCountText=label(),mailListNode=object(),emptyNode=object(),contentNodeState=stateCtrl()}
    local list={onUpdateCell=event(),transform=object(),cells={}}
    function list:UpdateCount(n)self.count=n;for i=1,n do self.cells[i]=self.cells[i]or browserCell();self.onUpdateCell:Invoke(self.cells[i],i-1)end end
    function list:UpdateShowingCells(fn)for i=1,self.count do fn(i-1,self.cells[i])end end
    -- Sender node wrapper regression check
    -- Strict metatable forbids the bad .rect access that escaped older mocks.
    v.senderNode=setmetatable({gameObject=object()}, {__index=function(_,k)error('wrapped senderNode has no '..k)end})
    v.sendTimeTxt.rectTransform.parent=object('SenderNode.Rect')
    -- Simulate pending layout in OnCreate
    v.mailList=list;return v
end
function verifyBrowser()
    local B=classes.ZMLModBrowserCtrl
    local b=setmetatable({panelId=110,view=browserView(),m_isClosed=false,m_phase={phaseId=1}},{__index=B})
    b:OnCreate();b:OnShow()
    assert(ZMLModMenu.state=='page_open', ZMLModMenu.error)
    b.view.mailList.transform.rect.width=1000;flush()
    assert(b.zml.searchRoot.width==920 and b.zml.search.kind=='search' and ZMLModMenu.state=='page_open')
    assert(b.view.zmlTitle=='模组菜单' and b.view.mailList.count==#ZML.mods() and b.view.getBtn.text=='模组配置')
    assert(b.headerCleared and not b.view.listCountText.active and not b.view.listTitleTxt.active)
    assert(not b.view.sendTimeTxt.active and b.zml.detailBadges[2].view.name.text=='已加载')
    assert(b.view.mailName.text=='模组菜单' or b.view.mailName.text=='测试模组')
    b.zml.search.commit('测试');flush();assert(b.view.mailList.count==1 and b.view.mailName.text=='测试模组')
    assert(b.zml.detailBadges[1].full and b.view.getBtn.text=='模组配置')
    assert(b.view.contentTxt.text==ZML.mod('demo').description) -- verify description textody
    local badges=b.view.mailList.cells[1].zmlBadges
    assert(badges[1].view.name.text=='v1.2.3' and badges[2].view.name.text=='测试' and badges[3].view.name.text=='工具')
    assert(ZML.set('mod-menu','show_tags',false));flush()
    assert(not badges[2].object.active and not badges[3].object.active)
    assert(ZML.set('mod-menu','show_tags',true));flush();assert(badges[2].object.active)
    b.zml.search.commit('does not exist');flush();assert(b.view.mailList.count==0 and not b.view.mailContentNode.active)
    b.zml.search.commit('');flush();assert(b.view.mailList.count==#ZML.mods())
    b.view.delReadBtn.onClick:Invoke();flush();assert(PhaseManager.popped==nil and ZMLModMenu.state~='render_error')
    b.view.mailList.cells[1].button.onClick:Invoke();assert(b.zml.selected==b.zml.items[1].id)
    b.boundBack();assert(PhaseManager.popped==1)
    b:OnClose()
end
function mountMinimal()
    -- Registration used by tests; main mount needs actual Unity hierarchy.
    ZMLModMenu.browser=MockNative.register('ZMLModBrowser',10,classes.ZMLModBrowserCtrl)
    ZMLModMenu.config=MockNative.register('ZMLModConfig',20,classes.ZMLModConfigCtrl)
end
function verifyUidConfig()
    local C=classes.ZMLModConfigCtrl
    local c=setmetatable({panelId=120,view=configView(),m_isClosed=false,m_phase={phaseId=1}},{__index=C})
    c:OnCreate({id='uid-mask'});c:OnShow();flush()
    assert(ZML.mod('uid-mask').config_menu=='standard' and not ZML.mod('uid-mask').has_entry)
    assert(ZML.config_entry('uid-mask')==nil and c.zml.cells.count==6 and c.zml.entryButton==nil and c.zml.customRoot==nil)
    local rows=c.zml.cells.items
    assert(rows[1].itemControl.toggle.value and not rows[3].itemControl.toggle.value and not rows[5].itemControl.toggle.value)
    rows[3].itemControl.toggle.change(true);rows[5].itemControl.toggle.change(true)
    local inputs=c.inputs
    for _,input in ipairs(inputs)do assert(input.kind=='standard-settings')end
    inputs[#inputs-2].commit('123456')
    inputs[#inputs-1].commit('验证昵称')
    inputs[#inputs].commit('0007')
    assert(ZML.get('uid-mask').alias_uid=='123456' and ZML.get('uid-mask').alias_name=='验证昵称' and ZML.get('uid-mask').alias_short_id=='0007')
    inputs[#inputs].commit('#bad');flush()
    assert(ZML.get('uid-mask').alias_short_id=='0007' and c.zml.cells.count==6 and c.zml.entryButton==nil)
    c.view.resetBtn.onClick:Invoke();flush();flush()
    local v=ZML.get('uid-mask');assert(v.enabled=='true' and v.alias_uid=='1000000000' and v.mask_name=='false' and v.mask_short_id=='false')
    c:OnClose()
end
