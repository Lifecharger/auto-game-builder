"""
Blender Auto-Splitter — Splits a rigged model into modular body parts by bone groups.

Usage (command line):
    "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" --background --python blender_auto_splitter.py -- --input model.fbx --output ./parts/

Usage (with arguments):
    blender --background --python blender_auto_splitter.py -- --input model.fbx --output ./parts/ --format glb --groups "Head,Spine,LeftArm,RightArm,LeftLeg,RightLeg"

The script:
1. Imports an FBX/GLB model
2. Finds the main mesh and its vertex groups (bone assignments)
3. Groups vertices by bone regions (head, torso, arms, legs, hands, feet)
4. Separates each region into its own mesh
5. Exports each part as .glb (or .fbx) with skeleton intact
"""

import bpy
import bmesh
import os
import sys
import argparse


# --- Bone-to-region mapping ---
# Maps common bone names (MakeHuman, Mixamo, etc.) to body regions
BONE_REGION_MAP = {
    # Head
    "head": "head", "Head": "head",
    "neck": "head", "Neck": "head",
    "jaw": "head", "Jaw": "head",
    "eye": "head", "Eye": "head",
    "tongue": "head", "Tongue": "head",
    # MakeHuman specific
    "orbicularis": "head", "temporalis": "head", "oculi": "head",
    "brow": "head", "nose": "head", "lip": "head", "cheek": "head",
    "ear": "head", "chin": "head", "masseter": "head",
    "levator": "head", "corrugator": "head", "frontalis": "head",

    # Torso
    "spine": "torso", "Spine": "torso",
    "chest": "torso", "Chest": "torso",
    "hips": "torso", "Hips": "torso",
    "pelvis": "torso", "Pelvis": "torso",
    "root": "torso", "Root": "torso",
    "abdomen": "torso",

    # Left arm
    "leftshoulder": "arm_left", "LeftShoulder": "arm_left",
    "leftarm": "arm_left", "LeftArm": "arm_left",
    "leftforearm": "arm_left", "LeftForeArm": "arm_left",
    "left_upper_arm": "arm_left", "left_lower_arm": "arm_left",
    "l_upperarm": "arm_left", "l_forearm": "arm_left",
    "clavicle_l": "arm_left", "upperarm_l": "arm_left", "lowerarm_l": "arm_left",

    # Right arm
    "rightshoulder": "arm_right", "RightShoulder": "arm_right",
    "rightarm": "arm_right", "RightArm": "arm_right",
    "rightforearm": "arm_right", "RightForeArm": "arm_right",
    "right_upper_arm": "arm_right", "right_lower_arm": "arm_right",
    "r_upperarm": "arm_right", "r_forearm": "arm_right",
    "clavicle_r": "arm_right", "upperarm_r": "arm_right", "lowerarm_r": "arm_right",

    # Left hand
    "lefthand": "hand_left", "LeftHand": "hand_left",
    "l_hand": "hand_left", "hand_l": "hand_left",
    "lefthandindex": "hand_left", "lefthandmiddle": "hand_left",
    "lefthandring": "hand_left", "lefthandpinky": "hand_left",
    "lefthandthumb": "hand_left",
    "l_index": "hand_left", "l_middle": "hand_left",
    "l_ring": "hand_left", "l_pinky": "hand_left", "l_thumb": "hand_left",

    # Right hand
    "righthand": "hand_right", "RightHand": "hand_right",
    "r_hand": "hand_right", "hand_r": "hand_right",
    "righthandindex": "hand_right", "righthandmiddle": "hand_right",
    "righthandring": "hand_right", "righthandpinky": "hand_right",
    "righthandthumb": "hand_right",
    "r_index": "hand_right", "r_middle": "hand_right",
    "r_ring": "hand_right", "r_pinky": "hand_right", "r_thumb": "hand_right",

    # Left leg
    "leftupleg": "leg_left", "LeftUpLeg": "leg_left",
    "leftleg": "leg_left", "LeftLeg": "leg_left",
    "left_upper_leg": "leg_left", "left_lower_leg": "leg_left",
    "l_thigh": "leg_left", "l_shin": "leg_left",
    "thigh_l": "leg_left", "calf_l": "leg_left",

    # Right leg
    "rightupleg": "leg_right", "RightUpLeg": "leg_right",
    "rightleg": "leg_right", "RightLeg": "leg_right",
    "right_upper_leg": "leg_right", "right_lower_leg": "leg_right",
    "r_thigh": "leg_right", "r_shin": "leg_right",
    "thigh_r": "leg_right", "calf_r": "leg_right",

    # Left foot
    "leftfoot": "foot_left", "LeftFoot": "foot_left",
    "lefttoebase": "foot_left", "LeftToeBase": "foot_left",
    "l_foot": "foot_left", "foot_l": "foot_left",
    "l_toe": "foot_left",

    # Right foot
    "rightfoot": "foot_right", "RightFoot": "foot_right",
    "righttoebase": "foot_right", "RightToeBase": "foot_right",
    "r_foot": "foot_right", "foot_r": "foot_right",
    "r_toe": "foot_right",
}


