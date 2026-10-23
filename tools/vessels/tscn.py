"""A tiny writer for Godot 4 text scenes (.tscn), used by the vessel scene tools.

Properties are given as raw Godot literal strings ("position = Vector2(1, 2)")
or as (key, value) pairs formatted with the helpers below.
"""


def vec(x, y):
    return f"Vector2({_num(x)}, {_num(y)})"


def rect(x, y, w, h):
    return f"Rect2({_num(x)}, {_num(y)}, {_num(w)}, {_num(h)})"


def pva(points):
    flat = ", ".join(f"{_num(x)}, {_num(y)}" for x, y in points)
    return f"PackedVector2Array({flat})"


def color(hex_or_tuple, alpha=None):
    if isinstance(hex_or_tuple, str):
        h = hex_or_tuple.lstrip("#")
        r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        a = 1.0 if alpha is None else alpha
    else:
        r, g, b = hex_or_tuple[:3]
        a = hex_or_tuple[3] if len(hex_or_tuple) > 3 else (1.0 if alpha is None else alpha)
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {a:.4f})"


def string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _num(v):
    v = float(v)
    return str(int(v)) if v.is_integer() else f"{v:.2f}".rstrip("0")


class Scene:
    def __init__(self):
        self.ext = []      # (type, path, id)
        self.sub = []      # (type, id, lines)
        self.nodes = []    # header, lines

    def ext_res(self, res_type, path):
        for t, p, i in self.ext:
            if p == path:
                return f'ExtResource("{i}")'
        rid = f"{len(self.ext) + 1}_r"
        self.ext.append((res_type, path, rid))
        return f'ExtResource("{rid}")'

    def sub_res(self, res_type, lines, rid=None):
        rid = rid or f"{res_type}_{len(self.sub) + 1}"
        self.sub.append((res_type, rid, list(lines)))
        return f'SubResource("{rid}")'

    def node(self, name, node_type=None, parent=None, lines=(), instance=None, extra=""):
        header = f'[node name="{name}"'
        if node_type:
            header += f' type="{node_type}"'
        if parent is not None:
            header += f' parent="{parent}"'
        if instance:
            header += f" instance={instance}"
        if extra:
            header += " " + extra
        header += "]"
        self.nodes.append((header, list(lines)))

    def text(self):
        out = [f"[gd_scene load_steps={len(self.ext) + len(self.sub) + 1} format=3]", ""]
        for t, p, i in self.ext:
            out.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        if self.ext:
            out.append("")
        for t, i, lines in self.sub:
            out.append(f'[sub_resource type="{t}" id="{i}"]')
            out.extend(lines)
            out.append("")
        for header, lines in self.nodes:
            out.append(header)
            out.extend(lines)
            out.append("")
        return "\n".join(out)

    def write(self, path):
        with open(path, "w") as f:
            f.write(self.text())
        print("wrote", path)
