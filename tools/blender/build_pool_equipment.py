"""Author three lightweight pool props from the supplied photographic references.

Blender --background --factory-startup --python tools/blender/build_pool_equipment.py

Working coordinates are Godot (X, Y height, Z toward water). The pool lip is Z=0
and the deck is Y=0. Closed shells are explicitly sampled; no decimation or
high-poly render meshes are used. Render-only studio objects are never exported.
"""
from pathlib import Path
import json
import sys
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pool_equipment'
OUT = ROOT / 'models/authored/pool_equipment'
ART.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
(ART / '.gdignore').write_text('')
bpy.context.preferences.filepaths.save_version = 0
parts = []
FILTER = next((arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--filter=')), '')
collisions = json.loads((OUT/'collision.json').read_text()) if FILTER and (OUT/'collision.json').exists() else {}
statistics = json.loads((OUT/'mesh_stats.json').read_text()) if FILTER and (OUT/'mesh_stats.json').exists() else {}


def xyz(p):
    return (p[0], -p[2], p[1])


def material(name, color, roughness, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    bs.inputs['Metallic'].default_value = metallic
    return mat


def nonslip_normal(mat):
    """A tiny repeating manufactured grip normal replaces modeled tread bumps."""
    size = 128
    y, x = np.mgrid[:size, :size]/size
    # Cross-hatched ribs, analytically differentiated for seamless normal tiling.
    dx = -np.sin(math.tau*(x+y))-np.sin(math.tau*(x-y))
    dy = -np.sin(math.tau*(x+y))+np.sin(math.tau*(x-y))
    vectors = np.stack((-dx*.15, -dy*.15, np.ones_like(x)), axis=-1)
    vectors /= np.linalg.norm(vectors, axis=-1, keepdims=True)
    pixels = np.ones((size, size, 4), dtype=np.float32)
    pixels[:, :, :3] = vectors*.5+.5
    im = bpy.data.images.new('Pool board grip 128px normal', width=size, height=size, alpha=False)
    im.colorspace_settings.name = 'Non-Color'
    im.pixels.foreach_set(pixels.ravel())
    im.filepath_raw = str(ART/'board_grip_normal.png')
    im.file_format = 'PNG'
    im.save()
    im.pack()
    nodes = mat.node_tree.nodes
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = im
    normal = nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = .7
    mat.node_tree.links.new(tex.outputs['Color'], normal.inputs['Color'])
    mat.node_tree.links.new(normal.outputs['Normal'], nodes['Principled BSDF'].inputs['Normal'])


def reset():
    global parts
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    parts = []


def mesh(name, vertices, faces, mat, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in vertices], [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    data.materials.append(mat)
    for face in data.polygons:
        face.use_smooth = smooth and len(face.vertices) == 4
    parts.append(ob)
    return ob


def box(name, p, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(p))
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    if bevel:
        mod = ob.modifiers.new('Small manufactured edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    parts.append(ob)
    return ob


def tube(name, points, radius, mat, sides=8):
    verts, faces = [], []
    previous = None
    for i, p in enumerate(points):
        tangent = (Vector(points[min(i+1, len(points)-1)]) -
                   Vector(points[max(0, i-1)])).normalized()
        if previous is None:
            guide = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((0, 0, 1))
            u = tangent.cross(guide).normalized()
        else:
            u = (previous - tangent * previous.dot(tangent)).normalized()
        v = tangent.cross(u).normalized()
        previous = u
        for j in range(sides):
            a = math.tau * j / sides
            verts.append(Vector(p) + radius * (u * math.cos(a) + v * math.sin(a)))
    for i in range(len(points)-1):
        for j in range(sides):
            a, b = i*sides+j, i*sides+(j+1) % sides
            faces.append((a, b, b+sides, a+sides))
    faces += [tuple(reversed(range(sides))),
              tuple(range((len(points)-1)*sides, len(points)*sides))]
    return mesh(name, verts, faces, mat)


def rounded_slab(name, x, z, width, length, bottom, height, radius, mat):
    points = []
    for cx, cz, start in [(x+width/2-radius, z+length/2-radius, 0),
                          (x-width/2+radius, z+length/2-radius, 90),
                          (x-width/2+radius, z-length/2+radius, 180),
                          (x+width/2-radius, z-length/2+radius, 270)]:
        for j in range(4):
            a = math.radians(start + j*30)
            points.append((cx+radius*math.cos(a), cz+radius*math.sin(a)))
    verts = [(px, y, pz) for y in (bottom, bottom+height) for px, pz in points]
    n = len(points)
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(j, (j+1) % n, (j+1) % n+n, j+n) for j in range(n)]
    ob = mesh(name, verts, faces, mat, False)
    if 'nonslip' in mat.name.lower():
        uv = ob.data.uv_layers.new(name='Grip repeat')
        for loop in ob.data.loops:
            point = ob.data.vertices[loop.vertex_index].co
            uv.data[loop.index].uv = (point.x/.018, -point.y/.018)
    return ob


def extrude_side(name, profile, xmin, xmax, mat):
    n = len(profile)
    verts = [(x, y, z) for x in (xmin, xmax) for z, y in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2*n)))]
    faces += [(j, (j+1) % n, (j+1) % n+n, j+n) for j in range(n)]
    return mesh(name, verts, faces, mat, False)


def footing(p, radius, mat):
    tube('Circular anchor plate', [(p[0], 0, p[2]), (p[0], .025, p[2])], radius, mat, 8)


def support(a, b, radius, mat, data):
    tube('Structural tube', [a, b], radius, mat)
    data['support_legs'].append({'a': list(a), 'b': list(b), 'radius': radius})
    if a[1] <= .04:
        footing(a, radius*2.2, mat)


def smooth_points(keys, subdivisions, end_tangent=None):
    """Monotone cubic interpolation: no S-curve overshoot or tiny cap slivers."""
    out = []
    keys = [Vector(p) for p in keys]
    tangents = []
    for i, key in enumerate(keys):
        if i == 0:
            tangents.append(keys[1]-key)
        elif i == len(keys)-1:
            tangents.append(key-keys[i-1])
        else:
            tangent = (keys[i+1]-keys[i-1])*.5
            before, after = key.y-keys[i-1].y, keys[i+1].y-key.y
            tangent.y = 2*before*after/(before+after) if before*after > 0 else 0
            tangents.append(tangent)
    if end_tangent is not None:
        tangents[-1] = Vector(end_tangent)
    for i in range(len(keys)-1):
        for j in range(subdivisions):
            t = j/subdivisions
            out.append(tuple((2*t**3-3*t*t+1)*keys[i] + (t**3-2*t*t+t)*tangents[i] +
                             (-2*t**3+3*t*t)*keys[i+1] + (t**3-t*t)*tangents[i+1]))
    out.append(tuple(keys[-1]))
    return out


def trough(name, path, half_width, wall_height, mat, flare=False):
    """One closed fiberglass shell: rounded raised lips, concave bed, real underside.

    Cross-sections stay vertical. The visible inner floor matches collision.json
    centerline exactly; there are no solid triangles across the open chute mouth.
    """
    w, h = half_width, wall_height
    profile = [(-w-.057, h-.025), (-w-.055, h+.010), (-w-.030, h+.032),
               (-w+.004, h+.025), (-w+.025, h-.008), (-w+.030, .105),
               (-w+.072, .032), (-w+.15, 0), (w-.15, 0), (w-.072, .032),
               (w-.030, .105), (w-.025, h-.008), (w-.004, h+.025),
               (w+.030, h+.032), (w+.055, h+.010), (w+.057, h-.025),
               (w+.045, .072), (w-.030, -.028), (w-.13, -.044),
               (-w+.13, -.044), (-w+.030, -.028), (-w-.045, .072)]
    verts = []
    n = len(profile)
    for i, p in enumerate(path):
        tangent = Vector(path[min(i+1, len(path)-1)])-Vector(path[max(0, i-1)])
        tangent.y = 0
        tangent.normalize()
        cross = Vector((tangent.z, 0, -tangent.x))
        t = i/(len(path)-1)
        # Widen the final mouth modestly, taper its lip for a rounded water entry.
        amount = max(0, (t-.85)/.15) if flare else 0
        for across, height in profile:
            verts.append(Vector(p)+cross*across*(1+.08*amount)+Vector((0, height*(1-.40*amount), 0)))
    faces = []
    for i in range(len(path)-1):
        for j in range(n):
            a, b = i*n+j, i*n+(j+1) % n
            faces.append((a, b, b+n, a+n))
    faces += [tuple(reversed(range(n))), tuple(range((len(path)-1)*n, len(path)*n))]
    return mesh(name, verts, faces, mat)


def ladder(bottom, top, width, count, frame, tread, data, grab_height=.62):
    b, t = Vector(bottom), Vector(top)
    direction = t-b
    direction.y = 0
    direction.normalize()
    cross = Vector((direction.z, 0, -direction.x))
    data['ladder_bottom'], data['ladder_top'] = list(b), list(t)
    data['ladder_width'] = width
    for side in (-1, 1):
        a = b+cross*side*(width/2+.035)
        c = t+cross*side*(width/2+.035)
        support(tuple(a+Vector((0, .02, 0))), tuple(c), .028, frame, data)
        # Rounded top rail: sides of the access opening remain open for climbing.
        rail = [c-Vector((0, .15, 0)), c+Vector((0, grab_height-.1, 0)),
                c+direction*.025+Vector((0, grab_height-.035, 0)),
                c+direction*.08+Vector((0, grab_height, 0)),
                c+direction*.42+Vector((0, grab_height, 0)),
                c+direction*.49+Vector((0, grab_height-.035, 0)),
                c+direction*.515+Vector((0, grab_height-.1, 0)), c+direction*.515]
        tube('Rounded ladder grab rail', rail, .025, frame)
    for i in range(1, count+1):
        p = b.lerp(t, i/(count+1))
        # An extruded tread has a genuinely flat upper surface and only 12 triangles.
        a = p-cross*width/2
        c = p+cross*width/2
        verts = []
        for y in (-.022, .015):
            for point in (a-direction*.072, c-direction*.072, c+direction*.072, a+direction*.072):
                verts.append(point+Vector((0, y, 0)))
        mesh('Flat nonslip ladder tread', verts,
             [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
              (2, 3, 7, 6), (3, 0, 4, 7)], tread, False)


def studio(prop, name):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 8
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.35, .40, .46, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .5
    scene.view_settings.view_transform = 'AgX'
    stage = bpy.data.collections.new('Preview studio - excluded from GLB')
    scene.collection.children.link(stage)
    def put(ob):
        for col in list(ob.users_collection):
            col.objects.unlink(ob)
        stage.objects.link(ob)
    def aim(ob, p):
        ob.rotation_euler = (Vector(p)-ob.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.001))
    floor = bpy.context.object
    floor.data.materials.append(material('Preview floor', (.17, .195, .205), .8))
    put(floor)
    bounds = statistics[name]['bounds_godot_m']
    target = Vector(xyz([(lo+hi)*.5 for lo, hi in zip(bounds['min'], bounds['max'])]))
    for label, loc, power, size in [('Key', (-3, -4, 6), 900, 4),
                                   ('Fill', (4, -1, 4), 650, 3),
                                   ('Rim', (0, 4, 5), 1100, 3)]:
        bpy.ops.object.light_add(type='AREA', location=loc)
        ob = bpy.context.object
        ob.name = label
        ob.data.energy = power
        ob.data.size = size
        aim(ob, target)
        put(ob)
    bpy.ops.object.camera_add(location=(4, -6, 3.65) if 'slide' in name else (3, -4, 2.45))
    camera = bpy.context.object
    put(camera)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 4.70 if 'spiral' in name else (3.85 if 'slide' in name else 3.05)
    aim(camera, target)
    scene.camera = camera
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    folder = ART/name
    folder.mkdir(exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    prop.select_set(True)
    bpy.context.view_layer.objects.active = prop
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(name+'.blend')))
    for side in ('front', 'reverse'):
        if side == 'reverse':
            camera.location = (-4, 5, 3.9) if 'slide' in name else (-3, 4, 2.4)
            aim(camera, target)
        scene.render.filepath = str(folder/('preview_'+side+'.png'))
        bpy.ops.render.render(write_still=True)


