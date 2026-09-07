r"""Mixamo FBX (iskelet, skin=false) -> gri manken surucu videosu (Wan Animate 2 icin).

Blender headless:
  blender -b --python mixamo_manken_render.py -- --fbx "...\Cross Punch [c9c7f89a].fbx" --out C:\...\cross_punch.mp4
       [--w 480 --h 832] [--azimuth 60] [--pad 0.18] [--fps 30] [--bbox_fbx a.fbx b.fbx ...]

Manken = iskelet kemikleri boyunca Skin modifier kapsulleri; Armature modifier ile
kemikleri takip eder. Kamera ortografik, TUM kareler (ve --bbox_fbx ile verilen diger
kliplerin kareleri) uzerinden birlesik sinir kutusuna gore bir kez kurulur -> yumruk/tekme
asla kadraj disina cikmaz, her animasyon ayni tuvali paylasir.
"""
import bpy, sys, os, math, json
from mathutils import Vector, Matrix

def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"w": 480, "h": 832, "azimuth": 60.0, "pad": 0.10, "fps": 30, "bbox_fbx": [], "elev": 0.0, "prop": "", "prop_len": 1.1}
    i = 0
    while i < len(a):
        k = a[i].lstrip("-")
        if k == "bbox_fbx":
            i += 1
            while i < len(a) and not a[i].startswith("--"):
                o["bbox_fbx"].append(a[i]); i += 1
            continue
        o[k] = a[i + 1]; i += 2
    o["w"], o["h"], o["fps"] = int(o["w"]), int(o["h"]), int(o["fps"])
    o["azimuth"], o["pad"], o["elev"], o["prop_len"] = float(o["azimuth"]), float(o["pad"]), float(o["elev"]), float(o["prop_len"])
    return o

PROP_LEN = 0.0
RADII = {  # metre
 "Hips": 0.125, "Spine": 0.12, "Spine1": 0.125, "Spine2": 0.13, "Neck": 0.05, "Head": 0.105,
 "HeadTop_End": None, "Shoulder": 0.055, "Arm": 0.05, "ForeArm": 0.042, "Hand": 0.035,
 "UpLeg": 0.085, "Leg": 0.062, "Foot": 0.045, "ToeBase": 0.035, "Toe_End": 0.03,
}
def radius_of(name):
    n = name.split(":")[-1]
    for side in ("Left", "Right"):
        if n.startswith(side): n = n[len(side):]
    return RADII.get(n)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, ignore_leaf_bones=False, automatic_bone_orientation=False)
    new = [o for o in bpy.data.objects if o not in before]
    arms = [o for o in new if o.type == "ARMATURE"]
    return arms[0], new

def build_manken(arm):
    """Her kemik icin kemige parent'lanmis silindir + eklem kuresi (deterministik, modifier'siz)."""
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    mw = arm.matrix_world
    mat = bpy.data.materials.new("ten")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.85, 0.72, 0.60, 1); bsdf.inputs["Roughness"].default_value = 0.55
    parts = []
    def link_part(ob, bname):
        ob.data.materials.append(mat)
        b = arm.data.bones[bname]
        parent_world = mw @ b.matrix_local @ Matrix.Translation((0, b.length, 0))
        desired = ob.matrix_world.copy()
        ob.parent = arm; ob.parent_type = "BONE"; ob.parent_bone = bname
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_basis = parent_world.inverted() @ desired
        parts.append(ob)
    for b in arm.data.bones:
        r = radius_of(b.name)
        if r is None: continue
        h = mw @ b.head_local; t = mw @ b.tail_local
        d = t - h; L = d.length
        if L < 1e-4: continue
        if b.name.split(":")[-1] == "Head":
            bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0)
            sp = bpy.context.active_object; sp.name = "head"
            sp.matrix_world = Matrix.Translation(h + d.normalized() * 0.09) @ Matrix.Diagonal((0.10, 0.115, 0.125, 1))
            for p in sp.data.polygons: p.use_smooth = True
            link_part(sp, b.name); continue
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1.0, depth=1.0)
        cyl = bpy.context.active_object; cyl.name = "cyl_" + b.name
        rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        cyl.matrix_world = Matrix.Translation((h + t) / 2) @ rot @ Matrix.Diagonal((r, r, L, 1))
        for p in cyl.data.polygons: p.use_smooth = True
        link_part(cyl, b.name)
        for pnt in (h, t):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0)
            sp = bpy.context.active_object; sp.name = "sph_" + b.name
            sp.matrix_world = Matrix.Translation(pnt) @ Matrix.Diagonal((r, r, r, 1))
            for p in sp.data.polygons: p.use_smooth = True
            link_part(sp, b.name)
    bpy.context.view_layer.update()
    arm.data.pose_position = "POSE"
    return parts

