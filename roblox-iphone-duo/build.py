# Сборка файла места Roblox (.rbxlx) из скриптов в src/: python3 build.py -> iPhone_Duo.rbxlx
import os, html
ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'src')
ref = [0]
def nref():
    ref[0] += 1
    return 'RBX%08X' % ref[0]
def script(cls, name, path):
    src = open(os.path.join(SRC, path), encoding='utf-8').read()
    assert ']]>' not in src, path
    return ('<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>'
            '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString></Properties></Item>') % (cls, nref(), html.escape(name), src)
def service(cls, children=''):
    return '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string></Properties>%s</Item>' % (cls, nref(), cls, children)
parts = [
    service('Workspace'),
    service('Lighting'),
    service('ReplicatedStorage', script('ModuleScript', 'PhoneConfig', 'ReplicatedStorage/PhoneConfig.lua')),
    service('ServerStorage'),
    service('ServerScriptService', script('ModuleScript', 'MapBuilder', 'ServerScriptService/MapBuilder.lua')
            + script('Script', 'GameServer', 'ServerScriptService/GameServer.lua')),
    service('StarterPlayer', '<Item class="StarterPlayerScripts" referent="%s"><Properties><string name="Name">StarterPlayerScripts</string></Properties>%s</Item>'
            % (nref(), script('LocalScript', 'PhoneClient', 'StarterPlayerScripts/PhoneClient.lua'))),
]
out = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n<External>null</External>\n<External>nil</External>\n'
       + '\n'.join(parts) + '\n</roblox>\n')
open(os.path.join(ROOT, 'iPhone_Duo.rbxlx'), 'w', encoding='utf-8').write(out)
print('iPhone_Duo.rbxlx', len(out.encode('utf-8')), 'bytes')
