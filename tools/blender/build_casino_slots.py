"""Build four original low-poly casino cabinets in Blender.

Run draw_casino_slot_art.py with Python/Pillow, then:
Blender --background --factory-startup --python tools/blender/build_casino_slots.py
Working coordinates: X, height, depth; exported cabinets face Godot +Z.
Four or five shared surfaces: enamel, metal, guides, displays, printed glass.
"""
from pathlib import Path
import bpy
import bmesh
import math
import json
import sys
import colorsys
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/casino_slots'
OUT = ROOT / 'models/authored/casino_slots'
OUT.mkdir(parents=True, exist_ok=True)
ART.mkdir(parents=True, exist_ok=True)
(ART / '.gdignore').touch()
bpy.context.preferences.filepaths.save_version = 0
REGIONS = {'title': (0,0,1024,512), 'reels': (0,520,1024,1032),
           'pay': (0,1040,1024,1328), 'wheel': (0,1344,640,1984),
           'labels': (648,1344,1024,1544)}
BLACK=(.012,.016,.025); INSET=(.004,.007,.013); STEEL=(.44,.49,.55)
GOLD=(.64,.37,.075); WHITE=(.68,.72,.76)
parts={}; mats={}; current_kind='classic'


def xyz(p): return (p[0],-p[2],p[1])


def register(ob, group='enamel', color=BLACK):
    ob.data.materials.append(mats[group])
    if group not in ['display','printed']:
        attr=ob.data.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
        for value in attr.data: value.color=(*color,1)
    parts[group].append(ob)
    return ob


def mesh(name, vertices, faces, group='enamel', color=BLACK):
    data=bpy.data.meshes.new(name)
    data.from_pydata([xyz(p) for p in vertices],[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob)
    return register(ob,group,color)


def box(name,p,size,group='enamel',color=BLACK,bevel=0,angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p))
    ob=bpy.context.object;ob.name=name
    ob.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Manufactured bevel','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.rotation_euler.x=angle
    return register(ob,group,color)


