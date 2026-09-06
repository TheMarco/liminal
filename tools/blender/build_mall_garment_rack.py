"""Author the white retail rack, two outfits, atlas and review renders in Blender.

Run with Blender --background --factory-startup --python <this file>.
Working coordinates: X = rail length, H = height, D = depth (Godot +Z).
Only RackFrame plus one of ClothesFormal/ClothesCasual renders in the game.
"""
from pathlib import Path
import bpy
import math
import json
import random
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/mall_garment_rack'
OUT = ROOT / 'models/authored/mall_garment_rack'
ART.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
random.seed(47)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.cycles.samples = 16
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.margin = 6
parts = []
group = 'RackFrame'


def xyz(p):
    return (p[0], -p[2], p[1])


def material(name, color, rough=.8, metallic=0., noise=.09, bump=0.):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    nt = m.node_tree
    bs = nt.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metallic
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    tex = nt.nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 31
    tex.inputs['Detail'].default_value = 3
    nt.links.new(geo.outputs['Position'], tex.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*(c*(1-noise) for c in color), 1)
    ramp.color_ramp.elements[1].color = (*(min(1,c*(1+noise)) for c in color), 1)
    nt.links.new(tex.outputs['Fac'], ramp.inputs[0])
    ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = .035
    ao.samples = 8
    mix = nt.nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = .35
    nt.links.new(ramp.outputs[0], mix.inputs[1])
    nt.links.new(ao.outputs['Color'], mix.inputs[2])
    nt.links.new(mix.outputs[0], bs.inputs['Base Color'])
    if bump:
        fine = nt.nodes.new('ShaderNodeTexNoise')
        fine.inputs['Scale'].default_value = 380
        fine.inputs['Detail'].default_value = 2
        nt.links.new(geo.outputs['Position'], fine.inputs['Vector'])
        bn = nt.nodes.new('ShaderNodeBump')
        bn.inputs['Strength'].default_value = .28
        bn.inputs['Distance'].default_value = bump
        nt.links.new(fine.outputs['Fac'], bn.inputs['Height'])
        nt.links.new(bn.outputs[0], bs.inputs['Normal'])
    return m


white = material('Warm white powder-coated steel',(.73,.735,.69),.47,noise=.045)
rubber = material('Black rubber feet and plugs',(.018,.021,.019),.91)
metal = material('Steel hooks and fixings',(.38,.40,.39),.28,.82)
wood = material('Honey beech hangers',(.38,.218,.087),.65,noise=.25,bump=.0004)
navy = material('Ink navy wool',(.029,.043,.064),.94,noise=.27,bump=.0011)
charcoal = material('Charcoal wool',(.044,.049,.049),.95,noise=.24,bump=.0011)
slate = material('Slate blue cloth',(.132,.167,.196),.91,noise=.22,bump=.001)
gray = material('Warm gray cloth',(.275,.28,.26),.93,noise=.20,bump=.001)
cream = material('Ivory cotton',(.65,.642,.566),.95,noise=.16,bump=.001)
sage = material('Sage cotton',(.245,.297,.20),.94,noise=.22,bump=.001)
mustard = material('Faded chartreuse jersey',(.52,.555,.13),.92,noise=.15,bump=.0008)
taupe = material('Sand cotton',(.38,.337,.258),.94,noise=.19,bump=.001)
seam = material('Dark button and seam detail',(.018,.022,.022),.83)
label = material('Small cream garment labels',(.67,.63,.51),.9)


def register(ob, mat):
    ob.data.materials.append(mat)
    vg = ob.vertex_groups.new(name=group)
    vg.add(list(range(len(ob.data.vertices))), 1., 'REPLACE')
    parts.append(ob)
    return ob


def mesh(name, vertices, faces, mat, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in vertices],[],faces)
    data.update()
    ob = bpy.data.objects.new(name,data)
    scene.collection.objects.link(ob)
    register(ob,mat)
    for p in data.polygons: p.use_smooth = smooth
    return ob


def box(name, p, size, mat, bevel=0.):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(p))
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Small manufactured edges','BEVEL')
        mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for face in ob.data.polygons:face.use_smooth=False
    return register(ob,mat)


def tube(name, points, radius, mat, sides=6, caps=True):
    verts=[]
    for i,p in enumerate(points):
        t=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        t.normalize()
        up=Vector((1,0,0)) if abs(t.x)<.9 else Vector((0,0,1))
        u=t.cross(up).normalized();v=t.cross(u).normalized()
        for k in range(sides):
            a=math.tau*k/sides
            verts.append(Vector(p)+radius*(u*math.cos(a)+v*math.sin(a)))
    faces=[]
    for i in range(len(points)-1):
        for k in range(sides):
            a=i*sides+k;b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    if caps:
        faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    return mesh(name,verts,faces,mat)


