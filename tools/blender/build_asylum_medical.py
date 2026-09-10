"""Author the photographed wooden ECT case and rolling restraint gurney.

Blender --background --factory-startup --python tools/blender/build_asylum_medical.py
Optional: -- --filter=ect or --filter=restraint. All modeling coordinates are
Godot (X, Y height, Z forward), metres. Source textures and editable packed
Blender scenes remain in art/asylum_medical; only the selected prop is exported.
"""
from pathlib import Path
import math
import json
import sys
import os

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/asylum_medical'
OUT=ROOT/'models/authored/asylum_medical'


def draw_art():
    """Original instrument graphics and localized upholstery distress, not photos."""
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    import random
    rng=random.Random(7364)
    ART.mkdir(parents=True,exist_ok=True)
    for folder in ('ect','restraint'):(ART/folder).mkdir(exist_ok=True)
    fontpath='/System/Library/Fonts/Helvetica.ttc'
    def font(size):return ImageFont.truetype(fontpath,size)
    im=Image.new('RGB',(1024,800),(24,27,24));d=ImageDraw.Draw(im)
    for _ in range(10000):
        x=rng.randrange(1024);y=rng.randrange(800);q=rng.randrange(18,43)
        d.point((x,y),fill=(q,q+1,q-1))
    cream=(225,220,192);faint=(147,145,125)
    d.rounded_rectangle((12,12,1011,787),18,outline=faint,width=3)
    def text(x,y,s,size=24,c=cream):d.text((x,y),s,font=font(size),fill=c,anchor='mm')
    text(235,56,'E.C.T. UNIT',32);text(781,56,'MODEL R-135',25)
    d.rectangle((332,100,772,143),fill=(139,44,27))
    text(552,121,'ST. AUDREY’S HOSPITAL',24)
    def scale(cx,cy,r,label,nums):
        for j in range(29):
            a=math.radians(140+j*9.3);rad=r-(14 if j%4==0 else 7)
            d.line((cx+rad*math.cos(a),cy+rad*math.sin(a),cx+r*math.cos(a),cy+r*math.sin(a)),fill=cream,width=3 if j%4==0 else 2)
        for j,n in enumerate(nums):
            a=math.radians(140+j*37.2);text(cx+(r+24)*math.cos(a),cy+(r+24)*math.sin(a),str(n),18)
        text(cx,cy+r+46,label,23)
    scale(223,327,104,'VOLTS',[70,80,90,100,110,120,130,140])
    scale(539,294,72,'TIME — SECS',[0,1,2,3,4,5,6,7])
    scale(775,602,74,'CURRENT',[0,2,4,6,8,10,12,14])
    text(240,564,'SAFETY / TREAT',25);text(540,554,'PILOT',22)
    text(239,710,'OFF',22);text(238,755,'ISOLATE BEFORE SERVICING',15)
    text(535,742,'SERIAL 2487     •     1956',17)
    # Gauge face is part of this texture, protected by a modeled rolled bezel.
    cx,cy,r=802,301,136
    d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=(221,213,184),outline=(115,111,95),width=5)
    for j in range(37):
        a=math.radians(203+j*3.72);rr=r-22
        d.line((cx+(rr-(13 if j%6==0 else 6))*math.cos(a),cy+25+(rr-(13 if j%6==0 else 6))*math.sin(a),cx+rr*math.cos(a),cy+25+rr*math.sin(a)),fill=(39,44,39),width=3 if j%6==0 else 2)
    for j in range(7):
        a=math.radians(203+j*22.3);text(cx+76*math.cos(a),cy+25+76*math.sin(a),str(j*20),16,(35,39,34))
    d.line((cx,cy+50,cx-62,cy-58),fill=(45,38,34),width=5)
    d.ellipse((cx-8,cy+42,cx+8,cy+58),fill=(54,49,41))
    text(cx,cy+92,'MILLIAMPERES',16,(53,54,42))
    # Sparse hairline finish scratches are baked into the original art.
    for _ in range(70):
        x=rng.randrange(20,1000);y=rng.randrange(20,780)
        d.line((x,y,x+rng.randrange(3,35),y+rng.randrange(-2,3)),fill=(66,65,54),width=1)
    im.save(ART/'ect/instrument_panel.png')
    # Projected upholstery map. Most of the cushion remains pale, with old
    # localized rusty stains and abrasion around the actual restraint positions.
    im=Image.new('RGB',(1024,2048),(190,188,169));d=ImageDraw.Draw(im)
    for y in range(0,2048,3):d.line((0,y,1024,y),fill=(183+(y%5),182+(y%4),166),width=1)
    for x in range(0,1024,3):d.line((x,0,x,2048),fill=(190,189,173),width=1)
    grime=Image.new('RGBA',im.size);g=ImageDraw.Draw(grime)
    for cx,cy in [(270,320),(750,340),(155,1030),(863,1020),(360,1640),(675,1690)]:
        for _ in range(175):
            x=rng.gauss(cx,40);y=rng.gauss(cy,34);rx=rng.uniform(1,15);ry=rng.uniform(1,7)
            poly=[]
            for k in range(7):
                a=math.tau*k/7;f=rng.uniform(.3,1.25);poly.append((x+rx*f*math.cos(a),y+ry*f*math.sin(a)))
            g.polygon(poly,fill=(60+rng.randrange(30),17+rng.randrange(19),10+rng.randrange(16),rng.randrange(60,215)))
        for _ in range(65):
            x=rng.gauss(cx,38);y=rng.gauss(cy,25)
            length=rng.randrange(25,135)
            g.line((x,y,x+length,y+rng.randrange(-12,12)),fill=(83,22,14,rng.randrange(60,195)),width=rng.randrange(1,4))
        for _ in range(220):
            x=rng.gauss(cx,63);y=rng.gauss(cy,52)
            g.line((x,y,x+1,y+2),fill=(64,26,16,rng.randrange(70,180)),width=1)
    im=Image.alpha_composite(im.convert('RGBA'),grime.filter(ImageFilter.GaussianBlur(.8)))
    d=ImageDraw.Draw(im)
    for _ in range(650):
        x=rng.randrange(1024);y=rng.randrange(2048)
        d.line((x,y,x+rng.randrange(1,5),y+rng.randrange(3,19)),fill=(128,125,109,120),width=1)
    im.convert('RGB').save(ART/'restraint/upholstery_distress.png')


