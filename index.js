const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");

const app = express();
const PORT = process.env.PORT || 8000;

// Proxy all requests to Bybit API
app.use(
  "/",
  createProxyMiddleware({
    target: "https://api.bybit.com",
    changeOrigin: true,
    secure: true,
    on: {
      proxyReq: (proxyReq, req) => {
        // Forward the original host header
        proxyReq.setHeader("host", "api.bybit.com");
      },
    },
  })
);

app.listen(PORT, () => {
  console.log(`Bybit proxy running on port ${PORT}`);
});
