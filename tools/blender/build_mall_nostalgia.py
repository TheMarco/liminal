"""Reference-led low-poly mall landmarks. Run in Blender background mode."""
import bpy,sys,math
from mathutils import Vector
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import hero_prop as h
ROOT=Path(__file__).resolve().parents[2]

def wood(name,color):
    m=h.material(name,color,.57,variation=.22,bump=.001)
    nt=m.node_tree
    for n in nt.nodes:
        if n.type=='TEX_NOISE':
            geo=nt.nodes.new('ShaderNodeTexCoord');v=nt.nodes.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=(3,3,.035);nt.links.new(geo.outputs['Generated'],v.inputs[0]);nt.links.new(v.outputs[0],n.inputs['Vector']);n.inputs['Scale'].default_value=13
    return m

def booth():
    h.reset();name='mall_photo_booth';art=ROOT/'art'/name;art.mkdir(parents=True,exist_ok=True)
    white=h.material('Warm ivory aluminum',(.72,.73,.70),.38,.6)
    silver=h.material('Brushed aluminum',(.48,.51,.52),.31,.8)
    walnut=wood('Woodgrain laminate',(.20,.08,.032))
    orange=h.material('Heavy burnt orange curtain',(.63,.105,.018),.92,variation=.15,bump=.001)
    black=h.material('Dark hardware',(.015,.019,.018),.7)
    cream=h.material('Interior ivory',(.64,.64,.54),.75)
    green=h.material('Checker green',(.16,.23,.19),.7)
    # Separate structural panels leave a genuine walk-in cavity behind the curtain.
    h.box('Raised floor',(0,.035,0),(1.45,.07,.94),silver,.015)
    h.box('Back wall',(0,1.02,-.445),(1.43,1.97,.05),cream)
    h.box('Roof',(0,2.01,0),(1.45,.065,.94),white,.008)
    h.box('Left camera cabinet',(-.535,1.01,0),(.35,1.93,.88),walnut,.006)
    h.box('Right lower wood side',(.694,.39,0),(.05,.65,.89),walnut,.005)
    h.box('Right upper ivory side',(.694,1.34,0),(.05,1.22,.89),cream)
    for x in [-.713,-.358,.713]:
        h.box('Vertical aluminum extrusion',(x,1.03,.465),(.032,2.045,.035),white,.004)
    for y in [.075,2.035]:h.box('Front cross rail',(0,y,.465),(1.455,.027,.035),white,.003)
    for z in [-.45,.44]:h.box('Right cabinet edge',(.714,.39,z),(.032,.68,.032),white,.003)
    for y in [.10,.71]:h.box('Right lower trim',(.714,y,0),(.035,.024,.91),white)
    # Checker tiles are geometry because seen at oblique angles through doorway.
    for i in range(6):
        for j in range(5):h.box('Checker floor tile',(-.265+i*.16,.075,-.345+j*.165),(.16,.006,.165),cream if (i+j)%2 else green)
    h.box('Seat cushion',(.39,.53,-.23),(.48,.075,.38),walnut,.025,2)
    h.tube('Seat support',[(.39,.07,-.23),(.39,.5,-.23)],.035,silver,10)
    # Lens on interior camera column aimed at sitting patron.
    h.box('Camera inset',(-.349,1.2,-.22),(.015,.21,.22),black,.005)
    h.tube('Camera lens', [(-.34,1.22,-.22),(-.314,1.22,-.22)],.048,black,12)
    h.tube('Lens chrome collar',[(-.341,1.22,-.22),(-.31,1.22,-.22)],.052,silver,12)
    h.tube('Lens glass',[(-.308,1.22,-.22),(-.303,1.22,-.22)],.039,black,12)
    h.tube('Curtain rod',[(-.34,1.965,.39),(.70,1.965,.39)],.009,silver,8)
    # Folded open-bottom curtain, slightly gathered to right leaving entry slit.
    nx=40;ny=5;vs=[]
    for row in range(ny+1):
        t=row/ny
        for i in range(nx+1):
            u=i/nx;x=-.285+u*.975+.028*math.sin(t*math.pi)*(1-u)
            y=1.94-t*(1.22+.018*math.sin(u*math.tau*3))
            z=.407+.028*math.cos(u*math.tau*10)+.009*math.sin(t*math.pi)
            vs.append((x,y,z))
    fs=[]
    for r in range(ny):
        for i in range(nx):
            a=r*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
    curtain=h.mesh('Sewn hanging curtain',vs,fs,orange,True)
    # Back faces form a thin closed cloth shell without subdivision.
    sol=curtain.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=.003;bpy.context.view_layer.objects.active=curtain;bpy.ops.object.modifier_apply(modifier=sol.name)
    for i in range(11):
        x=-.285+i*.0975
        h.tube('Curtain hanging ring',[(x,1.952,.38),(x,1.974,.393),(x,1.971,.414),(x,1.947,.426)],.004,silver,6)
    # Minimal filmstrip pickup hardware.
    for x in [-.615,-.485]:h.box('Photostrip outlet',(x,.69,.451),(.09,.105,.022),black,.005)
    h.box('Coin mechanism plate',(-.54,.97,.453),(.105,.10,.014),silver,.003)
    h.box('Coin slit',(-.54,.98,.463),(.013,.052,.004),black)
    artmat=h.image_material('Original booth graphic',art/'graphic.png')
    graphics=[h.decal('Photo booth graphic',(-.536,1.53,.451),(.303,.82),artmat,grid=1)]
    for x in [-.71,-.355,.71]:
        for y in [.13,.73,1.35,1.96]:h.tube('Frame rivet',[(x,y,.485),(x,y,.489)],.0038,silver,6)
    return h.finish(name,art,ROOT/'models/authored'/name,4000,specials=[('Printed booth sign',graphics)],surface_normals={'Printed booth sign':(0,0,1)},scale=2.9,camera=(3,-4,2.5),target=(0,0,1.02),metadata={'description':'Walk-in orange-curtain photo booth with checker floor and seated interior','texture_resolution':1024})

