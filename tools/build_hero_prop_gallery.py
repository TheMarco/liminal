"""Build the authored-prop review from Blender renders and native game captures."""
from pathlib import Path
from html import escape
import json
import re
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/hero-prop-review"
# title, source art, runtime model, native preview, room, description
PROPS = [
    ('Curtained photo booth', 'mall_photo_booth', 'mall_photo_booth/mall_photo_booth', 'photo-booth', 'photo-booth',
     'Orange folded curtain, checkerboard booth floor, walnut lower panels and original geometric photo-service graphics.'),
    ('Coin-operated rocket ride', 'mall_rocket_ride', 'mall_rocket_ride/mall_rocket_ride', 'rocket-ride', 'rocket-ride',
     'Blue moulded rocket with red seating tub, cream paint, yellow windows, coin pedestal and bellows support.'),
    ('Hotel ice machine', 'vegas_ice_machine', 'vegas_ice_machine/vegas_ice_machine', 'ice-machine', 'ice-machine',
     'Aged ivory cabinet with physical grille slats, recessed ice chute and a stainless drain tray.'),
    ('Brass bellhop cart', 'vegas_bellhop_cart', 'vegas_bellhop_cart/vegas_bellhop_cart', 'bellhop-cart', 'bellhop-cart',
     'Twin brass arches, carpeted platform, continuous bumper and four rounded rubber casters.'),
    ('Cigarette vending machine', 'vegas_cigarette_machine', 'vegas_cigarette_machine/vegas_cigarette_machine', 'cigarette-machine', 'cigarette-machine',
     'Walnut and chrome cabinet, twenty pull knobs, slanted selector labels and an illuminated Alpine advertisement.'),
    ('Coffee vending machine', 'office_coffee_machine', 'office_coffee_machine/office_coffee_machine', 'coffee-machine', 'coffee-machine',
     'Woodgrain enclosure, period coffee artwork, angled drink buttons and an open cup-delivery well.'),
    ('Overhead projector', 'school_overhead_projector', 'school_overhead_projector/school_overhead_projector', 'overhead-projector', 'overhead-projector',
     'Tabletop Fresnel stage, blue focus controls, toothed mast and an open reflecting head. Placed on the teacher’s desk.'),
    ("Vegas change machine", "vegas_change_machine", "vegas_change_machine/vegas_change_machine", "vegas-change", "change-machine",
     "Raked copper-brown control face, slanted walnut door, framed CHANGE header, angled bill inlet and one large left coin cup and a small right return tray in a sloping steel shelf."),
    ("Airport moving walkway", "airport_walkway/standard", "airport_walkway/standard/airport_walkway", "airport-travelator", "walkway",
     "Rounded rubber handrails, clear glass sides, brushed steel housings and yellow comb plates. The ribbed belt carries the player in its travel direction."),
    ("Airport escalator", "airport_escalator", "airport_escalator/airport_escalator", "airport-escalator-flight", "escalator",
     "Continuous curved handrails, glass balustrades, grooved treads and stainless cladding. Retains the walkable airport slope."),
    ("Cafeteria serving counter", "service_fixtures/school_servery", "service_fixtures/school_servery/school_servery", "school-servery", "servery",
     "Stainless serving line with recessed pans, clear sneeze guards, slate fascia and tray rails."),
    ("School trophy case", "school_trophy_case", "school_trophy_case/school_trophy_case", "school-trophy-case", "trophy-case",
     "Hollow oak cabinet with sliding glass, silver and brass cups, award shields and lower drawers."),
    ("School bleachers", "school_furniture/bleachers", "school_furniture/bleachers/school_bleachers", "school-bleachers", "bleachers",
     "Four tiers of aluminium seats and footboards over open braced supports. Modular sections fit each gym."),
    ("Cafeteria folding table", "school_furniture/cafeteria_table", "school_furniture/cafeteria_table/school_cafeteria_table", "school-cafeteria-table", "cafeteria-table",
     "Split laminate tabletop, attached benches, folding steel frame and eight casters."),
    ("Prison shower panel", "service_fixtures/prison_shower", "service_fixtures/prison_shower/prison_shower", "prison-shower-station", "shower-panel",
     "Shallow stainless wall panel with a hooded spray head and rotary temperature control."),
    ("Prison four-seat table", "service_fixtures/prison_mess_table", "service_fixtures/prison_mess_table/prison_mess_table", "prison-mess-table", "mess-table",
     "Clipped-corner stainless top, four cantilevered round stools and a bolted central pedestal."),
    ("School steel cupboard", "school_furniture/cupboard", "school_furniture/cupboard/school_cupboard", "school-cupboard", "cupboard",
     "Grey-blue folded steel cabinet with recessed double doors, hinges and a rotary lock."),
    ("Airport gate desk", "airport_gate_desk", "airport_gate_desk/airport_gate_desk", "airport-gate-desk", "gate-desk",
     "Sculpted white counter, fluted aluminium base, two agent-facing screens and a complete recessed staff workstation."),
    ("Airport carousel", "airport_carousel", "airport_carousel/airport_carousel", "airport-baggage", "airport",
     "Full-size 7 × 3m carousel with a 0.665m belt deck and moving luggage. The arrivals monitor faces the long side."),
    ("ECT machine", "asylum_medical/ect", "asylum_medical/ect_machine", "asylum-ect", "asylum",
     "Wooden carrying case, analog instrument panel, electrodes and a steel medical trolley."),
    ("Restraint table", "asylum_medical/restraint", "asylum_medical/restraint_table", "asylum-restraint", "asylum",
     "Padded rolling table with leather straps, cuffs, chains and a scissor support."),
    ("CRT terminal", "vt100", "vt100/vt100_monitor", "shared-terminal", "terminal",
     "VT100-style housing and matching keyboard. The screen keeps its live query interaction."),
    ("Mall merchandise station", "mall_merchandise/mall_merchandise_station", "mall_merchandise/mall_merchandise_station", "mall-kiosk", "mall",
     "Open staff well, folded clothing and illuminated fascia. The register faces inward toward the cashier."),
    ("Incubation machine", "bloom_incubator", "bloom_incubator/bloom_incubator", "bloom-pod", "incubator",
     "Industrial containment vessel with a pulsing egg suspended in cloudy liquid and rising bubbles."),
]
COMPANIONS = [
    ("Matching keyboard", "vt100/vt100_keyboard", "shared-keyboard"),
    ("Compact merchandise display", "mall_merchandise/mall_merchandise_display", "mall-display-table"),
]