def export(name, budget, collision):
    if FILTER and name != FILTER:
        return
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    prop = bpy.context.object
    prop.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Remove duplicate material slots left by joining to keep three draw surfaces.
    materials, mapping = [], {}
    for i, mat in enumerate(prop.data.materials):
        if mat not in materials:
            materials.append(mat)
        mapping[i] = materials.index(mat)
    indices = [mapping[f.material_index] for f in prop.data.polygons]
    prop.data.materials.clear()
    for mat in materials:
        prop.data.materials.append(mat)
    for face, index in zip(prop.data.polygons, indices):
        face.material_index = index
    bm = bmesh.new()
    bm.from_mesh(prop.data)
    invalid = sum(1 for edge in bm.edges if not edge.is_manifold)
    assert invalid == 0, (name, 'nonmanifold edges', invalid)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(prop.data)
    bm.free()
    count = len(prop.data.polygons)
    assert count <= budget, (name, count, budget)
    assert len(materials) <= 3
    coords = [Vector((v.co.x, v.co.z, -v.co.y)) for v in prop.data.vertices]
    lo = [min(v[i] for v in coords) for i in range(3)]
    hi = [max(v[i] for v in coords) for i in range(3)]
    stats = {'triangles': count, 'meshes': 1, 'materials': len(materials),
             'bounds_godot_m': {'min': lo, 'max': hi},
             'source': str((ART/name/(name+'.blend')).relative_to(ROOT)),
             'glb': str((OUT/(name+'.glb')).relative_to(ROOT)),
             'front_axis': '+Z', 'pool_lip_z': 0, 'deck_y': 0,
             'nonmanifold_edges': invalid,
             'material_names': [mat.name for mat in materials]}
    prop['triangles'] = count
    prop['front_axis'] = '+Z'
    prop['deck_y'] = 0.0
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB',
                             use_selection=True, export_yup=True, export_extras=True,
                             export_tangents=True)
    collisions[name] = collision
    statistics[name] = stats
    print('POOL_EQUIPMENT_STATS', json.dumps(stats), flush=True)
    studio(prop, name)


