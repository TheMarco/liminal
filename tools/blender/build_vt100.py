"""Author a hollow, low-poly VT100-style CRT and its matching keyboard.

Blender --background --factory-startup --python tools/blender/build_vt100.py
The asset coordinates are Godot metres: +Y up, +Z toward the operator.
Atlas lettering is rasterized by Pillow; no text meshes reach the game.
"""
from pathlib import Path
import json
import math
import random
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ART = ROOT / 'art/vt100'
OUT = ROOT / 'models/authored/vt100'
ART.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)

# Ordered key legend inventory is also used for stable atlas addressing.
ROWS = [
    ['ESC', '1 !', '2 @', '3 #', '4 $', '5 %', '6 ^', '7 &', '8 *', '9 (', '0 )', '- _', '= +', 'BACK'],
    ['TAB', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[ {', '] }', 'RETURN'],
    ['CTRL', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', '; :', "' \"", '\\ |'],
    ['SHIFT', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ', <', '. >', '/ ?', 'SHIFT'],
]
EXTRA = ['SET UP', 'LINE', 'LOCAL', 'PF1', 'PF2', 'PF3', 'PF4', '7', '8', '9', '-', '4', '5', '6', ',', '1', '2', '3', 'ENTER', '0', '.']
LEGENDS = [k for row in ROWS for k in row] + EXTRA


def draw_atlas():
    from PIL import Image, ImageDraw, ImageFont
    rng = random.Random(100)
    im = Image.new('RGB', (1024, 1024), (30, 29, 27))
    px = im.load()
    # Reusable grain patches keep the exported material and texture count low.
    for x0, y0, x1, y1, col, strength in [
        (0, 0, 256, 256, (210, 207, 183), 4),
        (256, 0, 512, 256, (31, 30, 28), 3),
        (768, 0, 896, 128, (193, 189, 162), 3),
    ]:
        for y in range(y0, y1):
            for x in range(x0, x1):
                n = rng.gauss(0, strength)
                px[x, y] = tuple(max(0, min(255, int(c+n))) for c in col)
    d = ImageDraw.Draw(im)
    font = '/System/Library/Fonts/Supplemental/Arial.ttf'
    bold = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
    mono = '/System/Library/Fonts/Supplemental/Andale Mono.ttf'
    def f(size, heavy=False):
        return ImageFont.truetype(bold if heavy else font, size)
    def center(rect, text, size, fill=(233, 229, 207), heavy=False):
        x0,y0,x1,y1=rect
        d.text(((x0+x1)/2,(y0+y1)/2),text,font=f(size,heavy),fill=fill,anchor='mm')
    d.rectangle((512,0,767,127), fill=(26,27,26))
    d.rounded_rectangle((518,6,760,118), radius=5, outline=(153,150,131), width=2)
    center((524,8,753,69),'VT100',45,(213,157,103),True)
    center((522,67,757,109),'FACILITY SYSTEMS',18)
    d.rectangle((512,128,767,191),fill=(176,174,162))
    center((514,130,765,190),'UNIT 86 / 0047',24,(66,65,57))
    d.rectangle((896,0,1023,255),fill=(31,30,28))
    center((900,15,1020,64),'SET-UP',17)
    center((900,94,1020,132),'ON LINE',14)
    center((900,174,1020,212),'LOCAL',14)
    # Ventilation and fasteners are texels, not dozens of separate draw surfaces.
    d.rectangle((0,256,511,383),fill=(210,207,183))
    for y in range(270,369,12):
        d.rounded_rectangle((18,y,493,y+5),radius=2,fill=(55,54,47))
        d.line((23,y+6,488,y+6),fill=(236,231,206))
    for x in [10,500]:
        for y in [263,376]:
            d.ellipse((x-3,y-3,x+3,y+3),fill=(130,129,116))
            d.line((x-2,y,x+2,y),fill=(71,71,63))
    d.rectangle((512,256,1023,383),fill=(42,42,37))
    center((525,259,1009,287),'VIDEO DISPLAY TERMINAL  /  120V 60Hz',15)
    for x,label in [(600,'COMM'),(744,'PRINTER'),(895,'KEYBOARD')]:
        d.rounded_rectangle((x-44,303,x+44,339),radius=5,fill=(129,130,124))
        d.rounded_rectangle((x-36,310,x+36,332),radius=4,fill=(13,15,14))
        for ix in range(x-29,x+30,12):
            d.ellipse((ix-2,315,ix+2,319),fill=(180,165,111))
            d.ellipse((ix-2,323,ix+2,327),fill=(180,165,111))
        center((x-58,340,x+58,378),label,15)
    d.rectangle((0,384,511,447),fill=(30,30,28))
    center((8,387,502,438),'L1   L2   L3   L4       LOCK     KBD',17)
    d.rectangle((512,384,1023,447),fill=(206,202,177))
    center((515,386,1020,444),'PROPERTY OF FACILITIES • DO NOT REMOVE',15,(84,80,66))
    for i,label in enumerate(LEGENDS):
        x=(i%16)*64; y=512+(i//16)*64
        for yy in range(y,y+64):
            for xx in range(x,x+64):
                n=rng.randrange(-2,3)
                px[xx,yy]=(38+n,37+n,34+n)
        d.line((x+5,y+56,x+58,y+56),fill=(43,42,39),width=1)
        if len(label)>4:
            words=label.split(' ')
            if len(words)>1:
                center((x+2,y+8,x+62,y+32),words[0],12)
                center((x+2,y+29,x+62,y+53),' '.join(words[1:]),12)
            else:center((x+2,y+2,x+62,y+60),label,11)
        elif ' ' in label:
            a,b=label.split(' ',1)
            center((x+2,y+3,x+62,y+31),b,17)
            center((x+2,y+28,x+62,y+60),a,24)
        else:center((x+2,y+2,x+62,y+59),label,24 if len(label)==1 else 14)
    # Discrete wear marks stay very restrained at player viewing distances.
    for _ in range(90):
        x=rng.randrange(10,245); y=rng.randrange(10,245)
        d.line((x,y,x+rng.randrange(1,5),y+1),fill=(202,199,176))
    im.save(ART/'vt100_atlas.png')
    # One tiny packed ORM map gives the black bezel a different finish from the
    # chalky cream casing without splitting either prop into extra draw surfaces.
    orm=Image.new('RGB',(256,256),(255,145,0));op=orm.load()
    normal=Image.new('RGB',(256,256),(128,128,255));np=normal.load()
    for y in range(256):
        for x in range(256):
            rough=109 if 64<=x<128 and y<64 else (132 if y>=128 else 151)
            op[x,y]=(255,rough+rng.randrange(-3,4),0)
            np[x,y]=(128+rng.randrange(-3,4),128+rng.randrange(-3,4),255)
    orm.save(ART/'vt100_orm.png');normal.save(ART/'vt100_normal.png')


if '--draw-atlas' in sys.argv:
    draw_atlas()
    raise SystemExit

import bpy
from mathutils import Vector

subprocess.run(['/opt/homebrew/bin/python3', str(Path(__file__).resolve()), '--draw-atlas'], check=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0

CREAM=(2,2,254,254)
BLACK=(258,2,510,254)
SPACE=(770,2,894,126)
parts=[]


def xyz(p):return (p[0],-p[2],p[1])


atlas=bpy.data.images.load(str(ART/'vt100_atlas.png'))
atlas.pack()
mat=bpy.data.materials.new('VT100 | original shared 1K plastic and lettering atlas')
mat.use_nodes=True
nodes=mat.node_tree.nodes
bs=nodes.get('Principled BSDF')
tex=nodes.new('ShaderNodeTexImage');tex.image=atlas
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
bs.inputs['Roughness'].default_value=.51
orm_image=bpy.data.images.load(str(ART/'vt100_orm.png'));orm_image.colorspace_settings.name='Non-Color';orm_image.pack()
orm_tex=nodes.new('ShaderNodeTexImage');orm_tex.image=orm_image
sep=nodes.new('ShaderNodeSeparateColor');mat.node_tree.links.new(orm_tex.outputs['Color'],sep.inputs[0])
mat.node_tree.links.new(sep.outputs['Green'],bs.inputs['Roughness'])
mat.node_tree.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
normal_image=bpy.data.images.load(str(ART/'vt100_normal.png'));normal_image.colorspace_settings.name='Non-Color';normal_image.pack()
normal_tex=nodes.new('ShaderNodeTexImage');normal_tex.image=normal_image
nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.35
mat.node_tree.links.new(normal_tex.outputs['Color'],nm.inputs['Color'])
mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])


def uv_rect(rect):
    x0,y0,x1,y1=rect
    return [(x0/1024,1-y1/1024),(x1/1024,1-y1/1024),(x1/1024,1-y0/1024),(x0/1024,1-y0/1024)]


def plain_uvs(ob,region):
    """Keep texel density proportional to geometry, with generous atlas gutters.

    Mapping every thin bevel across an entire color patch makes game mipmaps
    sample adjacent patches, even though Blender's full-resolution ray-traced
    preview looks clean. A 358 texel/metre projection gives narrow faces narrow
    UVs and keeps all ordinary plastic samples well inside their padded patch.
    """
    uv=ob.data.uv_layers.active.data
    x0,y0,x1,y1=region
    center=((x0+x1)/2048,1-(y0+y1)/2048)
    for poly in ob.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        axes=[i for i in range(3) if i!=axis]
        verts=[ob.data.vertices[i].co for i in poly.vertices]
        middle=[sum(v[a] for v in verts)/len(verts) for a in axes]
        for li in poly.loop_indices:
            v=ob.data.vertices[ob.data.loops[li].vertex_index].co
            uv[li].uv=(center[0]+(v[axes[0]]-middle[0])*.35,
                       center[1]+(v[axes[1]]-middle[1])*.35)


def mesh(name,vertices,faces,region=CREAM,smooth=False):
    data=bpy.data.meshes.new(name)
    data.from_pydata([xyz(v) for v in vertices],[],faces)
    data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob)
    data.materials.append(mat)
    uv=data.uv_layers.new(name='Atlas')
    rect=uv_rect(region)
    for poly in data.polygons:
        poly.use_smooth=smooth
        for j,li in enumerate(poly.loop_indices):
            if len(poly.loop_indices)==4:
                uv.data[li].uv=rect[j]
            else:
                a=math.tau*j/len(poly.loop_indices)
                uv.data[li].uv=((rect[0][0]+rect[2][0])*.5+(rect[2][0]-rect[0][0])*.45*math.cos(a),
                                (rect[0][1]+rect[2][1])*.5+(rect[2][1]-rect[0][1])*.45*math.sin(a))
    if region in [CREAM,BLACK,SPACE]:plain_uvs(ob,region)
    parts.append(ob)
    return ob


