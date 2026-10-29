"""Build a rigged, turnaround-inspired patrol soldier from the credited BAMEN base.

The generated sheets are visual references; this script does not claim to recover
their original 3D geometry or an exact historical uniform/likeness.
Run with Blender 5.2: blender --background --factory-startup --python this_file
"""

import bmesh
import bpy
import random
from mathutils import Matrix, Vector
from pathlib import Path

ROOT = Path(r"H:\Kargil-FPS")
SOURCE = ROOT / "assets/models/soldier_bamen_candidate.glb"
OUTPUT = ROOT / "assets/models/patrol_soldier_generated.glb"
TEXTURE_DIR = ROOT / "assets/textures"
REFERENCE = ROOT / "assets/reference/rifle_low_ready_turnaround.png"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
reference_image = bpy.data.images.load(str(REFERENCE), check_existing=True)
reference_pixels = list(reference_image.pixels[:])
reference_width, reference_height = reference_image.size
FABRIC_PATCHES = {
    "Patrol olive winter cloth": (103, 315, 135, 390),
    "Patrol olive jacket panels": (83, 145, 114, 207),
    "Field webbing and pouches": (142, 169, 181, 245),
    "Olive rib knit cap": (139, 25, 187, 51),
    "Dark wool neck warmer": (145, 75, 187, 100),
}

rig = bpy.data.objects["BamenMilitarySoldierRig"]
body = bpy.data.objects["BamenMilitarySoldierMesh"]
for name in ("Icosphere", "HeadSocket", "VestSocket", "BackpackSocket", "WeaponSocket", "BackWeaponSocket", "TeamPatchSocket"):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

# The imported candidate's opaque visor/helmet hides the face. Retain the
# neck and rig, then replace the head shell with a separate head-bone group.
mesh = bmesh.new()
mesh.from_mesh(body.data)
remove = [face for face in mesh.faces if sum(v.co.y for v in face.verts) / len(face.verts) > 178.0]
bmesh.ops.delete(mesh, geom=remove, context="FACES")
mesh.to_mesh(body.data)
mesh.free()
body.data.update()