reset()
ivory = material('Warm white molded fiberglass', (.78, .80, .76), .34)
metal = material('Brushed stainless fittings', (.47, .51, .52), .31, .85)
grip = material('Graphite nonslip tread', (.055, .065, .07), .91)
nonslip_normal(grip)
rounded_slab('Rounded springboard shell', 0, -.30, .52, 2.4, .465, .055, .105, ivory)
rounded_slab('Rear nonslip pad', 0, -1.215, .466, .40, .520, .003, .055, grip)
rounded_slab('Main nonslip pad', 0, -.09, .466, 1.80, .520, .003, .085, grip)
# An open pedestal: two tapered molded cheeks and cross-foot, not a solid cube.
profile = [(-1.18, 0), (-.47, 0), (-.51, .09), (-.68, .35),
           (-.70, .395), (-.98, .395), (-1.01, .34), (-1.16, .09)]
for side in (-1, 1):
    xmin, xmax = sorted((side*.10, side*.28))
    cheek = extrude_side('Tapered pedestal cheek', profile, xmin, xmax, ivory)
    bpy.context.view_layer.objects.active = cheek
    bevel = cheek.modifiers.new('Soft molded pedestal edges', 'BEVEL')
    bevel.width = .025
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    # Folded stainless leaf is visibly separated from the board and pedestal.
    spring = [(-1.31, .458), (-1.20, .425), (-.94, .354), (-.77, .353),
              (-.55, .410), (-.40, .456), (-.42, .471), (-.58, .438),
              (-.79, .382), (-.94, .385), (-1.20, .450)]
    extrude_side('Curved spring support', spring, side*.12-.045, side*.12+.045, metal)
    for z in (-1.105, -.55):
        tube('Deck anchor bolt', [(side*.22, .025, z), (side*.22, .049, z)], .021, metal)
    tube('Rear board bolt', [(side*.18, .523, -1.31), (side*.18, .531, -1.31)], .017, metal)
