# Сборка файла места Roblox из папки src/:  python3 build.py  ->  AmberAlert.rbxlx
#
# Правила (как у Rojo):
#   папка                 -> Folder
#   Имя.server.lua        -> Script
#   Имя.client.lua        -> LocalScript
#   Имя.lua               -> ModuleScript
#   Имя.lua + папка Имя/  -> ModuleScript, а содержимое папки — его дети
# Верхние папки src/ — это службы (ReplicatedStorage, ServerScriptService, StarterPlayer ...).
import os, html

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'AmberAlert.rbxlx')

_ref = [0]
def nref():
    _ref[0] += 1
    return 'RBX%08X' % _ref[0]

def esc(s):
    return html.escape(str(s), quote=False)

# свойства: ('bool', v) ('token', n) ('float', x) ('int', n) ('string', s) ('Color3', (r, g, b) 0..1) ('Vector3', (x, y, z))
def prop(name, kind, v):
    if kind == 'bool':
        return '<bool name="%s">%s</bool>' % (name, 'true' if v else 'false')
    if kind == 'Color3':
        return '<Color3 name="%s"><R>%g</R><G>%g</G><B>%g</B></Color3>' % (name, v[0], v[1], v[2])
    if kind == 'Vector3':
        return '<Vector3 name="%s"><X>%g</X><Y>%g</Y><Z>%g</Z></Vector3>' % (name, v[0], v[1], v[2])
    if kind in ('float', 'double'):
        return '<%s name="%s">%g</%s>' % (kind, name, v, kind)
    return '<%s name="%s">%s</%s>' % (kind, name, esc(v), kind)

def item(cls, name, props='', children=''):
    return '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>%s</Properties>%s</Item>' % (
        cls, nref(), esc(name), props, children)

def script_item(cls, name, path, children=''):
    src = open(path, encoding='utf-8').read()
    assert ']]>' not in src, path
    return item(cls, name, '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % src, children)

def build_dir(path):
    out = []
    entries = sorted(os.listdir(path))
    files = [e for e in entries if e.endswith('.lua')]
    dirs = [e for e in entries if os.path.isdir(os.path.join(path, e))]
    module_dirs = set()
    for f in files:
        full = os.path.join(path, f)
        if f.endswith('.server.lua'):
            out.append(script_item('Script', f[:-len('.server.lua')], full))
        elif f.endswith('.client.lua'):
            out.append(script_item('LocalScript', f[:-len('.client.lua')], full))
        else:
            name = f[:-len('.lua')]
            kids = ''
            if name in dirs:
                module_dirs.add(name)
                kids = build_dir(os.path.join(path, name))
            out.append(script_item('ModuleScript', name, full, kids))
    for d in dirs:
        if d in module_dirs:
            continue
        cls = d if d in ('StarterPlayerScripts', 'StarterCharacterScripts') else 'Folder'
        out.append(item(cls, d, '', build_dir(os.path.join(path, d))))
    return ''.join(out)

def service(cls, props='', children=''):
    return item(cls, cls, props, children)

def src_children(name):
    p = os.path.join(SRC, name)
    return build_dir(p) if os.path.isdir(p) else ''

# освещение: Realistic (бывший Future), мягкие тени, отражения окружения — остальное настраивает клиент по сцене
lighting = ''.join([
    prop('Technology', 'token', 4),             # Future (для старых версий Studio)
    prop('LightingStyle', 'token', 0),          # Realistic
    prop('PrioritizeLightingQuality', 'bool', True),
    prop('GlobalShadows', 'bool', True),
    prop('ShadowSoftness', 'float', 0.25),
    prop('EnvironmentDiffuseScale', 'float', 1),
    prop('EnvironmentSpecularScale', 'float', 1),
    prop('Brightness', 'float', 2),
    prop('ClockTime', 'float', 0.5),
    prop('Ambient', 'Color3', (0.07, 0.07, 0.1)),
    prop('OutdoorAmbient', 'Color3', (0.16, 0.17, 0.22)),
    prop('ExposureCompensation', 'float', 0),
])
workspace = ''.join([
    prop('StreamingEnabled', 'bool', False),      # всё строится скриптами — клиенту нужен весь мир
])
starter_player = ''.join([
    prop('CameraMaxZoomDistance', 'float', 22),
    prop('CharacterWalkSpeed', 'float', 14),
    prop('CharacterJumpHeight', 'float', 5.5),
])

parts = [
    service('Workspace', workspace),
    service('Lighting', lighting),
    service('ReplicatedStorage', '', src_children('ReplicatedStorage')),
    service('ServerScriptService', '', src_children('ServerScriptService')),
    service('StarterPlayer', starter_player, src_children('StarterPlayer')),
    service('SoundService', prop('RespectFilteringEnabled', 'bool', True)),
]
out = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n<External>null</External>\n<External>nil</External>\n'
       + '\n'.join(parts) + '\n</roblox>\n')
open(OUT, 'w', encoding='utf-8').write(out)
print(os.path.basename(OUT), len(out.encode('utf-8')), 'bytes')