# Two narrow ladder uprights with T feet: the defining construction in the photo.
for x in [-.565,.565]:
    box('T foot', (x,.054,0),(.042,.036,.596),white,.002)
    for z in [-.274,.274]:
        box('Non-slip foot cap',(x,.019,z),(.047,.038,.053),rubber,.002)
    for z in [-.081,.081]:
        box('Square-tube upright',(x,.872,z),(.027,1.626,.027),white,.0018)
    for h in [.151,1.038,1.151,1.652]:
        box('End-frame ladder rung',(x,h,0),(.026,.026,.182),white)
    box('Projecting hanger arm',(x,1.555,0),(.028,.025,.605),white,.0015)
    for z in [-.299,.299]:
        box('Rail end plug',(x,1.555,z),(.028,.023,.009),white)
    for h in [.15,1.036,1.65]:
        tube('Dark assembly screw',[(x+.014,h,.073),(x+.017,h,.073)],.0038,seam,6)
box('Lower longitudinal stretcher',(0,.154,0),(1.16,.029,.027),white,.0015)
box('Main hanging rail',(0,1.555,0),(1.568,.027,.027),white,.0015)
box('Raised display shelf',(0,1.706,0),(1.236,.025,.335),white,.003)
for x in [-.57,.57]:
    box('Shelf riser',(x,1.675,0),(.026,.044,.242),white)


def garment_transform(cx, angle=0, cz=0, offset=0):
    c=math.cos(angle);s=math.sin(angle)
    return lambda u,h,f: (cx+offset+f*c-u*s,h,cz+u*c+f*s)


def hanger(cx, angle=0, cz=0):
    tr=garment_transform(cx,angle,cz)
    # Open triangular wooden frame, gently dropped shoulders and separate hook.
    points=[(-.202,1.375,0),(-.152,1.395,0),(-.058,1.445,0),(0,1.475,0),(.058,1.445,0),(.152,1.395,0),(.202,1.375,0)]
    tube('Wooden shaped hanger',[tr(*p) for p in points],.0105,wood,5)
    tube('Wooden hanger crossbar',[tr(-.193,1.375,0),tr(.193,1.375,0)],.0055,wood,5)
    hook=[(0,1.475,0),(0,1.515,0),(.020,1.531,0),(.031,1.551,0),(.020,1.577,0),(-.004,1.585,0),(-.024,1.570,0),(-.026,1.548,0)]
    tube('Steel hanger hook',[tr(*p) for p in hook],.0028,metal,4)


xs=[-.657,-.48,-.309,-.14,.10,.278,.446,.637]
angles=[-.032,.055,-.044,.025,-.059,.042,-.02,.028]
for x,a in zip(xs,angles):hanger(x,a)
# An empty hanger on each projecting side arm keeps the rack readable as hardware.
hanger(-.565,math.pi/2,.229)
hanger(.565,math.pi/2,-.229)


def cloth_ribbon(name,pts,width,mat,tr):
    vs=[]
    for i,p in enumerate(pts):
        t=Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(0,i-1)])
        across=Vector((-t.y,t.x,0)).normalized()*width/2
        vs += [tr(*(Vector(p)+across)),tr(*(Vector(p)-across))]
    return mesh(name,vs,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(pts)-1)],mat)


