"""Reference-shaped hotel ice dispenser and tabletop overhead projector."""
from pathlib import Path
import sys, math, bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1]

def label(name,text,p,size,mat):
    # Geometry text is baked with the body so tiny labels add no runtime surfaces.
    cu=bpy.data.curves.new(name,'FONT');cu.body=text;cu.size=size;cu.align_x='CENTER';cu.extrude=0
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob)
    ob.location=h.xyz(p);ob.rotation_euler=(math.pi/2,0,0);ob.data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.convert(target='MESH');h.parts.append(ob);return ob

def rusted_cream():
    mat=h.material('Aged ivory enamel',(.55,.48,.30),.62,.13,.035)
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    tex=nt.nodes.new('ShaderNodeTexCoord')
    sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(tex.outputs['Generated'],sep.inputs[0])
    noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=29;noise.inputs['Detail'].default_value=2
    nt.links.new(tex.outputs['Generated'],noise.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.37;ramp.color_ramp.elements[0].color=(.48,.425,.29,1)
    ramp.color_ramp.elements[1].position=.68;ramp.color_ramp.elements[1].color=(.55,.49,.35,1)
    nt.links.new(noise.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
    return mat

def ice():
    h.reset()
    cream=rusted_cream();metal=h.material('Brushed stainless',(.37,.39,.35),.35,.8,.035)
    black=h.material('Grille dark gaps',(.007,.009,.008),.8,.1,.03)
    ivory=h.material('Printed warm white',(.82,.78,.61),.7,0,0)
    rust=h.material('Base edge rust',(.18,.060,.016),.96,.1,.04)
    rubber=h.material('Rubber feet',(.012,.013,.012),.93,0,.02)
    # Overall front is +Z; separated wall panels leave a deep, open dispenser bay.
    for x in [-.30,.30]:
        for z in [-.25,.25]:
            h.tube('Adjustable foot',[(x,0,z),(x,.075,z)],.033,rubber,10)
    h.box('Dark plinth',(0,.115,0),(.73,.09,.64),black,.007)
    h.box('Rear lower cabinet',(0,.71,-.185),(.71,1.10,.29),cream,.012)
    for x in [-.373,.373]:
        h.box('Folded full cabinet side',(x,.75,0),(.034,1.20,.70),cream,.006)
    # Wide right service panel; narrow left cheek. Their front faces are flush.
    h.box('Right service door',(.223,.735,.326),(.258,1.08,.046),cream,.006)
    h.box('Left recess surround',(-.319,.735,.326),(.074,1.08,.046),cream,.006)
    h.box('Lower apron',(-.09,.275,.326),(.386,.20,.046),cream,.005)
    h.box('Upper fascia',(-.09,1.23,.326),(.386,.13,.046),cream,.005)
    h.box('Dispenser well back',(-.09,.76,.12),(.386,.79,.025),metal,.005)
    for x in [-.285,.105]:
        h.box('Well side', (x,.76,.223),(.016,.79,.218),cream,.004)
    h.box('Well ceiling',(-.09,1.151,.223),(.40,.022,.218),cream,.004)
    h.box('Deep shadow under chute',(-.09,1.052,.142),(.225,.135,.022),black,.004)
    h.box('Ice chute steel flap',(-.09,.982,.181),(.186,.255,.024),metal,.008)
    label('Push label','PUSH',(-.09,1.046,.195),.024,black)
    for x in [-.149,-.124,-.099,-.074,-.049,-.024]:
        h.box('Flap cooling crease',(x,.963,.196),(.004,.113,.002),black)
    h.box('Drain tray dark bottom',(-.09,.389,.24),(.39,.025,.23),black,.004)
    h.box('Tray raised front lip',(-.09,.426,.35),(.426,.092,.035),cream,.008)
    for x in [-.295,.115]:
        h.box('Tray end', (x,.416,.245),(.025,.07,.21),metal,.002)
    for x in [-.26+i*.028 for i in range(13)]:
        h.tube('Drain grid wire',[(x,.407,.149),(x,.407,.33)],.0035,metal,6)
    # Separate upper compressor module, real louvres and sheet-metal seams.
    h.box('Compressor upper module',(0,1.625,-.008),(.79,.63,.704),cream,.010)
    h.box('Black front grille recess',(-.025,1.665,.347),(.58,.45,.012),black,.003)
    for j in range(18):
        yy=1.45+j*.024
        h.section('Angled vent blade',[(.355,yy),(.371,yy-.007),(.372,yy+.001),(.355,yy+.008)],-.304,.254,black)
    for x in [-.13,.02,.16]:
        h.box('Grille upright',(x,1.659,.374),(.009,.433,.007),black)
    h.box('Module seam',(0,1.306,.35),(.79,.009,.012),metal)
    h.box('Black ICE CUBES band',(0,1.27,.355),(.776,.052,.010),black)
    art=h.image_material('Ice machine nameplate',ROOT/'art/vegas_ice_machine/ice_label.png',0,.65)
    printface=h.decal('ICE CUBES nameplate',(0,1.27,.361),(.767,.05),art,grid=1)
    # Lock, warning plate and restrained lower-corner corrosion.
    h.tube('Service key lock',[(.223,1.1,.349),(.223,1.1,.358)],.012,metal,12)
    h.box('Key slot',(.223,1.1,.360),(.003,.010,.0015),black)
    label('Service label','SERVICE',(.223,1.052,.351),.010,black)
    for x in [-.351,.351]:
        for y in [.21,.52,1.15,1.89]:
            h.tube('Case rivet',[(x,y,.347),(x,y,.353)],.004,metal,8)
    for x in [-.34,-.31,.31,.343]:
        h.box('Small edge corrosion',(x,.18,.351),(.012,.039,.001),rust)
    h.finish('vegas_ice_machine',ROOT/'art/vegas_ice_machine',ROOT/'models/authored/vegas_ice_machine',4000,
             specials=[('Nameplate',[printface])],surface_normals={'Nameplate':(0,0,1)},
             metadata={'description':'Aged ivory ice dispenser with louvred compressor and open drain well'},
             scale=2.45,camera=(2.5,-4,2.5),target=(0,0,.98))

def projector():
    h.reset()
    cream=h.material('Warm ivory moulded shell',(.65,.62,.50),.47,.08,.025)
    charcoal=h.material('Textured charcoal body',(.070,.076,.07),.66,.08,.04)
    black=h.material('Optical recess black',(.007,.009,.010),.43,.12,.01)
    blue=h.material('Blue focus controls',(.025,.06,.25),.35,.08,.01)
    metal=h.material('Mast stainless steel',(.38,.41,.39),.3,.8,.02)
    glass=h.material('Fresnel optical stage',(.30,.35,.34),.17,.55,.009)
    mirror=h.material('Silver mirror',(.64,.68,.67),.09,.96,0)
    # Low tabletop housing, not an upright tower.
    for x in [-.163,.163]:
        for z in [-.177,.177]:h.box('Rubber foot',(x,.010,z),(.038,.020,.040),black,.003)
    h.section('Trapezoid lower housing',[(-.22,.025),(.22,.025),(.214,.255),(-.206,.295)],-.202,.202,charcoal,.007)
    for x in [-.195,.195]:h.box('Ivory stage side rim',(x,.289,0),(.023,.035,.45),cream,.004)
    for z in [-.214,.214]:h.box('Ivory stage end rim',(0,.289,z),(.394,.035,.023),cream,.004)
    h.box('Fresnel flat glass',(0,.285,0),(.36,.012,.396),glass,.001)
    # Thin concentric etched rings form a believable optical texture in the bake.
    for i in range(1,13):
        rr=i*.0146
        pts=[(rr*math.cos(j*math.tau/32),.292,rr*math.sin(j*math.tau/32)) for j in range(33)]
        # bake_export keeps this geometry; 24 rings at 56 too costly.
        # Alternating rings reduced to twelve broad rings, with low radial section.
        if i%3==0:h.tube('Fresnel ring',pts,.0006,metal,3)
    # Side carry-handle pocket: real hole framed in cream, dark rear.
    h.box('Handle dark cavity',(.204,.142,.026),(.008,.056,.125),black,.003)
    for z in [-.045,.097]:
        h.box('Handle vertical end',(.215,.145,z),(.025,.070,.018),cream,.002)
    for y in [.108,.182]:
        h.box('Handle top bottom',(.215,y,.026),(.025,.016,.16),cream,.002)
    # Rear side mast and focusing slider, with printed ruler teeth.
    h.box('Mast base bracket',(.215,.194,-.134),(.060,.084,.095),cream,.005)
    h.box('Vertical steel rack',(.246,.496,-.135),(.020,.49,.025),metal,.002)
    for j in range(25):
        h.box('Rack teeth',(.260,.29+j*.017,-.135),(.009,.003,.027),charcoal)
    h.box('Focus carriage',(.240,.505,-.13),(.055,.083,.056),cream,.004)
    h.tube('Blue focus knob',[(.261,.505,-.13),(.29,.505,-.13)],.032,blue,16)
    h.tube('Lower tilt knob',[(.227,.28,-.14),(.25,.28,-.14)],.030,blue,16)
    # Arm bends inward to put the lens over the stage.
    h.tube('Curved optical head support',[(.237,.53,-.135),(.237,.616,-.135),(.22,.633,-.135),(.08,.633,-.135),(0,.633,-.12)],.012,charcoal,10)
    # Open head: base lens aperture, cheeks, 45 degree reflecting mirror.
    h.box('Lens base',(0,.636,-.006),(.145,.017,.17),cream,.003)
    h.tube('Optical lens barrel',[(0,.622,-.006),(0,.657,-.006)],.051,black,20)
    h.tube('Lens surface',[(0,.62,-.006),(0,.624,-.006)],.042,glass,20)
    for x0,x1 in [(-.073,-.067),(.067,.073)]:
        h.section('Triangular mirror cheek',[(-.090,.645),(-.09,.762),(.080,.645)],x0,x1,cream)
    # Mirror slopes upward toward the rear. Visible aperture faces +Z.
    h.mesh('Open silver reflector',[(-.065,.655,.062),(.065,.655,.062),(.065,.753,-.079),(-.065,.753,-.079)],[(0,1,2,3)],mirror)
    for x in [-.07,.07]:
        h.tube('Mirror side rim',[(x,.648,.071),(x,.762,-.086)],.004,cream,6)
    h.tube('Mirror upper rim',[(-.074,.762,-.086),(.074,.762,-.086)],.004,cream,6)
    h.tube('Head hinge blue screw',[(.074,.658,-.073),(.08,.658,-.073)],.009,blue,10)
    # Controls and actual side vents; labels bake into the body.
    h.tube('Front brightness dial',[(0,.108,.221),(0,.108,.245)],.034,blue,16)
    for j in range(10):
        x=-.144+j*.027
        h.box('Front cooling vent',(x,.206,.222),(.012,.027,.004),black,.001)
    h.box('Power rocker',(.101,.065,.224),(.023,.035,.008),black,.002)
    label('Model label','LUMEN 3000',(0,.258,.219),.012,cream)
    label('Power marking','I',(.100,.093,.226),.008,cream)
    h.finish('school_overhead_projector',ROOT/'art/school_overhead_projector',ROOT/'models/authored/school_overhead_projector',4000,
             metadata={'description':'Tabletop overhead projector with Fresnel stage, focus rack and open mirror head'},
             scale=1.03,camera=(1.25,-1.8,1.15),target=(0,0,.37))
mode=sys.argv[-1]
if mode in ('ice','all'):ice()
if mode in ('projector','all'):projector()
