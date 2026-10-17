#!/bin/bash
# Online race, end to end: a server and two bot clients race a level; both bots
# must get the results, see each other's marble move, and at least one must finish.
#   bash tests/net_test.sh                       # starts its own server (the editor binary)
#   URL=ws://127.0.0.1:9080 bash tests/net_test.sh   # use a server that's already running (the Docker image)
# Env: GODOT (default godot), PORT (9123), LEVEL (12, the shortest)
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PORT=${PORT:-9123}
LEVEL=${LEVEL:-12}
LOGS=$(mktemp -d)
SERVER=""
if [ -z "${URL:-}" ]; then
	URL="ws://127.0.0.1:$PORT"
	$GODOT --headless -- --server --port="$PORT" --grace=45 > "$LOGS/server.log" 2>&1 &
	SERVER=$!
	for i in $(seq 1 40); do
		grep -q "listening on port" "$LOGS/server.log" 2>/dev/null && break
		sleep 0.5
	done
fi
echo "server: $URL"
$GODOT --headless -s tests/net_bot.gd -- --url="$URL" --name=Mint --host --players=2 --level="$LEVEL" > "$LOGS/a.log" 2>&1 &
A=$!
sleep 1
$GODOT --headless -s tests/net_bot.gd -- --url="$URL" --name=Lemon --players=2 > "$LOGS/b.log" 2>&1 &
B=$!
wait $A; RA=$?
wait $B; RB=$?
[ -n "$SERVER" ] && kill $SERVER 2>/dev/null
for f in server a b; do
	[ -f "$LOGS/$f.log" ] && grep -h "^\[" "$LOGS/$f.log" | grep -v "^\[ext\|^\[res" | sed "s/^/  /"
done
grep -h "SCRIPT ERROR" -A 3 "$LOGS"/*.log | head -20
if [ $RA -eq 0 ] && [ $RB -eq 0 ]; then
	echo "NET TEST PASSED"
	exit 0
fi
echo "NET TEST FAILED (bots exited $RA and $RB)"
exit 1
