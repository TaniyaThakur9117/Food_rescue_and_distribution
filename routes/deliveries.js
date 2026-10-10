const router = require('express').Router();
const pool = require('../db');
const wrap = require('./wrap');

router.post('/deliveries/:id/step', wrap(async (req, res) => {
  const { step } = req.body;
  if (!['Picked Up', 'Delivered'].includes(step)) return res.status(400).json({ error: 'Invalid step.' });
  await pool.query('UPDATE delivery SET step = ? WHERE delivery_id = ?', [step, req.params.id]);
  res.json({ ok: true });
}));

module.exports = router;