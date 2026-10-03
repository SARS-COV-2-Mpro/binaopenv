#!/bin/bash
set -euo pipefail

: "${VPN_USERNAME:?Set VPN_USERNAME in Koyeb}"
: "${VPN_PASSWORD:?Set VPN_PASSWORD in Koyeb}"
: "${EXPECTED_VPN_IP:?Set EXPECTED_VPN_IP in Koyeb}"
: "${PROXY_TOKEN:?Set PROXY_TOKEN in Koyeb}"

if [ ! -c /dev/net/tun ]; then
  echo "FATAL: /dev/net/tun is unavailable. Koyeb does not support this configuration."
  exit 1
fi

AUTH_FILE="$(mktemp)"
chmod 600 "$AUTH_FILE"
printf '%s\n%s\n' "$VPN_USERNAME" "$VPN_PASSWORD" > "$AUTH_FILE"
unset VPN_USERNAME VPN_PASSWORD

echo "Starting OpenVPN..."
openvpn --config /app/vpn.ovpn --auth-user-pass "$AUTH_FILE" &
VPN_PID=$!

connected=0
for i in $(seq 1 45); do
  if ! kill -0 "$VPN_PID" 2>/dev/null; then
    echo "FATAL: OpenVPN process exited early."
    exit 1
  fi

  if ip -4 addr show dev tun0 2>/dev/null | grep -q 'inet ' &&
     ip -4 route get 1.1.1.1 2>/dev/null | grep -q 'dev tun0'; then
    connected=1
    break
  fi
  sleep 2
done

if [ "$connected" -ne 1 ]; then
  echo "FATAL: VPN tunnel did not establish within 90 seconds."
  kill "$VPN_PID" 2>/dev/null || true
  exit 1
fi

ACTUAL_IP="$(curl -4fsS --interface tun0 --max-time 10 https://api.ipify.org)"
if [ "$ACTUAL_IP" != "$EXPECTED_VPN_IP" ]; then
  echo "FATAL: VPN exit IP is $ACTUAL_IP, expected $EXPECTED_VPN_IP."
  kill "$VPN_PID" 2>/dev/null || true
  exit 1
fi

echo "SUCCESS: VPN connected. Exit IP verified: $ACTUAL_IP"
node /app/index.js &
APP_PID=$!

wait -n "$VPN_PID" "$APP_PID"
echo "VPN or proxy process stopped; shutting down container."
kill "$VPN_PID" "$APP_PID" 2>/dev/null || true
exit 1
