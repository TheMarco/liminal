"""Original low-poly glass boarding bridge, based on the supplied reference.

Working coordinates are (X along bridge, Y up, Z across). The docking hood is
at +X and the service stairs face -Z. The source is full-depth; the airport
builder stages it with shallow depth to fit its sealed window diorama.
"""
from pathlib import Path
import sys
import math
import json
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from prop_bake import material, bake_export, studio

ROOT = HERE.parents[1]
ART = ROOT / 'art/airport_jetway'
OUT = ROOT / 'models/authored/airport_jetway'
ART.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
(ART / '.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
parts = []
windows = []
white = material('Weathered ivory powder coat', (.64, .68, .67), .53, .17, variation=.04)
blue = material('Airport blue support steel', (.023, .205, .48), .4, .32, variation=.05)
steel = material('Brushed stair steel', (.40, .46, .48), .34, .78, variation=.035)
dark = material('Graphite neoprene bellows', (.026, .034, .035), .89, variation=.09)
rib = material('Raised bellows seams', (.065, .077, .078), .78, variation=.06)
rubber = material('Bogie tire rubber', (.019, .024, .027), .92, variation=.07)
navy = material('Navy control trim', (.015, .029, .048), .57, variation=.025)
amber = material('Amber mast markers', (.94, .24, .012), .43, variation=0)
red = material('Red safety beacon lens', (.62, .013, .006), .3, variation=0)
floor_mat = material('Charcoal anti-slip deck', (.10, .13, .14), .89, variation=.13, bump=.001)
window_dark = material('Dark cab window', (.028, .07, .072), .17, .52, variation=.015)


def xyz(p):
    return (p[0], -p[2], p[1])


def mesh(name, vertices, faces, mat, smooth=False, target=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in vertices], [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    data.materials.append(mat)
    for face in data.polygons:
        face.use_smooth = smooth
    (parts if target is None else target).append(ob)
    return ob


def box(name, p, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(p))
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new('Manufactured edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat)
    parts.append(ob)
    return ob


def beam(name, a, b, width, depth, mat):
    a, b = Vector(xyz(a)), Vector(xyz(b))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (width, depth, (b - a).length)
    ob.rotation_euler = (b - a).to_track_quat('Z', 'Y').to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    parts.append(ob)
    return ob


def tube(name, points, radius, mat, sides=6, caps=True):
    vertices = []
    previous = None
    for i, p in enumerate(points):
        tangent = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(0, i - 1)])).normalized()
        if previous is None:
            guide = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((0, 0, 1))
            u = tangent.cross(guide).normalized()
        else:
            u = (previous - tangent * previous.dot(tangent)).normalized()
        v = tangent.cross(u).normalized()
        previous = u
        for j in range(sides):
            angle = math.tau * j / sides
            vertices.append(Vector(p) + radius * (u * math.cos(angle) + v * math.sin(angle)))
    faces = []
    for i in range(len(points) - 1):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if caps:
        faces += [tuple(reversed(range(sides))), tuple(range((len(points) - 1) * sides, len(points) * sides))]
    return mesh(name, vertices, faces, mat, True)


def accordion(name, start, end, bottom, top, half, folds):
    # Rectangular telescopic bellows: alternating peaks are actual silhouette.
    vertices = []
    for i in range(folds * 2 + 1):
        x = start + (end - start) * i / (folds * 2)
        swell = .023 if i % 2 else 0
        for z, y in [(-half-swell, bottom), (-half-swell, top+swell),
                     (half+swell, top+swell), (half+swell, bottom)]:
            vertices.append((x, y, z))
    faces = []
    for i in range(folds * 2):
        for k in range(4):
            faces.append((i*4+k, i*4+(k+1)%4, (i+1)*4+(k+1)%4, (i+1)*4+k))
    return mesh(name, vertices, faces, rib)


# Blue rear portal and static support leg anchor the bridge to the terminal.
box('Rear support foot', (-3.02, .045, 0), (.45, .09, .54), blue, .015)
box('Rear support column', (-3.02, .79, 0), (.17, 1.5, .19), blue, .012)
box('Rear crosshead', (-3.02, 1.46, 0), (.34, .15, 1.14), blue)
accordion('Terminal expansion boot', -3.63, -3.03, 1.50, 3.02, .54, 10)
for x in [-3.02, -2.73]:
    for z in [-.57, .57]:
        box('Blue portal jamb', (x, 2.28, z), (.11, 1.69, .11), blue)
    box('Blue portal head', (x, 3.09, 0), (.13, .11, 1.23), blue)

