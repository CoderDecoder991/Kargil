import bpy
from pathlib import Path

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(Path(r"H:\Kargil-FPS\assets\models\soldier_bamen_candidate.glb")))
rig = bpy.data.objects["BamenMilitarySoldierRig"]
for name in ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"):
    bone = rig.data.bones["mixamorig:" + name]
    pos = rig.matrix_world @ bone.head_local
    print("BONE", name, tuple(round(x, 3) for x in pos))
