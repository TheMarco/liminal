"""Low-poly 1980s brown/chrome/woodgrain change cabinet; metres, +Z front."""
from pathlib import Path
import sys, math
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1]
ART=ROOT/'art/vegas_change_machine'
OUT=ROOT/'models/authored/vegas_change_machine'
h.reset()
brown=h.material('Bronze brown powder coat',(.105,.067,.033),.49,.25,.075)
dark=h.material('Dark brown enamel sides',(.037,.026,.017),.44,.28,.06)
black=h.material('Recess shadow and rubber',(.008,.009,.008),.8,.05,.03)
chrome=h.material('Worn satin chrome',(.54,.57,.55),.28,.86,.028)
steel=h.material('Brushed coin well steel',(.27,.29,.27),.41,.78,.07)
wood=h.material('Bookmatched walnut laminate',(.15,.052,.012),.43,0,.04)
nt=wood.node_tree;bs=nt.nodes.get('Principled BSDF')
tex=nt.nodes.new('ShaderNodeTexCoord')
mapping=nt.nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(5,3,.42)
nt.links.new(tex.outputs['Generated'],mapping.inputs[0])
wave=nt.nodes.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='X'
wave.inputs['Scale'].default_value=5.5;wave.inputs['Distortion'].default_value=9
wave.inputs['Detail'].default_value=4;wave.inputs['Detail Scale'].default_value=1.4
nt.links.new(mapping.outputs[0],wave.inputs['Vector'])
ramp=nt.nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
for i,(at,col) in enumerate([(0,(.027,.008,.003,1)),(.23,(.09,.024,.006,1)),(.53,(.25,.079,.016,1)),(.74,(.12,.028,.005,1)),(1,(.043,.01,.002,1))]):
    el=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(at)
    el.position=at;el.color=col
