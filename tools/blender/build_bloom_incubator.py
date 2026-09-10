"""Low-poly containment machine with mechanical spine, fluid chamber and egg."""
from pathlib import Path
import sys,math,bpy,numpy as np
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1];ART=ROOT/'art/bloom_incubator';OUT=ROOT/'models/authored/bloom_incubator'
ART.mkdir(parents=True,exist_ok=True);h.reset()
ivory=h.material('Aged porcelain enamel',(.53,.59,.52),.46,.33,.12,.0007)
metal=h.material('Exposed dark titanium',(.105,.143,.145),.38,.72,.09,.0003)
rim=h.material('Machined tank rims',(.38,.44,.40),.26,.85,.065)
rubber=h.material('Black rubber hoses and gaskets',(.017,.029,.028),.76,0,.07,.0004)
ochre=h.material('Faded ochre safety paint',(.54,.32,.047),.53,.3,.1,.0002)
graphics=h.image_material('Lazarus printed controls',ROOT/'art/hero_props/labels.png',.65)
labels=[];cx=.23;cz=.035
# Foundation, rigid rear spine and asymmetric layered armor.
h.box('Common machine foundation',(-.08,.07,-.035),(1.37,.14,.86),metal,.045,2)
h.box('Isolated rear column',(-.44,1.17,-.20),(.49,2.14,.46),metal,.052,2)
h.section('Spine porcelain armor',[(-.42,.15),(.03,.15),(.13,.34),(.05,.69),(.04,1.65),(-.02,2.16),(-.35,2.25),(-.44,2.12)],-.665,-.235,ivory,.027)
for y,z,w,ht in [(.46,.138,.36,.49),(1.17,.067,.34,.52),(1.88,.014,.34,.49)]:
 h.box('Recessed spine panel',(-.455,y,z),(w,ht,.035),metal,.022)
 h.box('Removable porcelain panel',(-.455,y,z+.021),(w-.026,ht-.026,.025),ivory,.02)
 for s in [-1,1]:
  for sy in [-1,1]:h.tube('Panel captive bolt',[(-.455+s*(w/2-.035),y+sy*(ht/2-.035),z+.036),(-.455+s*(w/2-.035),y+sy*(ht/2-.035),z+.041)],.008,rim,6)
labels.append(h.decal('Spine serial plate',(-.455,.47,.184),(.25,.21),graphics,3))
labels.append(h.decal('Upper safety plate',(-.455,1.87,.056),(.19,.15),graphics,8))
# Circular inspection hatch with latch across its face.
hc=(-.447,1.02,.125)
for rad,depth,mat in [(.176,.031,metal),(.155,.045,ochre),(.119,.052,rim),(.093,.058,ivory)]:
 h.tube('Layered inspection hatch',[(hc[0],hc[1],hc[2]),(hc[0],hc[1],hc[2]+depth)],rad,mat,24)
h.tube('Hatch locking bar',[(-.507,.93,.203),(-.387,1.11,.203)],.023,metal,8)
for sx in [-1,1]:h.tube('Spine foot anchor',[(-.48+sx*.16,.11,-.31),(-.48+sx*.16,.162,-.31)],.024,rim,8)
# Service hose bundled down the exposed outer edge, generous bend radius.
for dz,r in [(-.11,.029),(.015,.017)]:
 h.tube('External service hose',[(-.41,2.21,-.25+dz),(-.63,2.18,-.25+dz),(-.70,2.00,-.22+dz),(-.704,1.63,-.18+dz),(-.695,1.12,-.15+dz),(-.66,.81,-.12+dz),(-.61,.65,-.08+dz)],r,rubber,8)
