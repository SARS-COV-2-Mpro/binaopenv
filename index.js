const express = require('express');
const proxy = require('express-http-proxy');

const app = express();
const PORT = process.env.PORT || 8080;

// CORS headers
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', '*');
  res.header('Access-Control-Allow-Methods', '*');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// Proxy to Binance Testnet
app.use('/', proxy('https://testnet.binance.vision'));

app.listen(PORT, () => {
  console.log(`Proxy running on port ${PORT}`);
});
