DELIMITER //

CREATE TRIGGER trg_check_claim_exceeds_coverage
AFTER INSERT ON Claim
FOR EACH ROW
BEGIN
    DECLARE v_coverage_amount DECIMAL(15, 2);

    SELECT Coverage_Amount
      INTO v_coverage_amount
      FROM Policy
     WHERE Policy_ID = NEW.Policy_ID;

    IF NEW.Claim_Amount > v_coverage_amount THEN
        INSERT INTO Fraud_Flag (Claim_ID, Rule_ID, Flag_Date, Status)
        VALUES (NEW.Claim_ID, 1, NOW(), 'Open');

        UPDATE Claim
           SET Status = 'Flagged'
         WHERE Claim_ID = NEW.Claim_ID;
    END IF;
END//

CREATE TRIGGER trg_log_claim_status_change
AFTER UPDATE ON Claim
FOR EACH ROW
BEGIN
    IF NOT (OLD.Status <=> NEW.Status) THEN
        INSERT INTO Claim_Status_Audit
            (Claim_ID, Old_Status, New_Status, Change_Timestamp)
        VALUES
            (NEW.Claim_ID, OLD.Status, NEW.Status, NOW());
    END IF;
END//

CREATE TRIGGER trg_prevent_excessive_payment
BEFORE INSERT ON Payment
FOR EACH ROW
BEGIN
    DECLARE v_claim_amount DECIMAL(15, 2);

    SELECT Claim_Amount
      INTO v_claim_amount
      FROM Claim
     WHERE Claim_ID = NEW.Claim_ID;

    IF NEW.Amount > v_claim_amount THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment amount cannot exceed the corresponding claim amount.';
    END IF;
END//

DELIMITER ;
