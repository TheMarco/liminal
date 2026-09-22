"""Build the local comparison page after --capture --all-sizes."""
import html
import json
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/liminal-breathing-environments")
records = json.loads((root / "report.json").read_text())
assert all(record.get("collision_pass") for record in records), "Review failed captures first"
themes = sorted({record["theme"] for record in records})
for theme in themes:
    assert {r["size_preset"] for r in records if r["theme"] == theme} == {"small", "medium", "large"}
    for size in ("small", "medium", "large"):
        for pose in ("rest", "half", "peak", "native"):
            assert (root / f"{theme:02d}_{size}_{pose}.png").is_file()

sections = []
profiles = {}

def dimensions(record):
    width, height = map(float, record["patch_size"].strip("()").split(","))
    return f'{width:.1f} × {height:.1f} m · {record["depth_m"] * 100:.0f} cm deep'

for theme in themes:
    rows = [r for r in records if r["theme"] == theme]
    large = next(r for r in rows if r["size_preset"] == "large")
    profiles[f"{theme:02d}"] = {
        r["size_preset"]: dimensions(r)
        for r in rows
    }
    sections.append(f'''<section id="environment-{theme:02d}"><h2>{html.escape(large["name"])}</h2>
<small data-dimensions="{theme:02d}"></small>
<img data-theme="{theme:02d}" src="{theme:02d}_large_peak.png" alt="{html.escape(large["name"])} breathing wall"></section>''')

page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Breathing wall — size comparison</title><style>
body{margin:0;background:#151615;color:#eee;font:16px system-ui}
main{max-width:1180px;margin:auto;padding:30px 24px}h1{font-size:30px;margin:0 0 12px}
p{color:#bdbfb8;line-height:1.6;max-width:900px}nav{position:sticky;top:0;background:#151615;padding:12px 0;z-index:1}
.row{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0}button{font:inherit;padding:9px 15px;border:1px solid #666;background:transparent;color:#eee;cursor:pointer}
button.active{background:#e0e6cd;color:#151615}section{margin:32px 0 48px}h2{text-transform:capitalize;font-weight:500}
img{display:block;width:100%;height:auto;border:1px solid #45473f}small{display:block;color:#acafa3;margin:8px 0}a{color:#dce6be}section{scroll-margin-top:140px}
</style><main><h1>Breathing wall / size comparison</h1>
<p>Three bulge sizes. Wall stripes, rails and lower panels now bend with their backing wall. Large expands where doors and furnishings leave room; small is a restrained alternative.</p>
<p>See the bands bend: <a href="#environment-06">School</a> · <a href="#environment-07">Mall</a> · <a href="#environment-08">Prison</a>.</p>
<nav><div class="row"><button data-size="small">Small</button><button data-size="medium">Medium</button><button class="active" data-size="large">Large</button></div>
<div class="row"><button data-pose="rest">At rest</button><button data-pose="half">Half bow</button><button class="active" data-pose="peak">Peak bow</button><button data-pose="native">Peak / native lighting</button></div></nav>
<p>The first three views use the player's flashlight settings. Sizes are fitted per wall; their actual dimensions appear below. Live preview: 1/2/3 selects size, V varies size between breaths, N/P changes environment.</p>
'''
page = page.replace('<p>Three bulge sizes.', '<p>Breath and travelling pressure are now integrated into quiet gameplay. <a href="#motion-breath">See the breath</a> · <a href="#motion-travel">See travelling pressure</a>.</p>\n<p>Three bulge sizes.')
page += "".join(sections)
motion_sections = []
for case, title in (("breath", "Runtime breath"), ("travel", "Travelling pressure"), ("ceiling", "Ceiling bulge"), ("paired", "Two opposing walls")):
    clip = root / case / "preview.webp"
    if clip.is_file():
        description = "Office motion study. Looping on an actual generated surface."
        if case in ("ceiling", "paired"): description += " Ceiling and paired-wall variants remain preview-only."
        motion_sections.append(f'''<section id="motion-{case}"><h2>{title}</h2>
<p>{description}</p>
<img src="{case}/preview.webp" alt="{title}: looping motion in Office"></section>''')
if motion_sections:
    page = page.replace('<nav>', ''.join(motion_sections) + '<h2>Single-wall size comparisons</h2><nav>', 1)
    page = page.replace('Breathing wall — size comparison', 'Breathing surfaces — motion previews')
    page = page.replace('Breathing wall / size comparison', 'Breathing surfaces / motion previews')
page += '<p>These are sampled motion previews, not frame-rate recordings. Live encounters use clear walls, shared horror pacing and actor-approach withdrawal. Ceiling and paired-wall studies remain preview-only.</p></main><script>\n'
page += "const profiles=" + json.dumps(profiles).replace("</", "<\\/") + ";\n"
page += '''let size='large',pose='peak';
function update(){
 document.querySelectorAll('[data-size]').forEach(b=>b.classList.toggle('active',b.dataset.size===size));
 document.querySelectorAll('[data-pose]').forEach(b=>b.classList.toggle('active',b.dataset.pose===pose));
 document.querySelectorAll('img[data-theme]').forEach(i=>i.src=i.dataset.theme+'_'+size+'_'+pose+'.png');
 document.querySelectorAll('[data-dimensions]').forEach(e=>e.textContent=profiles[e.dataset.dimensions][size]);
}
document.querySelectorAll('[data-size]').forEach(b=>b.onclick=()=>{size=b.dataset.size;update()});
document.querySelectorAll('[data-pose]').forEach(b=>b.onclick=()=>{pose=b.dataset.pose;update()});
update();</script></html>'''
(root / "index.html").write_text(page)
print(f"Gallery: {root / 'index.html'} ({len(themes)} environments, three sizes)")
