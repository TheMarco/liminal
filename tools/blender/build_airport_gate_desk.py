"""Reference-based low-poly gate counter. Metres; passengers -Z, agents +Z."""
from pathlib import Path
import sys
import math
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hero_prop as h

ROOT = HERE.parents[1]
ART = ROOT / "art/airport_gate_desk"
OUT = ROOT / "models/authored/airport_gate_desk"
h.reset()
white = h.material("Warm white solid-surface shell", (.79, .80, .785), .34, .025, .012)
metal = h.material("Brushed aluminium flutes", (.47, .50, .51), .39, .8, .024)
black = h.material("Graphite work surface", (.017, .022, .025), .51, .08, .025)
plastic = h.material("Monitor and keyboard polymer", (.012, .017, .018), .65, 0, .04)
inner = h.material("Staff cabinet light grey", (.43, .46, .46), .58, .03, .02)
seam = h.material("Recess and gasket", (.026, .035, .036), .83, 0, .02)
screen = h.image_material("Gate operations display", ART / "gate_screen.png", .08, .6)

# U-shaped outline: softly rounded passenger corners, straight staff returns.
outline = []
for i in range(12): outline.append((-1.22, .63 - .98 * i / 12))
for i in range(9):
    a = math.pi + math.pi / 2 * i / 8
    outline.append((-1.04 + .18 * math.cos(a), -.35 + .18 * math.sin(a)))
for i in range(1, 49): outline.append((-1.04 + 2.08 * i / 48, -.53))
for i in range(1, 9):
    a = 1.5 * math.pi + math.pi / 2 * i / 8
    outline.append((1.04 + .18 * math.cos(a), -.35 + .18 * math.sin(a)))
for i in range(1, 13): outline.append((1.22, -.35 + .98 * i / 12))

def smooth(t):
    t = max(0, min(1, t))
    return t * t * (3 - 2 * t)

def bottom(x, z):
    return .60 - .50 * smooth((abs(x) - .89) / .33)

def top(x, z):
    return 1.16 - .19 * smooth((z + .04) / .27)

normals = []
for i in range(len(outline)):
    a = outline[max(0, i - 1)]; b = outline[min(len(outline) - 1, i + 1)]
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz)
    normals.append((dz / n, -dx / n))

# Solid closed shell, not overlapping boxes: stepped top, swept lower edge.
verts = []
for (x, z), (nx, nz) in zip(outline, normals):
    low, high = bottom(x, z), top(x, z)
    verts.extend([(x, low, z), (x, high, z),
                  (x - nx * .075, high, z - nz * .075),
                  (x - nx * .075, low, z - nz * .075)])
faces = [(3, 2, 1, 0)]
for i in range(len(outline) - 1):
    for j in range(4):
        a = i * 4 + j; b = i * 4 + (j + 1) % 4
        faces.append((a, b, b + 4, a + 4))
faces.append(tuple(range(len(verts) - 4, len(verts))))
h.mesh("Continuous sculpted white fascia and returns", verts, faces, white, True)

# Real corrugated geometry, sampled by length for an even flute pitch around
# the rounded corners. One mesh/surface after baking, no individual rib objects.
distances = [0.0]
for i in range(1, len(outline)):
    distances.append(distances[-1] + math.dist(outline[i - 1], outline[i]))
length = distances[-1]
flutes = round(length / .028)
verts = []
edge_i = 0
for i in range(flutes * 3 + 1):
    distance = length * i / (flutes * 3)
    while edge_i < len(outline) - 2 and distance > distances[edge_i + 1]: edge_i += 1
    t = (distance - distances[edge_i]) / (distances[edge_i + 1] - distances[edge_i])
    x = outline[edge_i][0] * (1 - t) + outline[edge_i + 1][0] * t
    z = outline[edge_i][1] * (1 - t) + outline[edge_i + 1][1] * t
    nx = normals[edge_i][0] * (1 - t) + normals[edge_i + 1][0] * t
    nz = normals[edge_i][1] * (1 - t) + normals[edge_i + 1][1] * t
    depth = -.026 + (.015 if i % 3 == 1 else 0)
    verts.extend([(x + nx * depth, .055, z + nz * depth),
                  (x + nx * depth, bottom(x, z) + .01, z + nz * depth)])
faces = [(i * 2, i * 2 + 2, i * 2 + 3, i * 2 + 1) for i in range(flutes * 3)]
h.mesh("Fine aluminium fluted lower cladding", verts, faces, metal)

# Recessed heel rail, work surface and lower storage. Two knee bays open +Z.
h.box("Inset continuous toe plinth", (0, .032, .06), (2.34, .064, 1.06), seam, .015)
h.box("Graphite staff worktop", (0, .929, .045), (2.30, .056, 1.05), black, .013)
h.box("Inner front modesty panel", (0, .49, -.423), (2.28, .87, .065), inner, .005)
for side in [-1, 1]:
    h.box("Under-counter cabinet", (side * .97, .472, -.16), (.28, .86, .55), inner, .009)
    for y in [.35, .64]:
        h.box("Drawer separation", (side * .97, y, .119), (.258, .009, .008), seam)
    for y in [.50, .79]:
        h.box("Inset drawer pull", (side * .97, y, .126), (.12, .015, .012), metal, .003)
h.box("Centre service divider", (0, .47, -.13), (.06, .86, .56), inner, .006)
for side in [-1, 1]:
    h.box("Open rear shelf", (side * .51, .21, -.21), (.81, .028, .33), inner, .005)

# Displays and controls face +Z, the staff side. Readable graphics are one
# second material shared by both monitors; no light or particle nodes needed.
screens = []
for x in [-.58, .58]:
    h.box("Monitor foot", (x, .974, -.145), (.20, .025, .15), plastic, .008)
    h.box("Monitor riser", (x, 1.075, -.17), (.047, .19, .046), plastic, .005)
    h.box("Monitor housing", (x, 1.265, -.17), (.47, .305, .047), plastic, .008)
    screens.append(h.decal("Staff screen", (x, 1.265, -.1455), (.427, .258), screen, 0, grid=1))
    h.box("Keyboard lower tray", (x, .974, .312), (.395, .026, .162), plastic, .006)
    for row in range(4):
        for col in range(11):
            h.box("Low-profile key", (x - .158 + col * .030, .991, .263 + row * .026),
                  (.024, .009, .020), inner)
    h.box("Spacebar", (x, .991, .368), (.14, .009, .019), inner)
    h.box("Boarding reader foot", (x + .285, .981, .28), (.11, .045, .13), plastic, .008)
    h.box("Reader tilted head", (x + .285, 1.037, .26), (.092, .073, .071), plastic, .008)
    h.box("Reader scan window", (x + .285, 1.05, .297), (.058, .027, .003), black)

h.finish("airport_gate_desk", ART, OUT, 5000,
         specials=[("GateDeskScreens", screens)],
         metadata={"passenger_front_axis": "-Z", "staff_screen_axis": "+Z",
                   "worktop_height_m": .957, "counter_height_m": 1.16},
         surface_normals={"GateDeskScreens": (0, 0, 1)},
         scale=3.4, camera=(3.2, 4.5, 2.6), target=(0, 0, .68))