# Long glazed rectangular corridor. A real floor, ceiling and internal rails
# keep it readable from either side; the glass is a separate inexpensive mesh.
box('Corridor deck', (-.91, 1.50, 0), (3.72, .12, 1.12), white)
box('Interior anti-slip floor', (-.91, 1.565, 0), (3.62, .018, 1.05), floor_mat)
box('Corridor roof', (-.91, 3.08, 0), (3.80, .105, 1.19), white, .015)
for z in [-.55, .55]:
    box('Blue underfloor longitudinal', (-.91, 1.397, z), (3.86, .13, .105), blue)
    box('Lower window rail', (-.91, 1.69, z), (3.73, .14, .075), white)
    box('Upper window rail', (-.91, 2.98, z), (3.73, .13, .075), white)
    tube('Interior handrail', [(-2.7, 2.17, z*.83), (.91, 2.17, z*.83)], .015, steel)
    for k in range(7):
        x = -2.74 + k*.61
        box('Vertical glazing mullion', (x, 2.34, z), (.065, 1.40, .08), white)
    for k in range(6):
        x = -2.74 + k*.61
        beam('Diagonal corridor brace', (x+.045, 1.755, z), (x+.565, 2.91, z), .045, .055, white)
    for x in [-2.45, -1.25, -.05, .82]:
        beam('Underfloor diagonal truss', (x-.25, 1.33, z), (x+.24, 1.45, z), .036, .035, blue)

glass = bpy.data.materials.new('Green tinted bridge glazing')
glass.use_nodes = True
glass.diffuse_color = (.045, .22, .145, .36)
bs = glass.node_tree.nodes.get('Principled BSDF')
bs.inputs['Base Color'].default_value = (.045, .22, .145, 1)
bs.inputs['Alpha'].default_value = .36
bs.inputs['Roughness'].default_value = .18
bs.inputs['Metallic'].default_value = .14
glass.surface_render_method = 'DITHERED'
glass.use_backface_culling = False
for z in [-.54, .54]:
    for k in range(6):
        x = -2.74 + k*.61
        mesh('Green glazing pane', [(x+.034,1.76,z),(x+.576,1.76,z),
             (x+.576,2.915,z),(x+.034,2.915,z)], [(0,1,2,3)], glass, target=windows)

# Front lift assembly, hydraulic ram, wheel axle and solid pneumatic tires.
for z in [-.57, .57]:
    box('Blue lift column', (1.16, .86, z), (.16, 1.12, .16), blue, .012)
    box('Polished lift ram', (1.16, 1.22, z), (.10, .80, .10), steel)
    box('Tall lift guide', (.81, 2.30, z), (.15, 1.94, .13), white)
    box('Amber warning band', (.81, 3.175, z), (.153, .16, .134), amber)
    box('Navy mast cap', (.81, 3.31, z), (.18, .14, .17), navy)
box('Lift crossbeam', (1.16, .36, 0), (.35, .17, 1.29), blue, .018)
tube('Bogie axle', [(1.16,.235,-.71),(1.16,.235,.71)], .065, blue, 10)
box('Central steering housing', (1.16, .27, 0), (.35, .31, .34), blue, .04)
for z in [-.64, .64]:
    tube('Black bogie tire', [(1.16,.213,z-.072),(1.16,.213,z+.072)], .21, rubber, 16)
    for face in [-1,1]:
        tube('Wheel silver rim', [(1.16,.213,z+face*.073),(1.16,.213,z+face*.08)], .116, steel, 12)
        tube('Wheel axle hub', [(1.16,.213,z+face*.081),(1.16,.213,z+face*.092)], .05, blue, 8)
    tube('Hydraulic hose', [(1.08,.55,z),(1.03,.91,z),(1.07,1.10,z),(.95,1.18,z)], .012, rubber)

# Telescopic sleeve, cab, service hatch and the under-slung HVAC unit.
accordion('Front telescoping sleeve', .99, 1.46, 1.52, 3.06, .56, 10)
box('Cab floor', (2.10, 1.52, 0), (1.35, .14, 1.24), white, .02)
box('Cab roof', (2.10, 3.105, 0), (1.40, .10, 1.28), white, .018)
for z in [-.592, .592]:
    box('Cab sidewall', (2.08, 2.30, z), (1.28, 1.49, .048), white)
    box('Service door gasket', (1.69, 2.26, z*1.047), (.34, 1.34, .014), navy, .024)
    box('Service door leaf', (1.69, 2.26, z*1.066), (.306, 1.30, .012), white, .022)
    box('Service door oval window', (1.69, 2.67, z*1.083), (.115, .33, .012), window_dark, .055)
    tube('Service door handle', [(1.80,2.20,z*1.10),(1.80,2.31,z*1.10)], .012, steel)
box('Underslung AC casing', (2.03, 1.24, .02), (1.12, .34, .87), blue, .018)
box('AC side face', (2.03, 1.24, -.429), (1.04, .26, .015), white)
box('AC dark grille', (2.13, 1.24, -.44), (.71, .215, .014), navy)
for k in range(13):
    box('AC grille fin', (1.80+k*.053,1.24,-.45), (.016,.208,.012), steel)
box('AC fan inset', (1.62,1.24,-.442), (.23,.23,.014), navy, .075)
tube('AC round fan', [(1.62,1.24,-.45),(1.62,1.24,-.462)], .088, steel, 12)
for k in range(3):
    y=1.185+k*.055
    tube('AC fan grille wire',[(1.555,y,-.468),(1.685,y,-.468)],.006,navy)

