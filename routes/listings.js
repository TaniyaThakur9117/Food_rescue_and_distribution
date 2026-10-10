// const router = require('express').Router();
// const pool = require('../db');
// const wrap = require('./wrap');

// router.post('/listings', wrap(async (req, res) => {
//   const { donor, item, kg, expiry, addr } = req.body;
//   if (!item || !addr || !(kg > 0) || !(expiry > Date.now()))
//     return res.status(400).json({ error: 'Check item, quantity, address and a future expiry time.' });
//   const [r] = await pool.query(
//     `INSERT INTO listing (donor_id, item_name, quantity_kg, expiry_time, pickup_address)
//      SELECT donor_id, ?, ?, FROM_UNIXTIME(FLOOR(?/1000)), ? FROM donor WHERE name = ?`,
//     [item, kg, expiry, addr, donor]);
//   if (!r.affectedRows) return res.status(400).json({ error: 'Unknown donor.' });
//   res.json({ id: r.insertId });
// }));

// module.exports = router;


const router = require('express').Router();
const pool = require('../db');
const wrap = require('./wrap');
const CATEGORIES = ['Cooked meals', 'Bakery', 'Fruits & vegetables', 'Packaged food', 'Dairy', 'Other'];

// Donor Portal: INSERT a new surplus listing
router.post('/listings', wrap(async (req, res) => {
  const { donor, item, category, kg, expiry, addr } = req.body;
  if (!item || !addr || !(kg > 0) || !(expiry > Date.now()))
    return res.status(400).json({ error: 'Check item, quantity, address and a future expiry time.' });
  const cat = CATEGORIES.includes(category) ? category : 'Other';
  const [r] = await pool.query(
    `INSERT INTO listing (donor_id, item_name, category, quantity_kg, expiry_time, pickup_address)
     SELECT donor_id, ?, ?, ?, FROM_UNIXTIME(FLOOR(?/1000)), ? FROM donor WHERE name = ?`,
    [item, cat, kg, expiry, addr, donor]);
  if (!r.affectedRows) return res.status(400).json({ error: 'Unknown donor.' });
  res.json({ id: r.insertId });
}));

// Donor cancels a listing, only while nobody has claimed it
router.post('/listings/:id/cancel', wrap(async (req, res) => {
  const [r] = await pool.query(
    "UPDATE listing SET status = 'Cancelled' WHERE listing_id = ? AND status = 'Available'", [req.params.id]);
  if (!r.affectedRows) return res.status(409).json({ error: 'Only unclaimed listings can be cancelled.' });
  res.json({ ok: true });
}));

module.exports = router;