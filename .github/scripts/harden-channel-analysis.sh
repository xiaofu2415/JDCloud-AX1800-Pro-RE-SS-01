#!/usr/bin/env bash
set -euo pipefail

module="${1:?usage: harden-channel-analysis.sh CHANNEL_ANALYSIS_JS}"
[[ -f "$module" ]] || {
  echo "channel_analysis.js not found: $module" >&2
  exit 1
}

# The LuCI feed is pinned by the build's source lock, but formatting can differ
# between the device image and the feed checkout.  The Python step below uses
# four whitespace-tolerant, structurally exact anchors and rejects partial or
# ambiguous matches; this is the reviewed boundary for a source revision whose
# whole-file hash is unknown.
python3 - "$module" <<'PY'
from pathlib import Path
import os
import re
import sys

path = Path(sys.argv[1])
source = path.read_text()

new_guard = "create_channel_graph(chan_analysis,freq_tbl,band){if(chan_analysis.initialized||chan_analysis.graph.offsetWidth<1)return;const columns=(band!=2)?freq_tbl.length*4:freq_tbl.length+3;"
new_initialized = "createGraphHLine(G,curr_offset+step,0.1,1);chan_analysis.initialized=true;chan_analysis.tab.addEventListener('cbi-tab-active'"
new_graph_data = "graph_data={graph:csvg,offset_tbl:{},col_width:0,tab:tab,freq_tbl:bands[band].channels,band:band,initialized:false,};"
new_render_end = "for(let id in this.radios){const radio=this.radios[id];radio.graph.tab.addEventListener('cbi-tab-active',L.bind(function(ev){this.active_tab=ev.detail.tab;this.create_channel_graph(radio.graph,radio.graph.freq_tbl,radio.band);if(!radio.loadedOnce)poll.start();},this));}ui.tabs.initTabGroup(tabs.firstElementChild.childNodes);for(let id in this.radios){const radio=this.radios[id];requestAnimationFrame(L.bind(this.create_channel_graph,this,radio.graph,radio.graph.freq_tbl,radio.band));}this.pollFn=L.bind(this.handleScanRefresh,this);"

replacements = (
    (re.compile(r"create_channel_graph\(\s*chan_analysis\s*,\s*freq_tbl\s*,\s*band\s*\)\s*\{\s*const columns\s*=\s*\(band\s*!=\s*2\)\s*\?\s*freq_tbl\.length\s*\*\s*4\s*:\s*freq_tbl\.length\s*\+\s*3\s*;"), new_guard, "create_channel_graph guard"),
    (re.compile(r"createGraphHLine\(G,curr_offset\+step\s*,\s*0\.1\s*,\s*1\s*\);\s*chan_analysis\.tab\.addEventListener\('cbi-tab-active'"), new_initialized, "graph initialized marker"),
    (re.compile(r"graph_data\s*=\s*\{\s*graph\s*:\s*csvg\s*,\s*offset_tbl\s*:\s*\{\s*\}\s*,\s*col_width\s*:\s*0\s*,\s*tab\s*:\s*tab\s*,\s*\}\s*;"), new_graph_data, "graph metadata"),
    (re.compile(r"ui\.tabs\.initTabGroup\(\s*tabs\.firstElementChild\.childNodes\s*\)\s*;\s*this\.pollFn\s*=\s*L\.bind\(\s*this\.handleScanRefresh\s*,\s*this\s*\)\s*;"), new_render_end, "active-tab initialization"),
)

