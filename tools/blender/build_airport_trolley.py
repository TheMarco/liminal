"""Build a four-caster airport luggage trolley from the supplied photo reference.

Blender --background --factory-startup --python tools/blender/build_airport_trolley.py
Working coordinates are (X, height, depth); +depth is forward, away from handle.
"""
from pathlib import Path
import sys
import bpy
import math
import json
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from prop_bake import material, bake_export, studio

ROOT=HERE.parents[1]
ART=ROOT/'art/airport_trolley';OUT=ROOT/'models/authored/airport_trolley'
ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
parts=[]
steel=material('Satin stainless steel',(.53,.555,.57),.29,.92,variation=.065,bump=.00012)
rim_steel=material('Machined edges and axle bolts',(.64,.665,.68),.23,.95,variation=.035)
panel=material('Blank ivory sign panels',(.72,.732,.72),.58,.035,variation=.018)
rubber=material('Charcoal rubber tread',(.046,.055,.062),.87,variation=.12,bump=.00025)
sidewall=material('Gray rubber sidewalls',(.096,.12,.136),.78,variation=.09)
hub=material('Dark caster hubs',(.035,.046,.054),.6,.12,variation=.045)
grip=material('Dark blue handle mouldings',(.034,.059,.078),.58,variation=.035)


def xyz(p):return (p[0],-p[2],p[1])


def mesh(name,vertices,faces,mat,smooth=True):
    data=bpy.data.meshes.new(name);data.from_pydata([xyz(p) for p in vertices],[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob)
    data.materials.append(mat)
    for face in data.polygons:face.use_smooth=smooth
    parts.append(ob);return ob


def box(name,p,size,mat,bevel=0,segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p))
    ob=bpy.context.object;ob.name=name;ob.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Manufactured edge radius','BEVEL');mod.width=bevel;mod.segments=segments
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat);parts.append(ob);return ob


