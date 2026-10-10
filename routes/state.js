// const router = require('express').Router();
// const pool = require('../db');
// const wrap = require('./wrap');

// router.get('/state', wrap(async (req, res) => {
//   const [[listings], [deliveries], [log]] = await Promise.all([
//     pool.query(`SELECT l.listing_id AS id, d.name AS donor, l.item_name AS item, l.quantity_kg AS kg,
//                 UNIX_TIMESTAMP(l.expiry_time)*1000 AS expiry, l.pickup_address AS addr, l.status, n.name AS ngo
//                 FROM listing l JOIN donor d ON d.donor_id = l.donor_id
//                 LEFT JOIN ngo n ON n.ngo_id = l.ngo_id ORDER BY l.listing_id`),
//     pool.query(`SELECT dl.delivery_id AS id, dl.listing_id AS listingId, n.name AS ngo, v.name AS vol, dl.step
//                 FROM delivery dl JOIN ngo n ON n.ngo_id = dl.ngo_id
//                 JOIN volunteer v ON v.volunteer_id = dl.volunteer_id ORDER BY dl.delivery_id`),
//     pool.query(`SELECT UNIX_TIMESTAMP(ts)*1000 AS ts, table_name AS \`table\`, op, trigger_name AS trg, detail
//                 FROM audit_log ORDER BY log_id DESC LIMIT 50`)
//   ]);
//   res.json({ listings, deliveries, log });
// }));

// module.exports = router;


const router = require('express').Router();
const pool = require('../db');
const wrap = require('./wrap');

router.get('/state', wrap(async (req, res) => {
  const [[listings], [deliveries], [log], [ngos], [vols]] = await Promise.all([
    pool.query(`SELECT l.listing_id AS id, d.name AS donor, l.item_name AS item, l.category, l.quantity_kg AS kg,
                UNIX_TIMESTAMP(l.expiry_time)*1000 AS expiry, l.pickup_address AS addr, l.status, n.name AS ngo
                FROM listing l JOIN donor d ON d.donor_id = l.donor_id
                LEFT JOIN ngo n ON n.ngo_id = l.ngo_id ORDER BY l.listing_id`),
    pool.query(`SELECT dl.delivery_id AS id, dl.listing_id AS listingId, n.name AS ngo, v.name AS vol, dl.step
                FROM delivery dl JOIN ngo n ON n.ngo_id = dl.ngo_id
                JOIN volunteer v ON v.volunteer_id = dl.volunteer_id ORDER BY dl.delivery_id`),
    pool.query(`SELECT UNIX_TIMESTAMP(ts)*1000 AS ts, table_name AS \`table\`, op, trigger_name AS trg, detail
                FROM audit_log ORDER BY log_id DESC LIMIT 50`),
    pool.query('SELECT * FROM ngo ORDER BY ngo_id'),
    pool.query('SELECT * FROM volunteer ORDER BY volunteer_id')
  ]);
  res.json({ listings, deliveries, log, ngos, vols });
}));

module.exports = router;