def profile(name,width,outline,group='enamel',color=BLACK,bevel=.008):
    n=len(outline)
    vertices=[(x,h,d) for x in [-width/2,width/2] for d,h in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh(name,vertices,faces,group,color)
    if bevel:
        bpy.context.view_layer.objects.active=ob
        mod=ob.modifiers.new('Folded edge bevel','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


def tube(name,points,radius,group='metal',color=STEEL,sides=8):
    verts=[]
    for i,p in enumerate(points):
        t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
        up=Vector((1,0,0)) if abs(t.x)<.9 else Vector((0,1,0))
        u=t.cross(up).normalized();v=t.cross(u).normalized()
        for k in range(sides):
            a=math.tau*k/sides;verts.append(Vector(p)+radius*(u*math.cos(a)+v*math.sin(a)))
    faces=[]
    for i in range(len(points)-1):
        for k in range(sides):
            a=i*sides+k;b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    ob=mesh(name,verts,faces,group,color)
    for face in ob.data.polygons:face.use_smooth=len(face.vertices)==4
    return ob


def panel(name,p,w,h,region,angle=0):
    verts=[]
    for x,y in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]:
        verts.append((p[0]+x,p[1]+y*math.cos(angle),p[2]+y*math.sin(angle)))
    illustrated=isinstance(region,str) and region in ['title','reels']
    ob=mesh(name,verts,[(0,1,2,3)],'display' if illustrated else 'printed')
    x0,y0,x1,y1=REGIONS[region] if isinstance(region,str) else region
    # A small inset prevents adjacent atlas rectangles bleeding at lower mips.
    x0+=1;y0+=1;x1-=1;y1-=1
    uvs=[(x0/1024,1-y1/2048),(x1/1024,1-y1/2048),(x1/1024,1-y0/2048),(x0/1024,1-y0/2048)]
    if illustrated:
        split={'classic':.535,'wheel':.516,'dual':.504,'triple':.484}[current_kind]
        lower,upper=(1-split+.003,.998) if region=='title' else (.002,1-split-.003)
        uvs=[(.002,lower),(.998,lower),(.998,upper),(.002,upper)]
    layer=ob.data.uv_layers.new(name='DisplayAtlas')
    for loop in ob.data.loops:layer.data[loop.index].uv=uvs[loop.vertex_index]
    return ob


def screen(name,p,w,h,region,angle=0,trim=STEEL,accent=None):
    def shifted(depth):return (p[0],p[1]-depth*math.sin(angle),p[2]+depth*math.cos(angle))
    box(name+' closed housing',shifted(-.045),(w+.068,h+.068,.09),'enamel',BLACK,.016,angle)
    box(name+' bezel',shifted(.005),(w+.034,h+.034,.022),'metal',trim,.009,angle)
    box(name+' gasket',shifted(.019),(w+.014,h+.014,.012),'enamel',INSET,.005,angle)
    panel(name+' illuminated artwork',shifted(.026),w,h,region,angle)
    if accent:
        # A continuous segmented RGB light guide follows all four bezel edges.
        ww=w/2+.031;hh=h/2+.031
        outline=[(-ww,-hh),(ww,-hh),(ww,hh),(-ww,hh),(-ww,-hh)]
        for edge in range(4):
            for j in range(5):
                points=[]
                for t in [j/5,(j+1)/5]:
                    x=outline[edge][0]*(1-t)+outline[edge+1][0]*t
                    y=outline[edge][1]*(1-t)+outline[edge+1][1]*t
                    points.append((p[0]+x,p[1]+y*math.cos(angle),p[2]+y*math.sin(angle)+.024))
                col=colorsys.hsv_to_rgb((edge*5+j)/20,.87,.85)
                tube(name+' RGB bezel',points,.006,'glow',col,4)


def service_back(height,width=.65):
    box('Rear service door',(0,height*.48,-.309),(width-.10,height*.73,.016),'enamel',(.024,.029,.038),.012)
    for y in range(8):
        box('Rear cooling louver',(0,height*.72+y*.026,-.321),(width*.48,.009,.009),'enamel',INSET)
    tube('Rear keyed latch',[(width*.33,height*.43,-.323),(width*.33,height*.43,-.334)],.013)
    box('Rear power socket',(.17,.15,-.324),(.054,.073,.016),'enamel',INSET,.004)
    for h in [height*.23,height*.58]:
        box('Rear hinge',(-width*.41,h,-.328),(.012,.074,.016),'metal',STEEL,.003)


def console(h=1.02,w=.70,accent=(.035,.39,1.0),classic=False):
    # Top slopes toward the player; buttons sit on that plane, not in it.
    angle=math.radians(20)
    box('Sloping metal button deck',(0,h,.332),(w,.038,.27),'metal',(.19,.22,.27),.018,angle)
    for row in range(1 if classic else 2):
        for i in range(5):
            d=.345+row*.065;hh=h-(d-.332)*math.tan(angle)+.026
            x=-.22+i*.078
            box('Button socket',(x,hh,d),(.060,.019,.049),'enamel',INSET,.007,angle)
            box('Backlit play key',(x,hh+.009,d),(.047,.012,.037),'glow',WHITE if i<4 else accent,.006,angle)
    tube('Large spin button surround',[(.255,h-.007,.39),(.255,h+.014,.39)],.046,'metal',STEEL,12)
    tube('Illuminated spin button',[(.255,h+.015,.39),(.255,h+.025,.39)],.035,'glow',accent,12)
    for s in [-1,1]:
        box('Validator housing',(s*.23,h+.085,.24),(.155,.073,.052),'enamel',INSET,.005)
        box('Validator illuminated mouth',(s*.23,h+.090,.269),(.119,.013,.006),'glow',accent)
        box('Ticket intake slot',(s*.23,h+.075,.270),(.113,.007,.006),'enamel',BLACK)
    box('Padded wrist rest',(0,h-.047,.480),(w+.044,.06,.066),'enamel',BLACK,.024)
    tube('Front console light', [(-w*.47,h-.050,.515),(w*.47,h-.050,.515)],.005,'glow',accent,6)


def pedestal(w=.73,modern=False):
    if modern:
        outline=[(-.30,.015),(.34,.015),(.41,.085),(.27,.19),(.24,.71),(.46,.95),(.46,1.007),(.22,1.094),(-.30,1.08)]
    else:
        outline=[(-.30,.015),(.34,.015),(.37,.08),(.30,.15),(.28,.74),(-.30,.74)]
    profile('Closed pedestal and footwell',w,outline)
    box('Pedestal plinth',(0,.051,.020),(w+.07,.074,.71),'enamel',(.025,.030,.039),.012)
    box('Front locked cash door',(0,.43,.284),(w-.12,.49,.028),'enamel',(.023,.029,.04),.009)
    box('Recessed payout aperture',(0,.41,.305),(.23,.106,.018),'enamel',INSET,.008)
    box('Payout lip',(0,.356,.326),(.249,.018,.061),'metal',STEEL,.004)
    tube('Cash door lock',[(w*.32,.52,.301),(w*.32,.52,.314)],.012)
    for s in [-1,1]:box('Levelling foot',(s*(w/2-.07),.014,-.21),(.07,.028,.09),'enamel',INSET,.006)


def arched_housing(name,w,bottom,spring,top,depth,front,trim=STEEL):
    # Extruded closed arch: vertical lower edges, sampled semicircular crown.
    outline=[(-w/2,bottom),(w/2,bottom),(w/2,spring)]
    for i in range(1,13):
        a=math.pi*i/12;outline.append((w/2*math.cos(a),spring+(top-spring)*math.sin(a)))
    n=len(outline);verts=[(x,h,d) for d in [front-depth,front] for x,h in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh(name,verts,faces,'enamel',BLACK)
    tube(name+' crown trim',[(x,h,front+.009) for x,h in outline+[outline[0]]],.013,'metal',trim,8)
    return ob


def classic():
    pedestal(.70)
    box('Chrome mechanical cabinet',(0,1.125,-.015),(.675,.79,.56),'metal',STEEL,.022)
    box('Dark side insert',(0,1.185,-.010),(.699,.50,.41),'enamel',(.04,.024,.025),.009)
    screen('Mechanical reel glass',(0,1.22,.286),.57,.30,'reels')
    for x in [-.099,.099]:box('Reel window separator',(x,1.22,.318),(.017,.31,.017),'metal',STEEL,.003)
    screen('Lower pay table',(0,.847,.282),.58,.21,'pay')
    arched_housing('Arched printed topglass',.67,1.465,1.83,2.125,.37,.205)
    panel('Royal sevens topglass',(0,1.69,.217),.60,.38,'title')
    tube('Crown medallion drum',[(0,1.979,.200),(0,1.979,.219)],.115,'metal',GOLD,32)
    panel('Crown bonus medallion',(0,1.979,.222),.158,.145,(380,204,644,410))
    console(.999,.68,classic=True)
    tube('Pull arm bearing',[(.33,1.09,-.02),(.409,1.09,-.02)],.043,'metal',STEEL,12)
    tube('Classic pull lever',[(.409,1.09,-.02),(.421,1.38,.075),(.421,1.47,.071)],.016)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.041,location=xyz((.421,1.49,.071)))
    register(bpy.context.object,'enamel',(.022,.027,.038))
    tube('Beacon steel foot',[(0,2.119,-.03),(0,2.135,-.03)],.035)
    tube('Blue candle lamp',[(0,2.135,-.03),(0,2.225,-.03)],.024,'glow',(.08,.44,.75),12)
    tube('Beacon crown',[(0,2.225,-.03),(0,2.239,-.03)],.029)
    service_back(1.43)


def wheel():
    pedestal(.76)
    profile('Tall gold cabinet',.72,[(-.30,.71),(.25,.71),(.27,1.02),(.24,1.73),(-.28,1.77)],'enamel',(.018,.016,.024))
    for s in [-1,1]:box('Tall gold corner moulding',(s*.352,1.27,.246),(.028,1.07,.035),'metal',GOLD,.006)
    screen('Three classic reels',(0,1.205,.285),.63,.325,'reels',trim=GOLD)
    screen('Printed jackpot payglass',(0,1.593,.253),.63,.28,'title',trim=GOLD)
    screen('Lower payout chart',(0,.64,.310),.59,.16,'pay',trim=GOLD)
    console(.97,.73,accent=(.48,.29,.035),classic=True)
    arched_housing('Deep bonus wheel hood',.80,1.75,2.22,2.61,.24,.18,GOLD)
    tube('Wheel metal drum',[(0,2.20,.18),(0,2.20,.215)],.374,'metal',GOLD,48)
    # A circular face uses the wheel's atlas UVs; no black rectangular corners.
    verts=[(0,2.20,.237)]+[(.341*math.cos(k*math.tau/48),2.20+.341*math.sin(k*math.tau/48),.237) for k in range(48)]
    ob=mesh('Twenty four segment bonus wheel',verts,[(0,k+1,(k+1)%48+1) for k in range(48)],'printed')
    layer=ob.data.uv_layers.new(name='DisplayAtlas')
    for loop in ob.data.loops:
        p=verts[loop.vertex_index]
        layer.data[loop.index].uv=((320+p[0]/.341*300)/1024,1-(1664-(p[1]-2.20)/.341*300)/2048)
    for radius,group,col in [(.354,'glow',(.04,.8,.53)),(.382,'metal',GOLD),(.394,'glow',(.44,.035,.8))]:
        tube('Wheel rim',[(radius*math.cos(k*math.tau/48),2.20+radius*math.sin(k*math.tau/48),.223) for k in range(49)],.008,group,col,6)
    for k in range(32):
        a=k*math.tau/32
        tube('Perimeter lamp',[(.369*math.cos(a),2.20+.369*math.sin(a),.227),(.369*math.cos(a),2.20+.369*math.sin(a),.232)],.007,'glow',(.78,.65,.29),6)
    mesh('Wheel winning pointer',[(-.027,2.572,.242),(.027,2.572,.242),(0,2.521,.245),(-.027,2.572,.217),(.027,2.572,.217),(0,2.521,.220)],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'metal',GOLD)
    for s in [-1,1]:
        profile('Gold art deco side fin',.030,[(-.05,1.84),(.15,1.84),(.15,2.64),(.02,2.51),(-.05,2.57)],'metal',GOLD)
        ob=parts['metal'][-1];ob.location.x=s*.418
    service_back(1.75,.70)


def video(triple=False):
    pedestal(.76,True)
    accent=(.02,.42,.66) if triple else (.65,.20,.022)
    height=2.38 if triple else 2.19
    profile('Continuous rear screen spine',.64,[(-.30,.72),(-.03,.72),(.16,1.33),(.04,height),(-.29,height)],'enamel',(.020,.025,.033))
    console(1.06,.77,accent)
    dark_trim=(.065,.082,.11)
    if triple:
        screen('Lower slant touchscreen',(0,1.36,.242),.65,.345,'reels',math.radians(-27),trim=dark_trim,accent=accent)
        screen('Middle video display',(0,1.818,.092),.68,.445,'reels',math.radians(-4),trim=dark_trim,accent=accent)
        screen('Raised bonus display',(0,2.306,.041),.71,.377,'title',math.radians(-13),trim=dark_trim,accent=accent)
        top=2.523
    else:
        screen('Wide reel touchscreen',(0,1.435,.225),.74,.452,'reels',math.radians(-12),trim=dark_trim,accent=accent)
        screen('Wide bonus display',(0,1.968,.141),.74,.452,'title',math.radians(-7),trim=dark_trim,accent=accent)
        top=2.244
    for s in [-1,1]:
        tube('Console luminous side edge',[(s*.38,.98,.481),(s*.38,1.11,.241),(s*.38,1.20,.211)],.005,'glow',accent,6)
        for i in range(6):box('Speaker grille',(s*.286,1.145+i*.007,.274),(.075,.004,.010),'enamel',INSET)
    box('Lower accent',(0,.164,.326),(.47,.009,.012),'glow',accent)
    tube('Candle base',[(0,top,-.035),(0,top+.016,-.035)],.043,'metal',STEEL,12)
    tube('White service candle',[(0,top+.016,-.035),(0,top+.071,-.035)],.037,'glow',(.62,.59,.45),12)
    tube('Candle cap',[(0,top+.071,-.035),(0,top+.081,-.035)],.043,'metal',STEEL,12)
    service_back(height,.64)


def setup(kind):
    global parts,mats,current_kind
    current_kind=kind
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    parts={name:[] for name in ['enamel','metal','glow','display','printed']};mats={}
    for group in parts:
        mat=bpy.data.materials.new('Slot '+group);mat.use_nodes=True;mat.use_backface_culling=True
        bs=mat.node_tree.nodes.get('Principled BSDF');nt=mat.node_tree
        bs.inputs['Roughness'].default_value=.33 if group=='enamel' else .26
        bs.inputs['Metallic'].default_value=.82 if group=='metal' else 0
        if group not in ['display','printed']:
            color=nt.nodes.new('ShaderNodeVertexColor');color.layer_name='Color'
            nt.links.new(color.outputs['Color'],bs.inputs['Base Color'])
            if group=='glow':
                nt.links.new(color.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=3.0
        else:
            tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ART/f'{kind}_{"illustrated" if group=="display" else "displays"}.png'),check_existing=True)
            if group=='display':tex.image.scale(1024,1024)
            tex.image.pack()
            nt.links.new(tex.outputs['Color'],bs.inputs['Base Color']);nt.links.new(tex.outputs['Color'],bs.inputs['Emission Color'])
            bs.inputs['Emission Strength'].default_value=1.05;bs.inputs['Roughness'].default_value=.37
            bs.inputs['Specular IOR Level'].default_value=.22
        mats[group]=mat


