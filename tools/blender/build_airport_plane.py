"""Build an original unmarked twin-engine passenger airliner in Blender.

Metric display model: nose -X, starboard +Z, floor Y=0. The game uses a
depth-compressed instance behind terminal glass; the source remains full 3D.
"""
from pathlib import Path
import sys
import math
import json
import bpy
import numpy as np
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from prop_bake import material,bake_export,studio

ROOT=HERE.parents[1]
ART=ROOT/'art/airport_plane'
OUT=ROOT/'models/authored/airport_plane'
ART.mkdir(parents=True,exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True)
(ART/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
parts=[]
white=material('Unmarked warm white airframe',(.76,.77,.76),.43,.10,variation=.015)
belly=material('Cool light gray belly',(.48,.51,.53),.46,.16,variation=.025)
winggray=material('Light gray wing panels',(.55,.58,.59),.49,.22,variation=.018)
seam=material('Inset panel seams',(.26,.29,.30),.64,.12,variation=.015)
glass=material('Cockpit and cabin glazing',(.009,.024,.032),.13,.37,variation=.015)
rubber=material('Landing gear tire rubber',(.015,.019,.022),.94,variation=.08)
metal=material('Engine lip and gear metal',(.48,.52,.55),.27,.88,variation=.018)
fanmat=material('Turbofan blades',(.055,.069,.078),.42,.72,variation=.02)
black=material('Intake and exhaust interior',(.008,.012,.014),.92,variation=.01)
red=material('Red position lamp',(.65,.008,.004),.30,variation=0)
green=material('Green position lamp',(.008,.36,.06),.30,variation=0)


def xyz(p):return (p[0],-p[2],p[1])


def mesh(name,vertices,faces,mat,smooth=False):
    data=bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in vertices],[],faces)
    data.update()
    ob=bpy.data.objects.new(name,data)
    bpy.context.scene.collection.objects.link(ob)
    data.materials.append(mat)
    for poly in data.polygons:poly.use_smooth=smooth
    parts.append(ob)
    return ob


def box(name,p,size,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p))
    ob=bpy.context.object
    ob.name=name
    ob.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Soft manufactured edge','BEVEL')
        mod.width=bevel
        mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat)
    parts.append(ob)
    return ob


