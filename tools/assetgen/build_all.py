"""Build every generated 3D asset into game/assets/models. Usage:
   /opt/bpyenv/bin/python build_all.py [name ...]"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rigkit  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "models")


def builders():
    import heroes
    out = {f.__name__: ("heroes", f) for f in heroes.ALL}
    try:
        import monsters
        out.update({f.__name__: ("monsters", f) for f in monsters.ALL})
    except ImportError:
        pass
    try:
        import props
        out.update({f.__name__: ("props", f) for f in props.ALL})
    except ImportError:
        pass
    return out


def main():
    want = set(sys.argv[1:])
    for name, (folder, fn) in builders().items():
        if want and name not in want and folder not in want:
            continue
        t0 = time.time()
        rigkit.reset_scene()
        res = fn()
        d = os.path.join(OUT, folder)
        os.makedirs(d, exist_ok=True)
        path = os.path.abspath(os.path.join(d, name + ".glb"))
        if isinstance(res, rigkit.Character):
            res.export(path)
            tris = sum(len(p.vertices) - 2 for p in res.mesh_obj.data.polygons)
        else:
            rigkit.export_static(res, path)
            tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in res if o.type == "MESH")
        print(f"[assetgen] {folder}/{name}.glb  tris={tris}  {time.time() - t0:.1f}s", flush=True)


if __name__ == "__main__":
    main()