def export(kind):
    objects=[];triangles=0
    for group,obs in parts.items():
        if not obs:continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in obs:ob.select_set(True)
        bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join()
        ob=bpy.context.object;ob.name={'enamel':'ClosedCabinet','metal':'Hardware','glow':'LightGuides','display':'Displays','printed':'PrintedGlass'}[group]
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        if group in ['display','printed']:
            # Open display planes have no enclosed "outside". A volume-normal
            # recalculation flips disconnected panels unpredictably; enforce
            # the physical front direction explicitly before glTF culling.
            bm=bmesh.new();bm.from_mesh(ob.data);bm.normal_update()
            for face in bm.faces:
                if face.normal.y>0:face.normal_flip()
            bm.to_mesh(ob.data);bm.free();ob.data.update()
        else:
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
        mod=ob.modifiers.new('Game triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        triangles+=len(ob.data.polygons);objects.append(ob)
    assert triangles <= 5200,(kind,triangles)
    vertices=[ob.matrix_world@v.co for ob in objects for v in ob.data.vertices]
    low=Vector(tuple(min(p[i] for p in vertices) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in vertices) for i in range(3)))
    stats={'variant':kind,'triangles':triangles,'meshes':len(objects),'materials':len(objects),
           'texture_resolution':[1024,1024],'printed_texture_resolution':[1024,2048] if kind in ['classic','wheel'] else None,
           'front_axis':'+Z','dimensions_godot_m':[high.x-low.x,high.z-low.z,high.y-low.y],
           'bounds_godot_min':[low.x,low.z,-high.y],'bounds_godot_max':[high.x,high.z,-low.y]}
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'slot_{kind}.glb'),export_format='GLB',use_selection=True,
        export_yup=True,export_extras=True,export_attributes=False)
    (OUT/f'slot_{kind}_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    print('SLOT_STATS',json.dumps(stats),flush=True)
    return objects,stats


def render(kind,objects):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED';scene.render.threads=8
    def aim(ob,target):ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    for loc,energy,size in [((-2,-3,4),500,3),((3,-1,2.8),350,2),((0,2,3.5),700,2)]:
        bpy.ops.object.light_add(type='AREA',location=loc);ob=bpy.context.object;ob.data.energy=energy;ob.data.shape='DISK';ob.data.size=size;aim(ob,(0,0,1.2))
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor=bpy.context.object;floor.name='Studio floor (not exported)'
    mat=bpy.data.materials.new('Studio neutral');mat.diffuse_color=(.055,.063,.08,1);floor.data.materials.append(mat)
    scene.world.color=(.15,.15,.15)
    bpy.ops.object.camera_add(location=(3.1,-5.9,2.95));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=3.10;aim(cam,(0,-.03,1.31));scene.camera=cam
    scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
    for image in bpy.data.images:
        if image.source=='FILE':image.pack()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/f'slot_{kind}.blend'))
    scene.render.filepath=str(ART/f'{kind}_front.png');bpy.ops.render.render(write_still=True)
    cam.location=(-3.1,5.9,2.95);aim(cam,(0,-.03,1.31))
    scene.render.filepath=str(ART/f'{kind}_rear.png');bpy.ops.render.render(write_still=True)


args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for kind in ['classic','wheel','dual','triple']:
    if args and kind not in args:continue
    setup(kind)
    if kind=='classic':classic()
    elif kind=='wheel':wheel()
    else:video(kind=='triple')
    objects,stats=export(kind)
    render(kind,objects)
