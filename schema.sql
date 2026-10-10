-- Surplus Food Rescue: run this whole script in MySQL Workbench (lightning bolt button)
DROP DATABASE IF EXISTS food_rescue;
CREATE DATABASE food_rescue;
USE food_rescue;

CREATE TABLE donor     (donor_id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(80) NOT NULL UNIQUE);
CREATE TABLE ngo       (ngo_id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(80) NOT NULL UNIQUE);
CREATE TABLE volunteer (volunteer_id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(80) NOT NULL);

CREATE TABLE listing (
  listing_id INT AUTO_INCREMENT PRIMARY KEY,
  donor_id INT NOT NULL,
  item_name VARCHAR(60) NOT NULL,
  quantity_kg DECIMAL(8,2) NOT NULL CHECK (quantity_kg > 0),
  expiry_time DATETIME NOT NULL,
  pickup_address VARCHAR(80) NOT NULL,
  status ENUM('Available','Claimed','Delivered') NOT NULL DEFAULT 'Available',
  ngo_id INT NULL,
  FOREIGN KEY (donor_id) REFERENCES donor(donor_id),
  FOREIGN KEY (ngo_id)   REFERENCES ngo(ngo_id)
);
CREATE TABLE delivery (
  delivery_id INT AUTO_INCREMENT PRIMARY KEY,
  listing_id INT NOT NULL,
  ngo_id INT NOT NULL,
  volunteer_id INT NOT NULL,
  step ENUM('Assigned','Picked Up','Delivered') NOT NULL DEFAULT 'Assigned',
  FOREIGN KEY (listing_id)   REFERENCES listing(listing_id),
  FOREIGN KEY (ngo_id)       REFERENCES ngo(ngo_id),
  FOREIGN KEY (volunteer_id) REFERENCES volunteer(volunteer_id)
);
CREATE TABLE audit_log (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  table_name VARCHAR(30), op VARCHAR(10), trigger_name VARCHAR(40), detail VARCHAR(200)
);

-- Seed data (inserted before triggers exist, so the audit log starts empty)
INSERT INTO donor(name) VALUES ('Green Leaf Bakery'),('Spice Route Kitchen'),('Hotel Sayaji'),('Annapurna Mess'),('Fresh Basket Mart');
INSERT INTO ngo(name) VALUES ('Hope Foundation'),('Annadaan Trust'),('City Food Bank');
INSERT INTO volunteer(name) VALUES ('Rohan K.'),('Sneha P.'),('Imran S.'),('Aarti D.');
INSERT INTO listing(donor_id,item_name,quantity_kg,expiry_time,pickup_address,status,ngo_id) VALUES
 (3,'Veg biryani',42,DATE_ADD(NOW(),INTERVAL 5 HOUR),'12 Station Rd','Available',NULL),
 (1,'Assorted bread loaves',18,DATE_ADD(NOW(),INTERVAL 9 HOUR),'4 Market Yard','Available',NULL),
 (5,'Vegetables (mixed)',65,DATE_ADD(NOW(),INTERVAL 20 HOUR),'Plot 9, Shahu Naka','Available',NULL),
 (4,'Chapati and sabzi',25,DATE_SUB(NOW(),INTERVAL 2 HOUR),'3 College Rd','Delivered',2),
 (3,'Wedding buffet surplus',120,DATE_SUB(NOW(),INTERVAL 30 HOUR),'12 Station Rd','Delivered',3),
 (1,'Buns and pastries',22,DATE_SUB(NOW(),INTERVAL 50 HOUR),'4 Market Yard','Delivered',1),
 (2,'Paneer curry',35,DATE_SUB(NOW(),INTERVAL 70 HOUR),'88 Temple Lane','Delivered',2),
 (5,'Fruit crates',80,DATE_SUB(NOW(),INTERVAL 90 HOUR),'Plot 9, Shahu Naka','Delivered',3),
 (4,'Khichdi',15,DATE_SUB(NOW(),INTERVAL 100 HOUR),'3 College Rd','Delivered',1),
 (3,'Dinner rolls',12,DATE_SUB(NOW(),INTERVAL 110 HOUR),'12 Station Rd','Delivered',1);

