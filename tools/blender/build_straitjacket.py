"""Build the reference-inspired hanging canvas prop in Blender; no external assets.

Blender --background --factory-startup --python tools/blender/build_straitjacket.py
The editable source is excluded from Godot import; only the selected game mesh
is exported. Coordinates below are (horizontal, height, distance from wall), in m.
"""
from pathlib import Path
import bpy
import math
import json
import random
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/straitjacket'
OUT = ROOT / 'models/authored/straitjacket'
ART.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
random.seed(19)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version = 0
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.bake_type = 'DIFFUSE'
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.margin = 8
scene.world.color = (0.18, 0.18, 0.18)
objects = []


def xyz(p):
    return (p[0], -p[2], p[1])


def material(name, low, high, rough, scale, bump=0.0, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*high, 1)
    mat.use_nodes = True
    nt = mat.node_tree
    bs = nt.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metal
    tex = nt.nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = scale
    tex.inputs['Detail'].default_value = 4
    pos = nt.nodes.new('ShaderNodeNewGeometry')
    nt.links.new(pos.outputs['Position'], tex.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.22
    ramp.color_ramp.elements[0].color = (*low, 1)
    ramp.color_ramp.elements[1].position = 0.79
    ramp.color_ramp.elements[1].color = (*high, 1)
    nt.links.new(tex.outputs['Fac'], ramp.inputs[0])
    ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = 0.065
    ao.samples = 16
    mix = nt.nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = 0.48
    nt.links.new(ramp.outputs[0], mix.inputs[1])
    nt.links.new(ao.outputs['Color'], mix.inputs[2])
    nt.links.new(mix.outputs[0], bs.inputs['Base Color'])
    if bump:
        fine = nt.nodes.new('ShaderNodeTexNoise')
        fine.inputs['Scale'].default_value = 640 if metal == 0 else 170
        fine.inputs['Detail'].default_value = 2
        nt.links.new(pos.outputs['Position'], fine.inputs['Vector'])
        bn = nt.nodes.new('ShaderNodeBump')
        bn.inputs['Strength'].default_value = 0.48
        bn.inputs['Distance'].default_value = bump
        nt.links.new(fine.outputs['Fac'], bn.inputs['Height'])
        nt.links.new(bn.outputs[0], bs.inputs['Normal'])
    return mat


canvas = material('Canvas | aged unbleached cotton', (.255,.235,.167), (.60,.551,.40), .94, 13, .0012)
lining = material('Canvas | shadowed lining', (.205,.188,.131), (.42,.385,.275), .98, 21, .0008)
hem_mat = material('Canvas | reinforced binding', (.27,.249,.177), (.52,.476,.34), .96, 26, .0009)
thread = material('Flax thread', (.34,.303,.216), (.65,.59,.426), .99, 100)
leather = material('Leather | worn umber', (.035,.021,.014), (.115,.073,.042), .78, 66, .0006)
leather_edge = material('Leather | exposed edges', (.07,.044,.025), (.19,.129,.078), .88, 80)
steel = material('Steel | oxidized buckle', (.105,.112,.099), (.33,.34,.29), .42, 100, .0002, .78)
iron = material('Iron | wall hook', (.023,.026,.024), (.073,.077,.066), .72, 48, .0003, .7)
hole = material('Leather punched holes', (.008,.006,.004), (.022,.016,.009), 1, 30)

# Broad compressed fabric wrinkles complement the silhouette folds, without
# subdividing the game mesh. The fine grain above supplies the cotton surface.
for mat in [canvas, lining, hem_mat]:
    nt = mat.node_tree
    bs = nt.nodes.get('Principled BSDF')
    previous = bs.inputs['Normal'].links[0].from_socket
    tex = nt.nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 37
    tex.inputs['Detail'].default_value = 2.5
    tex.inputs['Roughness'].default_value = .72
    nt.links.new(nt.nodes.get('Geometry').outputs['Position'], tex.inputs['Vector'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .28
    bump.inputs['Distance'].default_value = .013
    nt.links.new(tex.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(previous, bump.inputs['Normal'])
    nt.links.new(bump.outputs[0], bs.inputs['Normal'])


def mesh(name, verts, faces, mat, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in verts], [], faces)
    data.materials.append(mat)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    objects.append(obj)
    for p in data.polygons:
        p.use_smooth = smooth
    return obj


def solid(obj, thickness=.003):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Thin sewn fabric', 'SOLIDIFY')
    mod.thickness = thickness
    mod.offset = -1
    bpy.ops.object.modifier_apply(modifier=mod.name)


def width(t):
    return .277 + .022*math.cos(t*math.pi*2) - .02*math.exp(-((t-.48)/.19)**2)


def front(x, h):
    w = width(h/1.04)
    return .078 + .054*max(0, 1-(x/w)**2) + .010*math.sin(38*x+12*h) + .006*math.sin(71*x-24*h) + .009*math.sin(30*h+9*x)


def panel_point(side, u, t):
    # The two overlapping coat skirts separate visibly below the waist.
    edge = (.023*(1-t/.43) if t < .43 else -.014)
    x = side*(edge+(width(t)-edge)*u)
    top = 1.025 + .04*math.sin(u*math.pi) - .098*(1-u)**5
    bottom = (.018 if side < 0 else .006) + .013*math.sin(u*8+side)
    h = bottom+(top-bottom)*t
    d = front(x,h) + (.006 if side > 0 else 0)
    return x,h,d


def grid(name, fn, nu, nv, mat, thickness=0):
    vs = [fn(i/nu,j/nv) for j in range(nv+1) for i in range(nu+1)]
    fs = []
    for j in range(nv):
        for i in range(nu):
            a=j*(nu+1)+i
            fs.append((a,a+1,a+nu+2,a+nu+1))
    ob=mesh(name,vs,fs,mat)
    if thickness:
        solid(ob,thickness)
    return ob


for side, name in [(-1,'Left overlapping skirt'),(1,'Right overlapping skirt')]:
    grid(name, lambda u,t,s=side: panel_point(s,u,t), 8, 15, canvas)


def back_point(u,t):
    x=(u*2-1)*width(t)
    h=.02 + t*(1.043-.02) - .066*t**9*(1-abs(u*2-1))**5
    d=.031 + .009*math.cos(x*44+h*14)+.004*math.sin(h*38)
    return x,h,d


grid('Back canvas',back_point,12,15,canvas)
for side in [-1,1]:
    def side_point(u,t,s=side):
        p=Vector(panel_point(s,1,t))
        q=Vector(back_point(0 if s<0 else 1,t))
        return p.lerp(q,u)
    grid('Side gusset',side_point,2,15,canvas)


def ribbon(name, points, widths, mat, thickness=.0025):
    verts=[]
    for i,p in enumerate(points):
        a=Vector(points[max(0,i-1)])
        b=Vector(points[min(len(points)-1,i+1)])
        tangent=b-a
        normal=Vector((-tangent.y,tangent.x,0)).normalized()
        w=widths[i] if isinstance(widths,list) else widths
        verts += [Vector(p)+normal*w/2,Vector(p)-normal*w/2]
    fs=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(points)-1)]
    ob=mesh(name,verts,fs,mat)
    if thickness:
        solid(ob,thickness)
    return ob


def tube(name, points, radii, mat, sides=8, depth_ratio=1.0, caps=True):
    verts=[]
    for i,p in enumerate(points):
        p=Vector(p)
        tangent=Vector(points[min(len(points)-1,i+1)])-Vector(points[max(0,i-1)])
        across=Vector((-tangent.y,tangent.x,0)).normalized()
        deep=Vector((0,0,1))
        radius=radii[i] if isinstance(radii,list) else radii
        for j in range(sides):
            ang=j*math.tau/sides
            verts.append(p+across*math.cos(ang)*radius+deep*math.sin(ang)*radius*depth_ratio)
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    if caps:
        faces += [tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    return mesh(name,verts,faces,mat)


left=[(-.265,1.0,.09),(-.308,.959,.1),(-.33,.902,.105),(-.359,.844,.11),(-.377,.783,.111),(-.41,.72,.12),(-.426,.66,.13),(-.418,.597,.143),(-.392,.551,.173),(-.341,.506,.202),(-.281,.479,.226),(-.218,.456,.24),(-.149,.425,.246),(-.113,.398,.241)]
lr=[.103,.108,.097,.106,.096,.101,.089,.08,.085,.075,.065,.072,.059,.052]
right=[(.258,1.004,.09),(.292,.972,.105),(.32,.913,.116),(.342,.85,.108),(.346,.783,.107),(.337,.721,.127),(.347,.66,.135),(.336,.592,.119),(.326,.525,.142),(.332,.452,.146),(.325,.382,.136),(.333,.311,.13),(.331,.24,.136),(.32,.169,.139),(.313,.106,.132),(.315,.069,.13)]
rr=[.103,.106,.097,.094,.1,.086,.088,.093,.078,.074,.085,.073,.074,.071,.063,.055]
tube('Loose left sleeve folded across waist',left,lr,canvas,10,.50)
tube('Long closed right sleeve',right,rr,canvas,10,.48)

# Rolled collar follows the open neck, with independent folded lapels.
tube('Soft rolled collar',[(-.218,1.054,.068),(-.165,1.092,.055),(-.098,1.085,.036),(0,1.066,.032),(.10,1.071,.041),(.18,1.059,.071),(.235,1.018,.105)], [.023,.025,.022,.021,.022,.024,.022],hem_mat,8,.68)
collar_top=[(-.218,1.054,.068),(-.165,1.092,.055),(-.098,1.085,.036),(0,1.066,.032),(.10,1.071,.041),(.18,1.059,.071),(.235,1.018,.105)]
collar_vertices=[]
for x,h,d in collar_top:
    back_h=1.043-.066*(1-abs(x/width(1)))**5
    collar_vertices.extend([(x,back_h-.006,.039),(x,h-.008,d)])
mesh('Continuous back collar band',collar_vertices,[(2*i,2*i+2,2*i+3,2*i+1) for i in range(6)],lining)
lapels=[('Left collapsed collar',[(-.221,1.041,.117),(-.153,1.073,.106),(-.069,.933,.184),(-.121,.884,.177),(-.175,.979,.183)]),('Right turned collar',[(.038,.969,.172),(.118,1.047,.108),(.235,1.019,.122),(.207,.924,.19),(.119,.914,.19)])]
for name,points in lapels:
    ob=mesh(name,points,[(0,1,4),(1,2,4),(2,3,4)],canvas)
    solid(ob,.004)


def stitches(name,points,step=.011,mat=thread):
    # Flat stitch dashes bake into the atlas; inexpensive even before baking.
    vs=[]; fs=[]
    for a,b in zip(points,points[1:]):
        a=Vector(a);b=Vector(b)
        length=(b-a).length
        count=max(1,int(length/step))
        direction=(b-a).normalized()
        across=Vector((-direction.y,direction.x,0)).normalized()*.0007
        for i in range(count):
            p=a.lerp(b,(i+.2)/count)+Vector((0,0,.001))
            q=a.lerp(b,(i+.67)/count)+Vector((0,0,.001))
            n=len(vs)
            vs += [p-across,p+across,q+across,q-across]
            fs.append((n,n+1,n+2,n+3))
    return mesh(name,vs,fs,mat,False)


# Hem tapes, skirt seams, and a fine stitched line along the long sleeve.
for s in [-1,1]:
    pts=[]
    for i in range(11):
        p=Vector(panel_point(s,i/10,.035));p.z+=.004;pts.append(p)
    ribbon('Turned bottom hem',pts,.016,hem_mat,.0015)
    stitches('Hem stitching',pts)
    pts=[]
    for i in range(10):
        p=Vector(panel_point(s,.10,i/12));p.z+=.005;pts.append(p)
    ribbon('Front opening bound edge',pts,.008,hem_mat,.001)
    pts=[]
    for i in range(9):
        p=Vector(panel_point(s,.81,.05+i*.057));p.z+=.003;pts.append(p)
    ribbon('Skirt reinforcement seam',pts,.004,hem_mat,.001)
    stitches('Panel seam stitching',pts,step=.013)
pts=[(p[0]+.044,p[1],p[2]+rr[i]*.40) for i,p in enumerate(right[2:],start=2)]
ribbon('Sleeve lengthwise seam',pts,.006,hem_mat,.001)
stitches('Sleeve seam stitching',pts,.014)
for name,centers,radii in [('Left cuff',left,lr),('Right cuff',right,rr)]:
    p=Vector(centers[-1]);q=Vector(centers[-2]);t=(p-q).normalized()
    across=Vector((-t.y,t.x,0)).normalized()
    pts=[p+across*((i/8-.5)*radii[-1]*1.85)+Vector((0,0,.025)) for i in range(9)]
    ribbon(name,pts,.020,hem_mat,.002)
    stitches(name+' stitching',pts,.010)


def patch(name,cx,h,w=.063,hh=.069):
    pts=[(-.5,-.33),(-.32,-.5),(.35,-.5),(.5,-.32),(.5,.36),(.33,.5),(-.34,.5),(-.5,.30)]
    vs=[(cx+x*w,h+y*hh,front(cx+x*w,h+y*hh)+.012) for x,y in pts]
    vs.append((cx,h,front(cx,h)+.013))
    ob=mesh(name,vs,[(i,(i+1)%8,8) for i in range(8)],leather)
    solid(ob,.004)
    inner=[(cx+x*w*.80,h+y*hh*.80,front(cx+x*w*.80,h+y*hh*.80)+.014) for x,y in pts]
    stitches(name+' saddle stitch',inner+[inner[0]],.009,leather_edge)


def buckle(name,cx,h,d,w=.049,hh=.034,tilt=0):
    # Actual open rounded rectangular steel frame and tongue, no solid block.
    shape=[(-.5,-.31),(-.33,-.5),(.33,-.5),(.5,-.31),(.5,.31),(.33,.5),(-.33,.5),(-.5,.31)]
    pts=[]
    for x,y in shape+shape[:1]:
        x*=w;y*=hh
        pts.append((cx+x*math.cos(tilt)-y*math.sin(tilt),h+x*math.sin(tilt)+y*math.cos(tilt),d))
    tube(name+' frame',pts,.0029,steel,6,.85,False)
    tube(name+' tongue',[(cx-w*.30,h,d+.003),(cx+w*.39,h+.003,d+.005)],.0019,steel,6)


for index,h in enumerate([.664,.548,.445]):
    lx=-.151+index*.004;rx=.124+index*.008
    patch('Left leather anchor %d'%index,lx,h)
    patch('Buckle leather anchor %d'%index,rx,h-.020)
    pts=[]
    for i in range(9):
        t=i/8;x=lx+(rx+.047-lx)*t
        hh=h-.020*t-.031*math.sin(t*math.pi)
        pts.append((x,hh,front(x,hh)+.025+.008*math.sin(t*math.pi)))
    ribbon('Sagging leather belt %d'%index,pts,.025,leather,.004)
    buckle('Waist buckle %d'%index,rx-.008,h-.029,front(rx,h-.029)+.041,tilt=-.07)
    for j in range(3):
        t=.30+j*.105;p=Vector(pts[int(t*8)]).lerp(Vector(pts[min(8,int(t*8)+1)]),t*8%1);p.z+=.003
        mesh('Punched belt hole',[(p.x+math.cos(k*math.tau/6)*.002,p.y+math.sin(k*math.tau/6)*.002,p.z) for k in range(6)],[tuple(range(6))],hole,False)

# Small shoulder buckle and the long, loose opposing strap seen in the photo.
patch('Upper fastening patch',.188,.884,.060,.064)
ribbon('Upper diagonal strap',[(.051,.925,.171),(.106,.906,.183),(.15,.889,.189),(.217,.889,.184)],.025,leather,.003)
buckle('Shoulder buckle',.160,.887,.204,.042,.033,-.13)
ribbon('Loose shoulder strap',[(-.164,1.026,.171),(-.182,.970,.204),(-.168,.912,.213),(-.187,.852,.205),(-.199,.796,.189),(-.222,.730,.187)],[.028,.028,.03,.029,.028,.022],leather,.0035)
buckle('Loose strap adjuster',-.177,.932,.223,.031,.024,-.13)
patch('Lower fastening patch',.083,.247,.062,.06)
ribbon('Lower short strap',[(-.031,.258,.151),(.028,.239,.174),(.093,.244,.167)],.022,leather,.003)
buckle('Lower buckle',.047,.244,.185,.041,.031,.1)
ribbon('Loose canvas crotch tie',[(-.031,.409,.268),(-.012,.329,.227),(-.073,.283,.208),(-.089,.213,.182)],[.032,.03,.029,.021],hem_mat,.003)

# Dark, unobtrusive wall hook integral to the prop; its back sits at the wall.
ob=mesh('Hook mounting plate',[(-.022,1.091,.009),(.022,1.091,.009),(.022,1.173,.009),(-.022,1.173,.009)],[(0,1,2,3)],iron,False)
solid(ob,.006)
tube('Bent wall hook',[(0,1.147,.016),(0,1.123,.048),(0,1.103,.070),(0,1.109,.088),(0,1.131,.092)],.008,iron,8)

# Collapse the prop to one mesh, unwrap once, then bake one material atlas.
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join()
prop=bpy.context.object
prop.name='Straitjacket_Game'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(62),island_margin=.006)
bpy.ops.object.mode_set(mode='OBJECT')
# Keep original procedural shaders in the .blend datablocks for editing/rebaking.
for mat in list(prop.data.materials):
    mat.use_fake_user=True


def bake_image(name,kind,noncolor=False):
    im=bpy.data.images.new(name,width=1024,height=1024,alpha=False)
    if noncolor: im.colorspace_settings.name='Non-Color'
    for mat in prop.data.materials:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.name='BAKE_TARGET';node.image=im
        mat.node_tree.nodes.active=node
    bpy.ops.object.bake(type=kind)
    im.filepath_raw=str(ART/(name+'.png'))
    im.file_format='PNG';im.save()
    for mat in prop.data.materials:
        mat.node_tree.nodes.remove(mat.node_tree.nodes.get('BAKE_TARGET'))
    return im


base=bake_image('straitjacket_basecolor','DIFFUSE')
normal=bake_image('straitjacket_normal','NORMAL',True)
rough=bake_image('straitjacket_roughness','ROUGHNESS',True)
for mat in prop.data.materials:
    nt=mat.node_tree
    out=nt.nodes.get('Material Output')
    nt.links.remove(out.inputs['Surface'].links[0])
    em=nt.nodes.new('ShaderNodeEmission')
    em.name='METAL_BAKE'
    m=nt.nodes.get('Principled BSDF').inputs['Metallic'].default_value
    em.inputs['Color'].default_value=(m,m,m,1)
    nt.links.new(em.outputs[0],out.inputs['Surface'])
metal=bake_image('straitjacket_metallic','EMIT',True)
for mat in prop.data.materials:
    nt=mat.node_tree
    nt.nodes.remove(nt.nodes.get('METAL_BAKE'))
    nt.links.new(nt.nodes.get('Principled BSDF').outputs[0],nt.nodes.get('Material Output').inputs['Surface'])

import numpy as np
rp=np.array(rough.pixels[:],dtype=np.float32).reshape(-1,4)
mp=np.array(metal.pixels[:],dtype=np.float32).reshape(-1,4)
packed=np.ones_like(rp);packed[:,1]=rp[:,0];packed[:,2]=mp[:,0]
orm=bpy.data.images.new('straitjacket_orm',width=1024,height=1024,alpha=False)
orm.colorspace_settings.name='Non-Color'
orm.pixels.foreach_set(packed.ravel())
orm.filepath_raw=str(ART/'straitjacket_orm.png');orm.file_format='PNG';orm.save()

game=bpy.data.materials.new('Straitjacket | baked canvas leather steel')
game.use_nodes=True
nt=game.node_tree;bs=nt.nodes.get('Principled BSDF')
for im,label in [(base,'Albedo'),(normal,'Normal'),(orm,'ORM')]:
    node=nt.nodes.new('ShaderNodeTexImage');node.image=im;node.label=label
    if label=='Albedo':nt.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    elif label=='Normal':
        nm=nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(node.outputs['Color'],nm.inputs['Color'])
        nt.links.new(nm.outputs[0],bs.inputs['Normal'])
    else:
        sep=nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(node.outputs['Color'],sep.inputs[0])
        nt.links.new(sep.outputs['Green'],bs.inputs['Roughness'])
        nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
prop.data.materials.clear();prop.data.materials.append(game)
for p in prop.data.polygons:p.material_index=0
tri=prop.modifiers.new('Explicit game triangles','TRIANGULATE')
bpy.context.view_layer.objects.active=prop
bpy.ops.object.modifier_apply(modifier=tri.name)
triangles=len(prop.data.polygons)
assert triangles <= 6000, f'Triangle budget exceeded: {triangles}'
prop['triangle_count']=triangles
prop['source']='Authored in Blender from user-supplied jacket.jpg visual reference'
prop['game_front']='+Z after glTF axis conversion'
prop['mount_y_m']=.92
for im in [base,normal,orm]: im.pack()
bpy.ops.export_scene.gltf(filepath=str(OUT/'straitjacket.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_tangents=True,export_extras=True,export_materials='EXPORT')
stats={'triangles':triangles,'vertices_blender':len(prop.data.vertices),'materials':1,'textures':'1024x1024 basecolor, tangent normal, ORM (embedded)','dimensions_blender_m':list(prop.dimensions),'godot_front':'+Z','godot_mount_y_m':.92}
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')

# Reusable studio in the source file. None of these nodes enter the GLB.
studio=bpy.data.collections.new('Preview studio (not exported)');scene.collection.children.link(studio)
def studio_move(ob):
    for col in list(ob.users_collection):col.objects.unlink(ob)
    studio.objects.link(ob)

def plain(name,color,roughness):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=roughness
    return m

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.045))
floor=bpy.context.object;floor.name='Studio floor';floor.data.materials.append(plain('Studio charcoal',(.047,.055,.059),.9));studio_move(floor)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,.014,0),rotation=(math.pi/2,0,0))
wall=bpy.context.object;wall.name='Studio wall';wall.data.materials.append(plain('Studio warm gray',(.12,.128,.12),.95));studio_move(wall)
def aim(ob,pt):ob.rotation_euler=(Vector(pt)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Large softbox',(-1.4,-1.8,2.6),110,1.5),('Gentle fill',(1.3,-1,1.5),45,1.3),('Top rim',(.3,-.4,2.8),50,1.)]:
    bpy.ops.object.light_add(type='AREA',location=loc);ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;aim(ob,(0,-.1,.6));studio_move(ob)
bpy.ops.object.camera_add(location=(.13,-2.7,1.16))
camera=bpy.context.object;camera.name='Jacket preview';studio_move(camera);aim(camera,(0,-.09,.59));camera.data.type='ORTHO';camera.data.ortho_scale=1.49;scene.camera=camera
scene.render.resolution_x=1100;scene.render.resolution_y=1300;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(ART/'preview_front.png')
scene.cycles.samples=32
scene.cycles.use_denoising=True
bpy.ops.object.select_all(action='DESELECT');prop.select_set(True);bpy.context.view_layer.objects.active=prop
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=2.1
        area.spaces.active.region_3d.view_location=Vector((0,-.1,.58))
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'straitjacket.blend'))
bpy.ops.render.render(write_still=True)
camera.location=(1.15,-2.6,1.2);aim(camera,(0,-.1,.59))
scene.render.filepath=str(ART/'preview_angle.png')
bpy.ops.render.render(write_still=True)
print('STRAITJACKET_STATS',json.dumps(stats))
