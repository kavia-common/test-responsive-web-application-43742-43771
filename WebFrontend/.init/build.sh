#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/test-responsive-web-application-43742-43771/WebFrontend"
LOGDIR="$WORKSPACE/.setup_logs"
LOGFILE="$LOGDIR/build.log"
mkdir -p "$WORKSPACE" "$LOGDIR"
cd "$WORKSPACE"
[ -f package.json ] || { echo "build: package.json missing in workspace ($WORKSPACE)" >&2; exit 3; }
export CI=1
# ensure build script exists
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{}; if(!p.scripts.build) p.scripts.build='react-scripts build'; fs.writeFileSync('package.json',JSON.stringify(p,null,2));"
npm run build >"$LOGFILE" 2>&1 || { echo "build: build failed, see $LOGFILE" >&2; tail -n 200 "$LOGFILE" >&2 || true; exit 4; }
if [ ! -f build/index.html ]; then echo "build: missing build/index.html" >&2; tail -n 200 "$LOGFILE" >&2 || true; exit 5; fi
if ! grep -q "<div id=\"root\"\|<div id='root'" build/index.html >/dev/null 2>&1; then echo "build: index.html missing root div" >&2; exit 6; fi
echo "build: artifact produced" >> "$LOGFILE"
exit 0
