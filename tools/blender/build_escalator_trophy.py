"""Reference-based escalator and hollow school trophy display; metres, Godot axes."""
from pathlib import Path
import sys, math
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1]

def rounded_profile(control):
    """Local quadratic fillets cannot overshoot at short-to-long transitions."""
    from mathutils import Vector
    result=[]
    for i,p in enumerate(control):
        p=Vector(p);before=Vector(control[i-1])-p;after=Vector(control[(i+1)%len(control)])-p
        cut=min(.14,before.length*.4,after.length*.4)
        a=p+before.normalized()*cut;b=p+after.normalized()*cut
        for j in range(4):
            t=j/3
            result.append(tuple((1-t)**2*a+2*(1-t)*t*p+t*t*b))
    return result

def closed_handrail(profile,x,mat):
    """Shared cyclic rings and a fixed planar frame, including the closing seam."""
    from mathutils import Vector
    verts=[];faces=[];sides=8;n=len(profile)
    for i,(z,y) in enumerate(profile):
        before=Vector(profile[i-1]);after=Vector(profile[(i+1)%n])
        tangent=(after-before).normalized()
        for j in range(sides):
            angle=math.tau*j/sides;r=.053
            verts.append((x+r*math.cos(angle),y+r*math.sin(angle)*tangent.x,z-r*math.sin(angle)*tangent.y))
    for i in range(n):
        for j in range(sides):
            faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%n)*sides+(j+1)%sides,((i+1)%n)*sides+j))
    ob=h.mesh('Continuous rubber handrail loop',verts,faces,mat,True)
    # A rail must be a closed manifold before baking/exporting.
    import bmesh
    bm=bmesh.new();bm.from_mesh(ob.data)
    assert all(e.is_manifold for e in bm.edges), 'Open handrail seam'
    bm.free()
    return ob

def glass(alpha=.22):
    m=h.material('Tinted safety glass',(.38,.65,.69),.19,.1,0)
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Alpha'].default_value=alpha
    m.diffuse_color=(.38,.65,.69,alpha)
    m.surface_render_method='DITHERED'
    return m

