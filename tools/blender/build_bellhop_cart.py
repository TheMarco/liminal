"""Brass hotel birdcage trolley, red carpet deck, paired caster forks."""
import math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import hero_prop as h
R=HERE.parents[1]
h.reset()
gold=h.material('Polished warm brass',(.58,.32,.085),.22,.88,.018)
red=h.material('Burgundy carpet',(.18,.008,.010),.91,0,.13,.008)
rubber=h.material('Rubber bumper and tires',(.012,.015,.013),.78,0,.03)
steel=h.material('Axles',(.24,.26,.24),.3,.8,.01)
def round_rect(width,depth,r,y):
    pts=[]
    for cx,cz,start in [(width/2-r,depth/2-r,0),(-width/2+r,depth/2-r,90),(-width/2+r,-depth/2+r,180),(width/2-r,-depth/2+r,270)]:
        for j in range(6):
            a=math.radians(start+j*18)
            pts.append((cx+r*math.cos(a),y,cz+r*math.sin(a)))
    return pts+[pts[0]]
# Horizontal laminated deck and continuous bumper (no disconnected bars).
h.box('Deck chassis',(0,.285,0),(1.13,.065,.70),gold,.022,3)
h.box('Carpet upholstered top',(0,.325,0),(1.10,.032,.67),red,.022,3)
h.tube('Continuous rounded rubber bumper',round_rect(1.17,.74,.095,.274),.031,rubber,8)
h.tube('Brass deck edge',round_rect(1.11,.68,.073,.337),.009,gold,8)
for z in [-.28,.28]:
    pts=[(-.49,.34,z),(-.49,1.30,z)]
    pts += [(.49*math.cos(math.pi-j*math.pi/20),1.30+.49*math.sin(math.pi-j*math.pi/20),z) for j in range(1,21)]
    pts.append((.49,.34,z))
    h.tube('Complete birdcage arch',pts,.025,gold,10)
    for x in [-.49,.49]:
        h.lathe('Post socket',(x,.335,z),[(.035,0),(.035,.022),(.028,.029)],gold,10)
for x in [-.49,.49]:
    h.tube('Side support rail',[(x,1.085,-.28),(x,1.085,.28)],.022,gold,10)
    for z in [-.12,.12]:h.tube('Rail vertical support',[(x,.34,z),(x,1.085,z)],.015,gold,8)
h.tube('Coat hanger rail',[(0,1.66,-.28),(0,1.66,.28)],.016,gold,10)
h.tube('Hanger suspension',[(0,1.66,0),(0,1.79,0)],.014,gold,10)
h.tube('Arch connector',[(0,1.79,-.28),(0,1.79,.28)],.022,gold,10)
h.lathe('Finial pedestal',(0,1.785,0),[(.035,0),(.035,.018),(.018,.028),(.018,.052),(.033,.063)],gold,12)
h.lathe('Ball finial',(0,1.887,0),[(.005,-.045),(.026,-.036),(.041,-.019),(.045,0),(.041,.019),(.026,.036),(.005,.045)],gold,16)
# Tire surfaces have a rounded shoulder profile; caster forks straddle the tire.
for x in [-.44,.44]:
    for z in [-.235,.235]:
        verts=[];profile=[(-.05,.078),(-.05,.105),(-.036,.119),(.036,.119),(.05,.105),(.05,.078)]
        for off,rad in profile:
            for j in range(16):
                a=j*math.tau/16;verts.append((x+off,.12+rad*math.cos(a),z+rad*math.sin(a)))
        faces=[]
        for i in range(len(profile)-1):
            for j in range(16):
                a=i*16+j;b=i*16+(j+1)%16;faces.append((a,b,b+16,a+16))
        h.mesh('Rounded tire',verts,faces,rubber,True)
        h.tube('Brass wheel hub',[(x-.052,.12,z),(x+.052,.12,z)],.079,gold,16)
        h.tube('Steel axle',[(x-.072,.12,z),(x+.072,.12,z)],.014,steel,10)
        for sx in [-.063,.063]:
            h.section('Separate caster fork',[(z-.052,.12),(z+.039,.12),(z+.045,.24),(z-.013,.248)],x+sx-.007,x+sx+.007,gold)
        h.lathe('Swivel bearing',(x,.24,z),[(.037,0),(.037,.019),(.028,.026)],gold,12)
h.finish('vegas_bellhop_cart',R/'art/vegas_bellhop_cart',R/'models/authored/vegas_bellhop_cart',4500,
         metadata={'description':'Twin brass birdcage arches, carpet deck, rounded bumper and four casters'},
         camera=(2,-3,2),target=(0,0,.96),scale=2.35)
