"""Lua/API/native-adapter behavioral checks; not client/visual acceptance."""
import argparse, base64, pathlib, subprocess, sys
p=argparse.ArgumentParser();p.add_argument('--lupa-dir');p.add_argument('--services',required=True);args=p.parse_args()
if args.lupa_dir:sys.path.insert(0,args.lupa_dir)
from lupa.lua54 import LuaRuntime
root=pathlib.Path(__file__).resolve().parents[1]
server=subprocess.Popen([str(pathlib.Path(args.services).resolve()),'--serve',str(root/'mod/mod.ini')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def route(_, path):
    server.stdin.write((path+'\n').encode());server.stdin.flush()
    length=int(server.stdout.readline());data=server.stdout.read(length)
    assert len(data)==length
    return data.decode('utf-8')
try:
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().native_route=route
    lua.execute('loadstring=load; LuaManagerInst={LoadLua=function(self,p)return native_route(self,p)end}')
    api=lua.execute(route(None,'ZML/Api'))
    lua.execute('''
        assert(#ZML.mods()==2 and ZML.mod('disabled')==nil)
        local first=ZML.mods();first[1].name='modified';assert(ZML.mods()[1].name~='modified')
        local v=ZML.get('demo');v.enabled='false';assert(ZML.get('demo').enabled=='true')
        local events=0
        local unsub=ZML.subscribe('demo',function(key,value,values,restart)
            assert(key=='amount' and value=='4' and values.amount=='4' and restart);events=events+1
        end)
        assert(not ZML.set('demo','amount',3));assert(events==0)
        assert(ZML.set('demo','amount',4));assert(events==1);unsub()
        assert(ZML.set('demo','amount',2));assert(events==1)
        assert(ZML.config_entry('demo').api==1 and ZML.config_entry('demo')==ZML.config_entry('demo'))
        assert(ZML.config_entry('mod-menu')==nil)
        assert(ZML.report('mod-menu','page_open') and not ZML.report('mod-menu','../../private'))
    ''')
    model=(root/'mod/model.lua').read_text(encoding='utf-8')
    native=(root/'mod/native-ui.lua').read_text(encoding='utf-8')
    assert native.count('__ZML_WATCH_ICON__') == 1
    native=native.replace('__ZML_WATCH_ICON__', '"'+base64.b64encode((root/'mod/watch-icon.png').read_bytes()).decode('ascii')+'"')
    main=(root/'mod/mod-menu.lua').read_text(encoding='utf-8')
    assembled=main.replace('__ZML_MODEL__','(function()\n'+model+'\nend)()').replace('__ZML_NATIVE__','(function()\n'+native+'\nend)()')
    syntax=lua.eval('function(s,n)local f,e=load(s,n);assert(f,e);return true end')
    for name,source in [('native-ui.lua',native),('model.lua',model),('mod-menu.assembled.lua',assembled)]:syntax(source,'@'+name)
    lua.globals().TestModel=lua.execute(model)
    lua.execute('''
        local m=TestModel;local mods=ZML.mods()
        assert(#m.filter(mods,'测试','全部')==1 and #m.filter(mods,'','配置')==1)
        local page,index,count=m.page(mods,99,1);assert(#page==1 and index==2 and count==2)
        assert(m.next_value({type='number',min=0,max=10,step=2,default='2'},'10',1)=='10')
        assert(m.next_value({type='bool'},'true',1)=='false')
        assert(m.theme(ZML.mod('mod-menu').values).accent==nil and #ZML.mod('mod-menu').config.fields==4)
    ''')
    lua.execute((root/'tests/native_menu_mock.lua').read_text(encoding='utf-8'))
    factory=lua.execute(native)
    theme=lua.eval("function()return TestModel.theme(ZML.mod('mod-menu').values)end")
    realnative=factory(api,theme,lua.eval('function()end'))
    lua.globals().verifyNative(realnative)
    lua.globals().verifyNativeControls(realnative)
    lua.globals().verifyNativeIcons(realnative)
    # Invoke actual Mod rendering/config code with API-shaped UI fixtures.
    mocked=main.replace('__ZML_MODEL__','(function()\n'+model+'\nend)()').replace('__ZML_NATIVE__','function()return MockNative end')
    lua.execute(mocked)
    assert lua.globals().ZMLModMenu.state=='controller_loaded',lua.globals().ZMLModMenu.error
    lua.execute('mountMinimal(); verifyConfig(); verifyBrowser()')
    print('PASS: assembled Lua54 syntax, live native services/API, model, native panel isolation/cache/style, config controls/save/reset/back, browser search/select/back')
finally:
    server.stdin.close()
    try:server.wait(timeout=5)
    except subprocess.TimeoutExpired:server.kill();server.wait()
    if server.returncode:raise RuntimeError(server.stderr.read().decode(errors='replace'))
