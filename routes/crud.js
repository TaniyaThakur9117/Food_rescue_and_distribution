// Reusable INSERT / UPDATE / DELETE routes for one table.
// table, idCol and fields are fixed in our own code (never from the browser); values are always parameterized.
const express = require('express');
const pool = require('../db');
const wrap = require('./wrap');

module.exports = (table, idCol, fields, path) => {
  const router = express.Router();
  const values = b => fields.map(f => String(b[f] ?? '').trim() || null);
  const needName = (b, res) => String(b.name || '').trim() ? true : (res.status(400).json({ error: 'Name is required.' }), false);

  router.post(`/${path}`, wrap(async (req, res) => {
    if (!needName(req.body, res)) return;
    const [r] = await pool.query(
      `INSERT INTO ${table} (${fields.join(',')}) VALUES (${fields.map(() => '?').join(',')})`, values(req.body));
    res.json({ id: r.insertId });
  }));

  router.put(`/${path}/:id`, wrap(async (req, res) => {
    if (!needName(req.body, res)) return;
    const [r] = await pool.query(
      `UPDATE ${table} SET ${fields.map(f => f + ' = ?').join(', ')} WHERE ${idCol} = ?`, [...values(req.body), req.params.id]);
    if (!r.affectedRows) return res.status(404).json({ error: 'Record not found.' });
    res.json({ ok: true });
  }));

  router.delete(`/${path}/:id`, wrap(async (req, res) => {
    await pool.query(`DELETE FROM ${table} WHERE ${idCol} = ?`, [req.params.id]);
    res.json({ ok: true });
  }));

  return router;
};