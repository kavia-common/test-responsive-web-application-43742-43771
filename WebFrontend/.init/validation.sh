#!/usr/bin/env bash
set -euo pipefail
# Validation: build -> start deterministic static server -> probe -> stop
WORKSPACE="/home/kavia/workspace/code-generation/test-responsive-web-application-43742-43771/WebFrontend"
LOGDIR="$WORKSPACE/.setup_logs"
LOGFILE="$LOGDIR/react_start.log"
PIDFILE="$LOGDIR/devserver.pid"
PM2_NAME="webfrontend-serve"
mkdir -p "$WORKSPACE" "$LOGDIR"
cd "$WORKSPACE"
export PORT=${PORT:-3000}
export HOST=${HOST:-0.0.0.0}
export NODE_ENV=${NODE_ENV:-production}
export BROWSER=none
export CI=1
# Ensure build exists; run build if missing
if [ ! -f "$WORKSPACE/build/index.html" ]; then
  echo "validation: build missing, running build" >"$LOGFILE"
  npm run build >>"$LOGFILE" 2>&1 || { echo "validation: build failed, see $LOGFILE" >&2; tail -n 200 "$LOGFILE" >&2 || true; exit 6; }
fi
# Determine start command: prefer local serve if executable, else create embedded server
START_CMD=""
if [ -x "$WORKSPACE/node_modules/.bin/serve" ]; then
  START_CMD="$WORKSPACE/node_modules/.bin/serve -s $WORKSPACE/build -l ${PORT}"
else
  cat > "$WORKSPACE/static-server.js" <<'EOF'
const http=require('http'),fs=require('fs'),path=require('path');const port=process.env.PORT||3000;const root=path.join(__dirname,'build');const mime={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','jpg':'image/jpeg','svg':'image/svg+xml'};http.createServer((req,res)=>{let url=req.url.split('?')[0]; if(url.includes('..')){res.statusCode=400;res.end('bad request');return;} let p=path.join(root, url); if(req.url.endsWith('/')) p=path.join(p,'index.html'); fs.stat(p,(e,s)=>{ if(e){ res.statusCode=404; res.end('not found'); return;} const ext=path.extname(p).slice(1); res.setHeader('Content-Type',mime[ext]||'application/octet-stream'); fs.createReadStream(p).pipe(res); });}).listen(port,()=>console.log('static server listening on '+port));
EOF
  START_CMD="node $WORKSPACE/static-server.js"
fi
# Start server under pm2 if available, else background process with PID file
set +e
if command -v pm2 >/dev/null 2>&1; then
  pm2 delete "$PM2_NAME" >/dev/null 2>&1 || true
  # Use sh -c so START_CMD is interpreted correctly
  pm2 start --name "$PM2_NAME" --no-autorestart -- sh -c "$START_CMD" >"$LOGFILE" 2>&1 || true
  sleep 1
  PID=$(pm2 pid "$PM2_NAME" 2>/dev/null || true)
  if [ -n "$PID" ] && [ "$PID" != "-" ]; then echo "$PID" > "$PIDFILE"; fi
else
  nohup setsid sh -c "$START_CMD" >"$LOGFILE" 2>&1 & echo $! > "$PIDFILE"
fi
set -e
# Probe until responsive
TRIES=0
MAX=60
until curl -sSf "http://localhost:${PORT}" >/dev/null 2>&1 || [ $TRIES -ge $MAX ]; do sleep 1; TRIES=$((TRIES+1)); done
if curl -sSf "http://localhost:${PORT}" >/dev/null 2>&1; then
  echo "validation: server responded on port ${PORT}" >> "$LOGFILE"
  tail -n 100 "$LOGFILE" || true
  # Cleanup
  if command -v pm2 >/dev/null 2>&1; then pm2 delete "$PM2_NAME" >/dev/null 2>&1 || true; fi
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" || true)
    if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
      kill -TERM "$PID" >/dev/null 2>&1 || true
      sleep 1
      kill -KILL "$PID" >/dev/null 2>&1 || true
    fi
    rm -f "$PIDFILE" || true
  fi
  exit 0
else
  echo "validation: server did not respond within ${MAX}s" >&2
  tail -n 200 "$LOGFILE" >&2 || true
  if command -v pm2 >/dev/null 2>&1; then pm2 delete "$PM2_NAME" >/dev/null 2>&1 || true; fi
  if [ -f "$PIDFILE" ]; then PID=$(cat "$PIDFILE" || true); [ -n "$PID" ] && kill -TERM "$PID" >/dev/null 2>&1 || true; fi
  exit 7
fi