PROP_RADIUS = {"sword": 0.022, "staff": 0.02, "bow": 0.015}
def add_prop(arm, kind, length):
    """Sag ele (mixamorig:RightHand) kemik ekseni boyunca uzanan cubuk: kilic/asa. Kabza elde, uc ileri."""
    if not kind: return
    arm.data.pose_position = "REST"; bpy.context.view_layer.update()
    mw = arm.matrix_world
    b = next((x for x in arm.data.bones if x.name.split(":")[-1] == "RightHand"), None)
    if b is None: return
    h = mw @ b.head_local; t = mw @ b.tail_local; d = (t - h).normalized()
    r = PROP_RADIUS.get(kind, 0.02)
    grip = h + d * 0.05
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=1.0, depth=1.0)
    ob = bpy.context.active_object; ob.name = "prop_" + kind
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    ob.matrix_world = Matrix.Translation(grip + d * (length / 2 - 0.15)) @ rot @ Matrix.Diagonal((r, r * 2.2 if kind == "sword" else r, length, 1))
    mat = bpy.data.materials.new("prop"); 
    try: mat.use_nodes = True
    except Exception: pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf: bsdf.inputs["Base Color"].default_value = (0.35, 0.36, 0.40, 1); bsdf.inputs["Roughness"].default_value = 0.3
    ob.data.materials.append(mat)
    parent_world = mw @ b.matrix_local @ Matrix.Translation((0, b.length, 0))
    desired = ob.matrix_world.copy()
    ob.parent = arm; ob.parent_type = "BONE"; ob.parent_bone = b.name
    ob.matrix_parent_inverse = Matrix.Identity(4); ob.matrix_basis = parent_world.inverted() @ desired
    arm.data.pose_position = "POSE"; bpy.context.view_layer.update()

def frame_range(arm):
    ad = arm.animation_data
    if ad and ad.action:
        f0, f1 = ad.action.frame_range
        return int(f0), int(math.ceil(f1))
    return 1, 60

def facing(arm, f):
    """Karakterin ileri yonu (dunya, XY): up x (sag kalca - sol kalca)."""
    bpy.context.scene.frame_set(f)
    mw = arm.matrix_world
    def hb(side):
        pb = next(x for x in arm.pose.bones if x.name.split(":")[-1] == side + "UpLeg")
        return mw @ pb.head
    r = hb("Right") - hb("Left"); r.z = 0
    fw = Vector((0, 0, 1)).cross(r); fw.z = 0
    hips = next(x for x in arm.pose.bones if x.name.split(":")[-1] == "Hips")
    return fw.normalized(), (mw @ hips.head)

def joint_points(arm, f0, f1, step=1):
    pts = []
    sc = bpy.context.scene
    for f in range(f0, f1 + 1, step):
        sc.frame_set(f)
        mw = arm.matrix_world
        for pb in arm.pose.bones:
            r = radius_of(pb.name) or 0.0
            for p in (pb.head, pb.tail):
                w = mw @ p
                pts.append((w, r))
            if PROP_LEN and pb.name.split(":")[-1] == "RightHand":
                d = (mw @ pb.tail - mw @ pb.head).normalized()
                pts.append((mw @ pb.head + d * PROP_LEN, 0.05))
    return pts

def setup_camera(pts, o, fwd):
    """fwd = karakterin ilk karedeki ileri yonu (facing()). azimuth 0 = tam onden, 60 = on-SAG 3/4 (karakter kadrajda sola bakar, kilic eli kameraya yakin; sprite sonra aynalanir)."""
    az = math.radians(o["azimuth"]); el = math.radians(o["elev"])
    up = Vector((0, 0, 1)); fwd = Vector((fwd.x, fwd.y, 0)).normalized(); right = fwd.cross(up).normalized()
    view_dir = (fwd * math.cos(az) + right * math.sin(az))  # kameradan karaktere dogru DEGIL: karakterden kameraya
    cam_dir = view_dir.normalized()
    cam_right = cam_dir.cross(up).normalized()
    cam_up = cam_right.cross(cam_dir).normalized()
    xs, ys = [], []
    for p, r in pts:
        x = p.dot(cam_right); y = p.dot(cam_up)
        xs += [x - r, x + r]; ys += [y - r, y + r]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    aspect = o["w"] / o["h"]
    scale = max(h, w / aspect) * (1 + 2 * o["pad"])   # sensor_fit VERTICAL: ortho_scale = dikey aciklik
    center = cam_right * cx + cam_up * cy
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.sensor_fit = "VERTICAL"; cam_data.ortho_scale = scale
    cam = bpy.data.objects.new("cam", cam_data); bpy.context.scene.collection.objects.link(cam)
    dist = 12.0
    pos = center + cam_dir * dist + up * (dist * math.tan(el))
    cam.location = pos
    look = (center - pos).normalized()
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return {"center": list(center), "ortho_scale": scale, "bbox_w": w, "bbox_h": h}

