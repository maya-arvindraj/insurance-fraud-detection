
DELIMITER //

CREATE PROCEDURE sp_assign_investigator(IN p_claim_id INT)
BEGIN
    DECLARE v_investigator_id INT DEFAULT NULL;
    DECLARE v_claim_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT COUNT(*)
    INTO v_claim_exists
    FROM Claim
    WHERE Claim_ID = p_claim_id;

    IF v_claim_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Claim does not exist.';
    END IF;

    SELECT Investigator_ID
    INTO v_investigator_id
    FROM Investigator
    ORDER BY (
        SELECT COUNT(*)
        FROM Investigation i
        WHERE i.Investigator_ID = Investigator.Investigator_ID
          AND i.Recommendation = 'Pending'
    ) ASC, Investigator_ID ASC
    LIMIT 1
    FOR UPDATE;

    IF v_investigator_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No investigators available.';
    END IF;

    INSERT INTO Investigation (
        Claim_ID,
        Investigator_ID,
        Recommendation
    )
    VALUES (
        p_claim_id,
        v_investigator_id,
        'Pending'
    );

    UPDATE Claim
    SET Status = 'Under Investigation'
    WHERE Claim_ID = p_claim_id;

    COMMIT;
END //


CREATE PROCEDURE sp_approve_claim(IN p_claim_id INT)
BEGIN
    DECLARE v_claim_amount DECIMAL(15,2) DEFAULT NULL;
    DECLARE v_open_flags INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Claim_Amount
    INTO v_claim_amount
    FROM Claim
    WHERE Claim_ID = p_claim_id
    FOR UPDATE;

    IF v_claim_amount IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Claim does not exist or claim amount is NULL.';
    END IF;

    SELECT COUNT(*)
    INTO v_open_flags
    FROM Fraud_Flag
    WHERE Claim_ID = p_claim_id
      AND Status = 'Open';

    IF v_open_flags > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot approve claim with active fraud flags.';
    END IF;

    UPDATE Claim
    SET Status = 'Approved'
    WHERE Claim_ID = p_claim_id;

    INSERT INTO Payment (
        Claim_ID,
        Amount,
        Payment_Status
    )
    VALUES (
        p_claim_id,
        v_claim_amount,
        'Pending'
    );

    COMMIT;
END //


DELIMITER ;


CREATE OR REPLACE VIEW vw_active_investigations AS
SELECT
    c.Claim_ID,
    c.Policy_ID,
    c.Claim_Amount,
    c.Status AS Claim_Status,
    p.Coverage_Amount,
    cu.Customer_ID,
    cu.Customer_Name,
    i.Investigation_ID,
    i.Investigator_ID,
    inv.Investigator_Name,
    i.Recommendation
FROM Claim c
INNER JOIN Policy p
    ON c.Policy_ID = p.Policy_ID
INNER JOIN Customer cu
    ON p.Customer_ID = cu.Customer_ID
INNER JOIN Investigation i
    ON c.Claim_ID = i.Claim_ID
INNER JOIN Investigator inv
    ON i.Investigator_ID = inv.Investigator_ID
WHERE i.Recommendation = 'Pending';


CREATE OR REPLACE VIEW vw_high_risk_facilities AS
SELECT
    f.Facility_ID,
    f.Facility_Name,
    COUNT(DISTINCT c.Claim_ID) AS Total_Claims_Handled,
    COUNT(DISTINCT CASE
        WHEN ff.Claim_ID IS NOT NULL THEN c.Claim_ID
    END) AS Total_Claims_Flagged,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN ff.Claim_ID IS NOT NULL THEN c.Claim_ID
        END) / NULLIF(COUNT(DISTINCT c.Claim_ID), 0),
        2
    ) AS Fraud_Percentage
FROM Facility f
LEFT JOIN Claim c
    ON c.Facility_ID = f.Facility_ID
LEFT JOIN Fraud_Flag ff
    ON ff.Claim_ID = c.Claim_ID
GROUP BY
    f.Facility_ID,
    f.Facility_Name;


CREATE OR REPLACE VIEW vw_monthly_fraud_summary AS
SELECT
    DATE_FORMAT(ff.Flag_Date, '%Y-%m') AS Year_Month,
    fr.Rule_ID,
    fr.Rule_Name,
    COUNT(DISTINCT ff.Flag_ID) AS Incident_Count,
    COALESCE(SUM(c.Claim_Amount), 0.00) AS Total_Exposure_Amount
FROM Fraud_Flag ff
INNER JOIN Fraud_Rule fr
    ON ff.Rule_ID = fr.Rule_ID
INNER JOIN Claim c
    ON ff.Claim_ID = c.Claim_ID
GROUP BY
    DATE_FORMAT(ff.Flag_Date, '%Y-%m'),
    fr.Rule_ID,
    fr.Rule_Name;
