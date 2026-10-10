   // require('dotenv').config();
   // const express = require('express');
   // const path = require('path');

   // const app = express();
   // app.use(express.json());
   // app.use(express.static(path.join(__dirname, 'public')));

   // app.use('/api', require('./routes/state'));
   // app.use('/api', require('./routes/listings'));
   // app.use('/api', require('./routes/claim'));
   // app.use('/api', require('./routes/deliveries'));

   // const port = process.env.PORT || 3000;
   // app.listen(port, () => console.log(`Dashboard running at http://localhost:${port}`));


require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Each file in /routes handles one part of the dashboard
app.use('/api', require('./routes/state'));
app.use('/api', require('./routes/listings'));
app.use('/api', require('./routes/claim'));
app.use('/api', require('./routes/deliveries'));
app.use('/api', require('./routes/ngos'));
app.use('/api', require('./routes/volunteers'));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Dashboard running at http://localhost:${port}`));