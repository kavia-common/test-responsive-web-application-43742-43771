#!/usr/bin/env bash
set -euo pipefail

# Scaffolding: safe CRA scaffold with compatibility check
WORKSPACE="/home/kavia/workspace/code-generation/test-responsive-web-application-43742-43771/WebFrontend"
LOGDIR="$WORKSPACE/.setup_logs"
LOGFILE="$LOGDIR/create_react_app.log"
mkdir -p "$WORKSPACE" "$LOGDIR"
cd "$WORKSPACE"

# If package.json exists, skip scaffolding
if [ -f package.json ]; then echo "scaffold: package.json exists, skipping" >"$LOGFILE"; exit 0; fi

# Allowed safe files list (include .setup_logs)
SAFE_LIST=(".git" "README" "README.md" "README.MD" "readme.md" ".gitignore" ".setup_logs")
# Check for any files outside the safe list
for f in $(ls -A); do
  ok=0
  for s in "${SAFE_LIST[@]}"; do
    [ "$f" = "$s" ] && ok=1 || true
  done
  if [ $ok -eq 0 ]; then
    echo "scaffold: workspace contains unexpected file '$f', aborting" >"$LOGFILE"
    exit 5
  fi
done

# Validate create-react-app binary and version compatibility
if ! command -v create-react-app >/dev/null 2>&1; then
  echo "scaffold: create-react-app not found" >"$LOGFILE"
  exit 6
fi
CRAVERSION=$(create-react-app --version 2>/dev/null || true)
CRA_MAJOR=$(echo "$CRAVERSION" | awk -F. '{print $1}' 2>/dev/null || true)
# Best-effort compatibility: require CRA major >=4 (CRA v4+ generally aligns with modern Node/npm)
if [ -z "$CRAVERSION" ] || [ -z "$CRA_MAJOR" ] || ! echo "$CRA_MAJOR" | grep -E '^[0-9]+$' >/dev/null 2>&1 || [ "$CRA_MAJOR" -lt 4 ]; then
  echo "scaffold: detected create-react-app version '$CRAVERSION' which may be incompatible with Node>=16/npm>=8; aborting" >"$LOGFILE"
  echo "create-react-app version: $CRAVERSION" >>"$LOGFILE" || true
  exit 7
fi

# Run CRA scaffold using installed binary (non-interactive) and log output
set +e
create-react-app . --use-npm >"$LOGFILE" 2>&1
RC=$?
set -e
if [ $RC -ne 0 ]; then
  echo "scaffold: create-react-app failed (rc=$RC). See $LOGFILE" >&2
  tail -n 200 "$LOGFILE" >&2 || true
  exit 8
fi

# Validate package.json for required scripts (start, build, test)
if ! node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));const s=p.scripts||{}; if(!s.start||!s.build||!s.test){console.error('missing default scripts');process.exit(2);}" 2>>"$LOGFILE"; then
  echo 'scaffold: validation failed - missing start/build/test scripts' >>"$LOGFILE"
  exit 9
fi

# Final success log entry
echo "scaffold: create-react-app completed successfully (version: $CRAVERSION)" >>"$LOGFILE"
exit 0
