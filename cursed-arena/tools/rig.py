# R6-персонаж для StarterPlayer.StarterCharacter (тот же, что собирает Rig Builder в Studio)
from rbxlx import Inst, Bool, Float, Vec3, Color, Content, Token, Ref, CF, cf_pos, rgb

R6_SKIN = rgb(234, 184, 146)


def part(name, size, pos, color, collide):
    p = Inst('Part', name,
             Anchored=Bool(False), CanCollide=Bool(collide), Size=Vec3(*size), CFrame=CF(cf_pos(*pos)),
             Color=Color(*color), Material=Token('Material', 'SmoothPlastic'),
             TopSurface=Token('SurfaceType', 'Smooth'), BottomSurface=Token('SurfaceType', 'Smooth'),
             Locked=Bool(True))
    return p


def attach(parent, name, pos):
    parent.add(Inst('Attachment', name, CFrame=CF(cf_pos(*pos))))


def motor(name, p0, p1, c0, c1):
    m = Inst('Motor6D', name, C0=CF(c0), C1=CF(c1), Part0=Ref(p0), Part1=Ref(p1))
    p0.add(m)
    return m


def build_r6(name='StarterCharacter', shirt=(0.16, 0.18, 0.24), pants=(0.1, 0.1, 0.13)):
    m = Inst('Model', name)
    hrp = part('HumanoidRootPart', (2, 2, 1), (0, 3, 0), (0.64, 0.64, 0.64), False)
    hrp.set('Transparency', Float(1))
    torso = part('Torso', (2, 2, 1), (0, 3, 0), shirt, True)
    head = part('Head', (2, 1, 1), (0, 4.5, 0), R6_SKIN, True)
    la = part('Left Arm', (1, 2, 1), (-1.5, 3, 0), R6_SKIN, False)
    ra = part('Right Arm', (1, 2, 1), (1.5, 3, 0), R6_SKIN, False)
    ll = part('Left Leg', (1, 2, 1), (-0.5, 1, 0), pants, False)
    rl = part('Right Leg', (1, 2, 1), (0.5, 1, 0), pants, False)
    head.add(Inst('SpecialMesh', 'Mesh', MeshType=Token('MeshType', 'Head'), Scale=Vec3(1.25, 1.25, 1.25)))
    head.add(Inst('Decal', 'face', Texture=Content('rbxasset://textures/face.png'), Face=Token('NormalId', 'Front')))
    for p in (hrp, torso, head, la, ra, ll, rl):
        m.add(p)
    # вложения для аксессуаров (ApplyDescription вешает шляпы, волосы и т.д.)
    attach(hrp, 'RootAttachment', (0, 0, 0))
    attach(head, 'HairAttachment', (0, 0.6, 0))
    attach(head, 'HatAttachment', (0, 0.6, 0))
    attach(head, 'FaceFrontAttachment', (0, 0, -0.6))
    attach(head, 'FaceCenterAttachment', (0, 0, 0))
    attach(torso, 'NeckAttachment', (0, 1, 0))
    attach(torso, 'BodyFrontAttachment', (0, 0, -0.5))
    attach(torso, 'BodyBackAttachment', (0, 0, 0.5))
    attach(torso, 'LeftCollarAttachment', (-1, 1, 0))
    attach(torso, 'RightCollarAttachment', (1, 1, 0))
    attach(torso, 'WaistFrontAttachment', (0, -1, -0.5))
    attach(torso, 'WaistCenterAttachment', (0, -1, 0))
    attach(torso, 'WaistBackAttachment', (0, -1, 0.5))
    attach(la, 'LeftShoulderAttachment', (0, 1, 0))
    attach(la, 'LeftGripAttachment', (0, -1, 0))
    attach(ra, 'RightShoulderAttachment', (0, 1, 0))
    attach(ra, 'RightGripAttachment', (0, -1, 0))
    attach(ll, 'LeftFootAttachment', (0, -1, 0))
    attach(rl, 'RightFootAttachment', (0, -1, 0))
    # суставы R6 (значения как у стандартного R6)
    motor('RootJoint', hrp, torso, (0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), (0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
    motor('Neck', torso, head, (0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), (0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
    motor('Right Shoulder', torso, ra, (1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), (-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
    motor('Left Shoulder', torso, la, (-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), (0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
    motor('Right Hip', torso, rl, (1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), (0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
    motor('Left Hip', torso, ll, (-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), (-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
    hum = Inst('Humanoid', 'Humanoid', RigType=Token('HumanoidRigType', 'R6'),
               HealthDisplayType=Token('HumanoidHealthDisplayType', 'AlwaysOff'),
               DisplayDistanceType=Token('HumanoidDisplayDistanceType', 'Viewer'),
               BreakJointsOnDeath=Bool(False), MaxHealth=Float(100), HipHeight=Float(0))
    m.add(hum)
    m.add(Inst('BodyColors', 'Body Colors',
               HeadColor3=Color(*R6_SKIN), LeftArmColor3=Color(*R6_SKIN), RightArmColor3=Color(*R6_SKIN),
               TorsoColor3=Color(*shirt), LeftLegColor3=Color(*pants), RightLegColor3=Color(*pants)))
    m.set('PrimaryPart', Ref(hrp))
    return m