def classify_bone(bone_name: str) -> str:
    """Classify a bone name into a body region."""
    # Direct match
    if bone_name in BONE_REGION_MAP:
        return BONE_REGION_MAP[bone_name]

    # Partial match (case-insensitive)
    name_lower = bone_name.lower()
    for key, region in BONE_REGION_MAP.items():
        if key.lower() in name_lower:
            return region

    # Fallback heuristics
    # Individual fingers
    if "_l" in name_lower or ".l" in name_lower:
        if "thumb" in name_lower: return "thumb_left"
        if "index" in name_lower: return "index_left"
        if "middle" in name_lower: return "middle_finger_left"
        if "ring" in name_lower: return "ring_finger_left"
        if "pinky" in name_lower: return "pinky_left"
    if "_r" in name_lower or ".r" in name_lower:
        if "thumb" in name_lower: return "thumb_right"
        if "index" in name_lower: return "index_right"
        if "middle" in name_lower: return "middle_finger_right"
        if "ring" in name_lower: return "ring_finger_right"
        if "pinky" in name_lower: return "pinky_right"

    hand_keywords = ["hand", "finger", "metacarpal", "wrist"]
    foot_keywords = ["foot", "toe", "ball"]
    leg_keywords = ["leg", "thigh", "shin", "calf"]
    arm_keywords = ["arm", "shoulder", "clavicle", "elbow"]

    if "left" in name_lower or "_l" in name_lower or ".l" in name_lower:
        if any(k in name_lower for k in hand_keywords):
            return "hand_left"
        if any(k in name_lower for k in foot_keywords):
            return "foot_left"
        if any(k in name_lower for k in leg_keywords):
            return "leg_left"
        if any(k in name_lower for k in arm_keywords):
            return "arm_left"

    if "right" in name_lower or "_r" in name_lower or ".r" in name_lower:
        if any(k in name_lower for k in hand_keywords):
            return "hand_right"
        if any(k in name_lower for k in foot_keywords):
            return "foot_right"
        if any(k in name_lower for k in leg_keywords):
            return "leg_right"
        if any(k in name_lower for k in arm_keywords):
            return "arm_right"

    if "head" in name_lower or "neck" in name_lower or "jaw" in name_lower or "eye" in name_lower:
        return "head"

    if "spine" in name_lower or "chest" in name_lower or "hip" in name_lower or "pelvis" in name_lower:
        return "torso"

    # Unknown — assign to torso as fallback
    return "torso"


def get_vertex_group_region_map(obj) -> dict:
    """Build a mapping from vertex group index to body region."""
    vg_map = {}
    for vg in obj.vertex_groups:
        region = classify_bone(vg.name)
        vg_map[vg.index] = region
    return vg_map


def get_vertex_regions(obj) -> dict:
    """Assign each vertex to a body region based on its strongest bone weight."""
    vg_region_map = get_vertex_group_region_map(obj)
    vertex_regions = {}  # vertex_index -> region

    for vert in obj.data.vertices:
        best_weight = 0.0
        best_region = "torso"

        for group in vert.groups:
            if group.weight > best_weight:
                region = vg_region_map.get(group.group, "torso")
                best_weight = group.weight
                best_region = region

        vertex_regions[vert.index] = best_region

    return vertex_regions