box('Pedestal rear cross foot', (0, .055, -1.08), (.53, .085, .11), ivory, .012)
export('pool_diving_board', 1800,
       {'boxes': [{'center': [0, .492, -.30], 'size': [.52, .055, 2.4]},
                  {'center': [0, .19, -.835], 'size': [.55, .38, .68]}],
        'takeoff': [0, .52, .85], 'support_legs': []})


reset()
blue = material('Pool blue molded fiberglass', (.008, .14, .40), .32)
frame = material('Ivory powder coated frame', (.79, .80, .75), .42, .08)
metal = material('Satin stainless ladder treads', (.43, .49, .50), .39, .78)
path = smooth_points([(0, 1.65, -1.7), (0, 1.58, -1.25), (0, .85, -.65),
                      (0, .28, 0), (0, .18, .45)], 5)
trough('Continuous S-profile chute', path, .45, .20, blue, True)
data = {'centerline': path, 'half_width': .45, 'wall_height': .20,
        'support_legs': [], 'entry': list(path[0]), 'exit': list(path[-1])}
ladder((0, 0, -2.49), (0, 1.65, -1.70), .88, 7, frame, metal, data, .65)
def floor_at_z(z):
    for a, b in zip(path[:-1], path[1:]):
        if a[2] <= z <= b[2]:
            return a[1]+(b[1]-a[1])*(z-a[2])/(b[2]-a[2])
    raise ValueError(z)

