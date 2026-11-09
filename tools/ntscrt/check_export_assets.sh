#!/usr/bin/env bash
# Reproduce the asset-only pack check with production Linux export filters.
# Requires Python 3, Godot, and current native-editor imports (RDShaderFile).
# No GPU process is started. GODOT_BIN selects Godot; KEEP_EXPORT_AUDIT=1
# retains the small staging project, PCK, and logs after a successful run.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/liminal-export-assets.XXXXXX")"
cleanup() {
  local result=$?
  if [[ "$result" -ne 0 || "${KEEP_EXPORT_AUDIT:-0}" == 1 ]]; then
    echo "Export audit artifacts: $audit_dir"
  else
    rm -rf "$audit_dir"
  fi
}
trap cleanup EXIT
python3 - "$repo_dir" "$audit_dir" <<'PY'
from pathlib import Path
import hashlib,re,shutil,sys
repo,stage=map(Path,sys.argv[1:])
folders=['third_party/ntscrt','shaders/ntscrs_gpu','shaders/ntscrt_receiver_gpu','shaders/ntscrt_downscale_gpu']
# Never silently package stale/missing shader bytecode. Native import is an
# explicit prerequisite, because the headless dummy RD cannot compile GLSL.
for folder in folders[1:]:
 for shader in (repo/folder).glob('*.glsl'):
  sidecar=Path(str(shader)+'.import')
  if not sidecar.exists():
   sys.exit(f'Missing {sidecar}: open/import the project with native Godot first; this check does not start a GPU job.')
  text=sidecar.read_text()
  found=re.search(r'^path="res://([^"]+)"',text,re.M)
  if not found or not (repo/found[1]).exists():
   sys.exit(f'Missing imported RDShaderFile for {shader}; run native editor import first.')
  md5_path=(repo/found[1]).with_suffix('.md5')
  if md5_path.exists():
   source_hash=re.search(r'source_md5="([^"]+)"',md5_path.read_text())
   if source_hash and source_hash[1]!=hashlib.md5(shader.read_bytes()).hexdigest():
    sys.exit(f'Stale imported RDShaderFile for {shader}; rerun native editor import first.')
for folder in folders:
 shutil.copytree(repo/folder,stage/folder)
shutil.copy(repo/'tools/audit_ntscrt_export.gd',stage/'audit.gd')
(stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="NTSCRT export audit"\n[rendering]\nrenderer/rendering_method="mobile"\n')
# Extract the real Linux preset unchanged, apart from its section index.
text=(repo/'export_presets.cfg').read_text()
sections=re.split(r'(?=^\[preset\.\d+\]$)',text,flags=re.M)
section=next((s for s in sections if re.search(r'^name="Linux"$',s,re.M)),None)
if section is None: sys.exit('Production Linux export preset not found')
section=re.sub(r'\[preset\.\d+(\.options)?\]',lambda m:'[preset.0'+(m[1] or '')+']',section)
(stage/'export_presets.cfg').write_text(section)
# Retain native shader imports and exact texture imports; cache metadata avoids
# unnecessary headless reimport. No project scripts/scenes or game saves copied.
for sidecar in stage.rglob('*.import'):
 for resource in set(re.findall(r'res://(\.godot/imported/[^"\n]+)',sidecar.read_text())):
  source=repo/resource
  if source.exists():
   target=stage/resource;target.parent.mkdir(parents=True,exist_ok=True)
   shutil.copy(source,target)
   md5=source.with_suffix('.md5')
   if md5.exists(): shutil.copy(md5,target.with_suffix('.md5'))
PY
run_logged() {
  local label="$1"
  shift
  if ! "$@" >"$audit_dir/$label.console.log" 2>&1; then
    tail -n 80 "$audit_dir/$label.console.log"
    return 1
  fi
}
run_logged baseline "$godot_bin" --headless --path "$repo_dir" \
  --log-file "$audit_dir/baseline.log" --script tools/audit_ntscrt_export.gd \
  --quit-after 120 -- --write-baseline="$audit_dir/third_party/ntscrt/audit_lut_hashes.json"
run_logged pack "$godot_bin" --headless --path "$audit_dir" \
  --log-file "$audit_dir/pack.log" --export-pack Linux "$audit_dir/assets.pck" --quit-after 120
# Run outside the source/staging project so missing packed assets cannot fall
# through to loose files. A separate empty working directory makes this explicit.
mkdir "$audit_dir/packed-only"
run_logged packed "$godot_bin" --headless --path "$audit_dir/packed-only" \
  --main-pack "$audit_dir/assets.pck" --log-file "$audit_dir/packed.log" \
  --script res://audit.gd --quit-after 120
cat "$audit_dir/packed.console.log"