def rounded(cx,cy,w,h,r,z,steps=5):
    points=[]
    for ax,ay,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]:
        for j in range(steps+1):
            a=math.radians(start+90*j/steps)
            points.append((cx+ax*(w*.5-r)+r*math.cos(a),cy+ay*(h*.5-r)+r*math.sin(a),z))
    return points


def loft(name,loops,region=CREAM,cap_first=False,cap_last=False,smooth=False):
    count=len(loops[0]);verts=[p for loop in loops for p in loop]
    faces=[]
    for j in range(len(loops)-1):
        for k in range(count):
            a=j*count+k;b=j*count+(k+1)%count
            faces.append((a,b,b+count,a+count))
    if cap_first:faces.append(tuple(reversed(range(count))))
    if cap_last:faces.append(tuple(range((len(loops)-1)*count,len(loops)*count)))
    return mesh(name,verts,faces,region,smooth)


def box(name,p,size,region=CREAM,bevel=.001):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p))
    ob=bpy.context.object;ob.name=name;ob.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Small manufactured chamfer','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat)
    uv=ob.data.uv_layers.get('UVMap') or ob.data.uv_layers.new(name='Atlas')
    rect=uv_rect(region)
    for poly in ob.data.polygons:
        for j,li in enumerate(poly.loop_indices):uv.data[li].uv=rect[j%4]
    if region in [CREAM,BLACK,SPACE]:plain_uvs(ob,region)
    parts.append(ob);return ob