def garment(cx,angle,mat,kind,index,offset=0):
    tr=garment_transform(cx,angle,offset=offset)
    short = kind=='tee'
    bottom=(.84 if short else .665)+.035*math.sin(index*2.1)
    width=.161 if short else .157
    ring_h=[bottom,bottom+.10,bottom+.25,1.16,1.31,1.405,1.459]
    ring_w=[width*.98,width,width*.97,width*.90,width*.96,.172,.065]
    verts=[];n=12
    for j,(h,w) in enumerate(zip(ring_h,ring_w)):
        for k in range(n):
            t=math.tau*k/n
            u=w*math.cos(t)
            f=.027*math.sin(t)
            f+=.005*math.sin(u*61+h*32+index)*(1 if j<5 else .2)
            hh=h+(.007*math.sin(k*2.6+index) if j==0 else 0)
            verts.append(tr(u,hh,f))
    faces=[]
    for j in range(len(ring_h)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n
            faces.append((a,b,b+n,a+n))
    # Neck stays visibly open; a shallow dark liner closes only the lower hem.
    faces.append(tuple(reversed(range(n))))
    mesh('Draped '+kind,verts,faces,mat)
    for side in [-1,1]:
        if short:
            centers=[(side*.147,1.423,0),(side*.190,1.379,0),(side*.222,1.313,.002),(side*.249,1.241,.004)]
            widths=[.024,.052,.055,.047]
        else:
            centers=[(side*.147,1.423,0),(side*.19,1.377,0),(side*.207,1.293,.002),(side*.218,1.145,.003),(side*.237,.984,.009),(side*.245,bottom+.09,.016)]
            widths=[.024,.052,.049,.044,.039,.037]
        vs=[]
        sleeve_sides=6
        for j,(u,h,f) in enumerate(centers):
            for k in range(sleeve_sides):
                t=math.tau*k/sleeve_sides
                vs.append(tr(u+widths[j]*math.cos(t),h+.015*math.cos(t),f+widths[j]*.51*math.sin(t)))
        fs=[]
        for j in range(len(centers)-1):
            for k in range(sleeve_sides):
                a=j*sleeve_sides+k;b=j*sleeve_sides+(k+1)%sleeve_sides
                fs.append((a,b,b+sleeve_sides,a+sleeve_sides))
        fs.append(tuple(reversed(range(sleeve_sides))))
        fs.append(tuple(range((len(centers)-1)*sleeve_sides,len(centers)*sleeve_sides)))
        mesh('Soft sleeve',vs,fs,mat)
    # Open rolled neckline, with a small inner label. Coats have turned lapels.
    collar=[]
    for k in range(9):
        a=math.tau*k/8
        collar.append(tr(.065*math.cos(a),1.459+.003*math.cos(a),.027*math.sin(a)))
    tube('Bound neckline',collar,.0045,mat,4,False)
    mesh('Woven neck label',[tr(-.014,1.442,-.017),tr(.014,1.442,-.017),tr(.014,1.428,-.017),tr(-.014,1.428,-.017)],[(0,1,2,3)],label,False)
    if not short:
        for side in [-1,1]:
            pts=[(side*.052,1.455,.029),(side*.117,1.398,.039),(side*.064,1.279,.044),(side*.018,1.365,.046)]
            mesh('Turned lapel',[tr(*p) for p in pts],[(0,1,3),(1,2,3)],mat,False)
        cloth_ribbon('Front opening',[(.004,bottom+.014,.032),(.003,1.04,.033),(0,1.284,.031)],.003,seam,tr)
        for h in [1.20,1.115,1.03]:
            tube('Sewn button',[tr(.014,h,.031),tr(.014,h,.034)],.0034,seam,5)
        for side in [-1,1]:
            pts=[(side*.063,bottom+.25,.031),(side*.119,bottom+.258,.030)]
            cloth_ribbon('Pocket welt',pts,.009,mat,tr)
    else:
        # A lightly raised sleeve edge and hem survive low-resolution atlas baking.
        pts=[(-.152,bottom+.01,.017),(-.05,bottom+.008,.032),(.05,bottom+.014,.032),(.152,bottom+.01,.017)]
        cloth_ribbon('T shirt hem',pts,.005,mat,tr)


def folded(cx,cz,base,mat,offset=0,rotation=0):
    # Soft, slightly uneven stacks with rolled edges and a cloth fold across top.
    nu,nv=5,4
    vertices=[]
    for j in range(nv+1):
        v=j/nv*2-1
        for i in range(nu+1):
            u=i/nu*2-1
            x=.151*u*(1-.07*abs(v)**8)
            z=.121*v*(1-.055*abs(u)**8)
            h=base+.026+.013*(1-u*u)*(1-v*v)+.0025*math.sin(u*7+v*3)
            vertices.append((cx+offset+x*math.cos(rotation)-z*math.sin(rotation),h,cz+z*math.cos(rotation)+x*math.sin(rotation)))
    faces=[]
    for j in range(nv):
        for i in range(nu):
            a=j*(nu+1)+i;faces.append((a,a+1,a+nu+2,a+nu+1))
    edge=list(range(nu+1))+[j*(nu+1)+nu for j in range(1,nv+1)]+[nv*(nu+1)+i for i in range(nu-1,-1,-1)]+[j*(nu+1) for j in range(nv-1,0,-1)]
    start=len(vertices)
    for a in edge:
        x,h,z=vertices[a];vertices.append((x,base+.001,z))
    for k,a in enumerate(edge):
        b=edge[(k+1)%len(edge)];faces.append((a,start+k,start+(k+1)%len(edge),b))
    faces.append(tuple(reversed(range(start,len(vertices)))))
    mesh('Soft folded knit shirt',vertices,faces,mat)


formal_colors=[gray,navy,charcoal,slate,cream,navy,gray,slate]
casual_colors=[charcoal,sage,taupe,cream,mustard,slate,cream,sage]
for variant,colors,offset in [('ClothesFormal',formal_colors,0),('ClothesCasual',casual_colors,3.)]:
    group=variant
    for i,(x,a,m) in enumerate(zip(xs,angles,colors)):
        kind='tee' if variant=='ClothesCasual' and i not in [0,5] else 'coat'
        garment(x,a,m,kind,i,offset)
    if variant=='ClothesFormal':
        for cx,colorset in [(-.398,[charcoal,gray]),(0,[navy,slate]),(.388,[cream,cream])]:
            for j,m in enumerate(colorset):folded(cx,0,1.719+j*.047,m,offset,(j-.5)*.025)
    else:
        for cx,colorset in [(-.375,[taupe,cream,gray]),(.025,[sage,cream])]:
            for j,m in enumerate(colorset):folded(cx,0,1.719+j*.045,m,offset,(j-.5)*.028)
        # Small black fedora on the display shelf, matching the second reference rack.
        cx=.414+offset;h=1.73
        verts=[]
        for radius,z in [(1.,0),(.61,.012),(.54,.087),(.43,.112)]:
            for k in range(16):
                a=math.tau*k/16
                verts.append((cx+.157*radius*math.cos(a),h+z+.006*math.cos(a*2),.119*radius*math.sin(a)))
        faces=[]
        for j in range(3):
            for k in range(16):
                a=j*16+k;b=j*16+(k+1)%16
                faces.append((a,b,b+16,a+16))
        verts.append((cx,h+.097,0))
        faces += [(48+k,48+(k+1)%16,64) for k in range(16)]
        mesh('Black felt fedora',verts,faces,charcoal)
        pts=[(cx+.091*math.cos(k*math.tau/16),h+.032,.069*math.sin(k*math.tau/16)) for k in range(17)]
        tube('Hat grosgrain band',pts,.006,rubber,5,False)

# Single unwrap and shared atlas. Casual clothes are offset while baking to
# avoid AO from the alternate outfit; move them home after separating meshes.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
prop=bpy.context.object
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.004)
bpy.ops.object.mode_set(mode='OBJECT')
for m in prop.data.materials:m.use_fake_user=True


