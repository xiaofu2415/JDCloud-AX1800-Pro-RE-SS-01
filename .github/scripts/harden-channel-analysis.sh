#!/usr/bin/env bash
set -euo pipefail

module="${1:?usage: harden-channel-analysis.sh CHANNEL_ANALYSIS_JS}"
[[ -f "$module" ]] || {
  echo "channel_analysis.js not found: $module" >&2
  exit 1
}

expected_original_shas=(
  '8e829e8815bd25277b7565325de936a2e12ca285e1fd3f4565e43416013797e1'
  'c575c928f580cc10173408e5cb9d5d1e54506a75221dd470ee1fa5afca0b1943'
)
expected_patched_shas=(
  'cc990dc67f9acf2c44e767393b8f6ae1665af0e868d0b2f704bd72ae72e82b68'
  'd3ce2f3ec84160698975dbad86ec2d7877ea1753a5c5ab577656be4c13305bb3'
)
current_sha="$(sha256sum "$module" | awk '{print $1}')"
if printf '%s\n' "${expected_patched_shas[@]}" | grep -Fqx "$current_sha"; then
  grep -Fq 'offsetWidth<1' "$module"
  grep -Fq 'initialized' "$module"
  exit 0
fi
if ! printf '%s\n' "${expected_original_shas[@]}" | grep -Fqx "$current_sha"; then
  echo "unsupported channel analysis module; refusing an unverified layout patch" >&2
  exit 1
fi

python3 - "$module" <<'PY'
from pathlib import Path
import os
import sys

path = Path(sys.argv[1])
source = path.read_text()

old_guard = "create_channel_graph(chan_analysis,freq_tbl,band){const columns=(band!=2)?freq_tbl.length*4:freq_tbl.length+3;"
new_guard = "create_channel_graph(chan_analysis,freq_tbl,band){if(chan_analysis.initialized||chan_analysis.graph.offsetWidth<1)return;const columns=(band!=2)?freq_tbl.length*4:freq_tbl.length+3;"

old_initialized = "createGraphHLine(G,curr_offset+step,0.1,1);chan_analysis.tab.addEventListener('cbi-tab-active'"
new_initialized = "createGraphHLine(G,curr_offset+step,0.1,1);chan_analysis.initialized=true;chan_analysis.tab.addEventListener('cbi-tab-active'"

old_graph_data = "graph_data={graph:csvg,offset_tbl:{},col_width:0,tab:tab,};"
new_graph_data = "graph_data={graph:csvg,offset_tbl:{},col_width:0,tab:tab,freq_tbl:bands[band].channels,band:band,initialized:false,};"

old_render_end = "ui.tabs.initTabGroup(tabs.firstElementChild.childNodes);this.pollFn=L.bind(this.handleScanRefresh,this);"
new_render_end = "for(let id in this.radios){const radio=this.radios[id];radio.graph.tab.addEventListener('cbi-tab-active',L.bind(function(ev){this.active_tab=ev.detail.tab;this.create_channel_graph(radio.graph,radio.graph.freq_tbl,radio.band);if(!radio.loadedOnce)poll.start();},this));}ui.tabs.initTabGroup(tabs.firstElementChild.childNodes);for(let id in this.radios){const radio=this.radios[id];requestAnimationFrame(L.bind(this.create_channel_graph,this,radio.graph,radio.graph.freq_tbl,radio.band));}this.pollFn=L.bind(this.handleScanRefresh,this);"

replacements = (
    (old_guard, new_guard, "create_channel_graph guard"),
    (old_initialized, new_initialized, "graph initialized marker"),
    (old_graph_data, new_graph_data, "graph metadata"),
    (old_render_end, new_render_end, "active-tab initialization"),
)

if source.count(new_guard) == 1 and source.count(new_initialized) == 1 and source.count(new_graph_data) == 1 and source.count(new_render_end) == 1:
    raise SystemExit(0)

for old, new, label in replacements:
    if source.count(old) != 1:
        raise SystemExit(f"unsupported channel analysis module; expected one {label} anchor")
    source = source.replace(old, new, 1)

temporary = path.with_name(path.name + ".tmp")
temporary.write_text(source)
temporary.chmod(path.stat().st_mode & 0o7777)
os.replace(temporary, path)
PY

patched_sha="$(sha256sum "$module" | awk '{print $1}')"
printf '%s\n' "${expected_patched_shas[@]}" | grep -Fqx "$patched_sha" || {
  echo "channel analysis patch did not match the reviewed module" >&2
  exit 1
}
grep -Fq 'offsetWidth<1' "$module"
grep -Fq 'initialized' "$module"
grep -Fq 'freq_tbl' "$module"
grep -Fq 'cbi-tab-active' "$module"
