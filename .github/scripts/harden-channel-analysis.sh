#!/usr/bin/env bash
set -euo pipefail

module="${1:?usage: harden-channel-analysis.sh CHANNEL_ANALYSIS_JS}"
[[ -f "$module" ]] || {
  echo "channel_analysis.js not found: $module" >&2
  exit 1
}

# The LuCI feed is pinned by the build's source lock, but formatting can differ
# between the device image and the feed checkout.  The Python step below uses
# four exact, unique anchors and rejects partial or ambiguous matches; this is
# the reviewed boundary for a source revision whose whole-file hash is unknown.
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

old_anchors = tuple(old for old, _new, _label in replacements)
new_anchors = tuple(new for _old, new, _label in replacements)
old_counts = tuple(source.count(anchor) for anchor in old_anchors)
new_counts = tuple(source.count(anchor) for anchor in new_anchors)

if new_counts == (1, 1, 1, 1) and old_counts == (0, 0, 0, 0):
    raise SystemExit(0)
if any(new_counts):
    raise SystemExit("unsupported channel analysis module; refusing a partial or mixed layout patch")
if old_counts != (1, 1, 1, 1):
    raise SystemExit("unsupported channel analysis module; expected one unique anchor for each reviewed change")

for old, new, label in replacements:
    source = source.replace(old, new, 1)

temporary = path.with_name(path.name + ".tmp")
temporary.write_text(source)
temporary.chmod(path.stat().st_mode & 0o7777)
os.replace(temporary, path)
PY

python3 - "$module" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
required = (
    "create_channel_graph(chan_analysis,freq_tbl,band){if(chan_analysis.initialized||chan_analysis.graph.offsetWidth<1)return;",
    "createGraphHLine(G,curr_offset+step,0.1,1);chan_analysis.initialized=true;chan_analysis.tab.addEventListener('cbi-tab-active'",
    "graph_data={graph:csvg,offset_tbl:{},col_width:0,tab:tab,freq_tbl:bands[band].channels,band:band,initialized:false,};",
    "for(let id in this.radios){const radio=this.radios[id];radio.graph.tab.addEventListener('cbi-tab-active'",
)
if any(source.count(anchor) != 1 for anchor in required):
    raise SystemExit("channel analysis patch verification failed")
PY
