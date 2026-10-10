-- Run ONCE on your existing database, in MySQL Workbench.
-- Change the next line if your database has a different name.
USE food_rescue;

ALTER TABLE listing  ADD COLUMN category VARCHAR(30) NOT NULL DEFAULT 'Other' AFTER item_name;
ALTER TABLE listing  MODIFY status ENUM('Available','Claimed','Delivered','Cancelled') NOT NULL DEFAULT 'Available';
ALTER TABLE delivery MODIFY step   ENUM('Assigned','Picked Up','Delivered','Cancelled') NOT NULL DEFAULT 'Assigned';
ALTER TABLE ngo       ADD COLUMN contact_person VARCHAR(80), ADD COLUMN phone VARCHAR(20), ADD COLUMN address VARCHAR(120);
ALTER TABLE volunteer ADD COLUMN phone VARCHAR(20), ADD COLUMN area VARCHAR(80), ADD COLUMN vehicle VARCHAR(40);

DELIMITER $$

DROP TRIGGER IF EXISTS trg_listing_claimed$$
CREATE TRIGGER trg_listing_claimed AFTER UPDATE ON listing FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    INSERT INTO audit_log(table_name,op,trigger_name,detail)
    VALUES ('listing','UPDATE',
            IF(NEW.status = 'Cancelled','trg_listing_cancelled','trg_listing_claimed'),
            CONCAT('listing #',NEW.listing_id,' status ',OLD.status,' → ',NEW.status));
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_delivery_status$$
CREATE TRIGGER trg_delivery_status AFTER UPDATE ON delivery FOR EACH ROW
BEGIN
  IF NEW.step <> OLD.step THEN
    IF NEW.step = 'Delivered' THEN
      UPDATE listing SET status = 'Delivered' WHERE listing_id = NEW.listing_id;
      INSERT INTO audit_log(table_name,op,trigger_name,detail)
      SELECT 'delivery','UPDATE','trg_delivery_complete',
             CONCAT('listing #',NEW.listing_id,' marked Delivered; impact_log +',quantity_kg,' kg')
      FROM listing WHERE listing_id = NEW.listing_id;
    ELSEIF NEW.step = 'Cancelled' THEN
      INSERT INTO audit_log(table_name,op,trigger_name,detail)
      VALUES ('delivery','UPDATE','trg_claim_cancelled',
              CONCAT('claim cancelled for listing #',NEW.listing_id,'; released to live feed'));
    ELSE
      INSERT INTO audit_log(table_name,op,trigger_name,detail)
      VALUES ('delivery','UPDATE','trg_delivery_status',
              CONCAT('task #',NEW.delivery_id,' step ',OLD.step,' → ',NEW.step));
    END IF;
  END IF;
END$$

-- NGO cancels a claim before pickup: listing goes back to the live feed
DROP PROCEDURE IF EXISTS sp_cancel_claim$$
CREATE PROCEDURE sp_cancel_claim(IN p_listing INT, OUT p_ok TINYINT)
BEGIN
  DECLARE v_del INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT delivery_id INTO v_del FROM delivery
   WHERE listing_id = p_listing AND step = 'Assigned'
   ORDER BY delivery_id DESC LIMIT 1 FOR UPDATE;
  IF v_del IS NULL THEN
    SET p_ok = 0; ROLLBACK;
  ELSE
    UPDATE delivery SET step = 'Cancelled' WHERE delivery_id = v_del;
    UPDATE listing  SET status = 'Available', ngo_id = NULL WHERE listing_id = p_listing;
    SET p_ok = 1; COMMIT;
  END IF;
END$$

DELIMITER ;