if '--draw-art' in sys.argv:
    draw_art();sys.exit(0)

import subprocess
import bpy
import bmesh
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prop_bake import material,bake_export,studio

ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
(ART/'.gdignore').write_text('')
bpy.context.preferences.filepaths.save_version=0
subprocess.run(['/opt/homebrew/bin/python3',str(Path(__file__).resolve()),'--draw-art'],check=True,
               env={k:v for k,v in os.environ.items() if k not in ('PYTHONPATH','PYTHONHOME')})
parts=[]


def xyz(p):return (p[0],-p[2],p[1])


def reset():
    global parts
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    parts=[]


def mesh(name,vs,fs,mat,smooth=False):
    data=bpy.data.meshes.new(name);data.from_pydata([xyz(v) for v in vs],[],fs);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob);data.materials.append(mat)
    for p in data.polygons:p.use_smooth=smooth
    parts.append(ob);return ob


def box(name,p,size,mat,bevel=0,segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));ob=bpy.context.object;ob.name=name
    ob.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        # Never let opposite bevels meet at the middle of a thin shelf. Blender's
        # overlap clamp otherwise creates collapsed corner triangles on export.
        mod=ob.modifiers.new('Manufactured edge radii','BEVEL');mod.width=min(bevel,min(size)*.45);mod.segments=segments
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat);parts.append(ob);return ob


