# Запись файла места Roblox в формате XML (.rbxlx).
# Дерево собирается из объектов Inst; свойства хранятся с типом, чтобы и Studio,
# и песочница (tools/sandbox.py) получали одно и то же.
import html
import math

# Настоящие значения перечислений Roblox (то, что Studio ждёт в <token>)
ENUMS = {
    'Material': {
        'Plastic': 256, 'SmoothPlastic': 272, 'Neon': 288, 'Wood': 512, 'WoodPlanks': 528, 'Marble': 784,
        'Basalt': 788, 'Slate': 800, 'CrackedLava': 804, 'Concrete': 816, 'Limestone': 820, 'Granite': 832,
        'Pavement': 836, 'Brick': 848, 'Pebble': 864, 'Cobblestone': 880, 'Rock': 896, 'Sandstone': 912,
        'CorrodedMetal': 1040, 'DiamondPlate': 1056, 'Foil': 1072, 'Metal': 1088, 'Grass': 1280,
        'LeafyGrass': 1284, 'Sand': 1296, 'Fabric': 1312, 'Snow': 1328, 'Mud': 1344, 'Ground': 1360,
        'Asphalt': 1376, 'Salt': 1392, 'Ice': 1536, 'Glacier': 1552, 'Glass': 1568, 'ForceField': 1584,
        'Air': 1792, 'Water': 2048,
    },
    'PartType': {'Ball': 0, 'Block': 1, 'Cylinder': 2, 'Wedge': 3, 'CornerWedge': 4},
    'SurfaceType': {'Smooth': 0, 'Glue': 1, 'Weld': 2, 'Studs': 3, 'Inlet': 4, 'Universal': 5, 'Hinge': 6,
                    'Motor': 7, 'SteppingMotor': 8, 'SmoothNoOutlines': 10},
    'NormalId': {'Right': 0, 'Top': 1, 'Back': 2, 'Left': 3, 'Bottom': 4, 'Front': 5},
    'MeshType': {'Head': 0, 'Torso': 1, 'Wedge': 2, 'Sphere': 3, 'Cylinder': 4, 'FileMesh': 5, 'Brick': 6,
                 'Prism': 7, 'Pyramid': 8, 'ParallelRamp': 9, 'RightAngleRamp': 10, 'CornerWedge': 11},
    'HumanoidRigType': {'R6': 0, 'R15': 1},
    'Technology': {'Legacy': 0, 'Voxel': 1, 'Compatibility': 2, 'ShadowMap': 3, 'Future': 4},
    'LightingStyle': {'Realistic': 0, 'Soft': 1},
    'CameraType': {'Fixed': 0, 'Attach': 1, 'Watch': 2, 'Track': 3, 'Follow': 4, 'Custom': 5, 'Scriptable': 6, 'Orbital': 7},
    'HumanoidDisplayDistanceType': {'Viewer': 0, 'Subject': 1, 'None': 2},
    'HumanoidHealthDisplayType': {'DisplayWhenDamaged': 0, 'AlwaysOn': 1, 'AlwaysOff': 2},
    'NameOcclusion': {'NoOcclusion': 0, 'EnemyOcclusion': 1, 'OccludeAll': 2},
    'CameraMode': {'Classic': 0, 'LockFirstPerson': 1},
    'RunContext': {'Legacy': 0, 'Server': 1, 'Client': 2, 'Plugin': 3},
}

# как свойство называется в файле и в API (Studio читает имя из файла)
SERIAL_NAMES = {('BasePart', 'Size'): 'size', ('BasePart', 'Shape'): 'shape', ('BasePart', 'Color'): 'Color3uint8'}
PART_CLASSES = {'Part', 'SpawnLocation', 'WedgePart', 'CornerWedgePart', 'TrussPart', 'Seat'}


def fnum(x):
    if isinstance(x, bool):
        return 'true' if x else 'false'
    if isinstance(x, int):
        return str(x)
    if x != x or x in (math.inf, -math.inf):
        raise ValueError('NaN/inf в свойстве')
    r = round(x, 6)
    if r == int(r) and abs(r) < 1e15:
        return str(int(r))
    return repr(r)


class Prop:
    __slots__ = ('kind', 'value')

    def __init__(self, kind, value):
        self.kind, self.value = kind, value


