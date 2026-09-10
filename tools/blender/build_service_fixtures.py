"""Reference-based service fixtures. Construction coordinates are Godot X/Y-up/Z."""
from pathlib import Path
import sys,math,bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));import hero_prop as h
ROOT=HERE.parents[1]
def mats():
 return (h.material('Brushed institutional stainless',(.44,.48,.50),.34,.78,.05),h.material('Slate enamel fascia',(.10,.16,.21),.47,.25,.05),h.material('Dark gaskets and recesses',(.014,.018,.02),.63,.07,.05))
def finish(name,budget,**kw):
 return h.finish(name,ROOT/'art/service_fixtures'/name,ROOT/'models/authored/service_fixtures'/name,budget,**kw)
def servery():
 h.reset();steel,slate,black=mats()
 glass=h.material('Clear sneeze guard',(.70,.82,.84),.16,.08,0)
 glass.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.055
 glass.surface_render_method='DITHERED';glass.diffuse_color=(.70,.82,.84,.055);transparent=[]
 # Cabinet shell closes below the inset wells, leaving real space above .80.
 for x in [-1.66,0,1.66]:
  h.box('Lower cabinet body',(x,.44,0),(1.62,.72,.84),steel,.014)
  h.box('Slate customer fascia',(x,.45,.438),(1.47,.61,.025),slate,.006)
  h.box('Black inset plinth',(x,.04,0),(1.55,.08,.80),black,.005)
  for s in [-1,1]:h.tube('Graphic diagonal front band',[(x-.66,.18 if s==1 else .70,.455),(x+.66,.70 if s==1 else .18,.455)],.009,black,4)
  for dx in [-.79,.79]:h.box('Stainless panel stile',(x+dx,.48,.447),(.037,.80,.045),steel,.004)
  # Staff doors and handles visible on the back.
  for dx in [-.40,.40]:
   h.box('Rear cupboard door',(x+dx,.45,-.432),(.76,.61,.025),steel,.005)
   h.tube('Staff door pull',[(x+dx+.20,.45,-.45),(x+dx+.20,.45,-.48),(x+dx+.20,.58,-.48),(x+dx+.20,.58,-.45)],.007,steel,6)
 # Counter rim and separators; no solid slab closing the food wells.
 for z in [-.43,.39]:h.box('Continuous counter rolled edge',(0,.93,z),(5,.06,.10),steel,.009)
 for x in [-2.45,-1.22,0,1.22,2.45]:h.box('Counter separator',(x,.93,-.02),(.10,.06,.72),steel,.008)
 for x in [-1.835,-.61,.61,1.835]:
  h.box('Recessed gastronorm pan bottom',(x,.824,-.02),(1.09,.016,.64),steel,.005)
  for z in [-.34,.30]:h.box('Pan folded long side',(x,.878,z),(1.09,.108,.018),steel,.003)
  for dx in [-.54,.54]:h.box('Pan folded end',(x+dx,.878,-.02),(.018,.108,.64),steel,.003)
  for z in [-.355,.315]:h.box('Pan rolled rim',(x,.947,z),(1.10,.014,.025),steel,.003)
 for z in [.49,.545,.60]:h.tube('Customer tray slide rail',[(-2.48,.922,z),(2.48,.922,z)],.015,steel,6)
 for x in [-2.25,-.8,.8,2.25]:h.box('Tray rail bracket',(x,.892,.52),(.027,.045,.20),steel,.004)
 # Lower outer glass and taller centre section, anchored through counter.
 for x,w,top in [(-1.67,1.60,1.49),(0,1.66,1.80),(1.67,1.60,1.49)]:
  for dx in [-w/2+.04,w/2-.04]:
   h.tube('Vertical guard upright',[(x+dx,.97,.27),(x+dx,top,.27)],.017,steel,8)
   h.box('Glass clamp',(x+dx,top-.035,.267),(.05,.036,.018),steel,.004)
  transparent.append(h.box('Clear vertical sneeze shield',(x,(top+1.11)/2,.27),(w-.06,top-1.11,.008),glass))
  transparent.append(h.box('Glass upper shelf',(x,top,-.005),(w-.06,.008,.55),glass))
  h.tube('Polished shelf back rail',[(x-w/2+.03,top,-.28),(x+w/2-.03,top,-.28)],.008,steel,6)
 # Original unbranded checkout register, turned toward the staff side.
 h.box('Register foot',(-2.1,.998,-.04),(.37,.076,.32),steel,.015)
 h.box('Checkout register',(-2.1,1.085,-.025),(.29,.12,.23),slate,.015)
 h.box('Register screen inset',(-2.1,1.12,-.149),(.21,.076,.006),black,.003)
 for x in [-.075,-.025,.025,.075]:h.box('Register keys',(-2.1+x,1.044,-.17),(.033,.012,.029),steel,.003)
 finish('school_servery',6000,specials=[('ServeryGlass',transparent)],metadata={'counter_height_m':.96,'customer_side':'+Z'},scale=6.1,camera=(5,-6,3.3),target=(0,0,.85))