def tube(name,points,radius,mat,sides=8,caps=True):
    vs=[];fs=[];previous=None
    for i,p in enumerate(points):
        t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        if previous is None:
            guide=Vector((0,1,0)) if abs(t.y)<.9 else Vector((0,0,1));u=t.cross(guide).normalized()
        else:u=(previous-t*previous.dot(t)).normalized()
        v=t.cross(u).normalized();previous=u
        for j in range(sides):
            a=math.tau*j/sides;vs.append(Vector(p)+radius*(u*math.cos(a)+v*math.sin(a)))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;fs.append((a,b,b+sides,a+sides))
    if caps:fs +=[tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    return mesh(name,vs,fs,mat,True)


def rod(name,a,b,r,mat,sides=8):return tube(name,[a,b],r,mat,sides)


def smooth_path(points,subdivisions=3):
    keys=[Vector(p) for p in points];out=[]
    for i in range(len(keys)-1):
        a=keys[max(0,i-1)];b=keys[i];c=keys[i+1];d=keys[min(len(keys)-1,i+2)]
        for j in range(subdivisions):
            t=j/subdivisions
            out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return out+[keys[-1]]


def ring(name,p,radius,thick,mat,normal=(0,1,0),segments=12,sides=5):
    n=Vector(normal).normalized();guide=Vector((1,0,0)) if abs(n.x)<.9 else Vector((0,0,1))
    u=n.cross(guide).normalized();v=n.cross(u).normalized()
    points=[Vector(p)+radius*(u*math.cos(math.tau*i/segments)+v*math.sin(math.tau*i/segments)) for i in range(segments+1)]
    return tube(name,points,thick,mat,sides,False)


def beam(name,a,b,width,depth,mat):
    a=Vector(a);b=Vector(b);ob=box(name,(a+b)/2,(width,(b-a).length,depth),mat,.003)
    ob.rotation_euler=(Vector(xyz(b))-Vector(xyz(a))).to_track_quat('Z','Y').to_euler();return ob


def material_set():
    return dict(steel=material('Oxidized clinical steel',(.22,.25,.25),.47,.78,.17,.0004),
                trim=material('Polished handled metal',(.52,.54,.51),.28,.88,.06),
                dark=material('Black baked enamel frame',(.025,.033,.031),.54,.48,.15,.0004),
                rubber=material('Aged charcoal rubber',(.019,.024,.022),.84,0,.12,.0005),
                leather=material('Old oxblood leather restraints',(.029,.010,.005),.49,0,.35,.001),
                stitch=material('Worn leather piping',(.15,.09,.04),.73,0,.16),
                cloth=material('Electrode woven fabric',(.69,.66,.51),.94,0,.10,.0006))


def wood_material():
    mat=material('Worn walnut case — continuous elongated grain',(.22,.106,.033),.58,0,.15,.0006)
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');geo=nt.nodes.new('ShaderNodeNewGeometry')
    mapping=nt.nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(2,75,92)
    nt.links.new(geo.outputs['Position'],mapping.inputs[0])
    noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=4.2;noise.inputs['Detail'].default_value=3.5;noise.inputs['Roughness'].default_value=.78
    nt.links.new(mapping.outputs[0],noise.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(.012,.008,.004,1)
    ramp.color_ramp.elements[1].position=.75;ramp.color_ramp.elements[1].color=(.22,.102,.032,1)
    mid=ramp.color_ramp.elements.new(.50);mid.color=(.080,.038,.012,1)
    nt.links.new(noise.outputs['Fac'],ramp.inputs[0])
    age=nt.nodes.new('ShaderNodeTexNoise');age.inputs['Scale'].default_value=19;age.inputs['Detail'].default_value=5;age.inputs['Roughness'].default_value=.85
    nt.links.new(geo.outputs['Position'],age.inputs['Vector'])
    age_ramp=nt.nodes.new('ShaderNodeValToRGB');age_ramp.color_ramp.elements[0].position=.3;age_ramp.color_ramp.elements[0].color=(.10,.09,.06,1)
    age_ramp.color_ramp.elements[1].position=.69;age_ramp.color_ramp.elements[1].color=(1,.89,.73,1)
    nt.links.new(age.outputs[0],age_ramp.inputs[0])
    mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.70
    nt.links.new(ramp.outputs[0],mix.inputs[1]);nt.links.new(age_ramp.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.24;bump.inputs['Distance'].default_value=.001
    nt.links.new(noise.outputs[0],bump.inputs['Height']);nt.links.new(bump.outputs[0],bs.inputs['Normal'])
    return mat


def caster(x,z,r,m,large=False):
    y=r;thick=r*.50;fx=x+.008;fz=z+.012
    # Crown profile, sidewalls and axle give the wheels a readable manufactured shape.
    rod('Rubber caster tire',(fx-thick/2,y,fz),(fx+thick/2,y,fz),r,m['rubber'],12)
    for s in [-1,1]:
        rod('Wheel hub',(fx+s*(thick/2+.001),y,fz),(fx+s*(thick/2+.006),y,fz),r*.57,m['steel'],10)
        side=[(fx+s*(thick/2+.009),y-.013,fz-.018),(fx+s*(thick/2+.009),y+.009,fz+.03),
              (fx+s*(thick/2+.009),y+r+.015,fz+.024),(fx+s*(thick/2+.009),y+r+.015,fz-.029)]
        ob=mesh('Swivel caster fork plate',side,[(0,1,2,3)],m['steel']);mod=ob.modifiers.new('Fork thickness','SOLIDIFY');mod.thickness=.006;bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
        rod('Axle nut',(fx+s*(thick/2+.009),y,fz),(fx+s*(thick/2+.014),y,fz),.009 if large else .006,m['trim'],6)
    rod('Swivel bearing',(fx,2*r+.008,z),(fx,2*r+.034,z),r*.48,m['steel'],10)
    rod('Swivel pin',(fx,2*r+.029,z),(fx,2*r+.08,z),r*.20,m['trim'],8)


def extrude_profile(name,profile,xmin,xmax,mat):
    n=len(profile);vs=[(x,y,z) for x in (xmin,xmax) for y,z in profile]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,mat)


def measured_bounds(prop):
    points=[prop.matrix_world@v.co for v in prop.data.vertices]
    pts=[(p.x,p.z,-p.y) for p in points]
    return {'min':[min(p[a] for p in pts) for a in range(3)],
            'max':[max(p[a] for p in pts) for a in range(3)]}


def validate_mesh(prop):
    assert prop.data.uv_layers, 'Runtime prop requires UVs'
    assert all(len(face.vertices)==3 and face.area>1e-12 for face in prop.data.polygons), 'Collapsed or untriangulated face'
    assert all(math.isfinite(c) for v in prop.data.vertices for c in v.co), 'Non-finite vertex'


def ect():
    reset();m=material_set();wood=wood_material();bakelite=material('Worn ribbed Bakelite controls',(.018,.021,.017),.4,0,.1,.0003)
    # Slim clinical trolley remains clear under the characteristic portable case.
    for y in [.295,.672]:
        box('Pressed trolley shelf',(0,y,0),(.596,.022,.49),m['steel'],.012,2)
        for sx in [-1,1]:box('Shelf upstand',(sx*.29,y+.018,0),(.012,.038,.465),m['steel'],.003)
        box('Shelf rear upstand',(0,y+.018,-.24),(.58,.038,.01),m['steel'],.003)
    for x in [-.257,.257]:
        for z in [-.192,.192]:
            rod('Tubular trolley upright',(x,.126,z),(x,.692,z),.012,m['trim'],8);caster(x,z,.045,m)
    # Closed wood bottom, trapezoidal side panels and a lower front lip expose the fascia.
    for x in [-.22,.22]:
        for z in [-.115,.115]:box('Portable case rubber foot',(x,.687,z),(.035,.009,.028),m['rubber'])
    box('Case bottom',(0,.709,0),(.54,.039,.34),wood,.008,2)
    for s in [-1,1]:extrude_profile('Sloping walnut case side',[(.705,-.17),(.903,-.17),(.835,.17),(.705,.17)],s*.27-.010,s*.27+.010,wood)
    box('Walnut front board',(0,.776,.166),(.54,.137,.018),wood,.004)
    box('Walnut rear board',(0,.809,-.166),(.54,.191,.018),wood,.004)
    for x in [-.185,.185]:
        extrude_profile('Instrument side divider',[(.73,-.15),(.896,-.15),(.829,.148),(.73,.148)],x-.006,x+.006,wood)
    # Open lid is a continuous tilted wooden board with a raised picture-frame rim.
    up=Vector((0,math.cos(math.radians(15)),-math.sin(math.radians(15))))
    normal=Vector((0,math.sin(math.radians(15)),math.cos(math.radians(15))))
    hinge=Vector((0,.902,-.163))
    def lid_slab(name,cx,t,w,h,depth,offset=0):
        c=hinge+up*t+normal*offset+Vector((cx,0,0));vs=[]
        for k in [-1,1]:
            for u,v in [(-1,-1),(1,-1),(1,1),(-1,1)]:vs.append(c+Vector((u*w/2,0,0))+up*v*h/2+normal*k*depth/2)
        return mesh(name,vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],wood)
    lid_slab('Recessed grain-bearing walnut lid',0,.148,.536,.298,.014)
    for x in [-.257,.257]:lid_slab('Lid edge moulding',x,.148,.024,.298,.014,.010)
    for t in [.010,.287]:lid_slab('Lid cross moulding',0,t,.518,.021,.014,.010)
    for x in [-.183,.183]:
        box('Nickel case hinge plate',(x,.905,-.151),(.074,.007,.027),m['trim'],.002)
        rod('Case hinge barrel',(x-.04,.907,-.17),(x+.04,.907,-.17),.009,m['trim'],8)
    box('Front latch upper',(0,.843,.18),(.045,.038,.012),m['trim'],.004)
    box('Front latch tongue',(0,.808,.183),(.037,.047,.009),m['trim'],.003)
    box('Carry handle mounting left',(-.065,.756,.18),(.025,.02,.014),m['trim'],.003)
    box('Carry handle mounting right',(.065,.756,.18),(.025,.02,.014),m['trim'],.003)
    tube('Folding leather carry handle',[(-.065,.756,.186),(-.058,.729,.198),(.058,.729,.198),(.065,.756,.186)],.009,m['leather'],6)
    # Painted hardboard inset (dedicated 1024x800 map avoids tiny unreadable labels in the main atlas).
    def panel_y(z):return .861-.23*z
    backing=extrude_profile('Sloped instrument fascia',[(panel_y(-.144)-.008,-.144),(panel_y(-.144),-.144),(panel_y(.145),.145),(panel_y(.145)-.008,.145)],-.179,.179,bakelite)
    panelmat=material('ECT instrument artwork — original cream silk-screen',(.1,.1,.1),.42,.15,0)
    nt=panelmat.node_tree;tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ART/'ect/instrument_panel.png'));tex.image.pack();nt.links.new(tex.outputs['Color'],nt.nodes['Principled BSDF'].inputs['Base Color'])
    fascia=mesh('Original legible instrument markings',[(-.177,panel_y(.143)+.001,.143),(.177,panel_y(.143)+.001,.143),(.177,panel_y(-.142)+.001,-.142),(-.177,panel_y(-.142)+.001,-.142)],[(0,1,2,3)],panelmat)
    # The panel gets its own per-face coordinates in the same UV stream as the
    # baked body. Godot's glTF material import does not reliably select UV2 for
    # base colour, even though Blender previews TEXCOORD_1 correctly.
    uv=fascia.data.uv_layers.new(name='UVMap');coords=[(0,0),(1,0),(1,1),(0,1)]
    for loop in fascia.data.loops:uv.data[loop.index].uv=coords[loop.vertex_index]
    parts.remove(fascia)
    def art_pos(px,py):
        x=(px/1024-.5)*.354;z=(py/800-.5)*.285
        return Vector((x,panel_y(z)+.004,z))
    panel_normal=Vector((0,1,.23)).normalized()
    for px,py,r in [(223,327,.028),(539,294,.022),(240,637,.023),(775,602,.024)]:
        c=art_pos(px,py);rod('Bakelite knob collar',c,c+panel_normal*.010,r*1.06,bakelite,12)
        rod('Bakelite fluted rotary control',c+panel_normal*.010,c+panel_normal*.030,r*.83,bakelite,10)
        # A wide raised pointer grip is characteristic of these early control knobs.
        grip=box('Raised pointer grip',c+panel_normal*.032,(r*.38,.014,r*1.65),bakelite,.003)
        grip.rotation_euler.x=math.atan(.23)
        rod('Cream dial pointer',c+panel_normal*.040+Vector((0,0,-r*.42)),c+panel_normal*.040+Vector((0,0,-r*.67)),.0018,m['cloth'],5)
    gauge=art_pos(802,301);ring('Rolled analog gauge bezel',gauge,.049,.0047,m['trim'],normal=panel_normal,segments=20,sides=6)
    for px,py in [(36,35),(988,35),(35,762),(988,762),(518,37)]:
        c=art_pos(px,py);rod('Slotted fascia screw',c,c+panel_normal*.002,.004,m['trim'],8)
    c=art_pos(539,627);rod('Pilot button chrome collar',c,c+panel_normal*.008,.014,m['trim'],12);rod('Pilot button',c+panel_normal*.008,c+panel_normal*.014,.009,m['cloth'],10)
    for s in [-1,1]:
        # A few fat rubber turns remain neatly stowed in each exposed side compartment.
        points=[]
        for i in range(35):
            a=i*math.tau/11;points.append((s*(.221+.027*math.cos(a)),.765+i*.0015,.015+.09*math.sin(a)))
        tube('Coiled rubber lead inside carrying case',points,.0058,m['rubber'],6)
    # Hanging leads and the two unmistakable round cloth electrode pads below.
    for s in [-1,1]:
        points=[(s*.232,.852,.035),(s*.274,.84,.10),(s*.294,.72,.16),(s*.284,.49,.23),
                (s*.215,.38,.232),(s*.12,.345,.20),(s*.060,.35,.105),(s*.092,.367,-.01)]
        tube('Heavy rubber electrode lead',smooth_path(points),.0055,m['rubber'],6)
        a=Vector((s*.105,.343,-.055));b=Vector((s*.15,.343,.09))
        rod('Cylindrical Bakelite electrode grip',a,b,.019,bakelite,10)
        tip=b+(b-a).normalized()*.018;rod('Electrode insulating disc',b,tip,.037,bakelite,12)
        rod('Cream woven circular electrode pad',tip,tip+(b-a).normalized()*.010,.032,m['cloth'],12)
    # Physical base bottom is exactly floor-height; no separate collision geometry exports.
    art=ART/'ect';out=OUT/'ect_machine.glb'
    prop,stats=bake_export(parts,'Asylum ECT wooden case and trolley',art,out,6000,metadata={'front_axis':'+Z','origin':'floor centre','label_surface':'original 1024x800 instrument panel'})
    bpy.ops.object.select_all(action='DESELECT');prop.select_set(True);fascia.select_set(True);bpy.context.view_layer.objects.active=prop;bpy.ops.object.join()
    mod=prop.modifiers.new('Triangulate original instrument plate','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    # Joining same-named UV layers preserves each face's coordinates, so the
    # atlas and full-frame panel art both export as TEXCOORD_0 on their surfaces.
    for mat in prop.data.materials:
        nt=mat.node_tree
        for texnode in [n for n in nt.nodes if n.type=='TEX_IMAGE']:
            uvnode=nt.nodes.new('ShaderNodeUVMap');uvnode.uv_map='UVMap';nt.links.new(uvnode.outputs['UV'],texnode.inputs['Vector'])
    stats['triangles']=len(prop.data.polygons);stats['materials']=len(prop.data.materials);stats['label_texture_resolution']=[1024,800]
    stats['bounds_godot_m']=measured_bounds(prop)
    assert stats['triangles']<=6000
    prop['triangles']=stats['triangles']
    validate_mesh(prop)
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_extras=True)
    studio(prop,art,'ect_machine',target=(0,0,.62),camera_at=(1.25,-1.75,1.45),scale=1.55)
    return stats


