// // Catches SQL errors and sends them to the browser as JSON
// module.exports = fn => (req, res) => fn(req, res).catch(e => {
//   console.error(e);
//   res.status(500).json({ error: e.sqlMessage || e.message });
// });



// Catches SQL errors and sends readable JSON to the browser
module.exports = fn => (req, res) => fn(req, res).catch(e => {
  console.error(e);
  if (e.errno === 1062) return res.status(409).json({ error: 'That name already exists.' });
  if (e.errno === 1451) return res.status(409).json({ error: 'Cannot delete: this record is used by existing listings or deliveries.' });
  res.status(500).json({ error: e.sqlMessage || e.message });
});