for y in [1.12,1.62,1.96]:h.box('Hose retaining saddle',(-.693,y,-.165),(.074,.058,.17),metal,.009)
# Layered tank pedestal and upper sealed lid. Circular, chamfered, readable metal lips.
h.lathe('Tank lower foot',(cx,0,cz),[(.355,.07),(.437,.095),(.45,.145),(.45,.21),(.40,.24)],metal,32)
h.lathe('Tank bottom armor',(cx,0,cz),[(.395,.21),(.433,.255),(.433,.45),(.397,.495),(.389,.535)],ivory,32)
h.lathe('Lower seal gasket',(cx,0,cz),[(.397,.491),(.406,.502),(.406,.525),(.397,.54)],rubber,32)
h.lathe('Lower machined tank collar',(cx,0,cz),[(.41,.531),(.418,.55),(.418,.577),(.403,.592)],rim,32)
h.lathe('Top seal gasket',(cx,0,cz),[(.401,1.738),(.411,1.751),(.411,1.78)],rubber,32)
h.lathe('Tank lid lower rim',(cx,0,cz),[(.40,1.762),(.438,1.79),(.438,1.825),(.417,1.842)],rim,32)
h.lathe('Tank domed lid',(cx,0,cz),[(.417,1.824),(.435,1.85),(.434,1.98),(.395,2.035),(.285,2.065),(.27,2.08)],ivory,32)
h.lathe('Lid pressure relief',(cx,0,cz),[(.105,2.074),(.105,2.1),(.056,2.12)],metal,16)
# Spine-mounted lid bridge and discrete locking clamps at cardinal angles.
h.box('Rigid top lid bridge',(-.01,2.105,-.17),(.84,.117,.20),metal,.025)
h.box('Top bridge armor',(-.02,2.163,-.17),(.78,.04,.176),ivory,.014)
for a in [0,math.pi/2,math.pi,3*math.pi/2]:
 x=cx+.429*math.cos(a);z=cz+.429*math.sin(a)
 for y in [.375,1.895]:
  ob=h.box('Captive cylinder latch',(x,y,z),(.105,.19,.063),metal,.015);ob.rotation_euler.z=-a+math.pi/2
  xa=cx+.467*math.cos(a);za=cz+.467*math.sin(a)
  h.tube('Rubber latch grip',[(xa,y-.04,za),(xa,y+.04,za)],.017,rubber,6)
for x in [cx-.36,cx+.36]:
 h.tube('Rear tank tie rod',[(x,.40,cz-.235),(x,1.95,cz-.235)],.018,metal,8)
 for y in [.51,1.77]:h.tube('Tie rod gland',[(x,y-.024,cz-.235),(x,y+.024,cz-.235)],.031,rim,8)
# External piping leaves the viewing face clear.
h.tube('Fluid return pipe',[(-.18,.29,-.12),(-.27,.30,-.16),(-.3,.38,-.16),(-.3,.7,-.16)],.025,rubber,8)
h.tube('Upper feed pipe',[(-.22,1.96,-.18),(-.14,1.96,-.29),(.03,1.96,-.31)],.025,rubber,8)
for y in [.67,1.95]:h.box('Pipe locking collar',(-.27,y,-.16),(.072,.08,.07),ochre,.006)
# Forward angled control block with two teal displays and warnings.
h.section('Control console wedge',[(.37,.19),(.54,.19),(.54,.56),(.43,.66),(.37,.66)],cx+.15,cx+.39,metal,.015)
labels.append(h.decal('Vital signs screen',(cx+.272,.445,.558),(.20,.235),graphics,2))
labels.append(h.decal('Pressure readout',(cx+.265,.635,.481),(.16,.125),graphics,7))
labels.append(h.decal('Lower tank warning',(cx-.12,.354,.475),(.15,.15),graphics,1))
for s in [-1,1]:
 h.box('Caution inlay',(cx+s*.25,1.921,cz+.359),(.032,.093,.007),ochre,.005)
 for y in [.155,.57,1.8,2.02]:
  h.tube('Tank fastener',[(cx+s*.29,y,cz+.29),(cx+s*.29,y,cz+.302)],.009,metal,6)
# Glass and fluid are independent low-poly surfaces for controlled runtime blending.
def transparent(name,color,alpha,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,alpha)
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Alpha'].default_value=alpha
 bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=.1
 m.surface_render_method='DITHERED';return m