def tube(name,points,radius,mat,sides=8,caps=True):
    vertices=[]
    previous=None
    for i,p in enumerate(points):
        t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        if previous is None:
            guide=Vector((0,1,0)) if abs(t.y)<.9 else Vector((0,0,1))
            u=t.cross(guide).normalized()
        else:u=(previous-t*previous.dot(t)).normalized()
        v=t.cross(u).normalized()
        previous=u
        for j in range(sides):
            a=math.tau*j/sides
            vertices.append(Vector(p)+radius*(u*math.cos(a)+v*math.sin(a)))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    if caps:faces += [tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    return mesh(name,vertices,faces,mat,True)


# Controlled cross-sections produce the lowered radome, cockpit brow and long
# constant-diameter cabin, followed by a taper to the APU tail cone.
profile=[(-5.25,.012,1.17),(-5.20,.105,1.18),(-5.08,.225,1.19),
         (-4.90,.335,1.23),(-4.69,.421,1.29),(-4.48,.496,1.33),
         (-4.22,.548,1.35),(-3.84,.56,1.35),(-3.0,.56,1.35),
         (-1.6,.56,1.35),(0,.56,1.35),(1.6,.56,1.35),(2.8,.548,1.35),
         (3.4,.49,1.35),(3.95,.388,1.36),(4.43,.275,1.38),
         (4.82,.16,1.40),(5.14,.078,1.42),(5.25,.018,1.425)]
N=32
verts=[]
for x,r,cy in profile:
    for k in range(N):
        a=math.tau*k/N
        verts.append((x,cy+r*math.sin(a),r*math.cos(a)))
faces=[]
for j in range(len(profile)-1):
    for k in range(N):
        a=j*N+k;b=j*N+(k+1)%N
        faces.append((a,b,b+N,a+N))
faces += [tuple(reversed(range(N))),tuple(range((len(profile)-1)*N,len(profile)*N))]
body=mesh('Shaped airliner fuselage',verts,faces,white,True)
body.data.materials.append(belly)
for i,p in enumerate(body.data.polygons):
    if i<(len(profile)-1)*N and N*.58 < i%N < N*.92:p.material_index=1


def section(x):
    for i in range(len(profile)-1):
        a,b=profile[i:i+2]
        if a[0]<=x<=b[0]:
            t=(x-a[0])/(b[0]-a[0])
            return a[1]*(1-t)+b[1]*t,a[2]*(1-t)+b[2]*t
    return profile[-1][1:]


def skin(x,y,side,offset=.004):
    r,cy=section(x)
    z=math.sqrt(max(.0001,r*r-(y-cy)**2))
    return (x,y,side*(z+offset))


def oval(name,x,y,rx,ry,side,mat,offset=.006):
    # Twelve vertices, with long straight sides, suggest an airliner window.
    shape=[(-.55,-1),(.55,-1),(1,-.65),(1,.65),(.55,1),(-.55,1),(-1,.65),(-1,-.65)]
    vs=[skin(x+u*rx,y+v*ry,side,offset) for u,v in shape]
    return mesh(name,vs,[tuple(range(8))],mat)


# Project the windshield outlines directly into the fuselage material. This
# makes the glass flush with the hull and prevents depth flicker through the
# terminal glazing and on Godot's simplified LOD meshes.
COCKPIT_PANES = [
    [(-4.965,1.535),(-4.545,.325),(-4.335,.690),(-4.680,1.535)],
    [(-4.520,.309),(-4.255,.245),(-4.090,.598),(-4.307,.680)],
    [(-4.222,.244),(-4.015,.307),(-4.006,.529),(-4.060,.587)],
]
projection=body.data.uv_layers.new(name='CockpitProjection')
for poly in body.data.polygons:
    angles=[(body.data.loops[i].vertex_index % N)/N for i in poly.loop_indices]
    wrapped=max(angles)-min(angles)>.5
    for loop_index,angle in zip(poly.loop_indices,angles):
        x=body.data.vertices[body.data.loops[loop_index].vertex_index].co.x
        if wrapped and angle<.5:angle+=1
        projection.data[loop_index].uv=((x+5.30)/1.55,angle)
# Pixel centers are in source (X, polar angle) coordinates. The mask is only
# a high-resolution bake input; the exported aircraft still has one 1K atlas.
w,h=2048,1024
xx,aa=np.meshgrid(-5.30+(np.arange(w)+.5)*1.55/w,(np.arange(h)+.5)*math.tau/h)
mask=np.zeros((h,w),dtype=bool)
for side in [-1,1]:
    for pane in COCKPIT_PANES:
        poly=[(x,theta if side>0 else math.pi-theta) for x,theta in pane]
        inside=np.zeros((h,w),dtype=bool)
        for a,b in zip(poly,poly[1:]+poly[:1]):
            if abs(a[1]-b[1])<1e-9:continue
            crossing=((a[1]>aa)!=(b[1]>aa))
            intersect=(b[0]-a[0])*(aa-a[1])/(b[1]-a[1])+a[0]
            inside^=crossing & (xx<intersect)
        mask|=inside
pixels=np.ones((h,w,4),dtype=np.float32)
pixels[:,:,:3]=mask[:,:,None]
windshield_mask=bpy.data.images.new('Cockpit projection mask (authoring only)',width=w,height=h,alpha=False)
windshield_mask.colorspace_settings.name='Non-Color'
windshield_mask.pixels.foreach_set(pixels.ravel())
windshield_mask.pack()
for slot in range(len(body.data.materials)):
    mat=body.data.materials[slot].copy()
    mat.name+=' | flush cockpit glazing'
    body.data.materials[slot]=mat
    nt=mat.node_tree
    bs=nt.nodes.get('Principled BSDF')
    source=bs.inputs['Base Color'].links[0].from_socket
    uv=nt.nodes.new('ShaderNodeUVMap')
    uv.uv_map='CockpitProjection'
    tex=nt.nodes.new('ShaderNodeTexImage')
    tex.image=windshield_mask
    tex.extension='CLIP'
    nt.links.new(uv.outputs['UV'],tex.inputs['Vector'])
    mix=nt.nodes.new('ShaderNodeMixRGB')
    nt.links.new(tex.outputs['Color'],mix.inputs[0])
    nt.links.new(source,mix.inputs[1])
    mix.inputs[2].default_value=(.009,.024,.032,1)
    nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    rough=nt.nodes.new('ShaderNodeMapRange')
    rough.inputs['To Min'].default_value=bs.inputs['Roughness'].default_value
    rough.inputs['To Max'].default_value=.24
    nt.links.new(tex.outputs['Color'],rough.inputs['Value'])
    nt.links.new(rough.outputs[0],bs.inputs['Roughness'])


for side in [-1,1]:
    for k in range(42):
        x=-3.47+k*.157
        if -.04<x<.63:continue
        oval('Oval passenger window',x,1.485,.036,.061,side,glass)
    # Front/aft doors and the two smaller overwing escape hatches.
    for x,w,h,cy in [(-3.81,.28,.79,1.34),(3.39,.26,.70,1.34),(.07,.20,.49,1.39),(.41,.20,.49,1.39)]:
        shape=[(-.34,-.5),(.34,-.5),(.5,-.40),(.5,.40),(.34,.5),(-.34,.5),(-.5,.40),(-.5,-.40),(-.34,-.5)]
        points=[]
        for a,b in zip(shape,shape[1:]):
            for i in range(5):
                t=i/5
                u=a[0]*(1-t)+b[0]*t
                v=a[1]*(1-t)+b[1]*t
                points.append(skin(x+u*w,cy+v*h,side,.010))
        points.append(points[0])
        tube('Passenger door recessed seam',points,.006,seam,4)
        oval('Door inspection window',x,cy+h*.29,.027,.04,side,glass,.011)
        tube('Door handle', [skin(x-.04,cy-.08,side,.014),skin(x+.035,cy-.08,side,.014)],.008,metal,6)
    # Radome separation follows the nose contour, with two small probes.
    tube('Radome seam',[(x,y,z) for x,y,z in [skin(-4.93,1.08,side,.004),skin(-4.89,1.20,side,.004),skin(-4.87,1.34,side,.004)]],.004,seam,4)
    tube('Pitot probe',[skin(-4.51,1.22,side,.015),skin(-4.69,1.22,side,.075)],.007,metal,6)
    oval('Cargo hatch mark',-2.76,1.03,.10,.058,side,seam,.005)


def slab(name,outline,thickness,mat,vertical=False):
    vs=[(x,y if vertical else y+d,z+d if vertical else z)
        for d in [-thickness*.5,thickness*.5] for x,y,z in outline]
    n=len(outline)
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
    return mesh(name,vs,fs,mat)


for side in [-1,1]:
    # Swept, tapered wings with a modest dihedral and pointed upturned tips.
    wing=[(-.89,1.08,side*.42),(-.39,1.10,side*1.30),
          (1.20,1.25,side*3.38),(1.82,1.39,side*4.28),
          (2.25,1.39,side*4.29),(1.94,1.22,side*2.45),(1.70,1.06,side*.45)]
    slab('Swept main wing',wing,.060,winggray)
    slab('Subtle upturned wingtip',[(1.82,1.39,side*4.28),(2.08,1.78,side*4.44),
         (2.27,1.77,side*4.45),(2.25,1.39,side*4.29)],.018,white)
    tube('Wing navigation light',[(2.23,1.43,side*4.29),(2.23,1.45,side*4.32)],.020,red if side<0 else green,6)
    for pts in [[(-.39,1.14,side*1.29),(1.20,1.29,side*3.38),(1.82,1.43,side*4.22)],
                [(1.12,1.11,side*.62),(1.37,1.20,side*2.0),(2.11,1.42,side*4.17)]]:
        tube('Wing panel seam',pts,.0045,seam,4)
    for z in [1.45,2.20,2.95]:
        x=1.33+(z-1.45)*.31
        slab('Flap track fairing',[(x-.30,1.055,side*z),(x+.39,1.055,side*z),
             (x+.22,.93,side*(z+.075)),(x-.18,.96,side*(z+.075))],.055,belly)
    # Horizontal tailplane remains distinct from the large swept vertical fin.
    slab('Horizontal tailplane',[(3.39,1.57,side*.19),(4.44,1.69,side*1.76),
         (4.94,1.69,side*1.80),(4.53,1.53,side*.12)],.04,winggray)
    tube('Tail elevator seam',[(4.21,1.60,side*.41),(4.81,1.713,side*1.68)],.004,seam,4)

fin=[(2.71,1.80),(3.27,2.00),(4.31,3.39),(4.80,3.38),(4.64,1.57)]
vs=[(x,y,z) for z in [-.036,.036] for x,y in fin]
faces=[tuple(reversed(range(5))),tuple(range(5,10))]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
mesh('Swept vertical tail fin',vs,faces,white)
for side in [-1,1]:
    tube('Rudder seam',[(4.69,3.26,side*.039),(4.56,1.91,side*.039)],.005,seam,4)
slab('Dorsal antenna', [(-3.41,1.902,0),(-3.31,2.09,0),
     (-3.22,2.09,0),(-3.28,1.902,0)],.022,white,vertical=True)
tube('APU tail exhaust',[(5.20,1.425,0),(5.255,1.425,0)],.033,black,10)
slab('Aft dorsal antenna',[(-.42,1.91,0),(-.31,2.085,0),(-.23,2.085,0),(-.30,1.91,0)],.022,white,vertical=True)


def engine(side):
    z=side*1.12
    cy=.80
    # Closed rolled intake lip around a dark, genuinely recessed fan disk.
    profile=[(-1.64,.291),(-1.68,.334),(-1.62,.375),(-1.47,.388),
             (-1.03,.365),(-.60,.303),(-.40,.244),(-.39,.184),
             (-.61,.171),(-1.21,.254),(-1.43,.279)]
    n=24
    vertices=[]
    for x,r in profile:
        for i in range(n):
            a=math.tau*i/n
            vertices.append((x,cy+math.sin(a)*r,z+math.cos(a)*r))
    faces=[]
    for k in range(len(profile)):
        for i in range(n):
            a=k*n+i;b=k*n+(i+1)%n
            faces.append((a,b,((k+1)%len(profile))*n+(i+1)%n,((k+1)%len(profile))*n+i))
    ob=mesh('Turbofan nacelle and rolled intake',vertices,faces,white,True)
    ob.data.materials.append(metal)
    ob.data.materials.append(black)
    for i,f in enumerate(ob.data.polygons):
        ring=i//n
        f.material_index=1 if ring in [0,1] else 2 if ring>=7 else 0
    tube('Deep fan disk',[(-1.26,cy,z),(-1.24,cy,z)],.257,black,24)
    for k in range(16):
        a=math.tau*k/16
        points=[]
        for r,offset in [(.055,0),(.245,.10),(.245,.245),(.065,.10)]:
            points.append((-1.29,cy+r*math.sin(a+offset),z+r*math.cos(a+offset)))
        mesh('Swept fan blade',points,[(0,1,2,3)],fanmat)
    tube('Fan spinner',[(-1.40,cy,z),(-1.265,cy,z)],.054,metal,12)
    tube('Rear exhaust cone',[(-.44,cy,z),(-.27,cy,z)],.108,fanmat,12)
    slab('Engine mounting pylon',[(-1.18,1.15,z),(-.57,1.10,z),(-.18,1.17,z),(-.58,1.34,z)],.16,belly,vertical=True)
    for x in [-1.10,-.66]:
        for a,b in zip(profile[2:6],profile[3:7]):
            if a[0]<=x<=b[0]:
                t=(x-a[0])/(b[0]-a[0])
                radius=a[1]*(1-t)+b[1]*t+.003
                break
        tube('Nacelle panel join',[(x,cy+radius*math.sin(a),z+radius*math.cos(a))
             for a in [math.tau*i/24 for i in range(25)]],.004,seam,4)


for side in [-1,1]:engine(side)


def wheel(x,cy,z,r,width):
    tube('Pneumatic landing tire',[(x,cy,z-width*.5),(x,cy,z+width*.5)],r,rubber,16)
    for face in [-1,1]:
        zz=z+face*(width*.5+.002)
        tube('Landing wheel alloy hub',[(x,cy,zz),(x,cy,zz+face*.006)],r*.60,metal,12)
        tube('Landing axle cap',[(x,cy,zz+face*.006),(x,cy,zz+face*.018)],r*.22,seam,8)


for side in [-1,1]:
    for zz in [.64,.87]:wheel(.66,.18,side*zz,.18,.115)
    tube('Main landing strut',[(.66,.20,side*.76),(.61,.91,side*.76)],.034,metal,8)
    tube('Main gear diagonal brace',[(.62,.41,side*.75),(1.05,1.02,side*.50)],.020,metal,6)
    box('Main gear door',(.50,.67,side*.77),(.28,.47,.038),white,.016)
    box('Wing root gear bay',(.78,.97,side*.49),(.60,.035,.24),black,.04)
for z in [-.095,.095]:wheel(-3.72,.139,z,.139,.074)
tube('Nose gear shock strut',[(-3.72,.16,0),(-3.63,.78,0)],.026,metal,8)
tube('Nose gear drag brace',[(-3.69,.36,0),(-3.27,.81,0)],.020,metal,6)
for z in [-.145,.145]:box('Nose gear door',(-3.57,.66,z),(.42,.24,.018),white,.012)
box('Nose gear bay',(-3.52,.79,0),(.62,.035,.25),black,.025)
tube('Upper anti-collision lens',[(.18,1.90,0),(.18,1.95,0)],.030,red,8)

prop,stats=bake_export(parts,'AirportAirliner',ART,OUT/'airport_plane.glb',12000,
    {'front_axis':'-X','engines':2,'landing_gear':'deployed','apron_depth_scale':.115},
    preserve_source_uvs=True,uv_detail_region=(0,-3.83,3.0))
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
studio(prop,ART,'airport_plane',target=(0,0,1.45),camera_at=(-8.7,12.4,5.8),scale=12.4,light_scale=5)
print('AIRPORT_PLANE_STATS',json.dumps(stats),flush=True)