def restraint():
    reset();m=material_set()
    cloth=material('Distressed restraint mattress fabric',(.70,.68,.58),.83,0,.06,.0007)
    nt=cloth.node_tree;tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ART/'restraint/upholstery_distress.png'));tex.image.pack()
    geo=nt.nodes.new('ShaderNodeNewGeometry');separate=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(geo.outputs['Position'],separate.inputs[0])
    x=nt.nodes.new('ShaderNodeMath');x.operation='MULTIPLY_ADD';x.inputs[1].default_value=1/.76;x.inputs[2].default_value=.5;nt.links.new(separate.outputs['X'],x.inputs[0])
    y=nt.nodes.new('ShaderNodeMath');y.operation='MULTIPLY_ADD';y.inputs[1].default_value=1/1.86;y.inputs[2].default_value=.5;nt.links.new(separate.outputs['Y'],y.inputs[0])
    uv=nt.nodes.new('ShaderNodeCombineXYZ');nt.links.new(x.outputs[0],uv.inputs['X']);nt.links.new(y.outputs[0],uv.inputs['Y']);nt.links.new(uv.outputs[0],tex.inputs['Vector']);nt.links.new(tex.outputs[0],nt.nodes['Principled BSDF'].inputs['Base Color'])
    # Distinct rounded upholstery is supported by a thin perimeter rail, not a slab pedestal.
    mattress=box('Rounded thick upholstered restraint mattress',(0,.813,0),(.77,.124,1.88),cloth,.042,3)
    for face in mattress.data.polygons:face.use_smooth=True
    weighted=mattress.modifiers.new('Broad flat cushion with soft rounded seams','WEIGHTED_NORMAL');weighted.weight=50;weighted.keep_sharp=True
    bpy.context.view_layer.objects.active=mattress;bpy.ops.object.modifier_apply(modifier=weighted.name)
    box('Mattress lower pan',(0,.729,0),(.806,.039,1.956),m['dark'],.024,2)
    for x in [-.416,.416]:rod('Tubular bed side rail',(x,.735,-.927),(x,.735,.927),.018,m['dark'],8)
    for z in [-.951,.951]:rod('Tubular bed end rail',(-.391,.735,z),(.391,.735,z),.020,m['dark'],8)
    # Continuous stitch welt around the cushion's perimeter uses only 160 triangles.
    outline=[]
    for cx,cz,start in [(.335,.89,0),(-.335,.89,90),(-.335,-.89,180),(.335,-.89,270)]:
        for j in range(4):
            a=math.radians(start+j*30);outline.append((cx+.045*math.cos(a),.814,cz+.045*math.sin(a)))
    outline.append(outline[0]);tube('Worn stitched mattress edge welt',outline,.0034,m['cloth'],5,False)
    # Rolling lower chassis with scissor links, pivots, hydraulic ram and foot pedal.
    for x in [-.326,.326]:
        box('Lower longitudinal chassis rail',(x,.232,0),(.038,.06,1.62),m['dark'],.006)
        for z in [-.79,.79]:caster(x,z,.069,m,True)
    for z in [-.74,.74]:box('Caster crossmember',(0,.225,z),(.76,.049,.048),m['dark'],.006)
    box('Lower hydraulic equipment tray',(0,.262,0),(.54,.023,1.26),m['dark'],.017)
    for x in [-.256,.256]:
        box('Upper scissor mounting runner',(x,.709,0),(.032,.032,1.28),m['dark'],.003)
        beam('Scissor lift forged link',(x,.282,-.60),(x,.685,.59),.035,.035,m['steel'])
        beam('Crossed scissor lift link',(x,.282,.60),(x,.685,-.59),.035,.035,m['dark'])
        for y,z in [(.282,-.60),(.282,.60),(.484,0),(.685,-.59),(.685,.59)]:
            rod('Scissor pivot rivet',(x-.022,y,z),(x+.022,y,z),.021,m['trim'],8)
    rod('Hydraulic cylinder outer',(0,.28,-.36),(0,.48,.12),.048,m['steel'],10)
    rod('Hydraulic polished piston',(0,.44,.02),(0,.677,.40),.023,m['trim'],8)
    tube('Hydraulic control foot pedal',[(-.10,.28,.42),(-.19,.20,.69),(-.29,.18,.80)],.013,m['steel'],8)
    box('Rubber foot pedal',(-.29,.184,.81),(.18,.021,.08),m['rubber'],.008)
    # Three broad leather straps wrap the complete rounded cushion profile.
    for z in [-.58,.01,.58]:
        cross=[(-.418,.728),(-.402,.782),(-.385,.845),(-.362,.878),(-.325,.883),(.325,.883),(.362,.878),(.385,.845),(.402,.782),(.418,.728)]
        n=len(cross);vs=[(x,y,z+dz) for dz in [-.039,.039] for x,y in cross]
        fs=[(i,i+1,i+1+n,i+n) for i in range(n-1)]
        ob=mesh('Broad leather restraint wrapped over mattress',vs,fs,m['leather']);mod=ob.modifiers.new('Heavy leather thickness','SOLIDIFY');mod.thickness=.006;bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
        # A flat strap tail and metal buckle sit visibly outside the cushion.
        tube('Heavy restraint buckle',[(-.338,.889,z-.043),(-.280,.889,z-.043),(-.280,.889,z+.043),(-.338,.889,z+.043),(-.338,.889,z-.043)],.004,m['trim'],5,False)
        rod('Buckle cross pin',(-.339,.890,z),(-.279,.890,z),.0025,m['trim'],5)
        box('Hanging leather strap tail',(.417,.679,z),(.008,.20,.064),m['leather'],.002)
    # Rolled leather wrist/ankle cuffs: inner opening and thick edges, without torus bloat.
    def cuff(cx,cz,r=.049):
        vs=[];n=16
        for y,rr in [(.884,r),(.934,r),(.934,r-.008),(.884,r-.008)]:
            for i in range(n):
                a=math.tau*i/n;vs.append((cx+rr*math.cos(a),y,cz+rr*math.sin(a)))
        fs=[]
        for k in range(4):
            for i in range(n):fs.append((k*n+i,k*n+(i+1)%n,((k+1)%4)*n+(i+1)%n,((k+1)%4)*n+i))
        mesh('Padded leather restraining cuff',vs,fs,m['leather'],True)
        ring('Rolled cuff edge',(cx,.933,cz),r-.003,.0026,m['stitch'],segments=16,sides=4)
        box('Cuff clasp',(cx+r,.912,cz),(.019,.023,.038),m['trim'],.003)
    for x,z in [(-.28,.01),(.28,.01),(-.115,.68),(.115,.68)]:cuff(x,z,.049 if abs(x)>.2 else .056)
    def chain(points):
        points=[Vector(p) for p in points]
        for j,center in enumerate(points):
            # Elliptical oval links, 8 bend stations x 4-sided metal cross-section.
            u=(points[min(j+1,len(points)-1)]-points[max(j-1,0)]).normalized()
            guide=Vector((1,0,0)) if abs(u.x)<.85 else Vector((0,0,1))
            v=(guide-u*guide.dot(u)).normalized()
            if j%2:v=u.cross(v)
            pts=[center+u*(.023*math.cos(math.tau*k/8))+v*(.014*math.sin(math.tau*k/8)) for k in range(9)]
            tube('Short interlocking steel chain link',pts,.0045,m['dark'],4,False)
    for s in [-1,1]:
        chain([(s*x,y,.013) for x,y in [(.342,.906),(.382,.905),(.416,.886),(.428,.849),(.428,.808),(.426,.767)]])
        chain([(s*.115,y,z) for y,z in [(.907,.753),(.908,.796),(.908,.838),(.907,.880),(.897,.920),(.871,.956),(.831,.969),(.789,.968)]])
    art=ART/'restraint';out=OUT/'restraint_table.glb'
    prop,stats=bake_export(parts,'Asylum rolling restraint table',art,out,6000,metadata={'front_axis':'+Z','origin':'floor centre','mattress_top_m':.875})
    validate_mesh(prop)
    stats['bounds_godot_m']=measured_bounds(prop)
    studio(prop,art,'restraint_table',target=(0,0,.48),camera_at=(1.8,-2.4,2.05),scale=2.45,light_scale=1.5)
    return stats