def bake(name,kind,noncolor=False):
    im=bpy.data.images.new(name,width=1024,height=1024,alpha=False)
    if noncolor:im.colorspace_settings.name='Non-Color'
    for m in prop.data.materials:
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.name='BAKE_TARGET';node.image=im
        m.node_tree.nodes.active=node
    bpy.ops.object.bake(type=kind)
    for m in prop.data.materials:m.node_tree.nodes.remove(m.node_tree.nodes.get('BAKE_TARGET'))
    return im


base=bake('garment_rack_basecolor','DIFFUSE')
normal=bake('garment_rack_normal','NORMAL',True)
rough=bake('garment_rack_roughness','ROUGHNESS',True)
for m in prop.data.materials:
    nt=m.node_tree;out=nt.nodes.get('Material Output')
    nt.links.remove(out.inputs['Surface'].links[0])
    em=nt.nodes.new('ShaderNodeEmission');em.name='BAKE_METAL'
    value=nt.nodes.get('Principled BSDF').inputs['Metallic'].default_value
    em.inputs[0].default_value=(value,value,value,1)
    nt.links.new(em.outputs[0],out.inputs['Surface'])
metallic=bake('garment_rack_metallic','EMIT',True)
for m in prop.data.materials:
    nt=m.node_tree;nt.nodes.remove(nt.nodes.get('BAKE_METAL'))
    nt.links.new(nt.nodes.get('Principled BSDF').outputs[0],nt.nodes.get('Material Output').inputs['Surface'])