def escalator():
    h.reset()
    steel=h.material('Brushed stainless skirt',(.43,.47,.50),.32,.78,.05)
    dark=h.material('Rubber moving handrail',(.013,.018,.022),.42,.03,.045)
    step=h.material('Ribbed cast treads',(.095,.115,.13),.58,.60,.04)
    bs=step.node_tree.nodes.get('Principled BSDF');nt=step.node_tree
    tex=nt.nodes.new('ShaderNodeTexWave');tex.wave_type='BANDS';tex.bands_direction='X';tex.inputs['Scale'].default_value=50
    geo=nt.nodes.new('ShaderNodeNewGeometry');nt.links.new(geo.outputs['Position'],tex.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.025,.035,.045,1);ramp.color_ramp.elements[1].color=(.23,.25,.27,1)
    nt.links.new(tex.outputs['Color'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
    yellow=h.material('Worn yellow safety line',(.80,.56,.065),.58,.05,.10)
    black=h.material('Newel return recess',(.023,.031,.034),.70,.10,.04)
    g=glass();panels=[]
    # The stair/slope contract is retained exactly from the existing airport.
    for i in range(12):
        y=.1875*(i+1);z=-1.1+.36*i+.18
        height=min(.22,y)
        h.box('Ribbed escalator tread %02d'%i,(0,y-height/2,z),(1,height,.38),step,.006)
        for x in [-.472,.472]:h.box('Yellow tread corner',(x,y-.001,z+.115),(.045,.008,.14),yellow)
        h.box('Tread safety nose',(0,y-.003,z+.166),(.92,.008,.022),yellow)
    for z,y,l in [(-1.62,.03,.75),(3.03,2.22,.5)]:
        h.box('Landing cassette',(0,y,z),(1.24,.06,l),steel,.009)
        h.box('Grooved landing plate',(0,y+.032,z),(1.0,.012,l*.8),step)
        for x in [-.49,.49]:h.box('Landing warning',(x,y+.04,z),(.026,.008,l*.8),yellow)
    # A formed side profile closes the step mechanism beneath the treads.
    profile=[(-2.12,0),(-2.12,.15),(-1.1,.15),(3.0,2.22),(3.7,2.22),(3.7,1.99),(-.90,0)]
    for s in [-1,1]:
        h.section('Continuous stainless truss cladding',profile,s*.66-.055,s*.66+.055,steel)
        outer=[(-2.12,.51),(-2.10,.74),(-1.96,.93),(-1.74,1.0),(-1.30,1.0),(-1.10,1.055),(2.97,3.145),(3.21,3.205),(3.40,3.18),(3.59,3.04),(3.67,2.84),(3.61,2.64),(3.44,2.52),(3.18,2.49),(-1.24,.25),(-1.75,.25),(-1.98,.30)]
        outer=rounded_profile(outer)
        ob=h.section('Curved transparent balustrade',outer,s*.62-.014,s*.62+.014,g);panels.append(ob)
        closed_handrail(outer,s*.62,dark)
        h.tube('Polished lower glazing channel',[(s*.62,y,z) for z,y in [(-1.98,.30),(-1.75,.25),(-1.24,.25),(3.18,2.49),(3.44,2.52)]],.023,steel,6)
        for z,y in [(-1.88,.15),(3.4,2.33)]:
            h.box('Handrail return housing',(s*.62,y,z),(.18,.22,.40),steel,.035,2)
            h.box('Rubber entry guard',(s*.62,y+.12,z),(.115,.028,.23),black,.008)
    h.finish('airport_escalator',ROOT/'art/airport_escalator',ROOT/'models/authored/airport_escalator',6000,
             specials=[('EscalatorGlass',panels)],metadata={'rise_m':2.25,'approach_axis':'-Z','step_count':12},
             scale=7.0,camera=(5,7,4.4),target=(0,-.75,1.5))

def trophy_case():
    h.reset()
    wood=h.material('Honey oak display frame',(.36,.21,.092),.49,.0,.12)
    nt=wood.node_tree;bs=nt.nodes.get('Principled BSDF');tex=nt.nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=4
    geo=nt.nodes.new('ShaderNodeNewGeometry');vec=nt.nodes.new('ShaderNodeVectorMath');vec.operation='MULTIPLY';vec.inputs[1].default_value=(2,60,60)
    nt.links.new(geo.outputs['Position'],vec.inputs[0]);nt.links.new(vec.outputs[0],tex.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.19,.095,.032,1);ramp.color_ramp.elements[1].color=(.48,.30,.13,1)
    nt.links.new(tex.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
    backing=h.material('Warm linen cabinet backing',(.37,.36,.27),.85,0,.09)
    silver=h.material('Tarnished silver awards',(.54,.56,.52),.30,.85,.07)
    brass=h.material('Aged brass awards',(.52,.35,.11),.34,.8,.1)
    black=h.material('Black trophy plinths',(.024,.023,.019),.42,.07,.04)
    darkwood=h.material('Walnut award shields',(.17,.075,.024),.48,0,.07)
    g=glass(.055);panels=[]
    lamp=h.material('Warm display downlights',(.88,.76,.48),.35)
    lamp.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(1,.82,.5,1)
    lamp.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=2
    lamps=[]
    for x in [-.72,0,.72]:
        lamps.append(h.lathe('Inset display downlight',(x,2.239,.22),[(.035,0),(.035,.008)],lamp,8))
    # Local origin is at floor/wall rear, front +Z. Actual hollow display.
    h.box('Oak lower drawer cabinet',(0,.24,.17),(2.2,.48,.34),wood,.012)
    h.box('Recessed dark toe kick',(0,.035,.18),(2.09,.07,.30),black,.005)
    h.box('Oak top fascia',(0,2.33,.17),(2.2,.16,.34),wood,.008)
    h.box('Linen back panel',(0,1.385,.021),(2.14,1.81,.042),backing)
    for x in [-1.067,1.067]:h.box('Slim oak outer stile',(x,1.365,.17),(.066,1.77,.34),wood,.005)
    for x in [-.73,0,.73]:
        h.box('Drawer front',(x,.285,.35),(.715,.31,.025),wood,.007)
        h.tube('Drawer pull',[(x-.08,.30,.371),(x-.08,.30,.393),(x+.08,.30,.393),(x+.08,.30,.371)],.008,silver,6)
    for y in [.5,1.06,1.62]:
        panels.append(h.box('Glass display shelf',(0,y,.185),(2.05,.015,.28),g))
        for x in [-1.01,1.01]:h.box('Shelf support tab',(x,y-.013,.17),(.026,.018,.08),silver)
    for x in [-.69,0,.69]:
        panels.append(h.box('Sliding glass door',(x,1.38,.346),(.686,1.75,.008),g))
        h.box('Polished door edge',(x+.337,1.38,.35),(.008,1.75,.013),silver)
        h.box('Small finger pull',(x+.30,1.36,.361),(.025,.07,.015),silver,.004)
    for row,y in enumerate([.514,1.074,1.634]):
        for col,x in enumerate([-.78,-.26,.26,.78]):
            if (row+col)%3==0:
                # Chamfered heraldic plaques with contrasting metal crest.
                outline=[(-.135,.36),(.135,.36),(.145,.17),(.10,.07),(0,0),(-.10,.07),(-.145,.17)]
                verts=[(x+xx,y+yy,z) for z in [.14,.165] for xx,yy in outline];n=len(outline)
                faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
                h.mesh('Walnut shield award',verts,faces,darkwood)
                h.decal('Brass shield citation',(x,y+.20,.17),(.11,.075),brass,grid=1)
                for dx,dy in [(-.08,.29),(.08,.29),(-.075,.12),(.075,.12)]:
                    h.box('Shield engraved plaque',(x+dx,y+dy,.171),(.034,.035,.004),silver,.004)
            else:
                mat=silver if col%2 else brass
                height=.31+.06*((row+col)%2);r=.086+.015*(col%2)
                h.lathe('Turned black award base',(x,y,.18),[(.076,0),(.076,.035),(.063,.045)],black,12)
                h.lathe('Hollow trophy cup',(x,y+.045,.18),[(.062,0),(.045,.016),(.018,.04),(.018,.10),(r*.7,height*.52),(r,height*.80),(r,height), (r-.008,height),(r-.012,height*.81),(.012,height*.50)],mat,12)
                for s in [-1,1]:
                    h.tube('Open trophy handle',[(x+s*r*.85,y+.045+height*.91,.18),(x+s*r*1.40,y+.045+height*.94,.18),(x+s*r*1.60,y+.045+height*.76,.18),(x+s*r*1.34,y+.045+height*.53,.18),(x+s*r*.69,y+.045+height*.52,.18)],.009,mat,5)
                h.box('Trophy engraved plate',(x,y+.022,.257),(.083,.019,.004),brass)
    h.finish('school_trophy_case',ROOT/'art/school_trophy_case',ROOT/'models/authored/school_trophy_case',6000,
             specials=[('TrophyCaseGlass',panels),('TrophyCaseLamps',lamps)],metadata={'wall_back_z':0,'awards':12},
             scale=3.35,camera=(3,-5,2.9),target=(0,-.17,1.2))

if __name__=='__main__':
    if '--trophy' in sys.argv:trophy_case()
    else:escalator()
