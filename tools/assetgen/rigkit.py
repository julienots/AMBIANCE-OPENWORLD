"""rigkit — procedural character construction for SYMBIOTE: ABYSS.

A character is described as a tree of joints (position + radius). Blender's Skin
modifier turns the tree into a smooth organic hull, a Subdivision modifier rounds it,
and the result is baked into a mesh. Each joint that has children owns a bone whose
head sits on the joint and whose tail points to its first child, so rotating a bone
pivots everything downstream. Rigid parts (heads, armour plates, horns, eyes…) are
added as extra geometry fully weighted to one bone.

Animations are authored as rotations expressed in *armature space* (X = character's
left, -Y = forward, Z = up) and converted to bone-local quaternions, so the same
animation function works for every body built from the same joint names.

Run with the Blender Python module (bpy), e.g. /opt/bpyenv/bin/python build_all.py
"""
import math
from collections import OrderedDict

import bpy  # must be imported before bmesh/mathutils
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def v(x, y=None, z=None):
    if y is None:
        return Vector(x)
    return Vector((x, y, z))


class Joint:
    def __init__(self, name, pos, r, parent, mat, bone):
        self.name = name
        self.pos = v(pos)
        self.r = (r, r) if isinstance(r, (int, float)) else tuple(r)
        self.parent = parent
        self.mat = mat
        self.force_bone = bone
        self.children = []


class Part:
    def __init__(self, bm_fn, bone, mat, smooth=True):
        self.bm_fn = bm_fn
        self.bone = bone
        self.mat = mat
        self.smooth = smooth


# ---------------------------------------------------------------------------
# Primitive builders (each returns a function that fills a bmesh, in armature space)
# ---------------------------------------------------------------------------

def _xform(bm, verts, loc, rot, scale):
    m = Matrix.Translation(v(loc)) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() \
        @ Matrix.Diagonal((*scale, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=verts)


def ellipsoid(loc, size, rot=(0, 0, 0), segs=16, rings=10):
    def fn(bm):
        before = set(bm.verts)
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
        new = [x for x in bm.verts if x not in before]
        _xform(bm, new, loc, rot, size)
    return fn


def box(loc, size, rot=(0, 0, 0), bevel=0.0):
    def fn(bm):
        before = set(bm.verts)
        bmesh.ops.create_cube(bm, size=1.0)
        new = [x for x in bm.verts if x not in before]
        _xform(bm, new, loc, rot, size)
        if bevel > 0:
            edges = list({e for vv in new for e in vv.link_edges})
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, profile=0.5, affect='EDGES')
    return fn


def cone(loc, r1, r2, depth, rot=(0, 0, 0), segs=10, scale=(1, 1, 1)):
    """Cone/cylinder along local +Z starting at loc (base) ending at loc+depth."""
    def fn(bm):
        before = set(bm.verts)
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs,
                              radius1=r1, radius2=r2, depth=depth)
        new = [x for x in bm.verts if x not in before]
        bmesh.ops.translate(bm, vec=(0, 0, depth / 2), verts=new)
        _xform(bm, new, loc, rot, scale)
    return fn


def torus(loc, major, minor, rot=(0, 0, 0), segs=24, ring=8, scale=(1, 1, 1)):
    def fn(bm):
        verts = []
        rows = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            row = []
            for j in range(ring):
                b = 2 * math.pi * j / ring
                x = (major + minor * math.cos(b)) * math.cos(a)
                y = (major + minor * math.cos(b)) * math.sin(a)
                z = minor * math.sin(b)
                vv = bm.verts.new((x, y, z))
                row.append(vv)
                verts.append(vv)
            rows.append(row)
        for i in range(segs):
            for j in range(ring):
                a, b = rows[i][j], rows[(i + 1) % segs][j]
                c, d = rows[(i + 1) % segs][(j + 1) % ring], rows[i][(j + 1) % ring]
                bm.faces.new((a, b, c, d))
        _xform(bm, verts, loc, rot, scale)
    return fn


def tube(points, radii, segs=8):
    """Smooth tube through points with per-point radius (for cables, tentacle props…)."""
    def fn(bm):
        rings = []
        pts = [v(p) for p in points]
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            s1 = d.cross(up).normalized()
            s2 = d.cross(s1).normalized()
            ring = []
            for k in range(segs):
                a = 2 * math.pi * k / segs
                ring.append(bm.verts.new(p + (s1 * math.cos(a) + s2 * math.sin(a)) * radii[i]))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(segs):
                bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return fn