nt.links.new(wave.outputs['Color'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
# The source has a raked control face and a sloping lower service door.
h.box('Recessed toe kick',(0,.04,-.02),(.99,.08,.54),black,.005)
h.section('Tapered lower enclosure',[(-.31,.06),(.245,.06),(.338,.685),(-.31,.685)],-.52,.52,dark)
h.section('Slanted walnut service door',[(.247,.085),(.331,.653),(.346,.653),(.262,.085)],-.493,.493,wood)
h.section('Bottom stainless kick strip',[(.245,.06),(.253,.11),(.268,.11),(.260,.06)],-.518,.518,steel)
# Upper face retreats 16cm per metre of height. All hardware follows that plane.
def rake(z,y): return z-.16*(y-.80)
# A rear core and separate cheeks leave the payout bay genuinely open.
h.box('Upper rear core',(0,1.20,-.19),(1.035,1.04,.24),dark,.005)
for x0,x1 in [(-.536,-.503),(.503,.536)]:
    h.section('Raked side cheek',[(-.31,.68),(.347,.68),(.176,1.733),(-.31,1.733)],x0,x1,dark)
    h.section('Continuous angled steel edge',[(.327,.682),(.156,1.733),(.182,1.733),(.353,.682)],x0,x1,chrome)
h.box('Steel top cap',(0,1.723,-.07),(1.072,.026,.49),steel,.004)
upper_start=len(h.parts)
h.box('Copper control door',(0,1.245,.238),(.99,.874,.026),brown,.004)
printing=h.image_material('Original change face printing',ART/'face_print.png',0,.52)
face=h.decal('Printed main fascia',(0,1.245,.252),(.982,.868),printing,grid=1)
# Continuous top hinge, visible above the printed CHANGE header.
h.tube('Long piano hinge',[(-.48,1.690,.265),(.48,1.690,.265)],.009,steel,8)
# Bill denomination plate on the left: broad chamfered metal picture frame.
for x in [-.473,.095]:
    h.box('Bill panel side frame',(x,1.382,.270),(.024,.198,.024),chrome,.002)
for y in [1.283,1.481]:
    h.box('Bill panel horizontal frame',(-.189,y,.270),(.59,.018,.024),chrome,.002)
# Acceptor has a sloped chrome throat rather than a projecting flat tile.
h.box('Acceptor shadow pocket',(.305,1.383,.267),(.334,.201,.03),black,.003)
for x in [.134,.478]:
    h.box('Acceptor frame upright',(x,1.383,.284),(.018,.224,.033),chrome,.002)
for y in [1.272,1.494]:
    h.box('Acceptor frame lintel',(.305,y,.284),(.36,.018,.033),chrome,.002)
h.box('Acceptor inner plate',(.305,1.383,.276),(.305,.19,.01),steel)
h.box('Coin reader vertical metal',(.212,1.389,.289),(.051,.16,.016),chrome,.002)
h.box('Vertical coin insertion slot',(.212,1.384,.300),(.010,.085,.006),black)
h.box('Coin reader upper window',(.212,1.445,.300),(.030,.021,.006),black)
h.box('Reader dark inlet',(.366,1.415,.282),(.091,.042,.008),black)
h.section('Sloped bill inlet lower funnel',[(.283,1.393),(.299,1.338),(.306,1.342),(.289,1.397)],.308,.424,chrome)
for x0,x1 in [(.301,.309),(.425,.433)]:
    h.section('Bill inlet cheek',[(.281,1.447),(.303,1.342),(.303,1.447)],x0,x1,chrome)
h.box('Bill entry top overhang',(.367,1.450,.304),(.128,.018,.05),chrome,.002)
# Vertical release lever over a black plate with two side fasteners.
h.box('Central release black mounting plate',(.015,.920,.269),(.113,.042,.015),black,.002)
for x in [-.026,.056]:
    h.tube('Release plate screw',[(x,.920,.279),(x,.920,.284)],.008,steel,10)
h.box('Vertical chrome release lever',(.015,.920,.287),(.037,.083,.022),chrome,.003)
h.tube('Release dark round button',[(.015,.914,.300),(.015,.914,.304)],.011,black,12)
for ob in h.parts[upper_start:]:
    # Transform world vertices so printed art, frames and hardware share rake.
    for v in ob.data.vertices:
        world=ob.matrix_world@v.co
        world.y += .16*(world.z-.80)  # Blender -Y equals Godot +Z.
        v.co=ob.matrix_world.inverted()@world
# Payout deck slopes toward the player. It is physically cut around two bowls.
def deck_y(z): return .752-.18*(z-.06)
def deck_piece(name,x0,x1,z0,z1):
    h.section(name,[(z0,deck_y(z0)),(z1,deck_y(z1)),
                   (z1,deck_y(z1)-.012),(z0,deck_y(z0)-.012)],x0,x1,steel)
# Tessellate around ONE large left cup and a small return well at the back.
xs=[-.503,-.34,-.10,.125,.215,.503]
zs=[.06,.11,.175,.275,.31,.350]
for x0,x1 in zip(xs,xs[1:]):
    for z0,z1 in zip(zs,zs[1:]):
        x=(x0+x1)/2;z=(z0+z1)/2
        if (-.34<x<-.10 and .11<z<.31) or (.125<x<.215 and .175<z<.275):
            continue
        deck_piece('Continuous payout shelf',x0,x1,z0,z1)
def bowl(name,cx,half_x):
    cz=.210;hz=.100
    corner=math.atan2(hz,half_x)
    angles=sorted(set([i*math.tau/16 for i in range(16)]+
                     [corner,math.pi-corner,math.pi+corner,math.tau-corner]))
    n=len(angles);verts=[]
    # Rectangle perimeter joins the surrounding deck exactly; inner rings curve down.
    for ring in range(5):
        for a in angles:
            ca,sa=math.cos(a),math.sin(a)
            if ring==0:
                r=min(half_x/max(abs(ca),1e-8),hz/max(abs(sa),1e-8))
                x,z=cx+r*ca,cz+r*sa;y=deck_y(z)
            else:
                scale=[0,1,.86,.56,.20][ring]
                x=cx+(half_x-.015)*scale*ca;z=cz+.085*scale*sa
                y=deck_y(z)-[0,0,.035,.064,.076][ring]
            verts.append((x,y,z))
    top_count=len(verts)
    verts += [(x,y-.006,z) for x,y,z in verts]
    faces=[]
    for ring in range(4):
        for j in range(n):
            a=ring*n+j;b=ring*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
            faces.append((a+top_count,a+n+top_count,b+n+top_count,b+top_count))
    faces += [tuple(range(4*n,5*n)),tuple(reversed(range(top_count+4*n,top_count+5*n)))]
    for j in range(n):
        k=(j+1)%n;faces.append((j,j+top_count,k+top_count,k))
    h.mesh(name,verts,faces,chrome,True)
bowl('Single left payout cup',-.220,.120)
# Small rectangular reject tray: a short well immediately below the return chute.
verts=[]
for inset,drop in [(0,0),(.008,0),(.016,.034)]:
    for x,z in [(.125+inset,.175+inset),(.215-inset,.175+inset),
                (.215-inset,.275-inset),(.125+inset,.275-inset)]:
        verts.append((x,deck_y(z)-drop,z))
faces=[]
for ring in range(2):
    for j in range(4):
        a=ring*4+j;b=ring*4+(j+1)%4;faces.append((a,b,b+4,a+4))
faces.append((8,9,10,11))
# Closed thin stamped shell, so the well renders correctly with backface culling.
count=len(verts)
verts += [(x,y-.004,z) for x,y,z in verts]
faces += [tuple(i+count for i in reversed(f)) for f in faces[:]]
for j in range(4):
    k=(j+1)%4;faces.append((j,j+count,k+count,k))
h.mesh('Small rectangular reject tray',verts,faces,steel)
h.box('Payout bay dark rear',(0,.79,.061),(.99,.08,.008),black)
h.box('Left payout chute',(-.22,.790,.090),(.135,.055,.018),black)
h.section('Left coin chute hood',[(.081,.818),(.141,.768),(.148,.773),(.089,.823)],-.295,-.145,steel)
h.box('Small reject chute mouth',(.170,.790,.181),(.062,.043,.015),black,.002)
for x in [.128,.212]:
    h.box('Reject chute side cheek',(x,.776,.193),(.008,.055,.055),chrome,.001)
h.box('Reject chute upper lip',(.170,.806,.202),(.084,.008,.058),steel,.001)
h.section('Broad slanted shelf fascia',[(.350,.700),(.340,.660),(.326,.660),(.335,.700)],-.536,.536,chrome)
h.finish('vegas_change_machine',ART,OUT,3000,
         specials=[('Printed face',[face])],surface_normals={'Printed face':(0,.16,1)},
         metadata={'description':'Raked vintage change cabinet, sloped walnut base, one left payout bowl and small rectangular reject tray and large CHANGE fascia'},
         scale=2.15,camera=(2.5,-4,2.45),target=(0,0,.88))
