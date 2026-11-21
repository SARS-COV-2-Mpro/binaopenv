const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 8080;

// ✅ CORS - allow all origins
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// ✅ CRITICAL: Health check route for Koyeb
// This must return 200 FAST, without hitting Binance
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.get('/', (req, res) => {
  res.status(200).send('Binance Testnet Proxy is running ✅');
});

// ✅ Proxy everything under /api to Binance Testnet
app.use(
  '/api',
  createProxyMiddleware({
    target: 'https://testnet.binance.vision',
    changeOrigin: true,
    secure: true,
    logLevel: 'debug',
    onError: (err, req, res) => {
      console.error('Proxy error:', err.message);
      res.status(502).json({ error: 'Proxy error', message: err.message });
    },
  })
);

// ✅ Also support WebSocket/stream proxying if needed
app.use(
  '/ws',
  createProxyMiddleware({
    target: 'wss://testnet.binance.vision',
    changeOrigin: true,
    ws: true,
  })
);

// ✅ Catch-all 404 (prevents crash on unknown routes)
app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

// ✅ Global error handler (prevents app from crashing)
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Binance Testnet Proxy running on port ${PORT}`);
});
