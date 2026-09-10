"""Explicit low-poly construction helpers. Coordinates: Godot X, Y up, +Z front."""
import bpy, bmesh, math, json
from mathutils import Vector
from prop_bake import material, bake_export, studio

parts=[]
def xyz(p): return (p[0],-p[2],p[1])
def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    parts.clear(); bpy.context.preferences.filepaths.save_version=0

def mesh(name,verts,faces,mat,smooth=False):
    data=bpy.data.meshes.new(name); data.from_pydata([xyz(v) for v in verts],[],faces); data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    ob=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(ob)
    data.materials.append(mat)
    for f in data.polygons:f.use_smooth=smooth and len(f.vertices)==4
    parts.append(ob);return ob

def box(name,p,size,mat,bevel=0,segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));ob=bpy.context.object;ob.name=name
    ob.dimensions=xyz((size[0],size[1],-size[2]));bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(mat)
    if bevel:
        m=ob.modifiers.new('Manufactured edge','BEVEL');m.width=min(bevel,min(size)*.24);m.segments=segments;bpy.ops.object.modifier_apply(modifier=m.name)
        m=ob.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
    parts.append(ob);return ob

def tube(name,points,radius,mat,sides=8,caps=True):
    verts=[];prev=None
    for i,p in enumerate(points):
        t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
        if prev is None: u=t.cross(Vector((0,1,0)) if abs(t.y)<.9 else Vector((0,0,1))).normalized()
        else:u=(prev-t*prev.dot(t)).normalized()
        v=t.cross(u).normalized();prev=u
        for j in range(sides):
            a=math.tau*j/sides;verts.append(Vector(p)+radius*(u*math.cos(a)+v*math.sin(a)))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    if caps:faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    return mesh(name,verts,faces,mat,True)

def lathe(name,center,profile,mat,sides=32,cap=True):
    verts=[(center[0]+r*math.cos(math.tau*i/sides),center[1]+y,center[2]+r*math.sin(math.tau*i/sides)) for r,y in profile for i in range(sides)]
    faces=[]
    for k in range(len(profile)-1):
        for j in range(sides):
            a=k*sides+j;b=k*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    if cap:faces.extend([tuple(reversed(range(sides))),tuple(range((len(profile)-1)*sides,len(profile)*sides))])
    return mesh(name,verts,faces,mat,True)

def section(name,profile,xmin,xmax,mat,bevel=0):
    n=len(profile);verts=[(x,y,z) for x in (xmin,xmax) for z,y in profile]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh(name,verts,faces,mat)
    if bevel:
        bpy.context.view_layer.objects.active=ob;m=ob.modifiers.new('Rounded edges','BEVEL');m.width=bevel;m.segments=1;bpy.ops.object.modifier_apply(modifier=m.name)
    return ob

def image_material(name,path,emission=0,rough=.55):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF')
    im=bpy.data.images.load(str(path),check_existing=True);im.pack()
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=rough
    if emission:
        mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=emission
    return mat

def decal(name,p,size,mat,tile=0,grid=4,yaw=0):
    w,h=size;u=Vector((math.cos(yaw),0,-math.sin(yaw)));v=Vector((0,1,0));c=Vector(p)
    ob=mesh(name,[c-u*w/2-v*h/2,c+u*w/2-v*h/2,c+u*w/2+v*h/2,c-u*w/2+v*h/2],[(0,1,2,3)],mat)
    uv=ob.data.uv_layers.new(name='Artwork');x=tile%grid;y=tile//grid
    coords=[((x+.002)/grid,1-(y+.998)/grid),((x+.998)/grid,1-(y+.998)/grid),((x+.998)/grid,1-(y+.002)/grid),((x+.002)/grid,1-(y+.002)/grid)]
    for loop in ob.data.loops:uv.data[loop.index].uv=coords[loop.vertex_index]
    return ob

def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);return ob

def finish(name,art,out,budget,specials=(),metadata=None,scale=3,camera=(3,-4,2.7),target=(0,0,1),surface_normals=None):
    art.mkdir(parents=True,exist_ok=True);out.mkdir(parents=True,exist_ok=True);(art/'.gdignore').write_text('')
    special_objs=[ob for group in specials for ob in group[1]]
    opaque=[ob for ob in parts if ob not in special_objs]
    prop,_=bake_export(opaque,name+'_Body',art,out/(name+'.glb'),budget,metadata)
    final=[prop]
    for label,group in specials:
        if group: final.append(join(group,label))
    total=0;surfaces=0;lo=[1e9]*3;hi=[-1e9]*3
    for ob in final:
        bpy.context.view_layer.objects.active=ob
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.0000001)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        # Capsule end caps contain intentionally collinear vertices along their
        # straight runs. Remove zero-area triangulation remnants, not detail.
        collapsed=[face for face in bm.faces if face.calc_area()<0.000000000001]
        if collapsed:bmesh.ops.delete(bm,geom=collapsed,context='FACES_ONLY')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        # Open display planes have no enclosed volume to define "outside".
        # Their intended viewing direction must survive Blender's recalculation.
        if surface_normals and ob.name in surface_normals:
            facing=Vector(xyz(surface_normals[ob.name])).normalized()
            for face in bm.faces:
                if face.normal.dot(facing)<0:face.normal_flip()
            bm.normal_update()
        bm.to_mesh(ob.data);bm.free()
        total+=len(ob.data.polygons);surfaces+=len(ob.data.materials)
        for v in ob.data.vertices:
            p=ob.matrix_world@v.co;g=(p.x,p.z,-p.y)
            for j in range(3):lo[j]=min(lo[j],g[j]);hi[j]=max(hi[j],g[j])
    assert total<=budget,(name,total,budget)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in final:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_extras=True)
    stats=dict(triangles=total,meshes=len(final),surfaces=surfaces,bounds_godot_m=dict(min=lo,max=hi),front_axis='+Z',**(metadata or {}))
    (out/'mesh_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    print('HERO_PROP_STATS',name,json.dumps(stats),flush=True)
    studio(prop,art,name,target=target,camera_at=camera,scale=scale,light_scale=2)
    return stats