def setup_world_light():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.11, 0.11, 0.12, 1); bg.inputs[1].default_value = 1.0
    sun = bpy.data.lights.new("sun", "SUN"); sun.energy = 5.0
    so = bpy.data.objects.new("sun", sun); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    fill = bpy.data.lights.new("fill", "SUN"); fill.energy = 2.0
    fo = bpy.data.objects.new("fill", fill); sc.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(60), 0, math.radians(-120))

def render(o, f0, f1):
    import subprocess, shutil, glob
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = o["w"], o["h"]; sc.render.resolution_percentage = 100
    sc.render.fps = o["fps"]; sc.frame_start, sc.frame_end = f0, f1
    frames_dir = os.path.splitext(o["out"])[0] + "_frames"
    shutil.rmtree(frames_dir, ignore_errors=True); os.makedirs(frames_dir, exist_ok=True)
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGB"
    sc.render.filepath = os.path.join(frames_dir, "f_")
    sc.render.film_transparent = False
    try: sc.eevee.taa_render_samples = 16
    except Exception: pass
    bpy.ops.render.render(animation=True)
    first = sorted(glob.glob(os.path.join(frames_dir, "f_*.png")))[0]
    start = int(os.path.basename(first)[2:-4])
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(o["fps"]), "-start_number", str(start),
           "-i", os.path.join(frames_dir, "f_%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", o["out"]]
    subprocess.run(cmd, check=True)
    shutil.copy(first, os.path.splitext(o["out"])[0] + "_first.png")
    mid = sorted(glob.glob(os.path.join(frames_dir, "f_*.png")))
    shutil.copy(mid[len(mid)//2], os.path.splitext(o["out"])[0] + "_mid.png")
    shutil.rmtree(frames_dir, ignore_errors=True)
    try:
        import numpy as np
        px = np.array(bpy.data.images.load(os.path.splitext(o["out"])[0] + "_mid.png").pixels[:]).reshape(-1, 4)[:, :3]
        fg = float(((px - px[0]).__abs__().sum(axis=1) > 0.08).mean())
        print("FG_RATIO", round(fg, 4))
    except Exception as e:
        print("FG_RATIO err", e)

def main():
    o = args()
    global PROP_LEN
    PROP_LEN = o["prop_len"] if o["prop"] else 0.0
    clear_scene()
    arm, _ = import_fbx(o["fbx"])
    f0, f1 = frame_range(arm)
    build_manken(arm)
    add_prop(arm, o["prop"], o["prop_len"])
    fwd0, hips0 = facing(arm, f0)
    pts = joint_points(arm, f0, f1, 1)
    # diger klipler de kadraja dahil (ortak tuval); her klip kendi yuz yonunden ana klibin yonune dondurulur
    for extra in o["bbox_fbx"]:
        a2, objs = import_fbx(extra)
        g0, g1 = frame_range(a2)
        fw2, hips2 = facing(a2, g0)
        ang = math.atan2(fwd0.y, fwd0.x) - math.atan2(fw2.y, fw2.x)
        R = Matrix.Rotation(ang, 4, "Z")
        for p, r in joint_points(a2, g0, g1, 2):
            q = R @ (p - hips2); q.z = p.z - hips2.z
            pts.append((q + hips0, r))
        for ob in objs: bpy.data.objects.remove(ob, do_unlink=True)
    bpy.context.scene.frame_set(f0)
    info = setup_camera(pts, o, fwd0)
    info["facing_deg"] = round(math.degrees(math.atan2(fwd0.y, fwd0.x)), 1)
    setup_world_light()
    os.makedirs(os.path.dirname(o["out"]), exist_ok=True)
    render(o, f0, f1)
    info.update({"frames": f1 - f0 + 1, "fps": o["fps"], "w": o["w"], "h": o["h"], "azimuth": o["azimuth"]})
    json.dump(info, open(os.path.splitext(o["out"])[0] + ".json", "w"), indent=1)
    print("MANKEN OK", json.dumps(info))

main()