def Bool(v): return Prop('bool', bool(v))
def Float(v): return Prop('float', float(v))
def Double(v): return Prop('double', float(v))
def Int(v): return Prop('int', int(v))
def Str(v): return Prop('string', str(v))
def Vec3(x, y, z): return Prop('Vector3', (float(x), float(y), float(z)))
def Vec2(x, y): return Prop('Vector2', (float(x), float(y)))
def Color(r, g, b): return Prop('Color3', (float(r), float(g), float(b)))
def Content(url): return Prop('Content', url or '')
def Token(enum_type, name):
    if name not in ENUMS[enum_type]:
        raise KeyError('нет %s.%s' % (enum_type, name))
    return Prop('token', (enum_type, name))
def Ref(inst): return Prop('Ref', inst)
def UDim2(xs, xo, ys, yo): return Prop('UDim2', (float(xs), int(xo), float(ys), int(yo)))
def Source(text): return Prop('ProtectedString', text)
def CF(m): return Prop('CoordinateFrame', tuple(float(v) for v in m))  # 12 чисел: x y z r00..r22


def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


class Inst:
    __slots__ = ('cls', 'name', 'props', 'children', 'ref', 'src', 'tags', 'attrs')

    def __init__(self, cls, name=None, **props):
        self.cls = cls
        self.name = name if name is not None else cls
        self.props = {}
        self.children = []
        self.ref = None
        self.src = None
        self.tags = []
        self.attrs = {}
        for k, v in props.items():
            self.set(k, v)

    def set(self, k, v):
        if not isinstance(v, Prop):
            raise TypeError('свойство %s.%s без типа' % (self.cls, k))
        self.props[k] = v
        return self

    def add(self, *kids):
        for c in kids:
            self.children.append(c)
        return kids[0] if len(kids) == 1 else kids

    def walk(self):
        yield self
        for c in self.children:
            yield from c.walk()


# ---------------- XML ----------------
def _esc(s):
    return html.escape(str(s), quote=False)


def _prop_xml(inst, name, p, refid):
    k, v = p.kind, p.value
    sname = name
    if inst.cls in PART_CLASSES:
        sname = SERIAL_NAMES.get(('BasePart', name), name)
    if k == 'bool':
        return '<bool name="%s">%s</bool>' % (sname, 'true' if v else 'false')
    if k in ('float', 'double', 'int', 'int64'):
        return '<%s name="%s">%s</%s>' % (k, sname, fnum(v), k)
    if k == 'string':
        return '<string name="%s">%s</string>' % (sname, _esc(v))
    if k == 'ProtectedString':
        if ']]>' in v:
            raise ValueError(']]> в исходнике %s' % inst.name)
        return '<ProtectedString name="%s"><![CDATA[%s]]></ProtectedString>' % (sname, v)
    if k == 'Vector3':
        return '<Vector3 name="%s"><X>%s</X><Y>%s</Y><Z>%s</Z></Vector3>' % (sname, fnum(v[0]), fnum(v[1]), fnum(v[2]))
    if k == 'Vector2':
        return '<Vector2 name="%s"><X>%s</X><Y>%s</Y></Vector2>' % (sname, fnum(v[0]), fnum(v[1]))
    if k == 'Color3':
        if name == 'Color' and inst.cls in PART_CLASSES:
            r, g, b = [max(0, min(255, int(round(c * 255)))) for c in v]
            return '<Color3uint8 name="Color3uint8">%d</Color3uint8>' % (0xFF000000 | (r << 16) | (g << 8) | b)
        return '<Color3 name="%s"><R>%s</R><G>%s</G><B>%s</B></Color3>' % (sname, fnum(v[0]), fnum(v[1]), fnum(v[2]))
    if k == 'Content':
        if not v:
            return '<Content name="%s"><null></null></Content>' % sname
        return '<Content name="%s"><url>%s</url></Content>' % (sname, _esc(v))
    if k == 'token':
        et, nm = v
        return '<token name="%s">%d</token>' % (sname, ENUMS[et][nm])
    if k == 'Ref':
        return '<Ref name="%s">%s</Ref>' % (sname, refid(v) if v is not None else 'null')
    if k == 'UDim2':
        return '<UDim2 name="%s"><XS>%s</XS><XO>%d</XO><YS>%s</YS><YO>%d</YO></UDim2>' % (sname, fnum(v[0]), v[1], fnum(v[2]), v[3])
    if k == 'CoordinateFrame':
        names = ['X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22']
        return '<CoordinateFrame name="%s">%s</CoordinateFrame>' % (sname, ''.join('<%s>%s</%s>' % (n, fnum(x), n) for n, x in zip(names, v)))
    raise ValueError('неизвестный тип свойства ' + k)


