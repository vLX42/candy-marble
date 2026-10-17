# Candy Marble online race server: the game's Linux build run headless with
# --server. It speaks WebSockets on port 9080 (plain ws://). Put a reverse
# proxy with a certificate in front of it for wss://, which the web version
# needs (see server/README.md).
#
# CI builds it from the exported Linux binary (server/app/CandyMarble.x86_64)
# and publishes ghcr.io/vlx42/candy-marble-server.
FROM debian:bookworm-slim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --create-home --uid 1000 marble

COPY --chown=marble:marble app/CandyMarble.x86_64 /app/CandyMarble.x86_64
RUN chmod +x /app/CandyMarble.x86_64

USER marble
WORKDIR /home/marble
ENV PORT=9080
EXPOSE 9080

LABEL org.opencontainers.image.source="https://github.com/vLX42/candy-marble" \
	org.opencontainers.image.description="Candy Marble online race server"

CMD ["/app/CandyMarble.x86_64", "--headless", "--", "--server"]
