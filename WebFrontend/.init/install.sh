#!/usr/bin/env bash
set -euo pipefail
# Idempotent dependency install + basic lint/format scaffolding
WORKSPACE="/home/kavia/workspace/code-generation/test-responsive-web-application-43742-43771/WebFrontend"
LOGDIR="$WORKSPACE/.setup_logs"
LOGFILE="$LOGDIR/npm_install.log"
mkdir -p "$WORKSPACE" "$LOGDIR"
cd "$WORKSPACE"
# Ensure package.json exists
if [ ! -f package.json ]; then
  echo "install: package.json missing in workspace ($WORKSPACE)" >&2
  exit 3
fi
# Local env for this run only (do not overwrite global settings)
export NODE_ENV=${NODE_ENV:-development}
export PORT=${PORT:-3000}
# Record node/npm versions for traceability
node -e "const fs=require('fs');fs.writeFileSync(process.env.PWD+'/.setup_logs/node_npm_versions.json',JSON.stringify({node:process.version, npm:require('child_process').execSync('npm --version').toString().trim()},null,2))" || true
# If npm exists prefer npm; otherwise fail
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found on PATH" >&2
  exit 4
fi
# Use npm ci when lockfile exists for deterministic installs
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund >"$LOGFILE" 2>&1 || { echo "npm ci failed, see $LOGFILE" >&2; tail -n 200 "$LOGFILE" >&2 || true; exit 5; }
else
  npm i --no-audit --no-fund >"$LOGFILE" 2>&1 || { echo "npm install failed, see $LOGFILE" >&2; tail -n 200 "$LOGFILE" >&2 || true; exit 6; }
fi
# Record installed package versions (react/react-dom/react-scripts) by reading node_modules if present
node -e "const fs=require('fs');const out={};['react','react-dom','react-scripts'].forEach(n=>{try{out[n]=require('./node_modules/'+n+'/package.json').version}catch(e){out[n]=null}});fs.writeFileSync(process.env.PWD+'/.setup_logs/installed_versions.json',JSON.stringify(out,null,2));" || true
# Create minimal lint/format configs if missing
[ -f .eslintrc.json ] || cat > .eslintrc.json <<'EOF'
{ "extends": ["react-app", "eslint:recommended"], "rules": {} }
EOF
[ -f .prettierrc.json ] || cat > .prettierrc.json <<'EOF'
{ "singleQuote": true, "trailingComma": "es5" }
EOF
[ -f .gitignore ] || cat > .gitignore <<'EOF'
node_modules
build
.env
EOF
# Add lint/format npm scripts to package.json if missing (idempotent)
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};let changed=false;if(!p.scripts.lint){p.scripts.lint='eslint src --ext .js,.jsx';changed=true;}if(!p.scripts.format){p.scripts.format='prettier --write \"src/**/*.{js,jsx,json,css}\"';changed=true;}if(changed)fs.writeFileSync('package.json',JSON.stringify(p,null,2));" || true
# Final verification: ensure npm is runnable and log a short tail of the install log for visibility
command -v npm >/dev/null 2>&1 || (echo "npm disappeared from PATH after install" >&2 && exit 7)
# Write a concise success marker
echo '{"status":"ok","installed_on":"'"$(date --iso-8601=seconds)"'"}' > "$LOGDIR/install_status.json"
exit 0