glassmat=transparent('Containment glass',(.48,.74,.70),.13,.12)
liquidmat=transparent('Preservation fluid',(.22,.43,.17),.17,.25)
glass=h.lathe('ContainmentGlass',(cx,0,cz),[(.397,.58),(.397,1.766)],glassmat,48,False)
fluid=h.lathe('PreservationLiquid',(cx,0,cz),[(.378,.583),(.378,1.663)],liquidmat,40,True)
# An asymmetric organic egg, with a deterministic seamless vascular texture.
size=512;y,x=np.mgrid[:size,:size]/size
n=np.zeros_like(x)
for f,a,p in [(2,.45,.2),(5,.22,1.7),(11,.16,3.1),(27,.075,5.2),(63,.035,1.1)]:n+=a*np.sin(x*math.tau*f+np.sin(y*math.tau*(f*.63))*2+p)*np.cos(y*math.tau*(f*.72)+p)
vein=np.abs(np.sin(x*math.tau*7+np.sin(y*math.tau*3)*2+n*3.2))
vein=np.clip((.11-vein)*10,0,1)
base=np.stack((.43+n*.14,.275+n*.09,.20+n*.095),axis=-1)
base=base*(1-vein[:,:,None]*.69)+vein[:,:,None]*np.array([.06,.014,.026])
pixels=np.ones((size,size,4),dtype=np.float32);pixels[:,:,:3]=np.clip(base,0,1)
im=bpy.data.images.new('Organic vessel membrane',width=size,height=size,alpha=False);im.pixels.foreach_set(pixels.ravel())
im.filepath_raw=str(ART/'egg_membrane.png');im.file_format='PNG';im.save();im.pack()
eggmat=h.image_material('Veined translucent membrane',ART/'egg_membrane.png',.05,.32)
verts=[];faces=[];rings=16;sides=28
for i in range(rings+1):
 t=i/rings;a=math.pi*t;r=max(.005,.246*math.sin(a)*(1-.20*t))
 for j in range(sides):
  u=math.tau*j/sides;rr=r*(1+.045*math.sin(3*u+4*t)+.021*math.sin(7*u-9*t))
  verts.append((cx+.027*math.sin(t*math.pi)+rr*math.cos(u),.762+.831*(1-math.cos(math.pi*t))*.5,cz+rr*math.sin(u)*.92))
for i in range(rings):
 for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
faces.extend([tuple(reversed(range(sides))),tuple(range(rings*sides,(rings+1)*sides))])
egg=h.mesh('LivingEgg',verts,faces,eggmat,True);uv=egg.data.uv_layers.new(name='Membrane')
for f in egg.data.polygons:
 js=[egg.data.loops[l].vertex_index%sides for l in f.loop_indices]
 for li,j in zip(f.loop_indices,js):
  vi=egg.data.loops[li].vertex_index;u=j/sides
  if max(js)-min(js)>sides/2 and j==0:u=1
  uv.data[li].uv=(u,vi//sides/rings)
# Small fluid bubbles, one mesh, animated together without particle emitters/lights.
bubbles=[];bubblemat=transparent('Gas pearls',(.31,.73,.48),.42,.12)
for i in range(11):
 a=i*2.399;r=.285+.035*math.sin(i*2);yy=.67+(i*.137)%1.02
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.009+.006*(i%3),location=h.xyz((cx+r*math.cos(a),yy,cz+r*math.sin(a))))
 ob=bpy.context.object;ob.name='Suspended fluid bubble';ob.data.materials.append(bubblemat);h.parts.append(ob);bubbles.append(ob)
h.finish('bloom_incubator',ART,OUT,8000,specials=[('PrintedGraphics',labels),('ContainmentGlass',[glass]),('PreservationLiquid',[fluid]),('LivingEgg',[egg]),('FluidBubbles',bubbles)],
 metadata={'egg_center':[cx,1.18,cz],'fluid_bottom_m':.583,'fluid_surface_m':1.663,'glass_radius_m':.397},scale=2.9,camera=(3,-5,2.8),target=(0,0,1.14))