def tube(name,points,radius,mat,sides=8,caps=True):
    vertices=[]
    # Parallel-transport the cross-section so bends do not twist or pinch.
    previous=None
    for i,p in enumerate(points):
        t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        if previous is None:
            guide=Vector((0,1,0)) if abs(t.y)<.9 else Vector((0,0,1))
            u=t.cross(guide).normalized()
        else:
            u=(previous-t*previous.dot(t)).normalized()
        v=t.cross(u).normalized();previous=u
        for j in range(sides):
            a=math.tau*j/sides
            vertices.append(Vector(p)+radius*(u*math.cos(a)+v*math.sin(a)))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    if caps:faces += [tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    return mesh(name,vertices,faces,mat)


def deck(d):return .322+.055*d


# The tapered platform nests at the existing 0.55m game pitch. It rises gently
# toward the nose; the wire deck remains open rather than a solid shopping basket.
outline=[(-.274,-.375),(-.259,-.13),(-.241,.23),(-.229,.403),(-.21,.449),
         (-.173,.47),(.173,.47),(.21,.449),(.229,.403),(.241,.23),(.259,-.13),(.274,-.375)]
deck_points=[(x,deck(d)-.01,d) for x,d in outline]
tube('Raised platform perimeter',deck_points,.010,steel,8)
tube('Rear platform crossbar',[(-.274,deck(-.375)-.01,-.375),(.274,deck(-.375)-.01,-.375)],.010,steel,8)
for x in [-.19,-.095,0,.095,.19]:
    tube('Longitudinal luggage slat',[(x,deck(-.365)-.006,-.365),(x,deck(.437)-.006,.437)],.006,steel,6)
for d in [-.26,-.02,.22,.38]:
    half=.27-(d+.375)*.05
    tube('Platform cross support',[(-half,deck(d)-.008,d),(half,deck(d)-.008,d)],.006,steel,6)

# Lower U chassis is open at the handle end for nesting. Rubber covers its nose.
base=[(-.276,.209,-.399),(-.255,.218,-.08),(-.23,.23,.315),(-.223,.232,.442),
      (-.19,.232,.474),(.19,.232,.474),(.223,.232,.442),(.23,.23,.315),(.255,.218,-.08),(.276,.209,-.399)]
tube('Lower tubular U chassis',base,.014,steel,8)
bumper=[(-.234,.233,.355),(-.238,.234,.441),(-.216,.234,.48),(-.177,.234,.49),
        (.177,.234,.49),(.216,.234,.48),(.238,.234,.441),(.234,.233,.355)]
tube('Dark protective nose bumper',bumper,.012,grip,8)
for s in [-1,1]:
    box('Tall handle upright',(s*.276,.644,-.397),(.027,.882,.030),steel,.003)
    tube('Rear deck attachment',[(s*.276,.237,-.397),(s*.272,deck(-.37)-.01,-.37)],.012,steel,8)
    tube('Front platform strut',[(s*.221,.232,.38),(s*.20,deck(.37)-.012,.37)],.011,steel,8)
    box('Handle end housing',(s*.276,1.082,-.407),(.075,.060,.086),grip,.015,2)
    tube('Handle fixing screw',[(s*.276,1.098,-.451),(s*.276,1.098,-.454)],.0035,rim_steel,6)
handle=[(-.269,1.078,-.42),(-.205,1.068,-.41),(-.10,1.061,-.397),
        (0,1.059,-.391),(.10,1.061,-.397),(.205,1.068,-.41),(.269,1.078,-.42)]
tube('Bowed stainless push handle',handle,.012,steel,8)

# Two blank advertising plates, held by thin steel edging as in the reference.
box('Large blank sign panel',(0,.646,-.39),(.477,.302,.006),panel,.003)
for x in [-.245,.245]:
    tube('Sign side frame',[(x,.488,-.392),(x,.804,-.392)],.0055,steel,6)
for h in [.491,.801]:
    tube('Sign horizontal frame',[(-.246,h,-.392),(.246,h,-.392)],.0055,steel,6)

# Upper carry-on basket: small open wire sides and an unprinted front panel.
def basket_ring(h):
    return [(-.246,h,-.407),(-.256,h,-.39),(-.256,h,-.163),(-.24,h,-.143),
            (.24,h,-.143),(.256,h,-.163),(.256,h,-.39),(.246,h,-.407),(-.246,h,-.407)]
for h in [.821,.959]:tube('Basket rim',basket_ring(h),.0045,steel,6,False)
for s in [-1,1]:
    for d in [-.392,-.302,-.219,-.158]:
        tube('Basket upright',[(s*.254,.822,d),(s*.254,.958,d)],.0035,steel,6)
for x in [-.19,-.095,0,.095,.19]:
    tube('Basket floor wire',[(x,.82,-.395),(x,.82,-.15)],.0035,steel,6)
for d in [-.345,-.245]:
    tube('Basket floor crosswire',[(-.249,.817,d),(.249,.817,d)],.0035,steel,6)
box('Basket blank fascia',(0,.887,-.14),(.469,.121,.006),panel,.003)
for s in [-1,1]:
    tube('Basket handle support',[(s*.168,.959,-.407),(s*.157,1.008,-.407),(s*.078,1.009,-.407),(s*.063,.959,-.407)],.0036,steel,6)
    tube('Small grip above basket',[(s*.085,1.009,-.407),(s*.150,1.009,-.407)],.005,grip,6)


def caster(cx,d,yaw):
    c=math.cos(yaw);s=math.sin(yaw)
    def tr(x,h,z):return (cx+x*c+z*s,h,d+z*c-x*s)
    n=16
    # Chamfered tire sidewalls, recessed dark hub and a visible steel axle.
    profile=[(-.027,.044),(-.027,.069),(-.022,.082),(.022,.082),(.027,.069),(.027,.044)]
    verts=[]
    for x,r in profile:
        for k in range(n):
            a=math.tau*k/n
            verts.append(tr(x,.082+r*math.sin(a),r*math.cos(a)))
    faces=[]
    for j in range(len(profile)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
    ob=mesh('Caster tire',verts,faces,sidewall)
    ob.data.materials.append(rubber)
    for i,face in enumerate(ob.data.polygons):face.material_index=1 if i//n==2 else 0
    for sign in [-1,1]:
        vs=[tr(sign*.0271,.082+.044*math.sin(k*math.tau/n),.044*math.cos(k*math.tau/n)) for k in range(n)]
        mesh('Recessed wheel hub',vs,[tuple(range(n))],hub,False)
    tube('Wheel axle',[tr(-.039,.082,0),tr(.039,.082,0)],.008,rim_steel,8)
    # Pressed sheet-steel forks, with the axle offset behind the swivel bearing.
    profile=[(-.046,.210),(.044,.202),(.027,.141),(.017,.087),(-.009,.067),(-.03,.097)]
    for side in [-1,1]:
        vertices=[]
        for x in [side*.033,side*.038]:
            for z,h in profile:vertices.append(tr(x,h,z))
        faces=[tuple(reversed(range(6))),tuple(range(6,12))]
        faces += [(k,(k+1)%6,(k+1)%6+6,k+6) for k in range(6)]
        mesh('Pressed caster fork',vertices,faces,steel,False)
    tube('Swivel bearing',[tr(0,.204,-.004),tr(0,.222,-.004)],.037,steel,12)


for x,d,yaw in [(-.276,-.410,.025),(.276,-.410,-.025),(-.216,.388,.10),(.216,.388,-.08)]:
    caster(x,d,yaw)

prop,stats=bake_export(parts,'AirportTrolley_Game',ART,OUT/'airport_trolley.glb',5000,
    {'casters':4,'front_axis':'+Z','nesting_pitch_m':.55,'deck_y_intercept_m':.322,'deck_slope':.055})
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
studio(prop,ART,'airport_trolley',target=(0,0,.55),camera_at=(-1.75,-2.45,1.48),scale=1.47)
print('AIRPORT_TROLLEY_STATS',json.dumps(stats),flush=True)