upper_z, lower_z = -1.54, -.24
upper_y, lower_y = floor_at_z(upper_z)-.043, floor_at_z(lower_z)-.043
for side in (-1, 1):
    support((side*.32, .025, upper_z), (side*.32, upper_y, upper_z), .033, frame, data)
    support((side*.35, .025, lower_z), (side*.35, lower_y, lower_z), .029, frame, data)
    tube('Under-chute longitudinal brace', [(side*.29, upper_y, upper_z),
                                           (side*.29, floor_at_z(-.50)-.05, -.50),
                                           (side*.29, lower_y, lower_z)], .025, frame)
tube('Upper cradle crossbar', [(-.37, upper_y, upper_z), (.37, upper_y, upper_z)], .028, frame)
tube('Lower cradle crossbar', [(-.37, lower_y, lower_z), (.37, lower_y, lower_z)], .025, frame)
export('pool_slide_straight', 4000, data)


reset()
blue = material('Pool blue molded fiberglass', (.008, .14, .40), .32)
frame = material('Ivory powder coated frame', (.79, .80, .75), .42, .08)
metal = material('Satin stainless ladder treads', (.43, .49, .50), .39, .78)
path = []
for i in range(29):
    t = i/28
    theta = -5.2+5.2*t
    # Near-constant fall preserves generous headroom around the single turn.
    path.append((.85*math.cos(theta), 2.75-2.30*t, -1.2+.85*math.sin(theta)))
# A separate gradual outlet turn transitions to +Z without cutting through the helix.
outlet = smooth_points([path[-1], (.835, .35, -.83), (.77, .24, -.25), (.65, .18, .45)], 3, end_tangent=(0, -.035, .70))
path += outlet[1:]
trough('Continuous open spiral fiberglass shell', path, .45, .28, blue, True)
data = {'centerline': path, 'half_width': .45, 'wall_height': .28,
        'support_legs': [], 'entry': list(path[0]), 'exit': list(path[-1])}
entry = Vector(path[0])
theta = -5.2
direction = Vector((-math.sin(theta), 0, math.cos(theta)))
cross = Vector((direction.z, 0, -direction.x))
# The ladder approaches from outside the coil. A tangent-aligned ladder at the
# original entry would cross the lower outlet; this small landing avoids that.
top = Vector((1.22, 2.75, -.74))
bottom = Vector((2.15, 0, -.74))
ladder(tuple(bottom), tuple(top), .88, 9, frame, metal, data, .68)
landing_path = [entry, entry-direction*.29, top]
landing_cross = [cross*.50, cross*.50, Vector((0, 0, .48))]
verts = []
for y in (-.061, -.006):
    for p, c in zip(landing_path, landing_cross):
        verts += [p-c+Vector((0, y, 0)), p+c+Vector((0, y, 0))]
