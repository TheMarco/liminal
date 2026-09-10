"""Low-poly school furniture hero props: bleachers, cafeteria table, cupboard."""
from pathlib import Path
import sys, bpy, math
HERE=Path(__file__).resolve().parent; sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1]

def build_bleachers():
 h.reset(); art=ROOT/'art/school_furniture/bleachers'; out=ROOT/'models/authored/school_furniture/bleachers'
 alum=h.material('Brushed aluminum',(.48,.52,.54),.3,.8,.04,.0002); dark=h.material('Dark steel',(.055,.065,.07),.58,.7); wood=h.material('Wood runners',(.25,.12,.045),.68,.05,.15)
 # Manufactured seat/footboard extrusions on three complete support frames.
 for i in range(4):
  y=.42+.42*i; z=-.4-.62*i
  h.box('Aluminum seat plank',(0,y-.025,z),(4,.05,.38),alum,.008)
  h.box('Aluminum footboard',(0,.42*i+.10,z+.30),(4,.045,.36),alum,.006)
  for x in [-1.65,0,1.65]:
   h.box('Vertical square support',(x,(.09+y-.025)/2,z),(.045,y-.115,.045),alum,.003)
   h.box('Seat cantilever bracket',(x,y-.055,z+.045),(.045,.045,.43),alum,.003)
   h.box('Footboard bracket',(x,.42*i+.07,z+.30),(.045,.045,.39),alum,.003)
   for yy in [y-.075,.14]:h.tube('Hex frame bolt',[(x-.025,yy,z),(x-.031,yy,z)],.013,alum,6)
 for x in [-1.65,0,1.65]:
  h.box('Wood floor runner',(x,.045,-1.25),(.18,.09,2.5),wood,.006)
  h.tube('Long rising diagonal brace',[(x,.12,-.12),(x,1.57,-2.26)],.022,alum,4)
  h.tube('Rear frame diagonal',[(x,.12,-2.36),(x,.78,-1.02)],.020,alum,4)
 for y,z in [(.13,-2.26),(1.5,-2.26),(.13,-.4)]:h.tube('Transverse frame tie',[(-1.65,y,z),(1.65,y,z)],.020,alum,4)
 h.finish('school_bleachers',art,out,4500,metadata={'tiers':4,'length_m':4.0,'tier_heights_m':[.42,.84,1.26,1.68]},scale=5,camera=(5,-6,3.5),target=(0,1.2,.8))

def build_table():
 h.reset(); art=ROOT/'art/school_furniture/cafeteria_table'; out=ROOT/'models/authored/school_furniture/cafeteria_table'
 top=h.material('Grey laminate',(.38,.4,.4),.5,.05,.06); edge=h.material('Dark edging',(.045,.05,.05),.6,.5); metal=h.material('Black folding steel',(.025,.03,.032),.5,.75); rubber=h.material('Caster rubber',(.018,.02,.02),.8)
 for x in [-.727,.727]:
  h.box('Black laminate edge band',(x,.727,0),(1.446,.038,.76),edge,.008)
  h.box('Grey split laminate surface',(x,.746,0),(1.432,.008,.746),top,.005)
 for z in [-.66,.66]:
  for x in [-.727,.727]:
   h.box('Bench black edge',(x,.427,z),(1.446,.038,.28),edge,.006)
   h.box('Bench laminate surface',(x,.446,z),(1.432,.008,.269),top,.004)
  h.box('Underbench box beam',(0,.39,z),(2.84,.04,.05),metal,.003)
 for x in [-1.20,1.20]:
  # Full transverse frames physically support both tabletop and benches.
  h.box('Table crossbeam',(x,.692,0),(.055,.04,.71),metal,.004)
  h.box('Bench crossbeam',(x,.385,0),(.055,.045,1.39),metal,.004)
  h.box('Bottom transverse foot',(x,.147,0),(.065,.055,1.48),metal,.005)
  for z in [-.29,.29]:
   h.tube('Folding tubular leg',[(x,.672,z),(x,.22,z),(x,.175,z*2.25)],.024,metal,8)
   h.tube('Diagonal folding stay',[(x,.22,z),(x*.32,.674,z)],.013,metal,6)
  for z in [-.59,-.73,.59,.73]:
   h.tube('Rubber caster wheel',[(x-.019,.06,z),(x+.019,.06,z)],.06,rubber,12)
   for dx in [-.027,.027]:
    h.box('Caster fork cheek',(x+dx,.091,z),(.012,.072,.024),metal,.002)
   h.tube('Caster axle',[(x-.035,.06,z),(x+.035,.06,z)],.014,edge,8)
   h.box('Caster swivel head',(x,.128,z),(.065,.017,.044),edge,.003)
 for z in [-.29,.29]:
  h.box('Undertop longitudinal beam',(0,.675,z),(2.4,.038,.045),metal,.003)
  h.tube('Centre folding pivot',[(-.06,.65,z),(.06,.65,z)],.035,edge,12)
  h.tube('Centre lock pin',[(-.064,.65,z),(.064,.65,z)],.013,metal,8)
 h.finish('school_cafeteria_table',art,out,4000,metadata={'length_m':2.9,'top_height_m':.75,'bench_height_m':.45,'caster_count':8},scale=4.2,camera=(4,-5,3),target=(0,0,.4))

def build_cupboard():
 h.reset(); art=ROOT/'art/school_furniture/cupboard'; out=ROOT/'models/authored/school_furniture/cupboard'
 steel=h.material('Grey blue painted steel',(.14,.18,.21),.62,.35,.07,.00025); seam=h.material('Recessed seams',(.035,.045,.05),.7,.4); lock=h.material('Black lock',(.015,.018,.02),.3,.8); silver=h.material('Lock handle',(.55,.58,.58),.24,.8)
 h.box('Folded steel shell',(0,.975,0),(1.0,1.95,.46),steel,.025)
 for x in [-.245,.245]: h.box('Recessed door',(x,.98,.236),(.47,1.78,.018),steel,.012)
 h.box('Center door seam',(0,.98,.25),(.018,1.79,.012),seam,.003)
 h.box('Top seam',(0,1.89,.25),(.94,.018,.012),seam,.002); h.box('Bottom seam',(0,.08,.25),(.94,.018,.012),seam,.002)
 h.box('Lock backplate',(0,1.02,.267),(.12,.14,.018),lock,.008)
 h.tube('Rotary lock',[(0,1.02,.278),(0,1.02,.326)],.038,lock,12)
 h.tube('Silver rotary face',[(0,1.02,.327),(0,1.02,.332)],.031,silver,12)
 h.box('Silver lock grip',(0,1.02,.340),(.017,.050,.02),silver,.003)
 for x in [-.475,.475]:
  for y in [.25,1.7]: h.lathe('Side hinge',(x,y,.245),[(.014,0),(.014,.06)],silver,8)
 h.finish('school_cupboard',art,out,1500,metadata={'height_m':1.95,'width_m':1.0,'depth_m':.46,'door_count':2},scale=3.8,camera=(3,-4,2.4),target=(0,0,1))

if __name__=='__main__':
 mode=next((a for a in sys.argv if a in ('bleachers','table','cupboard')),'all')
 if mode in ('bleachers','all'):build_bleachers()
 if mode in ('table','all'):build_table()
 if mode in ('cupboard','all'):build_cupboard()
