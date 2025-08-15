const express = require('express');
const app = express();
app.get('/healthz', (_, res) => res.status(200).send('ok'));
app.get('/', (_, res) => res.status(200).send('media api placeholder'));
const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`API listening on ${port}`));
