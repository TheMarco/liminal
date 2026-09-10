"""Reference-inspired vintage vending cabinets. Metres, Y up, +Z front."""
from pathlib import Path
import sys,math
import bpy
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1]
def woodmat():
    m=h.material('Vertical walnut laminate',(.12,.055,.022),.43,0,.025)
    nt=m.node_tree;b=nt.nodes.get('Principled BSDF');c=nt.nodes.new('ShaderNodeTexCoord');v=nt.nodes.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=(5,3,.35);nt.links.new(c.outputs['Generated'],v.inputs[0]);w=nt.nodes.new('ShaderNodeTexWave');w.wave_type='BANDS';w.bands_direction='X';w.inputs['Scale'].default_value=5;w.inputs['Distortion'].default_value=7;w.inputs['Detail'].default_value=3;nt.links.new(v.outputs[0],w.inputs['Vector']);r=nt.nodes.new('ShaderNodeValToRGB');r.color_ramp.elements[0].color=(.025,.012,.006,1);r.color_ramp.elements[1].color=(.12,.050,.018,1);nt.links.new(w.outputs['Color'],r.inputs[0]);nt.links.new(r.outputs[0],b.inputs['Base Color']);return m

def build(kind):
    h.reset();art=ROOT/'art'/kind;out=ROOT/'models/authored'/kind
    black=h.material('Charcoal enamel',(.015,.018,.019),.44,.25,.025)
    rubber=h.material('Recess shadows',(.005,.006,.006),.84,0,0)
    chrome=h.material('Soft brushed stainless',(.51,.54,.53),.29,.8,.015)
    satin=h.material('Satin steel',(.28,.30,.28),.4,.72,.028)
    brass=h.material('Champagne anodized aluminium',(.36,.25,.12),.37,.6,.025)
    knob=h.material('Pearl pull knobs',(.62,.66,.64),.20,.55,.015)
    wood=woodmat();printing=h.image_material('Vintage original advertisement',art/'advertising.png',.13,.49)
    graphics=[]
    def decal(name,p,size,rect=(0,0,1024,800),slope=0):
        ob=h.decal(name,p,size,printing,grid=1)
        x0,y0,x1,y1=rect;coords=[(x0/1024,1-y1/1024),(x1/1024,1-y1/1024),(x1/1024,1-y0/1024),(x0/1024,1-y0/1024)]
        for loop in ob.data.loops:ob.data.uv_layers[0].data[loop.index].uv=coords[loop.vertex_index]
        if slope:
            for v in ob.data.vertices:v.co.y += slope*(v.co.z-p[1])
        graphics.append(ob);return ob
    def strip(name,x,y,w,ht,z=.335,mat=chrome):h.box(name,(x,y,z),(w,ht,.025),mat,.002)
    def screw(x,y,z):h.tube('Cabinet screw',[(x,y,z),(x,y,z+.004)],.004,chrome,6)
    def feet():
        for x in [-.355,.355]:
            for z in [-.225,.225]:
                h.lathe('Short tapered foot',(x,0,z),[(.018,0),(.022,.01),(.032,.16)],black,8)
    def frame(x0,x1,y0,y1,z):
        for x in [x0,x1]:h.box('Display side bezel',(x,(y0+y1)/2,z),(.018,y1-y0+.025,.022),chrome,.002)
        for y in [y0,y1]:h.box('Display horizontal bezel',((x0+x1)/2,y,z),(x1-x0,.018,.022),chrome,.002)
    def coin(x,y,z):
        h.box('Coin mechanism bezel',(x,y,z),(.079,.267,.035),chrome,.004)
        h.box('Coin mechanism inner plate',(x,y,z+.019),(.061,.245,.010),satin)
        h.box('Coin slot shadow',(x,y+.073,z+.027),(.012,.06,.006),rubber,.002)
        h.box('Coin return flap',(x,y-.071,z+.030),(.04,.043,.012),chrome,.002)
        h.tube('Coin return knob',[(x,y+.009,z+.025),(x,y+.009,z+.056)],.009,chrome,8)
        for yy in [y-.115,y+.115]:screw(x,yy,z+.028)
    feet()
    if kind=='vegas_cigarette_machine':
        # Cabinet rear and individual sides preserve true recessed front bays.
        h.box('Black rear enclosure',(0,1.0475,-.050),(.9,1.485,.49),black,.009)
        for x in [-.446,.446]:h.box('Black side return',(x,.977,.135),(.029,1.635,.36),black,.004)
        h.box('Top lid',(0,1.79,.004),(.93,.045,.63),black,.006)
        h.box('Lower plinth',(0,.230,.025),(.90,.15,.60),black,.004)
        for x in [-.386,.386]:h.box('Walnut front pilaster',(x,1.015,.280),(.075,1.40,.043),wood,.002)
        for x in [-.444,.444]:h.box('Full-height chrome front trim',(x,1.018,.314),(.018,1.50,.025),chrome,.002)
        # Broad fluted top fascia; low-cost applied grooves.
        h.box('Top ribbed header',(0,1.704,.305),(.865,.132,.045),satin,.003)
        for y in [1.659+i*.009 for i in range(11)]:strip('Header rib',0,y,.84,.0025,.332,chrome)
        h.tube('Header lock',[(0,1.71,.332),(0,1.71,.341)],.010,chrome,10)
        h.box('Advertisement backing',(-.020,1.222,.279),(.666,.805,.02),black)
        decal('Alpine advertisement',(-.020,1.222,.294),(.64,.80))
        frame(-.349,.309,.817,1.627,.305)
        coin(.374,1.442,.320)
        # Two slanted selector shelves, each with TEN projecting pull rods.
        for row,y in enumerate([.767,.570]):
            h.section('Angled label shelf',[(.300,y+.025),(.378,y-.045),(.378,y-.060),(.298,y+.008)],-.348,.348,chrome)
            decal('Printed pack choices',(0,y-.007,.342),(.669,.088),(0,800+row*112,1024,910+row*112),slope=.90)
            h.box('Selector black mounting strip',(0,y-.098,.325),(.700,.082,.038),rubber,.002)
            for x in [-.313+j*.0695 for j in range(10)]:
                h.tube('Round knob collar',[(x,y-.098,.345),(x,y-.098,.355)],.025,satin,8)
                h.tube('Pull rod',[(x,y-.098,.352),(x,y-.098,.408)],.009,chrome,8)
                h.tube('Faceted pull handle',[(x,y-.098,.397),(x,y-.098,.430)],.019,knob,8)
            for x in [-.352,.352]:h.box('Selector strip side', (x,y-.088,.346),(.018,.090,.023),chrome)
        # Open delivery recess. Back at z=.15, lip at .39 leaves visible depth.
        h.box('Delivery dark back',(0,.352,.158),(.725,.104,.014),rubber)
        h.box('Delivery lower shelf',(0,.292,.270),(.744,.021,.249),satin)
        h.section('Downturned delivery lip',[(.392,.290),(.396,.320),(.380,.324),(.376,.293)],-.387,.387,chrome)
        for x in [-.371,.371]:h.box('Delivery side cheek',(x,.343,.268),(.014,.104,.238),chrome)
        strip('Delivery canopy',0,.405,.75,.017,.340)
        desc='Vintage cigarette vending cabinet with original Alpine print, twenty pull rods, dual slanted selection panels and recessed delivery trough'
    else:
        h.box('Rear walnut case',(0,.983,-.052),(.94,1.654,.49),wood,.005)
        for x in [-.459,.459]:h.box('Walnut enclosure cheek',(x,.986,.123),(.024,1.66,.374),wood,.002)
        h.box('Full walnut top cap',(0,1.820,.006),(.94,.020,.616),wood,.002)
        h.box('Top walnut fascia',(0,1.785,.276),(.94,.05,.057),wood,.002)
        h.box('Lower walnut access door',(0,.400,.280),(.89,.48,.052),wood,.002)
        for x in [-.465,.465]:h.box('Outer vertical stainless edging',(x,.987,.314),(.015,1.666,.022),chrome,.002)
        for y in [.156,.647,1.827]:strip('Cabinet edge rail',0,y,.944,.015,.314)
        h.box('Right walnut coin column',(.347,1.226,.276),(.224,1.126,.061),wood,.002)
        h.box('Left walnut surround',(-.411,1.227,.276),(.075,1.11,.051),wood,.002)
        h.box('Coffee advertisement backing',(-.070,1.480,.263),(.60,.50,.012),black)
        decal('Coffee harvest illuminated illustration',(-.070,1.480,.277),(.60,.50))
        frame(-.378,.238,1.220,1.742,.293)
        # Wide champagne selection fascia incl. actual protruding rectangular buttons.
        h.section('Angled coffee selector fascia',[(.273,1.215),(.352,1.047),(.348,1.030),(.260,1.212)],-.373,.232,brass)
        decal('Drink names and prices',(-.070,1.143,.308),(.59,.130),(0,800,1024,1024),slope=.47)
        for j in range(8):
            x=-.330+j*.074
            h.box('Drink selection button socket',(x,1.065,.351),(.049,.026,.020),rubber,.002)
            h.box('Drink selection button',(x,1.064,.367),(.033,.019,.019),black,.002)
        strip('Selection bottom rail',-.07,1.037,.624,.014,.357)
        # Lower front is assembled around a genuine cup opening, no dark decal substitute.
        h.box('Bronze delivery door upper',(-.070,.9575,.295),(.608,.155,.033),brass,.002)
        h.box('Bronze door lower',(-.070,.6775,.295),(.608,.045,.033),brass,.002)
        h.box('Bronze door right',(.053,.790,.295),(.361,.180,.033),brass,.002)
        h.box('Bronze door left',(-.366,.790,.295),(.027,.180,.033),brass,.002)
        h.box('Cup bay black back',(-.241,.791,.151),(.201,.179,.015),rubber)
        for x in [-.347,-.132]:h.box('Cup well side',(x,.789,.221),(.013,.185,.153),satin)
        h.box('Cup bay roof',(-.241,.876,.222),(.216,.017,.154),satin)
        h.box('Cup drip tray',(-.241,.700,.247),(.216,.015,.206),chrome,.001)
        for j in range(9):h.box('Drip grate slot',(-.330+j*.023,.709,.258),(.008,.003,.132),rubber)
        h.lathe('Cup dispenser nozzle',(-.241,.823,.224),[(.018,0),(.034,.032),(.037,.041)],black,12)
        frame(-.351,-.128,.690,.887,.319)
        h.box('Upper service instructions',(.347,1.603,.315),(.163,.183,.015),brass,.002)
        for y in [1.652,1.634,1.616,1.598,1.580]:h.box('Instruction engraved rule',(.348,y,.324),(.105,.002,.002),black)
        coin(.347,1.351,.330)
        h.box('Column lock plate',(.347,.984,.320),(.027,.071,.014),chrome,.002)
        h.tube('Door lock',[(.347,.991,.330),(.347,.991,.338)],.007,black,8)
        h.box('Service return bezel',(.339,.455,.318),(.090,.056,.020),chrome,.002)
        h.box('Service return flap',(.339,.455,.331),(.072,.039,.008),black)
        desc='Period walnut coffee vendor with original coffee harvest illustration, sloped eight-button panel and deep cup dispensing recess'
    stats=h.finish(kind,art,out,4000,specials=[('Advertising',graphics)],surface_normals={'Advertising':(0,0,1)},metadata={'description':desc},scale=2.2,camera=(2.8,-4.4,2.55),target=(0,0,.92))
    (out/'SOURCE.md').write_text(f'# {kind}\n\nOriginal low-poly Blender model based on user supplied period reference. Large advertisements are original fictional artwork generated with built-in imagegen, not photographs taken from the reference images. Selector labels are original procedural artwork. Generated source images are preserved under art/<asset>/advertising_source_imagegen.png; each runtime advertisement atlas remains 1024 x 1024.\n\nRebuild: python3 tools/blender/draw_vintage_vending.py, then Blender --background --python tools/blender/build_vintage_vending.py -- {kind}.\n\n{stats["triangles"]:,} triangles; {stats["surfaces"]} surfaces; 1K baked texture set and advertising atlas. Metres, +Z front, floor Y=0.\n')
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['vegas_cigarette_machine','office_coffee_machine']
for kind in args:build(kind)