# ---------------------------------------------------------------------------
# Character builder
# ---------------------------------------------------------------------------

class Character:
    def __init__(self, name):
        self.name = name
        self.joints = OrderedDict()
        self.parts = []
        self.materials = OrderedDict()
        self.subsurf = 1
        self.weight_sigma = 0.06
        self.arm_obj = None
        self.mesh_obj = None

    # -- definition --------------------------------------------------------
    def mat(self, name, color, emission=0.0, metallic=0.0, roughness=0.6):
        self.materials[name] = (color, emission, metallic, roughness)

    def j(self, name, pos, r, parent=None, mat=None, bone=False):
        if parent is not None and mat is None:
            mat = self.joints[parent].mat
        jt = Joint(name, pos, r, parent, mat or next(iter(self.materials)), bone)
        self.joints[name] = jt
        if parent:
            self.joints[parent].children.append(name)
        return jt

    def jm(self, name, pos, r, parent=None, mat=None, bone=False):
        """Define a left joint (suffix _l, +X) and its mirrored right twin (_r)."""
        p = v(pos)
        pl = parent + "_l" if parent and parent + "_l" in self.joints else parent
        self.j(name + "_l", p, r, pl, mat, bone)
        pr = parent + "_r" if parent and parent + "_r" in self.joints else parent
        self.j(name + "_r", (-p.x, p.y, p.z), r, pr, mat, bone)

    def chain(self, prefix, start_parent, points, radii, mat=None):
        """Joint chain (tentacles, tails, spines). Returns joint names."""
        names = []
        parent = start_parent
        for i, (p, r) in enumerate(zip(points, radii)):
            n = f"{prefix}{i}"
            self.j(n, p, r, parent, mat)
            names.append(n)
            parent = n
        return names

    def part(self, fn, bone, mat, smooth=True):
        self.parts.append(Part(fn, bone, mat, smooth))

    def part_m(self, maker, bone, mat, smooth=True, **kw):
        """Mirrored part: maker(sign) returns a bmesh fn; bone given without suffix."""
        self.parts.append(Part(maker(1), bone + "_l", mat, smooth))
        self.parts.append(Part(maker(-1), bone + "_r", mat, smooth))

    def bone_names(self):
        return [n for n, jt in self.joints.items() if jt.children or jt.force_bone]

    # -- build ---------------------------------------------------------------
    def _make_materials(self):
        mats = {}
        for name, (col, em, met, rough) in self.materials.items():
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            rgba = (*col, 1.0) if len(col) == 3 else col
            bsdf.inputs["Base Color"].default_value = rgba
            bsdf.inputs["Metallic"].default_value = met
            bsdf.inputs["Roughness"].default_value = rough
            if em > 0:
                bsdf.inputs["Emission Color"].default_value = rgba
                bsdf.inputs["Emission Strength"].default_value = em
            mats[name] = m
        return mats

    def _segments(self):
        segs = []  # (bone, a, b, ra, rb, mat)
        for n, jt in self.joints.items():
            if jt.parent:
                p = self.joints[jt.parent]
                segs.append((p.name, p.pos, jt.pos, sum(p.r) / 2, sum(jt.r) / 2, jt.mat))
        return segs

    def build(self):
        for part in self.parts:
            if part.bone in self.joints:
                self.joints[part.bone].force_bone = True
        names = list(self.joints.keys())
        index = {n: i for i, n in enumerate(names)}
        # Skin skeleton mesh
        sk = bpy.data.meshes.new(self.name + "_skel")
        edges = [(index[jt.parent], index[n]) for n, jt in self.joints.items() if jt.parent]
        sk.from_pydata([tuple(self.joints[n].pos) for n in names], edges, [])
        sob = bpy.data.objects.new(self.name + "_skel", sk)
        bpy.context.scene.collection.objects.link(sob)
        skin = sob.modifiers.new("skin", "SKIN")
        skin.branch_smoothing = 0.6
        skin.use_smooth_shade = True
        for i, n in enumerate(names):
            sv = sk.skin_vertices[0].data[i]
            sv.radius = self.joints[n].r
            sv.use_root = (self.joints[n].parent is None)
        if self.subsurf:
            sub = sob.modifiers.new("sub", "SUBSURF")
            sub.levels = self.subsurf
            sub.render_levels = self.subsurf
        dg = bpy.context.evaluated_depsgraph_get()
        body = bpy.data.meshes.new_from_object(sob.evaluated_get(dg))
        bpy.data.objects.remove(sob)

        mats = self._make_materials()
        mat_names = list(mats.keys())
        bm = bmesh.new()
        bm.from_mesh(body)
        segs = self._segments()
        bone_list = self.bone_names()
        bone_idx = {b: i for i, b in enumerate(bone_list)}
        weights = {}  # vert -> {bone: w}

        def seg_dist(p, a, b, ra, rb):
            ab = b - a
            L2 = ab.length_squared
            t = 0.0 if L2 < 1e-9 else max(0.0, min(1.0, (p - a).dot(ab) / L2))
            q = a + ab * t
            return (p - q).length - (ra + (rb - ra) * t), t

        for face in bm.faces:
            c = face.calc_center_median()
            best, bm_mat = 1e9, None
            for (bn, a, b, ra, rb, mat) in segs:
                d, t = seg_dist(c, a, b, ra, rb)
                if d < best:
                    best, bm_mat = d, mat
            face.material_index = mat_names.index(bm_mat)
            face.smooth = True
        sig = self.weight_sigma
        # Tag every vertex: >0 = body vertex uid, <0 = rigid part bone index (-(i+1)), 0 = untagged
        tag = bm.verts.layers.int.new("rig_tag")
        ftag = bm.faces.layers.int.new("rig_ftag")
        for f in bm.faces:
            f[ftag] = 1
        body_w = {}
        for vert in bm.verts:
            ws = {}
            for (bn, a, b, ra, rb, mat) in segs:
                d, t = seg_dist(vert.co, a, b, ra, rb)
                w = math.exp(-max(d, 0.0) / sig)
                ws[bn] = max(ws.get(bn, 0.0), w)
            top = sorted(ws.items(), key=lambda kv: -kv[1])[:3]
            top = [(b_, w_) for b_, w_ in top if w_ > 1e-6] or [top[0]]
            tot = sum(w for _, w in top) or 1.0
            kept = {b_: w_ / tot for b_, w_ in top if w_ / tot > 0.03}
            tot2 = sum(kept.values())
            uid = len(body_w) + 1
            body_w[uid] = {b_: w_ / tot2 for b_, w_ in kept.items()}
            vert[tag] = uid

        # Rigid parts
        for part in self.parts:
            part.bm_fn(bm)
            for f in bm.faces:
                if f[ftag] == 0:
                    f[ftag] = 1
                    f.material_index = mat_names.index(part.mat)
                    f.smooth = part.smooth
            bidx = bone_idx[part.bone] if part.bone in bone_idx else None
            if bidx is None:
                raise ValueError(f"{self.name}: part attached to non-bone joint {part.bone}")
            for vv in bm.verts:
                if vv[tag] == 0:
                    vv[tag] = -(bidx + 1)
        bm.verts.index_update()
        for vv in bm.verts:
            t_ = vv[tag]
            if t_ > 0:
                weights[vv.index] = body_w[t_]
            elif t_ < 0:
                weights[vv.index] = {bone_list[-t_ - 1]: 1.0}
            else:
                raise ValueError(f"{self.name}: untagged vertex {vv.index}")
        bm.verts.index_update()
        bm.normal_update()
        mesh = bpy.data.meshes.new(self.name + "_mesh")
        bm.to_mesh(mesh)
        bm.free()
        for m in mats.values():
            mesh.materials.append(m)
        # Remove unused material slots
        mob = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(mob)

        # Armature
        arm = bpy.data.armatures.new(self.name + "_arm")
        aob = bpy.data.objects.new(self.name + "_rig", arm)
        bpy.context.scene.collection.objects.link(aob)
        bpy.context.view_layer.objects.active = aob
        bpy.ops.object.mode_set(mode="EDIT")
        ebones = {}
        for bn in bone_list:
            jt = self.joints[bn]
            eb = arm.edit_bones.new(bn)
            eb.head = jt.pos
            if jt.children:
                tail = self.joints[jt.children[0]].pos
            else:
                tail = jt.pos + Vector((0, 0, max(0.05, jt.r[0])))
            if (tail - jt.pos).length < 1e-3:
                tail = jt.pos + Vector((0, 0, 0.05))
            eb.tail = tail
            eb.roll = 0.0
            ebones[bn] = eb
        for bn in bone_list:
            jt = self.joints[bn]
            if jt.parent:
                ebones[bn].parent = ebones[jt.parent]
                ebones[bn].use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")

        # Vertex groups
        groups = {bn: mob.vertex_groups.new(name=bn) for bn in bone_list}
        for vi, ws in weights.items():
            for bn, w in ws.items():
                if bn not in groups:
                    raise ValueError(f"{self.name}: weight to non-bone joint {bn}")
                groups[bn].add([vi], w, "REPLACE")
        mob.parent = aob
        mod = mob.modifiers.new("arm", "ARMATURE")
        mod.object = aob
        self.arm_obj, self.mesh_obj = aob, mob
        self.rest = {b.name: b.matrix_local.to_3x3() for b in arm.bones}
        return aob, mob

    # -- animation -----------------------------------------------------------
    def add_anim(self, name, frames, pose_fn, loop=True):
        """pose_fn(t) with t in [0,1] -> {bone: (rx, ry, rz) degrees in armature space}
        plus optional key '_loc' -> {bone: (x,y,z)} armature-space offsets."""
        aob = self.arm_obj
        if aob.animation_data is None:
            aob.animation_data_create()
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        aob.animation_data.action = act
        pbones = aob.pose.bones
        for pb in pbones:
            pb.rotation_mode = "QUATERNION"
        n = frames if loop else frames - 1
        for f in range(frames + (0 if not loop else 1)):
            t = (f / n) if n else 0.0
            if loop:
                t = (f % frames) / frames if f < frames else 1.0
            pose = pose_fn(t)
            locs = pose.pop("_loc", {})
            for pb in pbones:
                rot = pose.get(pb.name, (0, 0, 0))
                q = Euler([math.radians(a) for a in rot], "XYZ").to_quaternion()
                R = self.rest[pb.name]
                ql = (R.inverted() @ q.to_matrix() @ R).to_quaternion()
                pb.rotation_quaternion = ql
                pb.keyframe_insert("rotation_quaternion", frame=f + 1)
                if pb.name in locs:
                    pb.location = R.inverted() @ v(locs[pb.name])
                else:
                    pb.location = (0, 0, 0)
                if pb.parent is None or pb.name in locs:
                    pb.keyframe_insert("location", frame=f + 1)
        aob.animation_data.action = None
        return act

    # -- export ----------------------------------------------------------------
    def export(self, path):
        for o in bpy.context.scene.objects:
            o.select_set(o in (self.arm_obj, self.mesh_obj))
        bpy.context.view_layer.objects.active = self.arm_obj
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True,
            export_yup=True, export_apply=False, export_skins=True,
            export_animations=True, export_animation_mode="ACTIONS",
            export_force_sampling=True, export_optimize_animation_size=True,
            export_def_bones=False, export_materials="EXPORT", export_normals=True,
            export_texcoords=False, export_rest_position_armature=True,
        )