def separate_by_region(obj, regions_to_extract: list, output_dir: str, fmt: str = "glb"):
    """Separate mesh into body parts and export each."""
    vertex_regions = get_vertex_regions(obj)

    # Find all unique regions
    all_regions = set(vertex_regions.values())
    print(f"Found regions: {sorted(all_regions)}")

    # Filter to requested regions (or all if none specified)
    if regions_to_extract:
        target_regions = [r for r in regions_to_extract if r in all_regions]
    else:
        target_regions = sorted(all_regions)

    print(f"Extracting: {target_regions}")

    exported = []
    armature = obj.parent if obj.parent and obj.parent.type == 'ARMATURE' else None

    for region in target_regions:
        print(f"\nProcessing region: {region}")

        # Duplicate the object
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.duplicate()
        dup = bpy.context.active_object
        dup.name = f"part_{region}"

        # Enter edit mode and select vertices NOT in this region
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='DESELECT')

        bm = bmesh.from_edit_mesh(dup.data)
        bm.verts.ensure_lookup_table()

        # Select vertices that DON'T belong to this region
        for vert in bm.verts:
            orig_idx = vert.index
            if orig_idx in vertex_regions and vertex_regions[orig_idx] != region:
                vert.select = True

        bmesh.update_edit_mesh(dup.data)

        # Delete selected (non-region) vertices
        bpy.ops.mesh.delete(type='VERT')
        bpy.ops.object.mode_set(mode='OBJECT')

        # Check if any geometry remains
        if len(dup.data.vertices) == 0:
            print(f"  No vertices for region {region}, skipping")
            bpy.data.objects.remove(dup, do_unlink=True)
            continue

        print(f"  Vertices: {len(dup.data.vertices)}, Faces: {len(dup.data.polygons)}")

        # Export
        filepath = os.path.join(output_dir, f"{region}.{fmt}")

        bpy.ops.object.select_all(action='DESELECT')
        dup.select_set(True)
        if armature:
            armature.select_set(True)
        bpy.context.view_layer.objects.active = dup

        if fmt == "glb":
            bpy.ops.export_scene.gltf(
                filepath=filepath,
                use_selection=True,
                export_format='GLB',
                export_skins=True,
                export_morph=True,
            )
        elif fmt == "fbx":
            bpy.ops.export_scene.fbx(
                filepath=filepath,
                use_selection=True,
                add_leaf_bones=False,
                use_armature_deform_only=False,
            )

        exported.append(filepath)
        print(f"  Exported: {filepath}")

        # Clean up duplicate
        bpy.data.objects.remove(dup, do_unlink=True)

    return exported


def find_main_mesh():
    """Find the main mesh object in the scene."""
    meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
    if not meshes:
        return None
    # Prefer mesh with most vertices
    return max(meshes, key=lambda m: len(m.data.vertices))


def import_model(filepath: str):
    """Import a model file."""
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=filepath)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=filepath)
    else:
        raise ValueError(f"Unsupported format: {ext}")


def main():
    # Parse arguments after "--"
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    parser = argparse.ArgumentParser(description="Auto-split rigged model into body parts")
    parser.add_argument("--input", "-i", required=True, help="Input model file (.fbx, .glb)")
    parser.add_argument("--output", "-o", required=True, help="Output directory for parts")
    parser.add_argument("--format", "-f", default="glb", choices=["glb", "fbx"], help="Export format")
    parser.add_argument("--groups", "-g", default="", help="Comma-separated regions to extract (default: all)")
    parser.add_argument("--list-bones", action="store_true", help="Just list bones and their regions, don't split")

    args = parser.parse_args(argv)

    # Clean scene
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Import model
    print(f"\nImporting: {args.input}")
    import_model(args.input)

    # Find main mesh
    mesh_obj = find_main_mesh()
    if not mesh_obj:
        print("ERROR: No mesh found in the imported file!")
        sys.exit(1)

    print(f"Main mesh: {mesh_obj.name} ({len(mesh_obj.data.vertices)} vertices)")
    print(f"Vertex groups: {len(mesh_obj.vertex_groups)}")

    # List bones mode
    if args.list_bones:
        vg_map = get_vertex_group_region_map(mesh_obj)
        regions = {}
        for vg in mesh_obj.vertex_groups:
            region = classify_bone(vg.name)
            if region not in regions:
                regions[region] = []
            regions[region].append(vg.name)

        for region in sorted(regions.keys()):
            print(f"\n[{region}]")
            for bone in sorted(regions[region]):
                print(f"  {bone}")
        sys.exit(0)

    # Create output directory
    os.makedirs(args.output, exist_ok=True)

    # Parse region filter
    regions = [r.strip() for r in args.groups.split(",") if r.strip()] if args.groups else []

    # Split and export
    exported = separate_by_region(mesh_obj, regions, args.output, args.format)

    print(f"\n{'='*50}")
    print(f"Done! Exported {len(exported)} parts to: {args.output}")
    for path in exported:
        print(f"  {path}")


if __name__ == "__main__":
    main()
