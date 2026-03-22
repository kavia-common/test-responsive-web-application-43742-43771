#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/test-responsive-web-application-43742-43771/WebFrontend"
LOGDIR="$WORKSPACE/.setup_logs"
LOGFILE="$LOGDIR/jest.log"
mkdir -p "$WORKSPACE" "$LOGDIR"
cd "$WORKSPACE"
[ -f package.json ] || { echo "testing: package.json missing" >&2; exit 3; }
# ensure tests dir and minimal smoke test
mkdir -p src/__tests__
if [ ! -f src/__tests__/smoke.test.js ]; then
  cat > src/__tests__/smoke.test.js <<'EOF'
test('smoke: true is true', () => { expect(true).toBe(true); });
EOF
fi
# Preserve existing test script; if missing add a non-interactive react-scripts test
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{}; if(!p.scripts.test) p.scripts.test='react-scripts test --watchAll=false --silent'; fs.writeFileSync('package.json',JSON.stringify(p,null,2));"
# Ensure non-interactive single-run behavior
export CI=1
# Record node and jest info (no npx)
{
  echo "node=$(node -v)"
  if command -v jest >/dev/null 2>&1; then
    # jest CLI is available globally or in PATH
    echo "jest=$(jest --version 2>/dev/null || echo unknown)"
  elif [ -f node_modules/jest/package.json ]; then
    node -e "console.log('jest='+require('./node_modules/jest/package.json').version)"
  else
    echo "jest=not-found"
  fi
} >> "$LOGFILE" 2>&1 || true
# Run tests, capture logs; on failure tail recent output and exit non-zero
npm test >"$LOGFILE" 2>&1 || { echo "testing: tests failed, see $LOGFILE" >&2; tail -n 200 "$LOGFILE" >&2 || true; exit 4; }
exit 0