def decal(name,verts,region):
    return mesh(name,verts,[(0,1,2,3)],region)


# The case is a single hollow skin. No front slab occludes the live display.
case=loft('Rounded tapered cream enclosure',[
    rounded(0,.17,.462,.290,.027,-.169),
    rounded(0,.173,.484,.316,.026,-.135),
    rounded(0,.175,.52,.33,.024,.185),
    rounded(0,.175,.510,.320,.021,.210),
    rounded(-.055,.18,.376,.284,.026,.210),
    rounded(-.055,.18,.369,.277,.024,.188),
],cap_first=True,smooth=True)
# Flat fascia and rear panel normals avoid artificial pinching at the opening.
for poly in case.data.polygons:
    if 72 <= poly.index < 96 or poly.index==len(case.data.polygons)-1:
        poly.use_smooth=False
# Dark molded bezel wraps around a deep opening and leaves a broad cream fascia.
loft('Deep charcoal CRT bezel',[
    rounded(-.055,.18,.371,.279,.027,.192),
    rounded(-.055,.18,.365,.273,.025,.215),
    rounded(-.055,.18,.345,.255,.022,.230),
    rounded(-.055,.18,.310,.235,.017,.229),
    rounded(-.055,.18,.300,.225,.014,.196),
],region=BLACK,smooth=True)
# A recessed annular light baffle hides the sub-millimetre gap between the
# independently tessellated rounded glass and molded bezel. The central opening
# stays empty and the entire baffle sits behind the live screen surface.
loft('Black interior light baffle',[
    rounded(-.055,.18,.369,.277,.024,.182),
    rounded(-.055,.18,.260,.185,.012,.182),
],region=BLACK)
box('Lower case separation seam',(0,.013,.009),(.477,.003,.328),BLACK,.001)
box('Molded bottom pan',(0,.010,-.001),(.479,.012,.321),CREAM,.005)
for x in [-.191,.191]:
    for z in [-.12,.12]:box('Rubber desk foot',(x,.003,z),(.041,.006,.040),BLACK,.002)