def mesh_stats(model):
    data = (ROOT / f"models/authored/{model}.glb").read_bytes()
    size = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + size])
    primitives = [p for m in gltf["meshes"] for p in m["primitives"]]
    triangles = sum(gltf["accessors"][p["indices"]]["count"] // 3 for p in primitives)
    return f"{triangles:,} triangles · {len(primitives)} surfaces"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cards = []
    original_labels = {}
    for title, art, model, native, room, description in PROPS:
        sources = {
            "front": f"../../art/{art}/preview_front.png",
            "reverse": f"../../art/{art}/preview_reverse.png",
            "native": f"{native}.png",
            "game": f"rooms/{room}-clean.png",
            "tape": f"rooms/{room}-tape.png",
        }
        assert all((OUT / path).exists() for path in sources.values()), title
        attributes = " ".join(f'data-{key}="{escape(path)}"' for key, path in sources.items())
        stats = mesh_stats(model)
        original_labels[native] = f"Authored model: {stats}"
        cards.append(f'''<article id="{room if room != 'asylum' else native}" data-prop="{native}">
<div class="caption"><h2>{escape(title)}</h2><span>{stats}</span></div>
<p>{escape(description)}</p><a class="full" href="{sources['front']}" target="_blank">
<img {attributes} src="{sources['front']}" alt="{escape(title)}" loading="lazy"></a></article>''')
    companions = []
    for title, model, native in COMPANIONS:
        stats = mesh_stats(model)
        original_labels[native] = f"Authored model: {stats}"
        companions.append(f'<a href="{native}.png">{title} — {stats}</a>')
    nav = "".join(f'<a href="#{room if room != "asylum" else native}">{title}</a>'
                  for title, art, model, native, room, description in PROPS)
    html = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Blender prop review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#141516;color:#eee;font:16px/1.5 system-ui,sans-serif}
header,main,footer{max-width:1400px;margin:auto;padding:30px}h1{font-size:36px;letter-spacing:-1px;margin:0}
p{color:#b8bebc;max-width:850px}a{color:#d6e6ce;text-underline-offset:4px}nav{display:flex;flex-wrap:wrap;gap:10px 22px}
.views{position:sticky;top:0;background:#202321f5;z-index:2;padding:12px 30px;display:flex;justify-content:center;gap:10px;flex-wrap:wrap}
button{font:inherit;color:#ddd;background:#303632;border:1px solid #637064;padding:8px 14px;cursor:pointer;border-radius:4px}
button[aria-pressed=true]{background:#d5e6cd;color:#18231a}main{display:grid;grid-template-columns:1fr 1fr;gap:40px 24px}
article{min-width:0;scroll-margin-top:90px}.caption{display:flex;flex-wrap:wrap;align-items:baseline;justify-content:space-between;gap:5px 15px}
h2{font-size:23px;margin:0}.caption span{font-size:13px;color:#a3af9d}article p{min-height:48px;font-size:15px;margin:9px 0 18px}
img{display:block;width:100%;aspect-ratio:1;object-fit:contain;background:#0e0f0f}footer{border-top:1px solid #444;display:flex;flex-direction:column;gap:14px}
@media(max-width:850px){main{grid-template-columns:1fr}header,main,footer{padding:20px}h1{font-size:30px}}
</style><header><h1>Blender replacements</h1><p>Finished models, neutral native previews and views from the game. Select an angle or lighting mode, then click any image to inspect it at full size.</p><nav>'''
    html += nav + '''</nav></header><div class="views" aria-label="Preview mode">'''
    for key, title in [("front", "Blender front"), ("reverse", "Blender reverse"), ("native", "Godot studio"), ("game", "In game"), ("tape", "With tape filter")]:
        html += f'<button type="button" data-view="{key}" aria-pressed="{str(key == "front").lower()}">{title}</button>'
    html += '</div><main>' + "\n".join(cards) + '</main><footer>'
    html += '<b>Companion pieces</b>' + "".join(companions)
    html += '<a href="../procedural-review/index.html">Full procedural model gallery</a></footer>'
    html += '''<script>
document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{
  document.querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
  document.querySelectorAll('article img').forEach(img=>{img.src=img.dataset[button.dataset.view];img.parentElement.href=img.src});
}));
</script></html>'''
    (OUT / "index.html").write_text(html)

    # Refresh the earlier gallery without changing its before images or other props.
    old = ROOT / "build/procedural-review"
    if (old / "index.html").exists():
        page = (old / "index.html").read_text()
        for name, label in original_labels.items():
            for suffix in ["", "-reverse"]:
                shutil.copy2(OUT / f"{name}{suffix}.png", old / "after" / f"{name}{suffix}.png")
            pattern = rf'(<article\b[^>]*data-name="{re.escape(name)}"[^>]*>)(.*?)(</article>)'
            def update(match):
                body = re.sub(r'(After <span class="stats">).*?(</span>)',
                              lambda m: m[1] + '— ' + label + m[2], match[2])
                return match[1] + body + match[3]
            page = re.sub(pattern, update, page, flags=re.S)
        (old / "index.html").write_text(page)
    print(OUT / "index.html")


if __name__ == "__main__":
    main()
