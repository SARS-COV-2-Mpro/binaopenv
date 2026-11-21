const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 8080;

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', '*');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

app.get('/health', (req, res) => res.status(200).send('OK'));
app.get('/', (req, res) => res.status(200).send('Binance Futures Testnet Proxy ✅'));

// ✅ FUTURES endpoints -> Futures Testnet
app.use(
  '/fapi',
  createProxyMiddleware({
    target: 'https://testnet.binancefuture.com',
    changeOrigin: true,
    secure: true,
    onError: (err, req, res) => {
      res.status(502).json({ error: 'Proxy error', message: err.message });
    },
  })
);

app.use((req, res) => res.status(404).json({ error: 'Not found', path: req.path }));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Futures Proxy running on port ${PORT}`);
});