def _tags_xml(tags):
    import base64
    if not tags:
        return ''
    data = '\0'.join(tags).encode('utf-8')
    return '<BinaryString name="Tags">%s</BinaryString>' % base64.b64encode(data).decode('ascii')


def _attrs_xml(attrs):
    # формат AttributesSerialize: uint32 count, затем (uint32 len, name, type byte, value)
    import base64, struct
    if not attrs:
        return ''
    out = bytearray(struct.pack('<I', len(attrs)))
    for k in sorted(attrs):
        v = attrs[k]
        kb = k.encode('utf-8')
        out += struct.pack('<I', len(kb)) + kb
        if isinstance(v, bool):
            out += b'\x03' + (b'\x01' if v else b'\x00')
        elif isinstance(v, (int, float)):
            out += b'\x06' + struct.pack('<d', float(v))
        elif isinstance(v, str):
            vb = v.encode('utf-8')
            out += b'\x02' + struct.pack('<I', len(vb)) + vb
        else:
            raise TypeError('атрибут %s: тип %r' % (k, type(v)))
    return '<BinaryString name="AttributesSerialize">%s</BinaryString>' % base64.b64encode(bytes(out)).decode('ascii')


def to_xml(roots):
    counter = [0]
    ids = {}

    def refid(inst):
        if id(inst) not in ids:
            counter[0] += 1
            ids[id(inst)] = 'RBX%08X' % counter[0]
        return ids[id(inst)]

    parts = []

    def emit(inst):
        rid = refid(inst)
        props = ['<string name="Name">%s</string>' % _esc(inst.name)]
        for k, p in inst.props.items():
            props.append(_prop_xml(inst, k, p, refid))
        props.append(_tags_xml(inst.tags))
        props.append(_attrs_xml(inst.attrs))
        parts.append('<Item class="%s" referent="%s"><Properties>%s</Properties>' % (inst.cls, rid, ''.join(props)))
        for c in inst.children:
            emit(c)
        parts.append('</Item>\n')

    for r in roots:
        emit(r)
    head = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
            '<External>null</External>\n<External>nil</External>\n')
    return head + ''.join(parts) + '</roblox>\n'


# ---------------- CFrame ----------------
def cf_pos(x, y, z):
    return (x, y, z, 1, 0, 0, 0, 1, 0, 0, 0, 1)


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def rot_x(t):
    c, s = math.cos(t), math.sin(t)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(t):
    c, s = math.cos(t), math.sin(t)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(t):
    c, s = math.cos(t), math.sin(t)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def cf(x, y, z, rx=0.0, ry=0.0, rz=0.0):
    # как CFrame.new(x,y,z) * CFrame.Angles(rx, ry, rz)  (Angles = Rx * Ry * Rz)
    m = mat_mul(mat_mul(rot_x(rx), rot_y(ry)), rot_z(rz))
    return (x, y, z, m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2])


def cf_mul(a, b):
    ra = [[a[3], a[4], a[5]], [a[6], a[7], a[8]], [a[9], a[10], a[11]]]
    rb = [[b[3], b[4], b[5]], [b[6], b[7], b[8]], [b[9], b[10], b[11]]]
    m = mat_mul(ra, rb)
    px = a[0] + ra[0][0] * b[0] + ra[0][1] * b[1] + ra[0][2] * b[2]
    py = a[1] + ra[1][0] * b[0] + ra[1][1] * b[1] + ra[1][2] * b[2]
    pz = a[2] + ra[2][0] * b[0] + ra[2][1] * b[1] + ra[2][2] * b[2]
    return (px, py, pz, m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2])


def cf_look(px, py, pz, tx, ty, tz):
    # CFrame.lookAt без крена (вверх = +Y)
    fx, fy, fz = tx - px, ty - py, tz - pz
    L = math.sqrt(fx * fx + fy * fy + fz * fz) or 1
    fx, fy, fz = fx / L, fy / L, fz / L
    # right = forward x up
    rx, ry, rz = -fz, 0.0, fx
    rl = math.sqrt(rx * rx + rz * rz)
    if rl < 1e-6:
        rx, ry, rz = 1.0, 0.0, 0.0
    else:
        rx, rz = rx / rl, rz / rl
    # up = right x forward
    ux = ry * fz - rz * fy
    uy = rz * fx - rx * fz
    uz = rx * fy - ry * fx
    # столбцы: right, up, -forward
    return (px, py, pz, rx, ux, -fx, ry, uy, -fy, rz, uz, -fz)
