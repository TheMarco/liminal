"""Build original low-poly ZEON retail furniture from the supplied reference.

Blender --background --factory-startup --python tools/blender/build_mall_merchandise.py
The large station is U shaped, with a genuinely open rear staff entrance.
Coordinates are Godot: metres, Y up, +Z customer/front. No photo pixels are used.
"""
from pathlib import Path
import sys
import math
import json
import random
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import hero_prop as hp

ART = ROOT / 'art/mall_merchandise'
OUT = ROOT / 'models/authored/mall_merchandise'
LABELS = ROOT / 'art/hero_props/labels.png'


def materials():
    global wood, edge, black, chrome, light, artwork, fabrics, seam
    wood = hp.material('Bleached ash | fine vertical grain', (.49,.49,.455), .66, variation=.075, bump=.00045)
    nt=wood.node_tree
    noise=next(n for n in nt.nodes if n.bl_idname=='ShaderNodeTexNoise')
    geo=next(n for n in nt.nodes if n.bl_idname=='ShaderNodeNewGeometry')
    vector=nt.nodes.new('ShaderNodeVectorMath');vector.operation='MULTIPLY';vector.inputs[1].default_value=(52,52,2.3)
    nt.links.new(geo.outputs['Position'],vector.inputs[0]);nt.links.new(vector.outputs[0],noise.inputs['Vector'])
    noise.inputs['Scale'].default_value=1.0;noise.inputs['Detail'].default_value=2
    edge=hp.material('Ivory laminate | satin rounded edges',(.73,.715,.657),.38,variation=.023)
    black=hp.material('Charcoal POS polymer',(.018,.022,.021),.58,variation=.08)
    chrome=hp.material('Satin warm brass | skirting',(.41,.31,.13),.29,.72,variation=.05)
    seam=hp.material('Dark shelf recess',(.065,.075,.072),.86,variation=.1)
    light=hp.material('Warm white illuminated fascia',(.87,.78,.52),.4,variation=0)
    bs=light.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(1,.78,.43,1);bs.inputs['Emission Strength'].default_value=2.0
    artwork=hp.image_material('ZEON branding and POS artwork',LABELS,emission=.35,rough=.48)
    colors=[('Oxblood',(.30,.045,.055)),('Sage',(.20,.26,.135)),('Ecru',(.56,.50,.37)),('Navy',(.027,.048,.092)),('Teal',(.044,.22,.22)),('Lilac',(.23,.145,.32)),('Coal',(.031,.037,.037)),('Burnt coral',(.39,.115,.083))]
    fabrics=[hp.material(name+' folded cotton',color,.96,variation=.13,bump=.00065) for name,color in colors]


def yaw_point(p,center,yaw):
    return (center[0]+p[0]*math.cos(yaw)+p[2]*math.sin(yaw),center[1]+p[1],center[2]-p[0]*math.sin(yaw)+p[2]*math.cos(yaw))


def folded_shirt(name,center,w,d,t,mat,yaw=0,collar=False,seed=0):
    """A shaped three-ring folded garment, with exposed folds and sewn neckline.

    Polygon spending is on its soft silhouette, layered fold and collar, rather
    than uniformly beveling rectangular blocks. Lower layers omit hidden collars.
    """
    rng=random.Random(seed)
    outline=[(-.44,-.5),(.39,-.5),(.5,-.35),(.475,.36),(.35,.5),(-.37,.49),(-.5,.32),(-.5,-.31)]
    verts=[]
    for row in range(3):
        for i,(x,z) in enumerate(outline):
            scale=[.925,1,.9][row]
            y=[.001,t*.58,t*.92][row]
            if row==2:y+=t*(.05 if i in (1,2,6) else -.045)
            verts.append(yaw_point((x*w*scale,y,z*d*scale),center,yaw))
    verts.append(yaw_point((-.03*w,t*1.11,.045*d),center,yaw))
    faces=[tuple(reversed(range(8)))]
    for k in range(2):
        for i in range(8):faces.append((k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i))
    for i in range(8):faces.append((16+i,16+(i+1)%8,24))
    hp.mesh(name+' | soft folded body',verts,faces,mat,True)
    if not collar:return
    # Short folded sleeve panels introduce actual cloth overlaps across the top.
    for side in (-1,1):
        v=[(side*w*.45,t*.85,-d*.31),(side*w*.19,t*1.14,-d*.15),(side*w*.19,t*1.12,d*.15),(side*w*.44,t*.99,d*.27)]
        hp.mesh(name+' | tucked sleeve', [yaw_point(p,center,yaw) for p in v],[(0,1,2,3)],mat)
    # Sewn neckline: low eight-sided elliptical annulus, visible from above.
    n=8;vs=[]
    for radius,y in ((1,t*.97),(1,t*1.27),(.69,t*1.20)):
        for i in range(n):
            a=math.tau*i/n
            vs.append(yaw_point((math.cos(a)*w*.12*radius,y,-d*.26+math.sin(a)*d*.10*radius),center,yaw))
    fs=[]
    for ring in range(2):
        for i in range(n):fs.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    hp.mesh(name+' | sewn collar',vs,fs,mat,True)
    # Interior shadow disk prevents a light countertop showing through neckline.
    hp.mesh(name+' | neck opening',[yaw_point((math.cos(math.tau*i/n)*w*.075,t*1.02,-d*.26+math.sin(math.tau*i/n)*d*.067),center,yaw) for i in range(n)],[tuple(range(n))],seam)


