"""Recessed linear fluorescent fixture from the supplied product reference.

Construction coordinates are Godot X (length) / Y up / Z. The origin is the
ceiling plane: the trim flange hangs below Y=0, the housing rises into the
ceiling void above it and the diffuser faces -Y, so the model installs at
(x, ceiling_height, z) with no rotation.
"""
from pathlib import Path
import sys,math,bpy
import numpy as np
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));import hero_prop as h
ROOT=HERE.parents[1]
NAME='linear_recessed_light'
ART=ROOT/'art'/NAME;OUT=ROOT/'models/authored'/NAME

L,W=1.22,.19            # trim flange outline
HL,HW,HH=.585,.075,.11  # housing half length, half width, height
TRIM=[(0,0),(0,-.0105),(.0015,-.012),(.021,-.012),(.027,-.006),(.027,0)]  # (inset, y)
REVEAL=.027;LENS_Y=-.003
LA,LB=L/2-REVEAL+.0005,W/2-REVEAL+.0005  # lens half extents, tucked into the trim
EMISSION=2.4  # matches Mats.office_panel()


def trim_frame(mat,gap=.0003):
    # Four mitered sections; the hairline gap reads as the reference's corner seams.
    n=len(TRIM)
    sides=[(L,lambda s,d,y:(s,y,W/2-d)),(L,lambda s,d,y:(s,y,-W/2+d)),
           (W,lambda s,d,y:(L/2-d,y,s)),(W,lambda s,d,y:(-L/2+d,y,s))]
    for length,place in sides:
        verts=[place(sgn*(length/2-d-gap),d,y) for sgn in (-1,1) for d,y in TRIM]
        faces=[tuple(range(n)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        h.mesh('Mitered trim flange',verts,faces,mat)


def disc(name,c,normal,profile,mat,sides=12):
    """Small lathed head on an arbitrary axis: profile is (radius, height)."""
    n=Vector(normal);u=Vector((0,1,0)) if abs(n.y)<.5 else Vector((1,0,0));v=n.cross(u)
    verts=[tuple(Vector(c)+n*y+r*(u*math.cos(math.tau*i/sides)+v*math.sin(math.tau*i/sides)))
           for r,y in profile for i in range(sides)]
    faces=[(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j)
           for k in range(len(profile)-1) for j in range(sides)]
    faces+=[tuple(reversed(range(sides))),tuple(range((len(profile)-1)*sides,len(profile)*sides))]
    return h.mesh(name,verts,faces,mat,True)


def screw(c,normal,paint,dark):
    disc('Phillips pan head screw',c,normal,[(.0042,0),(.0042,.0006),(.0035,.0014),(.0019,.0019),(.0006,.002)],paint)
    top=Vector(c)+Vector(normal)*.0017;a=[abs(x) for x in normal]
    for arm in ((.005,.0005),(.0005,.005)):
        size=[.0008 if a[i]>.5 else 0 for i in range(3)];free=[i for i in range(3) if a[i]<.5]
        size[free[0]],size[free[1]]=arm
        h.box('Cross recess',tuple(top),tuple(size),dark)


def lens_texture(path,width=2048,height=256,ss=2):
    """Prismatic diffuser with a twin-tube PL-L lamp showing through it."""
    x=((np.arange(width*ss)+.5)/(width*ss)*2-1)*LA*1000  # millimetres
    z=((np.arange(height*ss)+.5)/(height*ss)*2-1)*LB*1000
    X,Z=np.meshgrid(x,z);AZ=np.abs(Z)
    def smooth(e0,e1,t):
        t=np.clip((t-e0)/(e1-e0),0,1);return t*t*(3-2*t)
    x0,x1,rb=-505.,480.,17.  # lamp base end, bridge end, twin-tube half width
    body=np.where(X<x1-rb,np.maximum(AZ-rb,x0-X),np.hypot(X-(x1-rb),Z)-rb)
    xe=x1-rb-6.  # the gap between the legs stops short of the bridge
    gap=np.where(X<x0,np.hypot(X-x0,Z),np.where(X>xe,np.hypot(X-xe,Z),AZ))
    along=smooth(x0-40,x0+10,X)*smooth(x1+25,x1-20,X)
    light=(.80+.13*smooth(4,-4,body)+.07*np.exp(-(Z/30)**2/2)*along
           -.04*np.exp(-(body/1.4)**2)-.17*np.exp(-(gap/1.8)**2))
    # Lampholder shadow behind the square base end.
    light-=.05*smooth(6,-6,np.maximum(AZ-20,np.maximum(X-x0,x0-40-X)))
    light*=1-.14*(AZ/(LB*1000))**2.5
    light*=1-.08*np.clip(1-(LA*1000-np.abs(X))/45,0,1)**2
    # Fine prismatic crosshatch with a slight moulding wobble.
    rng=np.random.default_rng(7)
    px=X/3.0+.12*np.sin(Z*.37+np.sin(X*.05)*2);pz=Z/2.2+.10*np.sin(X*.29)
    grid=((.5+.5*np.cos(math.tau*px))**6+(.5+.5*np.cos(math.tau*pz))**6)
    light=light*(1-.03*grid)+rng.normal(0,.006,light.shape)
    light=light.reshape(height,ss,width,ss).mean(axis=(1,3))
    tint=np.array([1.0,.985,.94])
    rgba=np.ones((height,width,4),dtype=np.float32)
    rgba[...,:3]=np.clip(light[...,None]*tint,0,1)
    im=bpy.data.images.new(path.stem,width=width,height=height,alpha=False)
    im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(path);im.file_format='PNG';im.save()
    bpy.data.images.remove(im)


def ceiling_preview(prop,art,name,**_):
    """Grey product-shot studio seen from below, like the reference photograph."""
    scene=bpy.context.scene
    collection=bpy.data.collections.new('Preview studio (not exported)')
    scene.collection.children.link(collection)
    def stage(ob):
        for col in list(ob.users_collection):col.objects.unlink(ob)
        collection.objects.link(ob)
    def aim(ob,p):ob.rotation_euler=(Vector(p)-ob.location).to_track_quat('-Z','Y').to_euler()
    bg=scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value=(.5,.5,.5,1);bg.inputs['Strength'].default_value=1.25
    # Stopped down so the lens's authored emission shows its lamp detail;
    # the lights are raised by the same factor to keep the paint mid-grey.
    scene.view_settings.exposure=-1.2
    for label,loc,power,size in [('Key',(-1.3,-1.5,-1.1),140,1.6),('Fill',(1.5,-.8,-.9),65,1.4),('Top rim',(.2,1.2,1.2),90,1.4)]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        ob=bpy.context.object;ob.name=label;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size
        aim(ob,(0,0,0));stage(ob)
    bpy.ops.object.camera_add(location=(-.78,-1.5,-.62))
    cam=bpy.context.object;cam.name='Reference angle';cam.data.lens=50;aim(cam,(-.04,0,.03));stage(cam)
    scene.camera=cam
    scene.render.resolution_x=1536;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    scene.cycles.samples=48;scene.cycles.use_denoising=True
    bpy.ops.wm.save_as_mainfile(filepath=str(art/(name+'.blend')))
    scene.render.filepath=str(art/'preview_reference.png');bpy.ops.render.render(write_still=True)
    cam.location=(.35,-.55,-1.25);aim(cam,(0,0,0))
    scene.render.filepath=str(art/'preview_underside.png');bpy.ops.render.render(write_still=True)
    cam.location=(-.95,.55,.45);aim(cam,(-.35,0,.03))
    scene.render.filepath=str(art/'preview_housing.png');bpy.ops.render.render(write_still=True)


def build():
    h.reset();ART.mkdir(parents=True,exist_ok=True)
    paint=h.material('Olive grey powder coat',(.125,.13,.098),.56,0,.07,.0006)
    dark=h.material('Screw recesses and holes',(.012,.012,.01),.7,0,0)
    trim_frame(paint)
    h.box('Sheet steel housing',(0,HH/2,0),(2*HL,HH,2*HW),paint,.0015)
    for s in (-1,1):
        # Folded end plate: stands proud of the housing and returns round both corners.
        h.box('Folded end plate',(s*(HL+.001),HH/2,0),(.002,HH,2*HW+.004),paint,.001)
        for zs in (-1,1):
            h.box('End plate corner return',(s*(HL-.006),HH/2,zs*(HW+.001)),(.012,HH,.002),paint,.001)
            screw((s*(HL-.03),.028,zs*(HW+.0005)),(0,0,zs),paint,dark)
        screw((s*(HL+.002),.075,s*.048),(s,0,0),paint,dark)
        disc('Empty fixing hole',(s*(HL+.002),.07,-s*.056),(s,0,0),[(.0024,0),(.0024,.0002)],dark,10)
    tex=ART/(NAME+'_diffuser.png');lens_texture(tex)
    lens_mat=h.image_material('Prismatic diffuser lit by twin-tube lamp',tex,emission=EMISSION,rough=.42)
    lens=h.mesh('DiffuserLens',[(-LA,LENS_Y,-LB),(LA,LENS_Y,-LB),(LA,LENS_Y,LB),(-LA,LENS_Y,LB)],[(0,1,2,3)],lens_mat)
    uv=lens.data.uv_layers.new(name='Diffuser')
    for loop in lens.data.loops:uv.data[loop.index].uv=[(0,0),(1,0),(1,1),(0,1)][loop.vertex_index]
    return h.finish(NAME,ART,OUT,2500,specials=[('DiffuserLens',[lens])],surface_normals={'DiffuserLens':(0,-1,0)},
                    metadata={'mount':'ceiling plane at Y=0, diffuser faces -Y','lens_node':'DiffuserLens',
                              'lens_size_m':[round(2*(LA-.0005),3),round(2*(LB-.0005),3)],'emission_energy':EMISSION},
                    preview=ceiling_preview)


if __name__=='__main__':
    build()