def material(name, color, roughness=0.89, metallic=0.0, textile=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if textile:
        TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
        texture_path = TEXTURE_DIR / ("patrol_" + name.lower().replace(" ", "_") + ".png")
        texture = bpy.data.images.new(name + " weave", width=128, height=128, alpha=False)
        rng = random.Random(name)
        x0, y0, x1, y1 = FABRIC_PATCHES[name]
        patch_light = []
        for sample_y in range(y0, y1, 3):
            for sample_x in range(x0, x1, 3):
                src_index = ((reference_height - 1 - sample_y) * reference_width + sample_x) * 4
                patch_light.append(sum(reference_pixels[src_index:src_index + 3]) / 3.0)
        mean_light = sum(patch_light) / len(patch_light)
        values = []
        for y in range(128):
            for x in range(128):
                source_x = x0 + (x * (x1 - x0)) // 128
                source_y = y0 + (y * (y1 - y0)) // 128
                src_index = ((reference_height - 1 - source_y) * reference_width + source_x) * 4
                source_light = sum(reference_pixels[src_index:src_index + 3]) / 3.0
                reference_variation = max(0.75, min(1.25, source_light / mean_light))
                weave = 0.022 if (x % 3 == 0) else -0.008
                factor = max(0.72, min(1.27, 0.55 + 0.45 * reference_variation + weave + rng.uniform(-0.012, 0.012)))
                values.extend((color[0] * factor, color[1] * factor, color[2] * factor, 1.0))
        texture.pixels[:] = values
        texture.filepath_raw = str(texture_path)
        texture.file_format = "PNG"
        texture.save()
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = texture
        bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    return mat

olive = material("Patrol olive winter cloth", (0.22, 0.21, 0.17), textile=True)
olive_light = material("Patrol olive jacket panels", (0.25, 0.24, 0.19), textile=True)
vest = material("Field webbing and pouches", (0.18, 0.17, 0.13), textile=True)
strap = material("Worn canvas straps", (0.10, 0.12, 0.09))
leather = material("Blackened boot leather", (0.075, 0.072, 0.064), roughness=0.76)
skin = material("Generic medium brown skin", (0.39, 0.245, 0.17), roughness=0.85)
metal = material("Dulled hardware", (0.13, 0.14, 0.12), roughness=0.69, metallic=0.28)
cap_mat = material("Olive rib knit cap", (0.19, 0.18, 0.14), textile=True)
scarf_mat = material("Dark wool neck warmer", (0.14, 0.13, 0.10), textile=True)

slot_map = {
    "Soldier_Clothes": olive,
    "Soldier_Iron": olive_light,
    "Soldier_Fabric": vest,
    "Soldier_Metal": metal,
    "Soldier_Elements": strap,
    "Soldier_Armor": vest,
    "Soldier_Flesh": skin,
    "Soldier_Shoes": leather,
    "Soldier_Boots": leather,
    "Soldier_Glass": olive,
    "Soldier_Skin": skin,
}
for i, old in enumerate(list(body.data.materials)):
    body.data.materials[i] = slot_map[old.name]

def attach_to_bone(obj, bone_name):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.matrix_world = world
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("follow humanoid rig", "ARMATURE")
    modifier.object = rig
    return obj

def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj

def uv_sphere(name, location, scale, mat, bone, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=(location[0], -location[1], location[2]))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return attach_to_bone(obj, bone)

def cube(name, location, scale, mat, bone, bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(location[0], -location[1], location[2]))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("soft sewn edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    return attach_to_bone(obj, bone)

def strap_between(name, start, end, width, depth, mat, bone):
    start = Vector((start[0], -start[1], start[2]))
    end = Vector((end[0], -end[1], end[2]))
    midpoint = (start + end) / 2
    span = end - start
    midpoint.y = -midpoint.y # cube() performs the Blender front-axis swap.
    obj = cube(name, midpoint, (width, depth, span.length), mat, bone, bevel=0.004)
    # Rotate the elongated Z axis into the requested strap direction.
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(span.normalized())
    return obj

HEAD = "mixamorig:Head"
SPINE = "mixamorig:Spine2"
HIPS = "mixamorig:Hips"

# A visible face and knit cap replace the opaque contemporary helmet.
uv_sphere("Face and jaw", (0.0, 0.010, 1.845), (0.118, 0.100, 0.143), skin, HEAD)
uv_sphere("Nose bridge", (0.0, 0.108, 1.852), (0.020, 0.027, 0.040), skin, HEAD, 12, 8)
for side in (-1, 1):
    uv_sphere("Ear %s" % side, (side * 0.119, 0.006, 1.835), (0.018, 0.024, 0.038), skin, HEAD, 12, 8)
    uv_sphere("Eye shadow %s" % side, (side * 0.040, 0.096, 1.880), (0.019, 0.006, 0.009), strap, HEAD, 12, 8)
    uv_sphere("Brow %s" % side, (side * 0.043, 0.094, 1.904), (0.029, 0.006, 0.005), strap, HEAD, 12, 8)
uv_sphere("Wool cap crown", (0.0, 0.000, 1.965), (0.135, 0.122, 0.095), cap_mat, HEAD)
uv_sphere("Folded cap rim", (0.0, 0.000, 1.915), (0.141, 0.128, 0.026), cap_mat, HEAD)
uv_sphere("Neck warmer", (0.0, 0.000, 1.716), (0.131, 0.120, 0.055), scarf_mat, SPINE)

# The reference silhouette has canvas equipment rather than exposed plate
# armor. These pieces follow torso/pelvis bones and leave the arms free.
cube("Layered field vest", (0.0, 0.152, 1.353), (0.45, 0.096, 0.44), vest, SPINE, 0.032)
for side in (-1, 1):
    x = side * 0.160
    for row, z in enumerate((1.195, 1.335)):
        cube("Front magazine pouch %s %s" % (side, row), (x, 0.222, z), (0.123, 0.073, 0.147), vest, SPINE, 0.016)
        cube("Pouch flap %s %s" % (side, row), (x, 0.268, z + 0.048), (0.120, 0.012, 0.043), olive_light, SPINE, 0.005)
    cube("Side utility pouch %s" % side, (side * 0.302, -0.006, 1.113), (0.094, 0.132, 0.158), vest, HIPS, 0.015)
    strap_between("Shoulder web strap %s" % side, (side * 0.225, 0.143, 1.555), (side * 0.17, 0.236, 1.175), 0.036, 0.014, strap, SPINE)

cube("Canvas mountain pack", (0.0, -0.235, 1.338), (0.422, 0.220, 0.462), vest, SPINE, 0.052)
cube("Pack flap", (0.0, -0.365, 1.525), (0.415, 0.052, 0.112), olive_light, SPINE, 0.025)
for side in (-1, 1):
    cube("Pack side pocket %s" % side, (side * 0.242, -0.258, 1.262), (0.101, 0.167, 0.202), olive_light, SPINE, 0.023)
    strap_between("Pack closure %s" % side, (side * 0.126, -0.394, 1.555), (side * 0.126, -0.407, 1.20), 0.024, 0.014, strap, SPINE)

# Collapse rigid kit details into the skinned body mesh. The imported body's
# armature modifier is kept active; matching bone vertex groups merge by name.
bpy.ops.object.select_all(action="DESELECT")
for obj in bpy.data.objects:
    if obj.type == "MESH":
        obj.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()

# Store a native Blender source alongside the exported rig for later art work.
bpy.context.preferences.filepaths.save_version = 0
(ROOT / "source_art").mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "source_art/patrol_soldier_generated.blend"))
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    export_apply=False,
    export_materials="EXPORT",
    export_animations=False,
    export_yup=True,
)
print("PATROL_EXPORT", OUTPUT, OUTPUT.stat().st_size)