-- View used by the NGO Live Feed
CREATE VIEW v_available_food AS
SELECT l.listing_id, d.name AS donor, l.item_name, l.quantity_kg, l.expiry_time, l.pickup_address
FROM listing l JOIN donor d ON d.donor_id = l.donor_id
WHERE l.status = 'Available' AND l.expiry_time > NOW();

DELIMITER $$

-- Triggers (these write the audit trail shown in the Admin tab)
CREATE TRIGGER trg_listing_audit AFTER INSERT ON listing FOR EACH ROW
BEGIN
  INSERT INTO audit_log(table_name,op,trigger_name,detail)
  VALUES ('listing','INSERT','trg_listing_audit',
          CONCAT('listing #',NEW.listing_id,' posted (',NEW.quantity_kg,' kg)'));
END$$

CREATE TRIGGER trg_listing_claimed AFTER UPDATE ON listing FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    INSERT INTO audit_log(table_name,op,trigger_name,detail)
    VALUES ('listing','UPDATE','trg_listing_claimed',
            CONCAT('listing #',NEW.listing_id,' status ',OLD.status,' → ',NEW.status));
  END IF;
END$$

CREATE TRIGGER trg_assign_volunteer AFTER INSERT ON delivery FOR EACH ROW
BEGIN
  INSERT INTO audit_log(table_name,op,trigger_name,detail)
  VALUES ('delivery','INSERT','trg_assign_volunteer',
          CONCAT('task #',NEW.delivery_id,' assigned to volunteer #',NEW.volunteer_id));
END$$

CREATE TRIGGER trg_delivery_status AFTER UPDATE ON delivery FOR EACH ROW
BEGIN
  IF NEW.step <> OLD.step THEN
    IF NEW.step = 'Delivered' THEN
      UPDATE listing SET status = 'Delivered' WHERE listing_id = NEW.listing_id;
      INSERT INTO audit_log(table_name,op,trigger_name,detail)
      SELECT 'delivery','UPDATE','trg_delivery_complete',
             CONCAT('listing #',NEW.listing_id,' marked Delivered; impact_log +',quantity_kg,' kg')
      FROM listing WHERE listing_id = NEW.listing_id;
    ELSE
      INSERT INTO audit_log(table_name,op,trigger_name,detail)
      VALUES ('delivery','UPDATE','trg_delivery_status',
              CONCAT('task #',NEW.delivery_id,' step ',OLD.step,' → ',NEW.step));
    END IF;
  END IF;
END$$

-- Transactional claim: row lock prevents two NGOs claiming the same listing
CREATE PROCEDURE sp_claim_listing(IN p_listing INT, IN p_ngo VARCHAR(80), OUT p_delivery INT)
BEGIN
  DECLARE v_status VARCHAR(20); DECLARE v_ngo INT; DECLARE v_vol INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT status INTO v_status FROM listing WHERE listing_id = p_listing FOR UPDATE;
  SELECT ngo_id INTO v_ngo FROM ngo WHERE name = p_ngo;
  IF v_status IS NULL OR v_status <> 'Available' THEN
    SET p_delivery = NULL; ROLLBACK;
  ELSE
    SELECT volunteer_id INTO v_vol FROM volunteer ORDER BY RAND() LIMIT 1;
    UPDATE listing SET status = 'Claimed', ngo_id = v_ngo WHERE listing_id = p_listing;
    INSERT INTO delivery(listing_id, ngo_id, volunteer_id) VALUES (p_listing, v_ngo, v_vol);
    SET p_delivery = LAST_INSERT_ID();
    COMMIT;
  END IF;
END$$

DELIMITER ;

-- Queries for your report
SELECT SUM(quantity_kg) AS total_kg_rescued FROM listing WHERE status = 'Delivered';
SELECT d.name, COUNT(*) AS listings, SUM(l.quantity_kg) AS total_kg
FROM listing l JOIN donor d ON d.donor_id = l.donor_id
WHERE l.status = 'Delivered'
GROUP BY d.name HAVING SUM(l.quantity_kg) >= 50 ORDER BY total_kg DESC;