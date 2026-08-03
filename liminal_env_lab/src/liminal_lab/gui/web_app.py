from __future__ import annotations

from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote
import threading
import webbrowser

from ..config import bundled_presets_dir, bundled_profiles_dir, list_json_ids
from ..pipeline import EXTRACTORS, process_image


def launch_web(host: str = "127.0.0.1", port: int = 8765) -> None:
    profiles = list_json_ids(bundled_profiles_dir())
    presets = list_json_ids(bundled_presets_dir())
    latest_output: Path | None = None
    message = "Choose a source image and generate its authored damage channels."

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            nonlocal latest_output
            if self.path.startswith("/asset?") and latest_output is not None:
                name = parse_qs(self.path.split("?", 1)[1]).get("name", [""])[0]
                target = (latest_output / Path(name).name).resolve()
                if target.parent == latest_output.resolve() and target.exists():
                    self.send_response(200)
                    self.send_header("Content-Type", "image/png")
                    self.end_headers()
                    self.wfile.write(target.read_bytes())
                    return
            self._page()

        def do_POST(self) -> None:
            nonlocal latest_output, message
            length = int(self.headers.get("Content-Length", "0"))
            form = parse_qs(self.rfile.read(length).decode("utf-8"))
            try:
                source = Path(form["source"][0]).expanduser().resolve()
                output = Path(form["output"][0]).expanduser().resolve()
                effect_value = form.get("effect", ["all enabled"])[0]
                process_image(source, output, form["profile"][0], form["preset"][0],
                              None if effect_value == "all enabled" else effect_value)
                latest_output = output
                message = f"Generated Phase 2 assets in {output}"
            except Exception as error:
                message = f"Processing failed: {error}"
            self._page()

        def _page(self) -> None:
            source_default = Path.cwd() / "review-output/annex-moisture-qc/stains1/original_scan.png"
            output_default = Path.cwd() / "review-output/phase2-gui"
            options = lambda values, selected: "".join(
                f'<option{" selected" if value == selected else ""}>{escape(value)}</option>'
                for value in values)
            preview = ""
            if latest_output is not None and (latest_output / "contact_sheet.png").exists():
                preview = '<img src="/asset?name=contact_sheet.png" alt="Damage channel contact sheet">'
            html = f"""<!doctype html><html><head><meta charset=utf-8><title>Liminal Environment Lab</title>
<style>body{{margin:0;background:#101315;color:#e5e8e4;font:15px system-ui}}main{{max-width:1200px;margin:auto;padding:28px}}h1{{font-size:28px}}form{{display:grid;grid-template-columns:1fr 1fr 180px 180px;gap:12px;background:#1b2023;padding:18px}}label{{font-size:12px;color:#9ca8a5}}input,select,button{{box-sizing:border-box;width:100%;padding:10px;background:#0f1214;color:#eef;border:1px solid #3a4448}}button{{background:#b8d84b;color:#111;font-weight:700;cursor:pointer}}.status{{padding:14px 0;color:#b8d84b}}img{{display:block;max-width:100%;margin:auto;background:#181b1d}}</style></head><body><main>
<h1>Liminal Environment Lab <small>Phase 2</small></h1><form method=post>
<label>Source image<input name=source value="{escape(str(source_default))}" required></label>
<label>Output directory<input name=output value="{escape(str(output_default))}" required></label>
<label>Profile<select name=profile>{options(profiles, 'annex')}</select></label>
<label>Preset<select name=preset>{options(presets, 'balanced')}</select></label>
<label>Effect<select name=effect>{options(['all enabled', *EXTRACTORS], 'all enabled')}</select></label>
<button type=submit>Generate preview</button></form><div class=status>{escape(message)}</div>{preview}</main></body></html>"""
            payload = html.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format: str, *args) -> None:
            return

    server = ThreadingHTTPServer((host, port), Handler)
    url = f"http://{host}:{port}"
    threading.Timer(0.25, lambda: webbrowser.open(url)).start()
    print(f"Liminal Environment Lab running at {url} (Ctrl-C to stop)")
    server.serve_forever()
