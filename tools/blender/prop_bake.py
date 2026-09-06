"""Small Blender-only bake/export helpers for original static game props."""
import bpy
import math
import numpy as np
from mathutils import Vector


def material(name, color, roughness=.6, metallic=0., variation=.08, bump=0.):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.diffuse_color=(*color,1)
    nt=mat.node_tree
    bs=nt.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=roughness
    bs.inputs['Metallic'].default_value=metallic
    geo=nt.nodes.new('ShaderNodeNewGeometry')
    tex=nt.nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value=85
    tex.inputs['Detail'].default_value=2
    nt.links.new(geo.outputs['Position'],tex.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(*(c*(1-variation) for c in color),1)
    ramp.color_ramp.elements[1].color=(*(min(1,c*(1+variation)) for c in color),1)
    nt.links.new(tex.outputs['Fac'],ramp.inputs[0])
    ao=nt.nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value=.04
    ao.samples=8
    mix=nt.nodes.new('ShaderNodeMixRGB')
    mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.35
    nt.links.new(ramp.outputs[0],mix.inputs[1])
    nt.links.new(ao.outputs['Color'],mix.inputs[2])
    nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    if bump:
        bn=nt.nodes.new('ShaderNodeBump')
        bn.inputs['Strength'].default_value=.25
        bn.inputs['Distance'].default_value=bump
        nt.links.new(tex.outputs['Fac'],bn.inputs['Height'])
        nt.links.new(bn.outputs[0],bs.inputs['Normal'])
    return mat


def bake_export(parts, name, art, output, triangle_budget, metadata=None,
                preserve_source_uvs=False, uv_detail_region=None):
    """Fuse selected prop pieces, bake a 1K PBR atlas, and export one surface."""
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.cycles.samples=16
    scene.render.bake.use_pass_direct=False
    scene.render.bake.use_pass_indirect=False
    scene.render.bake.use_pass_color=True
    scene.render.bake.margin=6
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    prop=bpy.context.object;prop.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if preserve_source_uvs:
        atlas_uv=prop.data.uv_layers.new(name='GameAtlas')
        prop.data.uv_layers.active=atlas_uv
        atlas_uv.active_render=True
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=math.radians(64),island_margin=.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    if uv_detail_region:
        # Reserve more atlas area for a close-view feature without larger maps.
        axis,limit,factor=uv_detail_region
        uv=prop.data.uv_layers.active.data
        for face in prop.data.polygons:
            center=sum(prop.data.vertices[i].co[axis] for i in face.vertices)/len(face.vertices)
            if center<=limit:
                for loop in face.loop_indices:uv[loop].uv*=factor
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.select_all(action='SELECT')
        bpy.ops.uv.pack_islands(rotate=True,margin=.004)
        bpy.ops.object.mode_set(mode='OBJECT')
    for mat in prop.data.materials:mat.use_fake_user=True

    def bake(suffix,kind,noncolor=False):
        im=bpy.data.images.new(output.stem+'_'+suffix,width=1024,height=1024,alpha=False)
        if noncolor:im.colorspace_settings.name='Non-Color'
        for mat in prop.data.materials:
            node=mat.node_tree.nodes.new('ShaderNodeTexImage')
            node.name='BAKE_TARGET';node.image=im;mat.node_tree.nodes.active=node
        bpy.ops.object.bake(type=kind)
        for mat in prop.data.materials:
            mat.node_tree.nodes.remove(mat.node_tree.nodes.get('BAKE_TARGET'))
        return im

    # Read the shader's base color directly: diffuse baking can darken metals
    # because their BSDF has little diffuse contribution.
    for mat in prop.data.materials:
        nt=mat.node_tree;out=nt.nodes.get('Material Output')
        nt.links.remove(out.inputs['Surface'].links[0])
        em=nt.nodes.new('ShaderNodeEmission');em.name='BAKE_COLOR'
        color=nt.nodes.get('Principled BSDF').inputs['Base Color']
        if color.is_linked:nt.links.new(color.links[0].from_socket,em.inputs['Color'])
        else:em.inputs['Color'].default_value=color.default_value
        nt.links.new(em.outputs[0],out.inputs['Surface'])
    base=bake('basecolor','EMIT')
    for mat in prop.data.materials:
        nt=mat.node_tree;nt.nodes.remove(nt.nodes.get('BAKE_COLOR'))
        nt.links.new(nt.nodes.get('Principled BSDF').outputs[0],nt.nodes.get('Material Output').inputs['Surface'])
    normal=bake('normal','NORMAL',True)
    rough=bake('roughness','ROUGHNESS',True)
    for mat in prop.data.materials:
        nt=mat.node_tree;out=nt.nodes.get('Material Output')
        nt.links.remove(out.inputs['Surface'].links[0])
        em=nt.nodes.new('ShaderNodeEmission');em.name='BAKE_METAL'
        value=nt.nodes.get('Principled BSDF').inputs['Metallic'].default_value
        em.inputs[0].default_value=(value,value,value,1)
        nt.links.new(em.outputs[0],out.inputs['Surface'])
    metal=bake('metallic','EMIT',True)
    for mat in prop.data.materials:
        nt=mat.node_tree;nt.nodes.remove(nt.nodes.get('BAKE_METAL'))
        nt.links.new(nt.nodes.get('Principled BSDF').outputs[0],nt.nodes.get('Material Output').inputs['Surface'])
    pixels=np.ones((1024*1024,4),dtype=np.float32)
    pixels[:,1]=np.asarray(rough.pixels[:],dtype=np.float32).reshape(-1,4)[:,0]
    pixels[:,2]=np.asarray(metal.pixels[:],dtype=np.float32).reshape(-1,4)[:,0]
    orm=bpy.data.images.new(output.stem+'_orm',width=1024,height=1024,alpha=False)
    orm.colorspace_settings.name='Non-Color';orm.pixels.foreach_set(pixels.ravel())
    for im in [base,normal,orm]:
        im.filepath_raw=str(art/(im.name+'.png'));im.file_format='PNG';im.save();im.pack()
    bpy.data.images.remove(rough);bpy.data.images.remove(metal)
    baked=bpy.data.materials.new(name+' | shared 1K PBR atlas');baked.use_nodes=True
    nt=baked.node_tree;bs=nt.nodes.get('Principled BSDF')
    for im in [base,normal,orm]:
        node=nt.nodes.new('ShaderNodeTexImage');node.image=im
        if im==base:nt.links.new(node.outputs['Color'],bs.inputs['Base Color'])
        elif im==normal:
            nm=nt.nodes.new('ShaderNodeNormalMap')
            nt.links.new(node.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs[0],bs.inputs['Normal'])
        else:
            sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(node.outputs['Color'],sep.inputs[0])
            nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    prop.data.materials.clear();prop.data.materials.append(baked)
    for face in prop.data.polygons:face.material_index=0
    if preserve_source_uvs:
        # Projection UVs are authoring inputs, not another runtime texture set.
        for layer in list(prop.data.uv_layers):
            if layer.name!='GameAtlas':prop.data.uv_layers.remove(layer)
    tri=prop.modifiers.new('Explicit game triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    count=len(prop.data.polygons)
    assert count<=triangle_budget, (count,triangle_budget)
    stats={'triangles':count,'meshes':1,'materials':1,'texture_resolution':1024,
           'dimensions_godot_m':[prop.dimensions.x,prop.dimensions.z,prop.dimensions.y]}
    stats.update(metadata or {})
    prop['triangles']=count
    for key,value in (metadata or {}).items():prop[key]=value
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
                             export_yup=True,export_tangents=True,export_extras=True)
    return prop,stats


def studio(prop, art, name, target=(0,0,.55), camera_at=(1.7,-2.4,1.5), scale=1.5, light_scale=1.0):
    """Save an editable source with a studio, then render front and reverse views."""
    scene=bpy.context.scene
    collection=bpy.data.collections.new('Preview studio (not exported)')
    scene.collection.children.link(collection)
    def stage(ob):
        for col in list(ob.users_collection):col.objects.unlink(ob)
        collection.objects.link(ob)
    def aim(ob,p):ob.rotation_euler=(Vector(p)-ob.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001))
    floor=bpy.context.object;floor.name='Studio floor'
    floor.data.materials.append(material('Studio charcoal',(.11,.123,.13),.91,variation=0))
    stage(floor)
    for label,loc,power,size in [('Key',(-1.4,-2.1,3.3),190,2.3),('Fill',(2,-.9,2.0),100,1.5),('Rim',(.3,1.5,2.7),160,1.7)]:
        bpy.ops.object.light_add(type='AREA',location=Vector(loc)*light_scale)
        ob=bpy.context.object;ob.name=label;ob.data.energy=power*light_scale**2;ob.data.shape='DISK';ob.data.size=size*light_scale
        aim(ob,target);stage(ob)
    scene.world.use_nodes=True
    background=scene.world.node_tree.nodes.get('Background')
    background.inputs['Color'].default_value=(.45,.48,.52,1)
    background.inputs['Strength'].default_value=.45
    bpy.ops.object.camera_add(location=camera_at)
    camera=bpy.context.object;camera.name='Prop review';camera.data.type='ORTHO';camera.data.ortho_scale=scale
    aim(camera,target);stage(camera);scene.camera=camera
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    scene.cycles.samples=32;scene.cycles.use_denoising=True
    bpy.ops.object.select_all(action='DESELECT');prop.select_set(True);bpy.context.view_layer.objects.active=prop
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=scale*1.6
            area.spaces.active.region_3d.view_location=Vector(target)
    bpy.ops.wm.save_as_mainfile(filepath=str(art/(name+'.blend')))
    scene.render.filepath=str(art/'preview_front.png');bpy.ops.render.render(write_still=True)
    camera.location=(-camera_at[0],-camera_at[1],camera_at[2]);aim(camera,target)
    scene.render.filepath=str(art/'preview_reverse.png');bpy.ops.render.render(write_still=True)
