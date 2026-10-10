// const router = require('express').Router();
// const pool = require('../db');
// const wrap = require('./wrap');

// router.post('/claim', wrap(async (req, res) => {
//   const conn = await pool.getConnection();
//   try {
//     await conn.query('CALL sp_claim_listing(?, ?, @did)', [req.body.listingId, req.body.ngo]);
//     const [[row]] = await conn.query('SELECT @did AS deliveryId');
//     if (!row.deliveryId) return res.status(409).json({ error: 'Already claimed by another NGO.' });
//     res.json({ deliveryId: row.deliveryId });
//   } finally { conn.release(); }
// }));

// module.exports = router;


const router = require('express').Router();
const pool = require('../db');
const wrap = require('./wrap');

// NGO Live Feed: claim through the stored procedure
router.post('/claim', wrap(async (req, res) => {
  const conn = await pool.getConnection();   // same connection must read @did
  try {
    await conn.query('CALL sp_claim_listing(?, ?, @did)', [req.body.listingId, req.body.ngo]);
    const [[row]] = await conn.query('SELECT @did AS deliveryId');
    if (!row.deliveryId) return res.status(409).json({ error: 'Already claimed by another NGO.' });
    res.json({ deliveryId: row.deliveryId });
  } finally { conn.release(); }
}));

// NGO cancels a claim (before pickup): food returns to the live feed
router.post('/claim/:listingId/cancel', wrap(async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.query('CALL sp_cancel_claim(?, @ok)', [req.params.listingId]);
    const [[row]] = await conn.query('SELECT @ok AS ok');
    if (!row.ok) return res.status(409).json({ error: 'A claim can only be cancelled before pickup.' });
    res.json({ ok: true });
  } finally { conn.release(); }
}));

module.exports = router;