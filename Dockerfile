FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openvpn iproute2 curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

COPY index.js vpn.ovpn start.sh ./
RUN chmod +x start.sh

EXPOSE 3000
CMD ["./start.sh"]
