#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/bin" "$SANDBOX/home/.acme.sh" "$SANDBOX/certs"
sed 's/if \[ "$EUID" -ne 0 \]; then/if false; then/' "$ROOT_DIR/get.sh" > "$SANDBOX/get.sh"
grep -q '^if false; then$' "$SANDBOX/get.sh"

for command in curl cron socat; do
  printf '#!/bin/bash\nexit 0\n' > "$SANDBOX/bin/$command"
  chmod +x "$SANDBOX/bin/$command"
done

cat > "$SANDBOX/bin/ss" <<'EOF'
#!/bin/bash
echo 'LISTEN 0 511 0.0.0.0:80 0.0.0.0:*'
EOF

cat > "$SANDBOX/bin/systemctl" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "is-active" ]; then
  exit 0
fi
printf '%s\n' "$*" >> "$EVENTS_FILE"
EOF

cat > "$SANDBOX/bin/crontab" <<'EOF'
#!/bin/bash
echo 'acme.sh --cron'
EOF

cat > "$SANDBOX/home/.acme.sh/acme.sh" <<'EOF'
#!/bin/bash
if [ "${1:-}" != "--issue" ]; then
  exit 0
fi
printf '%s\n' "$*" > "$ARGS_FILE"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --pre-hook) pre_hook="$2"; shift 2 ;;
    --post-hook) post_hook="$2"; shift 2 ;;
    *) shift ;;
  esac
done
bash -c "$pre_hook"
bash -c "$post_hook"
exit "$ACME_STATUS"
EOF

chmod +x "$SANDBOX/bin/ss" "$SANDBOX/bin/systemctl" "$SANDBOX/bin/crontab" "$SANDBOX/home/.acme.sh/acme.sh"

run_case() {
  local acme_status="$1"
  local expected_status="$2"
  : > "$SANDBOX/events"
  : > "$SANDBOX/args"

  set +e
  HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" EVENTS_FILE="$SANDBOX/events" ARGS_FILE="$SANDBOX/args" ACME_STATUS="$acme_status" \
    bash "$SANDBOX/get.sh" --domain example.com --key-name example --cert-dir "$SANDBOX/certs" --stop-nginx --force >/dev/null 2>&1
  actual_status="$?"
  set -e

  [ "$actual_status" -eq "$expected_status" ]
  [ "$(cat "$SANDBOX/events")" = $'stop nginx\nstart nginx' ]
  grep -q -- '--pre-hook .* stop nginx' "$SANDBOX/args"
  grep -q -- '--post-hook .* start nginx' "$SANDBOX/args"
}

run_case 0 0
run_case 42 1
echo "get_stop_nginx_test: OK"
