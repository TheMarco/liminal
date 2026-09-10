"""Reference-based moving walkway, native 8.4/10.4m lengths; no stretched newels.

Godot axes: X is travel, Y up; floor at 0; 1.15m clear belt width.
The exported belt is separate so Godot can retain animated pallet motion.
"""
from pathlib import Path
import math, sys
import bpy, bmesh
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import hero_prop as h
ROOT=HERE.parents[1]


def prism(name,profile,z0,z1,mat):
    n=len(profile)
    verts=[(x,y,z) for z in (z0,z1) for x,y in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return h.mesh(name,verts,faces,mat)


def rail_profile(length):
    # True elliptical ends meet the straight runs tangentially. No spline
    # extrapolation, duplicated seam rings or mismatched endpoint normals.
    points=[];tangents=[]
    cx=length/2-.43;cy=.66;rx=.33;ry=.44
    for side,start in [(1,-math.pi/2),(-1,math.pi/2)]:
        for i in range(13):
            a=start+math.pi*i/12
            points.append((side*cx+rx*math.cos(a),cy+ry*math.sin(a)))
            tangents.append(Vector((-rx*math.sin(a),ry*math.cos(a))).normalized())
    return points,tangents


def handrail(profile,tangents,z,mat):
    verts=[];faces=[];n=len(profile);sides=8
    for (x,y),t in zip(profile,tangents):
        for k in range(sides):
            a=math.tau*k/sides
            # Broad, slightly flattened rubber belt, not a round pipe.
            verts.append((x-t.y*.035*math.sin(a),y+t.x*.035*math.sin(a),z+.050*math.cos(a)))
    for i in range(n):
        for k in range(sides):
            faces.append((i*sides+k,i*sides+(k+1)%sides,((i+1)%n)*sides+(k+1)%sides,((i+1)%n)*sides+k))
    ob=h.mesh('Continuous moulded rubber handrail',verts,faces,mat,True)
    bm=bmesh.new();bm.from_mesh(ob.data)
    assert all(e.is_manifold for e in bm.edges)
    assert all(f.calc_area()>1e-10 for f in bm.faces)
    bm.free()


def tread_material():
    m=h.material('Longitudinal metal pallet grooves',(.23,.25,.27),.38,.72,0)
    nt=m.node_tree;bs=nt.nodes.get('Principled BSDF')
    geo=nt.nodes.new('ShaderNodeNewGeometry')
    wave=nt.nodes.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='Y'
    wave.inputs['Scale'].default_value=85
    nt.links.new(geo.outputs['Position'],wave.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(.035,.042,.046,1)
    ramp.color_ramp.elements[1].color=(.35,.38,.4,1)
    nt.links.new(wave.outputs['Color'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],bs.inputs['Base Color'])
    return m


def build(length):
    h.reset()
    name='airport_walkway' if length==8.4 else 'airport_walkway_long'
    art=ROOT/'art/airport_walkway'/('standard' if length==8.4 else 'long')
    out=ROOT/'models/authored/airport_walkway'/('standard' if length==8.4 else 'long')
    steel=h.material('Brushed silver stainless',(.48,.51,.53),.32,.80,.04)
    grey=h.material('Folded satin steel skirt',(.25,.28,.30),.42,.68,.04)
    dark=h.material('Black handrail rubber',(.014,.019,.022),.41,.02,.025)
    seam=h.material('Recessed black seams',(.025,.032,.036),.56,.15,0)
    yellow=h.material('Yellow comb safety edge',(.92,.65,.045),.46,.14,.015)
    white=h.material('Printed safety label',(.77,.79,.80),.59,0,0)
    red=h.material('Safety prohibition red',(.64,.025,.014),.52,0,0)
    blue=h.material('Safety instruction blue',(.015,.15,.39),.5,0,0)
    tread=tread_material()
    glass=h.material('Pale blue laminated safety glass',(.53,.72,.78),.18,.08,0)
    bs=glass.node_tree.nodes.get('Principled BSDF');bs.inputs['Alpha'].default_value=.16
    glass.diffuse_color=(.53,.72,.78,.16);glass.surface_render_method='DITHERED'
    panes=[]
    profile,tangents=rail_profile(length)
    # Low undercarriage: the deck is only 13cm above the terminal floor.
    h.box('Recessed continuous undercarriage',(0,.05,0),(length,.10,1.78),seam,.012)
    belt=h.box('Moving pallet deck',(0,.123,0),(length-1.10,.014,1.15),tread)
    for s in [-1,1]:
        z=s*.735
        handrail(profile,tangents,z,dark)
        panes.append(prism('Continuous curved clear balustrade',profile,z-.010,z+.010,glass))
        # The return half of the rubber loop disappears into the skirt.
        skirt=[(-length/2,.10),(-length/2,.19),(-length/2+.32,.38),
               (length/2-.32,.38),(length/2,.19),(length/2,.10)]
        prism('Folded full length metal housing',skirt,s*.60,s*.91,grey)
        h.box('Polished inner skirt',(0,.265,s*.603),(length-.64,.23,.018),steel,.004)
        h.box('Satin top cap',(0,.383,s*.753),(length-.68,.026,.306),steel,.009)
        h.box('Recessed glazing gasket',(0,.399,z),(length-.71,.012,.038),dark,.003)
        h.box('Inner safety brush',(0,.162,s*.586),(length-1.12,.025,.022),dark)
        # Sparse glass joints are baked into the opaque atlas; no extra panes.
        for i in range(1,6):
            x=-(length/2-.48)+(length-.96)*i/6
            h.box('Glazing panel joint',(x,.746,z),(.007,.68,.022),steel)
        for e in [-1,1]:
            x=e*(length/2-.12)
            # Newel inlet is angled to meet the ramp, with a recessed rubber lip.
            h.box('Handrail inlet rubber boot',(e*(length/2-.22),.218,z),(.22,.10,.145),dark,.021,2)
            for dx in [-.065,.065]:
                h.box('Newel housing seam',(e*(length/2-.42)+dx,.402,s*.847),(.009,.009,.072),seam)
            # Red/blue instructional pictograms on small metal plates.
            for j,col in enumerate([blue,red,red]):
                q=e*(length/2-.61-j*.083)
                h.box('Safety sticker white border',(q,.401,s*.84),(.073,.003,.090),white)
                h.box('Safety sticker colour',(q,.404,s*.84),(.061,.003,.078),col)
                h.box('Safety sticker pictogram',(q,.407,s*.84),(.040,.002,.054),white)
                h.box('Safety sticker black mark',(q,.409,s*.84),(.009,.002,.036),seam)
            h.box('Brushed service panel',(e*(length/2-.33),.12,s*.773),(.32,.026,.27),steel,.010)
    # Silver entry ramps slope continuously from the existing deck to floor.
    for e in [-1,1]:
        points=[(e*(length/2-.60),.13),(e*(length/2+.56),.012),
                (e*(length/2+.56),0),(e*(length/2-.60),.075)]
        prism('Grooved sloping entry plate',points,-.915,.915,tread)
        h.box('Yellow comb plate',(e*(length/2-.54),.134,0),(.15,.018,1.15),yellow,.003)
        for k in range(25):
            h.box('Comb tooth',(e*(length/2-.62),.136,-.54+k*.045),(.055,.012,.016),steel)
        for s in [-1,1]:
            # Narrow perimeter edge follows the ramp exactly.
            prism('Polished ramp edge',points,s*.893,s*.918,steel)
    # Give the static gallery belt its own readable longitudinal grooves. At
    # runtime this exact mesh gets the existing animated shader, never a duplicate.
    stats=h.finish(name,art,out,5000,
        specials=[('WalkwayGlass',panes),('WalkwayBelt',[belt])],
        metadata={'travel_axis':'+X','length_m':length,'belt_width_m':1.15,'belt_height_m':.13},
        scale=length*1.03,camera=(length*.71, -length*.62, length*.57),target=(0,0,.47))
    return stats


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for length in ([10.4] if '--long' in args else [8.4] if '--standard' in args else [8.4,10.4]):build(length)