decal('Original institutional model badge',[(.150,.065,.211),(.232,.065,.211),(.232,.099,.211),(.150,.099,.211)],(514,2,766,126))
decal('Serialized inspection plate',[(.169,.104,.2111),(.226,.104,.2111),(.226,.117,.2111),(.169,.117,.2111)],(514,130,766,190))
# Rear vents and plugs are placed on an actual surface and share the same atlas.
decal('Rear molded ventilation grille',[(.20,.250,-.170),(-.20,.250,-.170),(-.20,.296,-.170),(.20,.296,-.170)],(2,258,510,382))
decal('Rear input and output panel',[(.19,.045,-.170),(-.19,.045,-.170),(-.19,.144,-.170),(.19,.144,-.170)],(514,258,1022,382))
decal('Rear facilities inventory strip',[(.17,.157,-.170),(-.17,.157,-.170),(-.17,.19,-.170),(.17,.19,-.170)],(514,386,1022,446))
# Side slots follow the enclosure's taper, avoiding floating plaques.
for side in [-1,1]:
    rear_x=side*.2451;front_x=side*.2529
    verts=[(rear_x,.206,-.089),(front_x,.205,.05),(front_x,.257,.05),(rear_x,.258,-.089)]
    if side<0:verts.reverse()
    decal('Side cooling slots',verts,(2,258,510,382))