def rocket():
    h.reset();name='mall_rocket_ride';art=ROOT/'art'/name;art.mkdir(parents=True,exist_ok=True)
    blue=h.material('Worn cobalt fiberglass',(.012,.095,.30),.26,variation=.12,bump=.0007)
    red=h.material('Cherry red fiberglass',(.48,.024,.028),.31,variation=.1)
    ivory=h.material('Warm cream pinstripe',(.84,.81,.64),.4)
    yellow=h.material('Yellow molded windows',(.76,.75,.016),.27)
    black=h.material('Rubber and inset sockets',(.018,.025,.027),.68)
    chrome=h.material('Chromed hardware',(.50,.55,.56),.28,.85)
    h.box('Cast machine plinth',(0,.115,0),(1.12,.23,1.47),blue,.065,2)
    for x in [-.45,.45]:
        for z in [-.57,.57]:h.tube('Rubber foot',[(x,.018,z),(x,.045,z)],.065,black,10)
    for x in [-.37,.37]:h.box('Textured boarding tread',(x,.239,.31),(.17,.009,.57),black,.024)
    h.box('Tall left coin pedestal',(-.465,.60,-.12),(.24,.91,.43),blue,.05,2)
    h.box('Coin mechanism recess',(-.465,.70,.109),(.145,.28,.013),black,.013)
    h.box('Polished payment plate',(-.465,.70,.121),(.122,.25,.01),chrome,.009)
    for y in [.63,.77]:
        h.box('Payment slot',(-.47,y,.13),(.018,.062,.009),black,.003)
        h.tube('Coin return knob',[(-.45,y-.025,.132),(-.45,y-.025,.15)],.011,chrome,8)
    # Recessed speaker below the payment panel.
    h.box('Speaker inset',(-.465,.42,.111),(.15,.12,.012),black,.018)
    for k in range(6):h.box('Speaker grille bar',(-.465,.375+k*.017,.12),(.138,.006,.008),blue,.002)
    h.box('Service access rear seam',(-.465,.61,-.341),(.188,.76,.008),black,.006)
    h.box('Service access rear panel',(-.465,.61,-.347),(.180,.750,.006),blue,.006)
    # Payment tower stands ahead of the swept wing, with real mechanical clearance.
    for ob in h.parts:
        if ob.name.startswith(('Tall left coin','Coin mechanism','Polished payment','Payment slot','Coin return','Speaker','Service access')):
            ob.location.y-=.53
    h.lathe('Molded support bellows',(0,.245,.0),[(.145,0),(.145,.025),(.106,.032),(.143,.06),(.10,.073),(.138,.099),(.105,.112),(.13,.135),(.10,.155)],black,16)
    # Sculpted axial fuselage, top removed over the seat instead of intersecting solids.
    rings=[(-.62,.065,.07,.94),(-.53,.20,.20,.91),(-.34,.30,.28,.87),(-.05,.34,.30,.85),(.22,.33,.28,.87),(.47,.25,.22,.90),(.63,.14,.14,.91),(.70,.025,.045,.91)]
    n=24;v=[]
    for z,rx,ry,cy in rings:
        for i in range(n):
            a=math.tau*i/n;v.append((rx*math.sin(a),cy+ry*math.cos(a),z))
    f=[]
    for j in range(len(rings)-1):
        for i in range(n):
            # Opening extends along rear cockpit, angular arc around upper crown.
            if j in [1,2] and (i<5 or i>=19):continue
            a=j*n+i;b=j*n+(i+1)%n;f.append((a,b,b+n,a+n))
    f.extend([tuple(reversed(range(n))),tuple(range((len(rings)-1)*n,len(rings)*n))])
    hull=h.mesh('Sculpted open cockpit rocket hull',v,f,blue,True)
    # Red seating tub shares the hull aperture edge exactly; no intersecting walls.
    seatv=[]
    for row,(z,rx,ry,cy) in enumerate(rings[1:4]):
        for i in range(13):
            t=2*i/12-1;x=t*rx*math.sin(math.radians(75));edge=cy+ry*math.cos(math.radians(75))
            y=(cy+ry*math.sqrt(max(0,1-(x/rx)**2))) if row in [0,2] else edge-.235*(1-t*t)
            seatv.append((x,y,z))
    seatf=[]
    for j in range(2):
        for i in range(12):a=j*13+i;seatf.append((a,a+1,a+14,a+13))
    h.mesh('Hollow red molded seat',seatv,seatf,red,True)
    h.tube('Support riser',[(0,.37,0),(0,.59,0)],.075,blue,12)
    # Cockpit lip runs down both opening edges with a rolled red border.
    for side in [-1,1]:
        rim=[]
        for k in range(9):
            t=k/8;rim.append((side*((1-t)**2*.193+2*(1-t)*t*.302+t*t*.328),(1-t)**2*.962+2*(1-t)*t*.944+t*t*.928,(1-t)**2*(-.53)+2*(1-t)*t*(-.34)+t*t*(-.05)))
        h.tube('Rolled cockpit rim',rim,.019,red,10)
    # Lower cream stripe follows fuselage around the complete contour.
    stripe=[];stripefaces=[]
    for s in [-1,1]:
        start=len(stripe)
        for z,rx,ry,cy in rings:
            for dy in [-.018,.018]:stripe.append((s*(rx+.0015),cy+dy,z))
        for j in range(len(rings)-1):a=start+j*2;stripefaces.append((a,a+2,a+3,a+1))
    h.mesh('Cream fuselage racing stripe',stripe,stripefaces,ivory,True)
    # Colored nose dome follows actual hull curvature.
    nv=[];nf=[];nn=24
    for z,r in [(.588,.148),(.627,.142),(.67,.108),(.708,.058),(.721,0.008)]:
        for i in range(nn):a=math.tau*i/nn;nv.append((r*math.sin(a),.91+r*math.cos(a),z))
    for j in range(4):
        for i in range(nn):a=j*nn+i;b=j*nn+(i+1)%nn;nf.append((a,b,b+nn,a+nn))
    nf.append(tuple(range(4*nn,5*nn)))
    h.mesh('Rounded red nose cap',nv,nf,red,True)
    # Painted fiberglass uses a projected source image baked onto this same hull.
    # No floating decoration meshes or disconnected window corners remain.
    painted=blue.copy();painted.name='Flush painted rocket fiberglass'
    nt=painted.node_tree;bs=nt.nodes.get('Principled BSDF');base=bs.inputs['Base Color'].links[0].from_socket
    geo=nt.nodes.new('ShaderNodeNewGeometry');mul=nt.nodes.new('ShaderNodeVectorMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=(1.25,-1/.9,0)
    nt.links.new(geo.outputs['Position'],mul.inputs[0]);add=nt.nodes.new('ShaderNodeVectorMath');add.operation='ADD';add.inputs[1].default_value=(.5,.1/.9,0);nt.links.new(mul.outputs['Vector'],add.inputs[0])
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(art/'top_paint.png'));tex.image.pack();tex.extension='CLIP';nt.links.new(add.outputs['Vector'],tex.inputs['Vector'])
    sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(geo.outputs['Position'],sep.inputs[0]);above=nt.nodes.new('ShaderNodeMath');above.operation='GREATER_THAN';above.inputs[1].default_value=.98;nt.links.new(sep.outputs['Z'],above.inputs[0])
    mask=nt.nodes.new('ShaderNodeMath');mask.operation='MULTIPLY';nt.links.new(tex.outputs['Alpha'],mask.inputs[0]);nt.links.new(above.outputs[0],mask.inputs[1])
    mix=nt.nodes.new('ShaderNodeMixRGB');nt.links.new(mask.outputs[0],mix.inputs[0]);nt.links.new(base,mix.inputs[1]);nt.links.new(tex.outputs['Color'],mix.inputs[2]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    hull.data.materials.clear();hull.data.materials.append(painted)
    # Swept molded wings use explicit beveled profiles; pinstripes sit flush on upper surface.
    for s in [-1,1]:
        vv=[(s*.24,.72,.18),(s*.54,.70,.10),(s*.56,.69,-.10),(s*.27,.69,-.04),(s*.24,.68,.18),(s*.54,.66,.10),(s*.56,.65,-.10),(s*.27,.65,-.04)]
        h.mesh('Swept short wing',vv,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],red)
        h.tube('Rounded wingtip',[(s*.54,.68,.10),(s*.56,.67,-.10)],.027,blue,8)
        h.mesh('Wing ivory stripe',[(s*.40,.712,.137),(s*.43,.709,.125),(s*.46,.694,-.08),(s*.43,.696,-.07)],[(0,1,2,3)],ivory)
    # Swept tail rising behind cockpit with a horizontal red/blue stabilizer.
    h.section('Swept tail fin',[(-.58,.98),(-.72,1.39),(-.51,1.39),(-.38,1.03)],-.042,.042,blue,.008)
    h.tube('Rounded T-tail stabilizer',[(-.28,1.39,-.62),(.28,1.39,-.62)],.065,blue,12)
    for s in [-1,1]:
        h.tube('Red tail band',[(s*.15,1.39,-.62),(s*.275,1.39,-.62)],.066,red,12)
        for x in [.14,.28]:h.tube('Cream tail stripe',[(s*(x-.008),1.39,-.62),(s*(x+.008),1.39,-.62)],.067,ivory,12)
    for side in [-1,1]:
        vv=[];ff=[];n=12
        for x,r in [(.28,.065),(.305,.06),(.325,.044),(.339,.023),(.344,.003)]:
            for i in range(n):a=math.tau*i/n;vv.append((side*x,1.39+r*math.sin(a),-.62+r*math.cos(a)))
        for row in range(4):
            for i in range(n):a=row*n+i;b=row*n+(i+1)%n;ff.append((a,b,b+n,a+n))
        ff.append(tuple(range(4*n,5*n)));h.mesh('Torpedo tail tip',vv,ff,blue,True)
    # Flush curved portholes follow the varying body cross-section.
    for side in [-1,1]:
        for zz in [-.40,-.25,-.10]:
            coords=[]
            for i in range(16):
                a=math.tau*i/16;z=zz+.041*math.cos(a);dy=.079*math.sin(a)
                for j in range(len(rings)-1):
                    if rings[j][0]<=z<=rings[j+1][0]:
                        t=(z-rings[j][0])/(rings[j+1][0]-rings[j][0]);rx=rings[j][1]*(1-t)+rings[j+1][1]*t;ry=rings[j][2]*(1-t)+rings[j+1][2]*t;cy=rings[j][3]*(1-t)+rings[j+1][3]*t
                        coords.append((side*(rx*math.sqrt(1-(dy/ry)**2)+.003),cy+dy,z));break
            center=tuple(sum(q[k] for q in coords)/16 for k in range(3));center=(center[0]+side*.008,center[1],center[2]);coords.append(center)
            h.mesh('Flush yellow porthole',coords,[(i,(i+1)%16,16) for i in range(16)],yellow)
    for s in [-1,1]:
        h.tube('Handlebar',[(s*.18,1.08,-.02),(s*.22,1.22,-.08),(s*.22,1.32,-.08)],.017,black,8)
        h.tube('Red hand grip',[(s*.22,1.24,-.08),(s*.22,1.35,-.08)],.024,red,10)
    return h.finish(name,art,ROOT/'models/authored'/name,4500,scale=2.35,camera=(-2.8,-3.5,2.0),target=(0,0,.73),metadata={'description':'Molded fiberglass rocket kiddie ride with actual open red cockpit and mechanical base','texture_resolution':1024})

if __name__=='__main__':
    which=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if not which or 'booth' in which:booth()
    if not which or 'rocket' in which:rocket()