new_patterns = (
    re.compile(r"create_channel_graph\(\s*chan_analysis\s*,\s*freq_tbl\s*,\s*band\s*\)\s*\{\s*if\s*\(\s*chan_analysis\.initialized\s*\|\|\s*chan_analysis\.graph\.offsetWidth\s*<\s*1\s*\)\s*return\s*;\s*const columns\s*=\s*\(band\s*!=\s*2\)\s*\?\s*freq_tbl\.length\s*\*\s*4\s*:\s*freq_tbl\.length\s*\+\s*3\s*;"),
    re.compile(r"createGraphHLine\(G,curr_offset\+step\s*,\s*0\.1\s*,\s*1\s*\);\s*chan_analysis\.initialized\s*=\s*true\s*;\s*chan_analysis\.tab\.addEventListener\('cbi-tab-active'"),
    re.compile(r"graph_data\s*=\s*\{\s*graph\s*:\s*csvg\s*,\s*offset_tbl\s*:\s*\{\s*\}\s*,\s*col_width\s*:\s*0\s*,\s*tab\s*:\s*tab\s*,\s*freq_tbl\s*:\s*bands\[band\]\.channels\s*,\s*band\s*:\s*band\s*,\s*initialized\s*:\s*false\s*,\s*\}\s*;"),
    re.compile(r"for\s*\(\s*let\s+id\s+in\s+this\.radios\s*\)\s*\{\s*const\s+radio\s*=\s*this\.radios\[id\]\s*;\s*radio\.graph\.tab\.addEventListener\('cbi-tab-active'.*?ui\.tabs\.initTabGroup\(\s*tabs\.firstElementChild\.childNodes\s*\)\s*;\s*for\s*\(\s*let\s+id\s+in\s+this\.radios\s*\)\s*\{.*?requestAnimationFrame\(.*?this\.pollFn\s*=\s*L\.bind\(\s*this\.handleScanRefresh\s*,\s*this\s*\)\s*;", re.S),
)
old_counts = tuple(len(pattern.findall(source)) for pattern, _new, _label in replacements)
new_counts = tuple(len(pattern.findall(source)) for pattern in new_patterns)

if new_counts == (1, 1, 1, 1) and old_counts == (0, 0, 0, 0):
    raise SystemExit(0)
if any(new_counts):
    raise SystemExit("unsupported channel analysis module; refusing a partial or mixed layout patch")
if old_counts != (1, 1, 1, 1):
    raise SystemExit("unsupported channel analysis module; expected one unique anchor for each reviewed change")

for pattern, new, label in replacements:
    source, count = pattern.subn(new, source, count=1)
    if count != 1:
        raise SystemExit(f"channel analysis patch failed at {label}")

temporary = path.with_name(path.name + ".tmp")
temporary.write_text(source)
temporary.chmod(path.stat().st_mode & 0o7777)
os.replace(temporary, path)
PY

python3 - "$module" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()
required = (
    r"create_channel_graph\(\s*chan_analysis\s*,\s*freq_tbl\s*,\s*band\s*\)\s*\{\s*if\s*\(\s*chan_analysis\.initialized\s*\|\|\s*chan_analysis\.graph\.offsetWidth\s*<\s*1\s*\)\s*return\s*;",
    r"createGraphHLine\(G,curr_offset\+step\s*,\s*0\.1\s*,\s*1\s*\);\s*chan_analysis\.initialized\s*=\s*true\s*;\s*chan_analysis\.tab\.addEventListener\('cbi-tab-active'",
    r"graph_data\s*=\s*\{\s*graph\s*:\s*csvg\s*,\s*offset_tbl\s*:\s*\{\s*\}\s*,\s*col_width\s*:\s*0\s*,\s*tab\s*:\s*tab\s*,\s*freq_tbl\s*:\s*bands\[band\]\.channels\s*,\s*band\s*:\s*band\s*,\s*initialized\s*:\s*false\s*,",
    r"for\s*\(\s*let\s+id\s+in\s+this\.radios\s*\)\s*\{\s*const\s+radio\s*=\s*this\.radios\[id\]\s*;\s*radio\.graph\.tab\.addEventListener\('cbi-tab-active'",
)
if any(len(re.findall(anchor, source, re.S)) != 1 for anchor in required):
    raise SystemExit("channel analysis patch verification failed")
PY
