"""Build the low oval stainless carousel from the supplied reference in Blender."""
from pathlib import Path
import sys,math,bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1];ART=ROOT/'art/airport_carousel';OUT=ROOT/'models/authored/airport_carousel'
h.reset()
steel=h.material('Satin brushed stainless',(.50,.54,.57),.31,.82,.045,.00018)
edge=h.material('Polished folded edge',(.68,.71,.72),.22,.91,.025)
dark=h.material('Rubber and black enamel',(.016,.022,.026),.75,0,.05,.0002)
yellow=h.material('Airport yellow powdercoat',(.82,.63,.018),.43,.15,.04)
red=h.material('Ruby beacon lens',(.52,.008,.003),.23,.1,.03)
graphics=h.image_material('Arrival and service graphics',ROOT/'art/hero_props/labels.png',.5)
labels=[]
# Full-size baggage claim: 7 x 3m, with a 665mm belt deck. Keep signage and
# feed equipment human-sized, moving their mounts onto the enlarged island.
HALF=2.0;N=64
RADIAL_SCALE=1.5/1.04
HEIGHT_SCALE=.665/.415
FIXTURE_LIFT=.511*(HEIGHT_SCALE-1.0)
END_SHIFT=HALF-1.16
def shift_parts(first,dy=0,dz=0):
 for ob in h.parts[first:]:ob.location+=Vector(h.xyz((0,dy,dz)))
def perimeter(r):
 r*=RADIAL_SCALE
 points=[]
 # Sample curved ends and straight runs at similar spacing for belt UVs.
 for i in range(16):
  a=math.pi*i/16;points.append((r*math.cos(a),HALF+r*math.sin(a)))
 for i in range(16):points.append((-r,HALF-2*HALF*i/16))
 for i in range(16):
  a=math.pi+math.pi*i/16;points.append((r*math.cos(a),-HALF+r*math.sin(a)))
 for i in range(16):points.append((r,-HALF+2*HALF*i/16))
 return points
def shell(name,profile,mat,cap=True):
 verts=[(x,y*HEIGHT_SCALE,z) for r,y in profile for x,z in perimeter(r)]
 faces=[]
 for k in range(len(profile)-1):
  for i in range(N):a=k*N+i;b=k*N+(i+1)%N;faces.append((a,b,b+N,a+N))
 if cap:faces.extend([tuple(reversed(range(N))),tuple(range((len(profile)-1)*N,len(profile)*N))])
 return h.mesh(name,verts,faces,mat,True)
shell('Recessed black toe rail',[(.995,.045),(.995,.16)],dark)
shell('Continuous stainless skirt',[(1.008,.115),(1.04,.16),(1.04,.38),(1.025,.413)],steel)
shell('Rolled outer stainless lip',[(.99,.397),(1.031,.414),(1.04,.445),(.998,.459),(.972,.44)],edge,False)
shell('Inner sloped stainless island',[(.39,.409),(.38,.44),(.335,.49),(.29,.50)],steel)
shell('Inset island lid seam',[(.292,.501),(.290,.504)],dark,False)
shell('Raised island access lid',[(.282,.503),(.271,.511)],steel)
# Belt as one annular mesh; UV.u is distance along the racetrack, animated in game.
beltmat=h.image_material('Segmented rubber conveyor belt',ROOT/'art/hero_props/carousel_belt.png',rough=.82)
belt=shell('CarouselBelt',[(.392,.415),(.975,.415)],beltmat,False)
uv=belt.data.uv_layers.new(name='Belt travel metres')
path=perimeter(.684);distance=[0.0]
for i in range(1,N+1):distance.append(distance[-1]+math.dist(path[i-1],path[i%N]))
for i,face in enumerate(belt.data.polygons):
 values=[(distance[i],0),(distance[i+1],0),(distance[i+1],1),(distance[i],1)]
 for li,v in zip(face.loop_indices,values):uv.data[li].uv=v
# Hood sits wholly on the inner island, with a proper dark rubber strip mouth.
start=len(h.parts)
h.section('Sloping feed hood',[(-1.51,.50),(-1.51,.93),(-.99,.93),(-.80,.51)],-.32,.32,steel,.018)
h.box('Black feed opening',(0,.70,-1.523),(.575,.35,.009),dark,.009)
for x in [-.25,-.194,-.138,-.082,-.026,.03,.086,.142,.198,.254]:
 h.box('Hanging curtain strip',(x,.702,-1.532),(.049,.346,.008),dark,.002)
for s in [-1,1]:h.tube('Feed mouth steel edging',[(s*.298,.52,-1.54),(s*.298,.9,-1.54)],.012,edge,6)
labels.append(h.decal('Feed warning',(0,.731,-1.54),(.12,.12),graphics,1,yaw=math.pi))
shift_parts(start,FIXTURE_LIFT,-END_SHIFT)
# Black and yellow integrated carousel number pylon, saved as separate named mesh.
start=len(h.parts)
h.box('Number pylon black',(0,1.12,1.26),(.45,1.22,.15),dark,.012)
h.box('Number pylon yellow spine',(-.25,1.12,1.26),(.08,1.22,.17),yellow,.006)
h.box('Pylon plinth',(0,.525,1.26),(.55,.037,.26),edge,.008)
shift_parts(start,FIXTURE_LIFT,END_SHIFT)
# Two-post arrivals display, carefully positioned in the island.
start=len(h.parts)
for z in [-.14,.30]:
 h.tube('Monitor support',[(0,.50,z),(0,1.07,z)],.017,steel)
 h.lathe('Monitor mounting foot',(0,0,z),[(.032,.51),(.032,.535)],dark,12)
h.box('Arrivals monitor housing',(0,1.235,.08),(.054,.39,.71),dark,.017)
labels.append(h.decal('Arrivals display',(.031,1.235,.08),(.658,.342),graphics,0,yaw=math.pi/2))
h.lathe('Beacon socket',(0,0,-.42),[(.035,.51),(.035,.538),(.022,.57),(.019,.595)],steel,12)
h.lathe('Red warning beacon',(0,0,-.42),[(.024,.592),(.024,.648),(.013,.67)],red,12)
shift_parts(start,FIXTURE_LIFT)
for s in [-1,1]:
 for z in [-.75,.30]:
  h.box('Service access panel',(s*1.041*RADIAL_SCALE,.258*HEIGHT_SCALE,z),(.004,.24,.75),steel,.005)
  labels.append(h.decal('Skirt service warning',(s*1.045*RADIAL_SCALE,.265*HEIGHT_SCALE,z),(.16,.105),graphics,1,yaw=s*math.pi/2))
h.finish('airport_carousel',ART,OUT,4500,specials=[('CarouselBelt',[belt]),('PrintedGraphics',labels)],
 metadata={'belt_half_straight_m':HALF,'belt_path_radius_m':.684*RADIAL_SCALE,'belt_height_m':.665,'number_position':[0,1.30+FIXTURE_LIFT,1.343+END_SHIFT]},scale=8.1,camera=(6,-9,6.3),target=(0,0,.95))
