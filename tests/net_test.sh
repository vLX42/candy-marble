#!/bin/bash
# Online race, end to end: a server and two bot clients race a level with two
# AI bots (run by the host); both clients must get the results for all four,
# see the other marbles move, and at least one racer must finish.
#   bash tests/net_test.sh                       # starts its own server (the editor binary)
#   URL=ws://127.0.0.1:9080 bash tests/net_test.sh   # use a server that's already running (the Docker image)
# Env: GODOT (default godot), PORT (9123), LEVEL (4, a race level the bots know), BOTS (2)
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PORT=${PORT:-9123}
LEVEL=${LEVEL:-4}
BOTS=${BOTS:-2}
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
$GODOT --headless -s tests/net_bot.gd -- --url="$URL" --name=Mint --host --players=2 --level="$LEVEL" --bots="$BOTS" > "$LOGS/a.log" 2>&1 &
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
# Godot exits 0 even when a script fails to load, so also insist on each
# bot's own verdict.
grep -q "NET BOT PASSED" "$LOGS/a.log" || RA=1
grep -q "NET BOT PASSED" "$LOGS/b.log" || RB=1
if [ $RA -eq 0 ] && [ $RB -eq 0 ]; then
	echo "NET TEST PASSED"
	exit 0
fi
echo "NET TEST FAILED (bots exited $RA and $RB)"
exit 1
