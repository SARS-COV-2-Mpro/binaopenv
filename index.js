const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 8080;

// Allow all CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', '*');
  res.header('Access-Control-Allow-Methods', '*');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// Proxy everything to Binance Testnet
app.use(
  '/',
  createProxyMiddleware({
    target: 'https://testnet.binance.vision',
    changeOrigin: true,
    secure: true,
    on: {
      error: (err, req, res) => {
        console.error('Proxy error:', err.message);
        res.status(502).send('Proxy Error');
      },
    },
  })
);

app.listen(PORT, () => {
  console.log(`✅ Binance Testnet Proxy running on port ${PORT}`);
});