selected=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--filter=')),'')
stats=json.loads((OUT/'mesh_stats.json').read_text()) if (OUT/'mesh_stats.json').exists() else {}
for name,build in [('ect',ect),('restraint',restraint)]:
    if not selected or name==selected:
        stats[name]=build();(OUT/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
(OUT/'README.md').write_text('''# Asylum medical props

Original low-poly Blender models authored from the supplied visual references.
`ect_machine.glb` is a wooden carrying-case ECT unit on a slim two-shelf trolley,
with a sloped analog fascia, Bakelite controls, rubber leads and cloth electrodes.
`restraint_table.glb` is an upholstered rolling gurney with leather restraints,
short chain runs and a hydraulic scissor undercarriage.

Units are metres, +Y up, +Z front, origin on the floor at the centre. The ECT
instrument face keeps its own original 1024×800 texture for close inspection;
the remaining surfaces share a baked 1K base-colour/normal/ORM atlas per model.
No text, scratches, grain or woven fabric are represented by dense geometry.
Exact measured triangles and bounds are in `mesh_stats.json`.

Editable packed Blender sources and front/reverse previews:
`art/asylum_medical/ect/` and `art/asylum_medical/restraint/`.
Rebuild: Blender --background --factory-startup --python tools/blender/build_asylum_medical.py
Optional `-- --filter=ect` or `-- --filter=restraint` rebuilds only one prop.
''')
print('ASYLUM_MEDICAL_STATS '+json.dumps(stats,sort_keys=True))