# Open, slender service stair: eleven treads, two stringers and continuous rails.
stair_start, stair_end, stair_bottom, stair_top = -1.73, .94, .09, 1.52
for z in [-1.085, -.665]:
    beam('Stair side stringer', (stair_start,stair_bottom-.025,z), (stair_end,stair_top-.045,z), .057, .05, steel)
    tube('Stair handrail', [(stair_start-.07,.66,z),(stair_start,.86,z),
                           (stair_end,2.30,z),(1.64,2.30,z)], .014, steel)
    tube('Stair middle rail', [(stair_start,.45,z),(stair_end,1.92,z),(1.64,1.92,z)], .010, steel)
    for t in [0,.34,.68,1]:
        x=stair_start+(stair_end-stair_start)*t
        h=stair_bottom+(stair_top-stair_bottom)*t
        tube('Stair rail stanchion',[(x,h,z),(x,h+.78,z)],.012,steel)
for i in range(12):
    t=i/11
    x=stair_start+(stair_end-stair_start)*t
    h=stair_bottom+(stair_top-stair_bottom)*t
    box('Open service stair tread',(x,h,-.875),(.26,.027,.43),steel)
    box('Dark tread inset',(x-.015,h+.017,-.875),(.19,.006,.355),floor_mat)
box('Service landing',(1.31,1.52,-.857),(.78,.05,.465),steel)
for x in [1.01,1.66]:
    tube('Landing outer guard post',[(x,1.52,-1.09),(x,2.30,-1.09)],.012,steel)
for x in [-1.84,-1.65]:
    box('Stair rubber foot',(x,.027,-.875),(.09,.054,.46),rubber)

# Recessed docking face: no person, just the sealed boarding door and cab glass.
box('Recessed docking face',(2.715,2.30,0),(.055,1.50,1.15),white)
box('Boarding door gasket',(2.75,2.29,-.18),(.018,1.37,.60),navy,.025)
box('Boarding door leaf',(2.764,2.29,-.18),(.012,1.33,.564),white,.023)
for h in [2.22,2.49]:
    for z in [-.335,-.065]:
        box('Boarding door oval pane',(2.775,h,z),(.012,.16,.205),window_dark,.065)
box('Cab operator window gasket',(2.75,2.47,.35),(.025,.64,.335),navy,.05)
box('Cab operator window',(2.768,2.47,.35),(.014,.565,.27),window_dark,.04)
for h in [1.77,1.91,2.07,2.64,2.80]:
    box('Door horizontal seam',(2.775,h,-.18),(.006,.008,.55),steel)
box('Door sill',(2.86,1.57,0),(.31,.045,1.16),floor_mat)

# Deep black accordion canopy, with sloping shoulders and an open front mouth.
section=[(-.67,1.51),(-.67,2.73),(-.53,3.25),(-.42,3.35),
         (.42,3.35),(.53,3.25),(.67,2.73),(.67,1.51)]
verts=[]
folds=11
for i in range(folds*2+1):
    t=i/(folds*2)
    x=2.60+.58*t
    swell=.022 if i%2 else 0
    for z,y in section:
        verts.append((x,y+max(0,y-1.51)*swell*.5,z*(1+swell)))
faces=[]
for i in range(folds*2):
    for j in range(len(section)-1):
        a=i*8+j
        faces.append((a,a+1,a+9,a+8))
mesh('Aircraft docking accordion canopy',verts,faces,dark)
for i in range(1,folds*2,2):
    points=[verts[i*8+j] for j in range(8)]
    tube('Canopy raised fold seam',points,.006,rib,4)
tube('Heavy docking mouth gasket',[(3.185,y,z) for z,y in section],.036,dark,8)
box('Docking lower bumper',(3.12,1.50,0),(.23,.09,1.40),dark,.025)
for z in [-.58,.58]:
    tube('Beacon pedestal',[(2.61,3.16,z),(2.61,3.25,z)],.043,white,8)
    tube('Red docking beacon',[(2.61,3.25,z),(2.61,3.36,z)],.030,red,8)

prop,stats=bake_export(parts,'JetwayStructure',ART,OUT/'airport_jetway.glb',9000,
    {'front_axis':'+X','service_stairs_side':'-Z','apron_depth_scale':.42})
bpy.ops.object.select_all(action='DESELECT')
for ob in windows:ob.select_set(True)
bpy.context.view_layer.objects.active=windows[0]
bpy.ops.object.join()
glazing=bpy.context.object
glazing.name='JetwayGlazing'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
tri=glazing.modifiers.new('Game triangles','TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=tri.name)
prop.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'airport_jetway.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_tangents=True,export_extras=True)
stats['triangles']+=len(glazing.data.polygons)
stats['meshes']=2
stats['materials']=2
stats['glazing_triangles']=len(glazing.data.polygons)
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
studio(prop,ART,'airport_jetway',target=(-.15,0,1.72),camera_at=(6.6,9.7,5.3),scale=8.2,light_scale=4)
print('AIRPORT_JETWAY_STATS',json.dumps(stats),flush=True)
