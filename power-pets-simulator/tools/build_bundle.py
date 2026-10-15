"""Собирает один файл bundle.luau: API-таблица + исходники игры (как их раскладывает Rojo) + мок + тест.
Запуск: python3 build_bundle.py <папка проекта> <api.luau> <mock.luau> <test.luau> <bundle.luau>
"""
import json, os, sys
root, api_path, mock_path, test, out = sys.argv[1:6]
sources, tree = {}, []
def add_dir(src_dir, inst_path):
    for dirpath, dirnames, filenames in os.walk(src_dir):
        dirnames.sort()
        rel = os.path.relpath(dirpath, src_dir)
        base = inst_path if rel == '.' else inst_path + '/' + rel.replace(os.sep, '/')
        for f in sorted(filenames):
            full = os.path.join(dirpath, f)
            relsrc = os.path.relpath(full, root).replace(os.sep, '/')
            if f.endswith('.server.lua'):
                name, cls = f[:-11], 'Script'
            elif f.endswith('.client.lua'):
                name, cls = f[:-11], 'LocalScript'
            elif f.endswith('.lua'):
                name, cls = f[:-4], 'ModuleScript'
            elif f.endswith('.model.json'):
                data = json.load(open(full, encoding='utf-8'))
                tree.append({'path': base + '/' + f[:-11], 'class': data['className'], 'props': data.get('properties', {})})
                continue
            else:
                continue
            sources[relsrc] = open(full, encoding='utf-8').read()
            tree.append({'path': base + '/' + name, 'class': cls, 'source': relsrc})
tree.append({'path': 'StarterPlayer/StarterPlayerScripts', 'class': 'StarterPlayerScripts'})
add_dir(os.path.join(root, 'src/shared'), 'ReplicatedStorage/Shared')
add_dir(os.path.join(root, 'src/server'), 'ServerScriptService/Server')
add_dir(os.path.join(root, 'src/client'), 'StarterPlayer/StarterPlayerScripts/Client')
add_dir(os.path.join(root, 'src/gui'), 'StarterGui')
def lstr(s):
    level = 1
    while ('[' + '='*level + '[') in s or (']' + '='*level + ']') in s:
        level += 1
    return '[' + '='*level + '[\n' + s + ']' + '='*level + ']'
def lval(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    raise Exception(v)
parts = []
parts.append('local API = (function()\n' + open(api_path, encoding='utf-8').read() + '\nend)()\n')
parts.append('local SOURCES = {\n' + ''.join('[%s] = %s,\n' % (json.dumps(k), lstr(v)) for k, v in sources.items()) + '}\n')
tl = []
for n in tree:
    props = ''
    if n.get('props'):
        props = ', props = {' + ', '.join('%s = %s' % (k, lval(v)) for k, v in n['props'].items()) + '}'
    src = (', source = %s' % json.dumps(n['source'])) if n.get('source') else ''
    tl.append('{ path = %s, class = %s%s%s },' % (json.dumps(n['path']), json.dumps(n['class']), src, props))
parts.append('local TREE = {\n' + '\n'.join(tl) + '\n}\n')
parts.append('local M = (function()\n' + open(mock_path, encoding='utf-8').read() + '\nend)()\n')
parts.append(open(test, encoding='utf-8').read())
open(out, 'w', encoding='utf-8').write('\n'.join(parts))
print('bundle ok:', len(sources), 'sources,', len(tree), 'tree nodes')