def stack(name,p,w,d,layers,color,seed,yaw=0):
    rng=random.Random(seed)
    y=p[1]
    for i in range(layers):
        t=.024+rng.random()*.006
        pos=(p[0]+rng.uniform(-.012,.012),y,p[2]+rng.uniform(-.01,.01))
        folded_shirt(name+f' layer {i+1}',pos,w*(1+rng.uniform(-.03,.03)),d,t,fabrics[(color+i//2)%len(fabrics)],yaw+rng.uniform(-.065,.065),i==layers-1,seed+i)
        y+=t*.99


def box(name,p,size,mat= None,bevel=0):
    return hp.box(name,p,size,mat or wood,bevel)


def strip(name,p,size):
    ob=box(name,p,size,light);glow.append(ob);return ob


def u_band(name,w,d,y,h,depth,mat,inset=0):
    """Three abutting boards, never a slab spanning the staff well."""
    width=w-2*inset;depth_total=d-2*inset
    front=depth_total/2-depth/2
    out=[]
    out.append(box(name+' front',(0,y,front),(width,h,depth),mat))
    for side in (-1,1):
        out.append(box(name+(' left' if side<0 else ' right'),(side*(width/2-depth/2),y,-depth/2),(depth,h,depth_total-depth),mat))
    return out


def station():
    global glow,decals
    hp.reset();materials();glow=[];decals=[]
    w=2.8;d=1.72;side_depth=.45;front_depth=.44
    # Open U base. Its empty centre reaches the floor and the rear entrance.
    u_band('Recessed dark plinth',w-.09,d-.06,.043,.086,.39,seam)
    u_band('Brass kickplate',w-.02,d-.018,.103,.095,.43,chrome)
    glow.extend(u_band('Luminous skirting',w-.024,d-.021,.151,.022,.43,light))
    u_band('Bottom shelf',w-.008,d-.012,.191,.060,.45,wood)
    # Front merchandise back, plus side merchandise backs bound the staff well.
    box('Front interior staff panel',(0,.551,.421),(1.90,.690,.037))
    for s in (-1,1):
        box('Side inner staff panel',(s*.938,.551,-.20),(.034,.690,1.21))
        box('Rear shelf end',(s*1.164,.55,-.838),(.472,.681,.044))
        # Counter legs end on the base and frame each side opening.
        box('Front corner stile',(s*1.367,.551,.626),(.066,.679,.456))
        box('Rear stile',(s*1.367,.551,-.80),(.066,.679,.082))
    for y in (.414,.645,.881):u_band('Open merchandise shelf',w-.020,d-.100,y,.032,.45,wood)
    # Thin shelf lips deliberately leave openings unobstructed.
    for y in (.215,.433,.664):
        box('Front ash shelf edge',(0,y,.809),(2.68,.024,.022),edge)
        for s in (-1,1):box('Side ash shelf edge',(s*1.39,y,-.202),(.019,.024,1.215),edge)
    # Two shallow architectural steps define the reference silhouette.
    u_band('Lower countertop lip',w,d,.908,.035,.47,edge)
    glow.extend(u_band('Lower light fascia',w-.04,d-.04,.955,.064,.44,light))
    u_band('Lower tier cap',w-.034,d-.034,.997,.020,.44,edge)
    u_band('Upper tier ash shadow',w-.21,d-.21,1.023,.025,.42,wood)
    glow.extend(u_band('Upper light fascia',w-.226,d-.226,1.074,.075,.42,light))
    u_band('Upper working counter',w-.202,d-.202,1.132,.036,.43,edge)
    # Wide, reachable staff aperture at the rear; no phantom rear counter.
    box('Rear-left tall brand panel',(-1.121,.925,-.749),(.440,1.85,.070),edge,.007)
    decals.append(hp.decal('ZEON illuminated brand',(-1.121,1.582,-.710),(.345,.345),artwork,tile=4))
    # POS on the right return, facing inward so staff in the well can use it.
    pos_parts_start=len(hp.parts)
    box('Cash drawer',(.99,1.187,-.415),(.34,.074,.28),black,.006)
    box('Drawer handle',(.99,1.183,-.268),(.12,.012,.01),chrome,.003)
    box('Receipt printer',(.991,1.259,-.523),(.13,.067,.11),black,.008)
    box('Receipt exit',(.991,1.293,-.488),(.087,.005,.009),seam)
    box('POS stand foot',(.991,1.233,-.38),(.20,.024,.13),black,.005)
    hp.tube('POS stand',[(.991,1.240,-.38),(.991,1.390,-.426)],.024,black,6)
    screen=box('POS display',(.991,1.438,-.421),(.268,.197,.035),black,.005)
    screen.rotation_euler[0]=math.radians(8)
    # Slightly inset screen remains readable; screen artwork uses our original atlas.
    decals.append(hp.decal('ZEON point-of-sale screen',(.991,1.44,-.394),(.229,.158),artwork,tile=5))
    # Rotate the complete checkout unit toward -X, into the staff well.
    pivot=Vector(hp.xyz((.991,1.15,-.421)))
    inward=Matrix.Translation(pivot) @ Matrix.Rotation(-math.pi/2,4,'Z') @ Matrix.Translation(-pivot)
    for ob in hp.parts[pos_parts_start:]: ob.matrix_world=inward @ ob.matrix_world
    # Three front shelf rows. Clothing varies in colour and stack height, with air
    # between piles rather than filling each shelf with a coloured rectangle.
    colors=[1,7,3,2,0,6,4,1,5]
    for row,y in enumerate((.222,.435,.666)):
        for col,x in enumerate((-.985,-.33,.325,.975)):
            stack(f'Front shelf {row} stack {col}',(x,y,.638),.345,.30,2+(row+col)%2,colors[(row*4+col)%len(colors)],100+row*10+col)
    for side in (-1,1):
        for row,y in enumerate((.222,.435,.666)):
            for col,z in enumerate((-.595,-.15)):
                stack(f'Side {side} shelf {row} stack {col}',(side*1.16,y,z),.285,.30,2+(col+row)%2,(row*3+col+(1 if side<0 else 5))%8,300+row*10+col+(50 if side<0 else 0),side*math.pi/2)
    # Single composed shirt stack on rear left return, clear of the brand sign.
    stack('Counter seasonal fold',(-.992,1.152,-.32),.29,.25,2,2,801)
    return export('mall_merchandise_station',6000,4.0,(3.4,-4.4,3.0),(0,0,.83),dict(variant='large U-shaped staff station',staff_well_width_m=1.738,rear_access_open=True,counter_height_m=1.15))


def display():
    global glow,decals
    hp.reset();materials();glow=[];decals=[]
    w=2.20;d=.90
    box('Recessed low plinth',(0,.041,0),(2.10,.082,.80),seam)
    box('Brass kickplate',(0,.107,0),(2.16,.081,.855),chrome)
    strip('Front skirting',(0,.152,.431),(2.16,.021,.020))
    strip('Back skirting',(0,.152,-.431),(2.16,.021,.020))
    for s in (-1,1):strip('End skirting',(s*1.071,.152,0),(.022,.021,.864))
    box('Bottom shelf',(0,.189,0),(2.2,.052,.90))
    # Double-sided shelving around a central spine. End panels bind the piece
    # while keeping all three broad front/rear merchandise rows open.
    box('Central shelf spine',(0,.506,0),(2.10,.662,.034))
    for s in (-1,1):box('End frame',(s*1.072,.51,0),(.055,.668,.892))
    for y in (.406,.622,.844):box('Merchandise shelf',(0,y,0),(2.145,.033,.88))
    for y in (.217,.426,.643):
        for s in (-1,1):box('Thin shelf edge',(0,y,s*.4395),(2.09,.022,.021),edge)
    box('Lower counter lip',(0,.872,0),(2.20,.028,.90),edge)
    strip('Front light fascia',(0,.920,.426),(2.16,.066,.025))
    strip('Rear light fascia',(0,.920,-.426),(2.16,.066,.025))
    for s in (-1,1):strip('End light fascia',(s*1.079,.920,0),(.023,.066,.827))
    box('Pale inset counter core',(0,.92,0),(2.11,.068,.823),edge)
    box('Counter cap',(0,.967,0),(2.18,.025,.88),edge,.004)
    box('Raised display tier',(0,.998,0),(1.15,.038,.60),wood,.004)
    box('Upper tier lip',(0,1.027,0),(1.17,.026,.62),edge,.004)
    for side in (-1,1):
        for row,y in enumerate((.218,.428,.644)):
            for col,x in enumerate((-.76,0,.75)):
                stack(f'Compact {side} row {row} stack {col}',(x,y,side*.23),.345,.27,2,(col+row*3+(1 if side<0 else 0))%8,1000+row*10+col+(100 if side<0 else 0),0 if side>0 else math.pi)
    return export('mall_merchandise_display',3500,3.2,(3.0,-3.5,2.1),(0,0,.46),dict(variant='compact double-sided merchandise display',counter_height_m=1.04))


def export(name,budget,scale,camera,target,metadata):
    art=ART/name;out=art/'export'
    stats=hp.finish(name,art,out,budget,specials=[('Warm illuminated fascia',glow),('ZEON artwork',decals)],metadata=metadata,scale=scale,camera=camera,target=target)
    # Stable top-level paths keep runtime references concise while variant source
    # and preview directories retain descriptive self-contained contents.
    import shutil
    shutil.move(out/(name+'.glb'),OUT/(name+'.glb'))
    return stats


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True);(ART/'.gdignore').write_text('')
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    selected=args[0] if args else 'both'
    stats={}
    if selected in ('both','station'):stats['station']=station()
    if selected in ('both','display'):stats['display']=display()
    report=OUT/'mesh_stats.json'
    if selected!='both' and report.exists():
        previous=json.loads(report.read_text());previous.update(stats);stats=previous
    report.write_text(json.dumps(stats,indent=2)+'\n')
    (OUT/'README.md').write_text('''# ZEON merchandise furniture\n\nOriginal Blender-authored retail furniture inspired by the supplied checkout/display reference. Both variants use pale ash cabinets, warm illuminated fascia, open shelving and shaped folded garments with tucked sleeves, layered fabric edges and collars. No reference image pixels are used.\n\n- `mall_merchandise_station.glb`: 2.80 m wide × 1.72 m deep × 1.85 m tall. U-shaped, open rear staff entrance and open interior well; working counter 1.15 m high; original ZEON branding and POS facing -X into the staff well.\n- `mall_merchandise_display.glb`: 2.20 m wide × 0.90 m deep × 1.04 m tall. Double-sided three-tier merchandise shelving, no high brand panel or POS.\n\nCoordinates: metres, Y up, +Z customer/front. Origin floor centre. Mesh statistics and exact bounds are in `mesh_stats.json`. Static furniture meshes carry no generated colliders: runtime should use the existing furnishing footprint or three U-shaped boxes when staff access is needed. All parts in each opaque variant share one baked 1K PBR atlas; fascia uses one emissive surface and the large station one shared artwork surface.\n\nRebuild with `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_mall_merchandise.py`. Optional final argument `-- station` or `-- display` rebuilds one variant. Editable packed Blender files, original atlas maps and front/reverse review renders live under `art/mall_merchandise/`.\n''')
