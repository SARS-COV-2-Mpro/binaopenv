import express from "express";
import https from "node:https";
import { execFileSync } from "node:child_process";

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(express.raw({ type: () => true, limit: "1mb" }));

const targets = {
  mainnet: "api.binance.com",
  futures: "fapi.binance.com",
  testnet: "testnet.binance.vision",
  "testnet-futures": "testnet.binancefuture.com"
};

function vpnAddress() {
  const route = execFileSync("ip", ["-4", "route", "get", "1.1.1.1"], {
    encoding: "utf8"
  });
  if (!/\bdev tun0\b/.test(route)) {
    throw new Error("VPN route is down");
  }

  const output = execFileSync("ip", ["-4", "-o", "addr", "show", "dev", "tun0"], {
    encoding: "utf8"
  });
  const address = output.match(/\binet (\d+\.\d+\.\d+\.\d+)\//)?.[1];
  if (!address) throw new Error("VPN interface has no IPv4 address");
  return address;
}

app.get("/health", (_req, res) => {
  try {
    vpnAddress();
    res.json({ ok: true, vpnRoute: true });
  } catch {
    res.status(503).json({ ok: false, vpnRoute: false });
  }
});

app.all(/^\/(mainnet|futures|testnet|testnet-futures)(\/.*)?$/, (req, res) => {
  if (!process.env.PROXY_TOKEN ||
      req.get("x-proxy-token") !== process.env.PROXY_TOKEN) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  let localAddress;
  try {
    localAddress = vpnAddress();
  } catch (error) {
    return res.status(503).json({ error: error.message });
  }

  const prefix = req.path.split("/")[1];
  const host = targets[prefix];
  const path = req.originalUrl.slice(prefix.length + 1) || "/";

  const headers = {
    "user-agent": "binance-openvpn-proxy/1.0"
  };
  for (const name of ["x-mbx-apikey", "content-type", "accept"]) {
    if (req.headers[name]) headers[name] = req.headers[name];
  }
  if (Buffer.isBuffer(req.body) && req.body.length) {
    headers["content-length"] = req.body.length;
  }

  const upstream = https.request({
    hostname: host,
    port: 443,
    path,
    method: req.method,
    headers,
    localAddress,
    family: 4,
    timeout: 15000
  }, (response) => {
    res.status(response.statusCode || 502);
    if (response.headers["content-type"]) {
      res.set("content-type", response.headers["content-type"]);
    }
    response.pipe(res);
  });

  upstream.on("timeout", () => upstream.destroy(new Error("Upstream timeout")));
  upstream.on("error", (error) => {
    console.error("Binance request failed:", error.message);
    if (!res.headersSent) res.status(502).json({ error: "VPN upstream unavailable" });
    else res.destroy();
  });

  upstream.end(Buffer.isBuffer(req.body) ? req.body : undefined);
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Binance proxy listening on ${port}`);
});