def join_objects(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();ob=bpy.context.object;ob.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    # Weighted corner normals preserve broad molded panels while rounding edges.
    mod=ob.modifiers.new('Weighted plastic corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tri=ob.modifiers.new('Explicit efficient triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    return ob


monitor=join_objects(parts,'VT100_MoldedHousing')
parts=[]
# Rectangular UVs remain stable while the glass bows out toward the player.
vertices=[];uvs=[];nx=16;ny=12
for iy in range(ny+1):
    v=iy/ny;h=(v-.5)*.225
    excess=max(0,abs(h)-(.225*.5-.014))
    half=.15-.014+math.sqrt(max(0,.014**2-excess**2))
    for ix in range(nx+1):
        u=ix/nx;x=(u*2-1)*half
        bulge=.014*(1-(x/.15)**2)*(1-(h/.1125)**2)
        vertices.append((x-.055,h+.18,.204+bulge));uvs.append((u,v))
faces=[]
for iy in range(ny):
    for ix in range(nx):
        a=iy*(nx+1)+ix;faces.append((a,a+1,a+nx+2,a+nx+1))
screen=mesh('CRTScreen',vertices,faces,BLACK,True)
screen.data.materials.clear()
glass=bpy.data.materials.new('CRTScreen | replace with live CRT shader in game');glass.use_nodes=True
g=glass.node_tree.nodes.get('Principled BSDF')
g.inputs['Base Color'].default_value=(.008,.024,.021,1);g.inputs['Roughness'].default_value=.23
g.inputs['Metallic'].default_value=.05
screen.data.materials.append(glass)
for p in screen.data.polygons:
    for li in p.loop_indices:screen.data.uv_layers.active.data[li].uv=uvs[screen.data.loops[li].vertex_index]
screen['terminal_screen']=True
screen['screen_center_godot']=[-.055,.18,.211]
screen['screen_size_m']=[.30,.225]
screen['front_axis']='+Z'
tri=screen.modifiers.new('Glass game triangles','TRIANGULATE');bpy.context.view_layer.objects.active=screen
bpy.ops.object.modifier_apply(modifier=tri.name)


def export(objects,path):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                             export_yup=True,export_tangents=True,export_extras=True)


export([monitor,screen],OUT/'vt100_monitor.glb')
monitor.hide_set(True);screen.hide_set(True)
monitor.hide_render=True;screen.hide_render=True
parts=[]

# Low wedge keyboard: top slopes toward the operator (+Z).
def top(z):return .025-.08*z


outline=[(-.25,-.103),(.25,-.103),(.26,-.091),(.26,.087),(.251,.107),(-.251,.107),(-.26,.087),(-.26,-.091)]
vs=[(x,.005,z) for x,z in outline]+[(x,top(z)-.003,z) for x,z in outline]
faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
mesh('Rounded wedge keyboard casing',vs,faces,CREAM)
outline2=[(x*.985,z*.975) for x,z in outline]
vs=[(x,.001,z) for x,z in outline2]+[(x,.005,z) for x,z in outline2]
mesh('Keyboard lower shadow seam',vs,faces,BLACK)
decal('Dark recessed keyboard tray',[(-.245,top(.083),.083),(.245,top(.083),.083),(.245,top(-.085),-.085),(-.245,top(-.085),-.085)],BLACK)


def key(label,index,x,z,w=.021,d=.022,cream=False):
    y=top(z)+.001
    # Three rings give a sloped, sculpted keycap, at 20 triangles per key.
    rings=[]
    for ww,dd,hh in [(w,d,0),(w*.82,d*.84,.009),(w*.77,d*.78,.0105)]:
        rings += [(x-ww/2,y+hh-.08*(-dd/2),z-dd/2),(x+ww/2,y+hh-.08*(-dd/2),z-dd/2),
                  (x+ww/2,y+hh-.08*(dd/2),z+dd/2),(x-ww/2,y+hh-.08*(dd/2),z+dd/2)]
    fs=[]
    for j in range(2):
        for i in range(4):fs.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
    fs.append((8,11,10,9))
    ob=mesh('Keycap '+label,rings,fs,SPACE if cream else BLACK)
    if not cream:
        rect=uv_rect(((index%16)*64+2,512+(index//16)*64+2,(index%16)*64+62,512+(index//16)*64+62))
        # Top order goes front-left, front-right, rear-right, rear-left in texture.
        poly=ob.data.polygons[-1]
        for j,li in enumerate(poly.loop_indices):ob.data.uv_layers.active.data[li].uv=rect[(j+3)%4]


index=0
for ri,row in enumerate(ROWS):
    z=-.052+ri*.030
    x=-.222+ri*.003
    for ki,label in enumerate(row):
        width=.022
        if label in ['TAB','CTRL','SHIFT']:width=.030
        if label in ['RETURN','BACK']:width=.031
        key(label,index,x+width/2,z,width)
        x+=width+.002
        index+=1
# Separate keypad at right uses the same keycap atlas and one mesh surface.
for i,label in enumerate(EXTRA):
    if i<3:
        x=-.22+i*.032;z=-.081
        key(label,index,x,z,.026,.017)
    else:
        ni=i-3;x=.145+(ni%4)*.026;z=-.057+(ni//4)*.028
        key(label,index,x,z,.021,.022)
    index+=1
key('Cream space bar',0,-.05,.074,.180,.020,True)
decal('Keyboard lock indicator legend',[(-.09,top(-.073)+.0004,-.073),(.098,top(-.073)+.0004,-.073),(.098,top(-.086)+.0004,-.086),(-.09,top(-.086)+.0004,-.086)],(2,386,510,446))
keyboard=join_objects(parts,'VT100_MatchingKeyboard')
export([keyboard],OUT/'vt100_keyboard.glb')

monitor.hide_set(False);screen.hide_set(False)
monitor.hide_render=False;screen.hide_render=False
# Studio previews pair the separate assets without changing exported transforms.
keyboard.location.y=-.355
stats={
    'monitor':{'triangles':len(monitor.data.polygons)+len(screen.data.polygons),'meshes':2,'materials':2,
               'housing_triangles':len(monitor.data.polygons),'screen_triangles':len(screen.data.polygons),
               'dimensions_godot_m':[round(monitor.dimensions.x,4),round(monitor.dimensions.z,4),round(monitor.dimensions.y,4)],
               'screen_node':'CRTScreen','screen_center_godot_m':[-.055,.18,.211],
               'screen_dimensions_m':[.30,.225],'screen_z_range_m':[.204,.218],'bezel_max_z_m':.230,
               'screen_uv':'Exported glTF: U left-to-right, V top-to-bottom; rectangular 0–1 UVs'},
    'keyboard':{'triangles':len(keyboard.data.polygons),'meshes':1,'materials':1,'keycaps':len(LEGENDS)+1,
                'dimensions_godot_m':[round(keyboard.dimensions.x,4),round(keyboard.dimensions.z,4),round(keyboard.dimensions.y,4)]},
    'shared_texture_resolution':1024,'front_axis':'+Z','origin':'Tabletop floor at y=0; centered horizontally',
}
assert stats['monitor']['triangles']<=2500,stats
assert stats['keyboard']['triangles']<=4000,stats
(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
(OUT/'README.md').write_text('''# VT100-style terminal and keyboard

Original low-poly Blender meshes modeled after the supplied vintage terminal reference.
The cream enclosure is hollow at the front. Its deep offset black bezel leaves a wide
right fascia with an original fictional facility badge. Rear ports, ventilation,
plastic grain, inspection markings and key legends use one shared 1024px atlas.
Plain plastic faces use consistent physical UV density and padded atlas regions
to prevent texture bleeding on thin bevels in Godot's mipmapped renderer.

`vt100_monitor.glb` contains `VT100_MoldedHousing` and the separate `CRTScreen`.
The screen is a smooth convex 16×12 grid with ordinary 0–1 UVs. Exported glTF UVs
run U left-to-right and V top-to-bottom (Blender flips V during glTF export).
Replace its material
with the game's live CRT shader; do not place an opaque housing box in the opening.
Front is Godot +Z. Origin is the bottom of the monitor on its tabletop, y=0.
Screen center: (-0.055, 0.18, 0.211); visible size: 0.30 × 0.225 m.
Glass front z=0.218, bezel lip z=0.230. Place in-game readout at z≈0.220.

`vt100_keyboard.glb` is a separate matching wedge keyboard. Origin is its tabletop
floor, +Z toward the operator, width 0.52m, depth 0.21m. No letters are mesh geometry.
The preview places this keyboard forward of the monitor; GLB transforms stay at origin.

Rebuild: `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_vt100.py`
Source atlas and editable scene: `art/vt100/`. Exact counts: `mesh_stats.json`.
''')
(ART/'.gdignore').write_text('')

# Keep the modeling meshes editable and pack the atlas before rendering.
sys.path.insert(0,str(HERE))
from prop_bake import studio
bpy.context.scene.render.engine='CYCLES'
studio(monitor,ART,'vt100',target=(0,-.105,.17),camera_at=(.75,-1.1,.68),scale=.81,light_scale=.6)
print('VT100_STATS',json.dumps(stats),flush=True)