faces = [(0, 1, 3, 2), (2, 3, 5, 4), (6, 8, 9, 7), (8, 10, 11, 9),
         (0, 6, 7, 1), (4, 5, 11, 10), (0, 2, 8, 6), (2, 4, 10, 8),
         (1, 7, 9, 3), (3, 9, 11, 5)]
mesh('Wide guarded entry landing', verts, faces, frame, False)
# Two overlapping low-cost boxes support the bridge from ladder top to chute.
# Rotation is Godot yaw about +Y in radians; local +Z follows each box's length.
data['boxes'] = []
for a, b in zip(landing_path[:-1], landing_path[1:]):
    delta = b-a
    midpoint = (a+b)*.5
    data['boxes'].append({'center': [midpoint.x, 2.713, midpoint.z],
                          'size': [1.00, .062, delta.length+.04],
                          'yaw': math.atan2(delta.x, delta.z)})
for side in (-1, 1):
    a = entry+cross*side*.49
    b = entry-direction*.29+cross*side*.49
    c = Vector((.705, 2.75, -.74+side*.475))
    tube('Landing top guard', [tuple(a), tuple(a+Vector((0, .60, 0))),
                              tuple(a-direction*.02+Vector((0, .66, 0))),
                              tuple(b+Vector((0, .68, 0))),
                              tuple(c+Vector((.095, .68, 0)))], .025, frame)
    tube('Landing middle guard', [tuple(a+Vector((0, .34, 0))),
                                 tuple(b+Vector((0, .34, 0))),
                                 tuple(c+Vector((0, .34, 0)))], .023, frame)
# One outside post and the central mast carry the landing. Neither pierces the
# lower outlet, unlike vertical columns directly below the entry corners.
support((1.50, .025, -.35), (1.50, 2.69, -.35), .040, frame, data)
tube('Landing outside bracket', [(1.50, 2.69, -.35), (1.15, 2.69, -.55)], .043, frame)
tube('Landing central bracket', [(0, 2.55, -1.20), (.64, 2.68, -.60)], .043, frame)
support((0, .025, -1.20), (0, 2.55, -1.20), .052, frame, data)
for index in (4, 11, 18, 25):
    p = Vector(path[index])
    p.y -= .07
    center = Vector((0, max(.30, p.y-.12), -1.20))
    tube('Radial cradle arm', [tuple(center), tuple(p)], .039, frame)
    # The side posts do not extend into water or across the slide bed.
    radial = Vector((p.x, 0, p.z+1.2)).normalized()
    foot = p+radial*.17
    if foot.z <= -.25:
        support((foot.x, .025, foot.z), (foot.x, p.y, foot.z), .036, frame, data)
        tube('Cradle connection', [tuple(foot), tuple(p)], .035, frame)
for x in (.40, 1.03):
    support((x, .025, -.22), (x, .195, -.22), .029, frame, data)
tube('Outlet cradle', [(.40, .195, -.22), (1.03, .195, -.22)], .027, frame)
export('pool_slide_spiral', 6500, data)

(OUT/'collision.json').write_text(json.dumps(collisions, indent=2)+'\n')
(OUT/'mesh_stats.json').write_text(json.dumps(statistics, indent=2)+'\n')
(OUT/'README.md').write_text('''# Pool equipment

Original low-poly Blender props based on the supplied pool equipment photographs.
Coordinates are metres, +Y up, +Z toward water. The pool lip is Z=0 and the dry
deck is Y=0. Each GLB is one mesh with three PBR material surfaces. Each slide is
an explicitly sampled, closed fiberglass shell, with no high-poly decimation.

Editable Blender sources and front/reverse render previews live under
`art/pool_equipment/`. Rebuild with Blender's background mode and
`tools/blender/build_pool_equipment.py`.

`collision.json` describes inner trough centerlines, ladder endpoints, and support
primitives for lightweight game collision, independently of the render mesh.
`mesh_stats.json` records exact triangle counts and Godot-coordinate bounds.
''')
print('POOL_EQUIPMENT_COMPLETE', flush=True)
