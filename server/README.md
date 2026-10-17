# Candy Marble online server

Up to six players race the same level. Every player rolls their own marble
on their own machine; the server only runs the lobby and the race (who is in,
start, GO, finish times, results) and passes the marbles' positions around.
It's the game itself, run headless with `--server`, so it's tiny and needs
no GPU.

## Run it on the NAS (Unraid)

The image is built by CI on every push to main:
`ghcr.io/vlx42/candy-marble-server:latest` (and `:<version>`).

```bash
docker run -d --name candy-marble-server --restart unless-stopped -p 9080:9080 ghcr.io/vlx42/candy-marble-server:latest
```

Or in Unraid: Docker > Add Container, repository
`ghcr.io/vlx42/candy-marble-server:latest`, port 9080 (container) to any free
host port. To use another port inside the container, set `PORT`.

`docker logs candy-marble-server` shows who joins, races and finishes.

If the pull says "unauthorized", the package is private: make it public in
GitHub (Packages > candy-marble-server > Package settings > Change
visibility) or `docker login ghcr.io` on the NAS first.

## A name with a certificate (needed for the web version)

The web version is served over https, so the browser only allows a secure
WebSocket (`wss://`). In Nginx Proxy Manager:

1. Add a Proxy Host: domain `marble.vlx.dk` (or whatever name you like),
   scheme `http`, forward to the NAS IP and the port above (9080).
2. Switch on **Websockets Support**. Without it the connection hangs.
3. SSL tab: request a Let's Encrypt certificate, force SSL.

Then in the game: **Online race**, server `wss://marble.vlx.dk`.
Desktop builds on the same network can also use `ws://192.168.1.15:9080`
directly. A link like
`https://vlx42.github.io/candy-marble/play/?server=wss://marble.vlx.dk`
fills the address in for web players.

## How a race goes

- The first player in the lobby is the host: they pick the level and press
  Start race. If the host leaves, the next seat takes over.
- Everyone loads the level, the server waits for all of them (15 s at most),
  then GO and the 3-2-1.
- Each player solves their own switches and gates and has their own
  monsters. The other marbles are solid: you can bump them, they push you.
- When the first marble finishes, the others get 30 seconds (`--grace=`),
  then the results, and 10 seconds later everyone is back in the lobby.
- Players who join mid-race wait in the lobby for the next one.

## Run it anywhere else

Any machine with the game or the Godot editor:

```bash
godot --headless -- --server --port=9080
```

Test it with two bots: `bash tests/net_test.sh` (starts its own server), or
`URL=ws://192.168.1.15:9080 bash tests/net_test.sh` against a running one.