def shower():
 h.reset();steel,slate,black=mats()
 # Bent stainless cover: back at Z=0, front at -.10, rounded side returns.
 profile=[(-.15,0),(-.15,-.055),(-.14,-.085),(-.115,-.10),(.115,-.10),(.14,-.085),(.15,-.055),(.15,0)]
 verts=[(x,y,z) for y in [0,1.5] for x,z in profile];n=len(profile)
 h.mesh('Folded rounded stainless panel',verts,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],steel)
 # A low-profile hood, with a perforated downward face rather than a pipe.
 y=1.34
 rings=[(.082,y-.025),(.080,y+.005),(.061,y+.067),(.027,y+.088)]
 h.lathe('Dark anti-ligature shower hood',(0,0,-.128),rings,black,16)
 h.lathe('Downward spray plate',(0,y-.026,-.128),[(.074,0),(.074,.007)],steel,16)
 for a in range(8):
  t=math.tau*a/8
  h.lathe('Spray perforation',(math.cos(t)*.046,y-.027,-.128+math.sin(t)*.046),[(.0035,0),(.0035,.001)],black,6)
 h.tube('Rotary valve flange',[(0,.25,-.105),(0,.25,-.12)],.055,steel,16)
 h.tube('Round temperature control',[(0,.25,-.12),(0,.25,-.16),(0,.25,-.17)],.042,steel,16)
 h.box('Knob index',(0,.276,-.174),(.006,.020,.006),black,.001)
 red=h.material('Hot temperature marker',(.48,.035,.02),.6);blue=h.material('Cold temperature marker',(.025,.17,.44),.6)
 for x,m in [(-.026,blue),(.026,red)]:h.box('Temperature mark',(x,.307,-.102),(.014,.008,.003),m,.001)
 for y in [.07,1.44]:
  for x in [-.113,.113]:h.tube('Security screw',[(x,y,-.101),(x,y,-.104)],.007,steel,6)
 finish('prison_shower',1200,metadata={'mount_base_height_m':.9,'front_note':'-Z; back plane zero'},scale=1.95,camera=(1.3,3,1.25),target=(0,.05,.75))
def table():
 h.reset();steel,slate,black=mats()
 # Chamfered square top with a folded skirt, like the four-place steel unit.
 outline=[(-.38,-.50),(.38,-.50),(.50,-.38),(.50,.38),(.38,.50),(-.38,.50),(-.50,.38),(-.50,-.38)]
 verts=[(x,y,z) for y in [.72,.78] for x,z in outline];n=len(outline)
 h.mesh('Clipped-corner stainless tabletop',verts,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],steel)
 h.box('Floor bolted square footplate',(0,.018,0),(.58,.036,.58),steel,.008)
 h.box('Welded centre pedestal',(0,.374,0),(.20,.712,.20),steel,.007)
 for x in [-.235,.235]:
  for z in [-.235,.235]:h.lathe('Floor anchor bolt',(x,.036,z),[(.014,0),(.014,.012)],steel,6)
 for x,z in [(.8,0),(-.8,0),(0,.8),(0,-.8)]:
  h.box('Cantilever stool arm',(x*.51,.30,z*.51),(.82,.085,.09) if z==0 else (.09,.085,.82),steel,.006)
  h.box('Short raised seat support',(x,.375,z),(.075,.15,.075),steel,.004)
  h.lathe('Rolled stainless stool',(x,.435,z),[(.175,0),(.19,.008),(.19,.019),(.18,.027),(.06,.031)],steel,20)
  # Small gusset underneath the arm where it meets the upright.
  if z==0:h.mesh('Welded triangular arm gusset',[(x*.11,.24,-.035),(x*.11,.36,-.035),(x*.34,.24,-.035),(x*.11,.24,.035),(x*.11,.36,.035),(x*.34,.24,.035)],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],steel)
 finish('prison_mess_table',2500,metadata={'seat_count':4,'tabletop_height_m':.78,'footprint_m':1.98},scale=2.85,camera=(2.6,-3,2.3),target=(0,0,.39))
if __name__=='__main__':
 mode=next((a for a in sys.argv if a in ('servery','shower','table')),'all')
 if mode in ('servery','all'):servery()
 if mode in ('shower','all'):shower()
 if mode in ('table','all'):table()