def export_static(objs, path):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_materials="EXPORT", export_normals=True,
        export_texcoords=False, export_animations=False,
    )


# ---------------------------------------------------------------------------
# Helpers for animation authoring
# ---------------------------------------------------------------------------

def sw(t, phase=0.0):
    """Sine wave over a loop (t in [0,1])."""
    return math.sin(2 * math.pi * (t + phase))


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def env(t, a, b, c=None, d=None):
    """Envelope: 0 before a, ramps to 1 at b, holds until c, back to 0 at d."""
    if t < a:
        return 0.0
    if t < b:
        return ease((t - a) / max(1e-6, b - a))
    if c is None or t < c:
        return 1.0
    if t < d:
        return 1.0 - ease((t - c) / max(1e-6, d - c))
    return 0.0


def merge(*poses):
    out = {}
    for p in poses:
        for k, val in p.items():
            if k == "_loc":
                loc = out.setdefault("_loc", {})
                for b, xyz in val.items():
                    old = loc.get(b, (0, 0, 0))
                    loc[b] = tuple(o + n for o, n in zip(old, xyz))
            else:
                old = out.get(k, (0, 0, 0))
                out[k] = tuple(o + n for o, n in zip(old, val))
    return out


def scale_pose(p, s):
    out = {}
    for k, val in p.items():
        if k == "_loc":
            out["_loc"] = {b: tuple(x * s for x in xyz) for b, xyz in val.items()}
        else:
            out[k] = tuple(x * s for x in val)
    return out
