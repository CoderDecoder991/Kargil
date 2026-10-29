import bpy
from mathutils import Vector

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=r"H:\Kargil-FPS\assets\models\soldier_bamen_candidate.glb")

for obj in bpy.data.objects:
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box] if obj.type == "MESH" else []
    extent = (
        tuple(round(max(p[i] for p in corners) - min(p[i] for p in corners), 3) for i in range(3))
        if corners else None
    )
    bounds_world = tuple((round(min(p[i] for p in corners), 3), round(max(p[i] for p in corners), 3)) for i in range(3)) if corners else None
    print("PATROL_OBJECT", obj.name, obj.type, "parent", obj.parent.name if obj.parent else None, "extent", extent, "bounds", bounds_world)
    if obj.type == "MESH":
        print("PATROL_MATERIALS", obj.name, [(m.name if m else None) for m in obj.data.materials])
        if obj.name == "BamenMilitarySoldierMesh":
            for material in obj.data.materials:
                print("PATROL_MATERIAL_NODES", material.name, [(n.type, n.name, getattr(getattr(n, 'image', None), 'name', '')) for n in material.node_tree.nodes] if material and material.use_nodes else [])
        if obj.name == "BamenMilitarySoldierMesh":
            for index, material in enumerate(obj.data.materials):
                used = [obj.data.vertices[v].co for poly in obj.data.polygons if poly.material_index == index for v in poly.vertices]
                if used:
                    bounds = [(round(min(p[k] for p in used), 3), round(max(p[k] for p in used), 3)) for k in range(3)]
                    print("PATROL_MATERIAL_BOUNDS", index, material.name, len(used), bounds)
    if obj.type == "ARMATURE":
        print("PATROL_BONES", [bone.name for bone in obj.data.bones])
        for key in ("mixamorig:Head", "mixamorig:LeftHand", "mixamorig:RightHand", "mixamorig:Hips"):
            bone = obj.data.bones.get(key)
            print("PATROL_BONE", key, tuple(round(x, 3) for x in bone.head_local), tuple(round(x, 3) for x in bone.tail_local))
            print("PATROL_BONE_WORLD", key, tuple(round(x, 3) for x in (obj.matrix_world @ bone.head_local)))