pixels=np.ones((1024*1024,4),dtype=np.float32)
pixels[:,1]=np.array(rough.pixels[:],dtype=np.float32).reshape(-1,4)[:,0]
pixels[:,2]=np.array(metallic.pixels[:],dtype=np.float32).reshape(-1,4)[:,0]
orm=bpy.data.images.new('garment_rack_orm',width=1024,height=1024,alpha=False)
orm.colorspace_settings.name='Non-Color';orm.pixels.foreach_set(pixels.ravel())
for im in [base,normal,orm]:
    im.filepath_raw=str(ART/(im.name+'.png'));im.file_format='PNG';im.save();im.pack()
bpy.data.images.remove(rough);bpy.data.images.remove(metallic)
mat=bpy.data.materials.new('Garment rack | shared 1K atlas');mat.use_nodes=True
nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
for im in [base,normal,orm]:
    node=nt.nodes.new('ShaderNodeTexImage');node.image=im
    if im==base:nt.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    elif im==normal:
        nm=nt.nodes.new('ShaderNodeNormalMap');nt.links.new(node.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs[0],bs.inputs['Normal'])
    else:
        sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(node.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
prop.data.materials.clear();prop.data.materials.append(mat)
for face in prop.data.polygons:face.material_index=0
tri=prop.modifiers.new('Explicit game triangles','TRIANGULATE')
bpy.context.view_layer.objects.active=prop;bpy.ops.object.modifier_apply(modifier=tri.name)
game_objects=[]
for name in ['ClothesFormal','ClothesCasual']:
    bpy.ops.object.select_all(action='DESELECT');prop.select_set(True);bpy.context.view_layer.objects.active=prop
    prop.vertex_groups.active_index=prop.vertex_groups[name].index
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.vertex_group_select()
    before=set(bpy.data.objects)
    bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
    ob=(set(bpy.data.objects)-before).pop();ob.name=name
    if name=='ClothesCasual':
        for vertex in ob.data.vertices:vertex.co.x-=3.
    game_objects.append(ob)
prop.name='RackFrame';game_objects.append(prop)
counts={ob.name:len(ob.data.polygons) for ob in game_objects}
counts['formal_visible']=counts['RackFrame']+counts['ClothesFormal']
counts['casual_visible']=counts['RackFrame']+counts['ClothesCasual']
assert max(counts['formal_visible'],counts['casual_visible'])<=7000,counts
for ob in game_objects:
    ob['authored_prop']='mall_garment_rack';ob['triangles']=len(ob.data.polygons)
bpy.ops.object.select_all(action='DESELECT')
for ob in game_objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'garment_rack.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_extras=True)
stats={'triangles':counts,'visible_meshes':2,'shared_materials':1,'texture_size':1024,'orientation':'Godot Y up, long rail X, centred footprint, floor origin','variants':['formal','casual']}
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')

# Neutral studio is stored in the editable .blend but excluded from the GLB.
studio=bpy.data.collections.new('Preview studio (not exported)');scene.collection.children.link(studio)
def studio_move(ob):
    for col in list(ob.users_collection):col.objects.unlink(ob)
    studio.objects.link(ob)
bpy.ops.mesh.primitive_plane_add(size=200)
floor=bpy.context.object;floor.name='Studio floor'
fm=material('Studio gray',(.105,.114,.117),.92,noise=0)
floor.data.materials.append(fm);studio_move(floor)
def aim(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Softbox',(1.2,-3,4.3),210,3.),('Fill',(-2,-.5,2.2),90,2.2),('Rim',(0,1.7,3.6),170,2.)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;aim(ob,(0,0,.95));studio_move(ob)
bpy.ops.object.camera_add(location=(2.6,-3.1,2.08))
camera=bpy.context.object;camera.name='Retail rack review';camera.data.type='ORTHO';camera.data.ortho_scale=2.32;aim(camera,(0,0,.95));scene.camera=camera;studio_move(camera)
scene.world.color=(.19,.19,.19)
scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'
formal=bpy.data.objects['ClothesFormal'];casual=bpy.data.objects['ClothesCasual']
casual.hide_render=True;casual.hide_set(True)
bpy.ops.object.select_all(action='DESELECT');prop.select_set(True);formal.select_set(True);bpy.context.view_layer.objects.active=prop
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=3.3
        area.spaces.active.region_3d.view_location=Vector((0,0,.95))
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'garment_rack.blend'))
scene.render.filepath=str(ART/'preview_formal.png');bpy.ops.render.render(write_still=True)
formal.hide_render=True;casual.hide_render=False;casual.hide_set(False)
scene.render.filepath=str(ART/'preview_casual.png');bpy.ops.render.render(write_still=True)
print('GARMENT_RACK_STATS',json.dumps(stats),flush=True)
