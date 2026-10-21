CREATE DATABASE IF NOT EXISTS insurance_claim_fraud
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE insurance_claim_fraud;

-- =========================================================
-- 1. CUSTOMER
-- =========================================================
CREATE TABLE Customer (
    Customer_ID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    DOB DATE,
    Address TEXT,
    Phone VARCHAR(20),
    Email VARCHAR(100) UNIQUE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;


-- =========================================================
-- 2. POLICY
-- =========================================================
CREATE TABLE Policy (
    Policy_ID INT AUTO_INCREMENT,
    Customer_ID INT NOT NULL,
    Policy_Type VARCHAR(50) NOT NULL,
    Coverage_Amount DECIMAL(12,2) NOT NULL,
    Start_Date DATE NOT NULL,
    End_Date DATE NOT NULL,
    Premium DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_policy PRIMARY KEY (Policy_ID),

    CONSTRAINT fk_policy_customer
        FOREIGN KEY (Customer_ID)
        REFERENCES Customer (Customer_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_policy_coverage CHECK (Coverage_Amount > 0),
    CONSTRAINT chk_policy_premium CHECK (Premium >= 0),
    CONSTRAINT chk_policy_dates CHECK (End_Date >= Start_Date)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 3. CLAIM
-- =========================================================
CREATE TABLE `Claim` (
    Claim_ID INT AUTO_INCREMENT,
    Policy_ID INT NOT NULL,
    Claim_Date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Claim_Amount DECIMAL(12,2) NOT NULL,
    Claim_Type VARCHAR(50) NOT NULL,
    Status ENUM(
        'Submitted',
        'Under Review',
        'Flagged',
        'Under Investigation',
        'Approved',
        'Rejected'
    ) NOT NULL DEFAULT 'Submitted',
    Description TEXT,

    CONSTRAINT pk_claim PRIMARY KEY (Claim_ID),

    CONSTRAINT fk_claim_policy
        FOREIGN KEY (Policy_ID)
        REFERENCES Policy (Policy_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_claim_amount CHECK (Claim_Amount > 0)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 4. DOCUMENT
-- =========================================================
CREATE TABLE Document (
    Document_ID INT AUTO_INCREMENT,
    Claim_ID INT NOT NULL,
    Document_Type VARCHAR(50) NOT NULL,
    Doc_Hash VARCHAR(64) NOT NULL,
    Upload_Date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_document PRIMARY KEY (Document_ID),

    CONSTRAINT fk_document_claim
        FOREIGN KEY (Claim_ID)
        REFERENCES `Claim` (Claim_ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_document_hash_length
        CHECK (CHAR_LENGTH(Doc_Hash) = 64)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 5. FACILITY
-- =========================================================
CREATE TABLE Facility (
    Facility_ID INT AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Type ENUM('Hospital', 'Garage') NOT NULL,
    Address TEXT,
    Contact VARCHAR(20),

    CONSTRAINT pk_facility PRIMARY KEY (Facility_ID)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 6. CLAIM_FACILITY (MANY-TO-MANY)
-- =========================================================
CREATE TABLE Claim_Facility (
    Claim_ID INT NOT NULL,
    Facility_ID INT NOT NULL,

    CONSTRAINT pk_claim_facility
        PRIMARY KEY (Claim_ID, Facility_ID),

    CONSTRAINT fk_claim_facility_claim
        FOREIGN KEY (Claim_ID)
        REFERENCES `Claim` (Claim_ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_claim_facility_facility
        FOREIGN KEY (Facility_ID)
        REFERENCES Facility (Facility_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 7. INVESTIGATOR
-- =========================================================
CREATE TABLE Investigator (
    Investigator_ID INT AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    Experience_Years INT NOT NULL DEFAULT 0,

    CONSTRAINT pk_investigator PRIMARY KEY (Investigator_ID),
    CONSTRAINT uq_investigator_email UNIQUE (Email),
    CONSTRAINT chk_investigator_experience
        CHECK (Experience_Years >= 0)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 8. INVESTIGATION
-- =========================================================
CREATE TABLE Investigation (
    Investigation_ID INT AUTO_INCREMENT,
    Claim_ID INT NOT NULL,
    Investigator_ID INT NOT NULL,
    Assigned_Date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Findings TEXT,
    Recommendation ENUM('Approve', 'Reject', 'Pending')
        NOT NULL DEFAULT 'Pending',

    CONSTRAINT pk_investigation PRIMARY KEY (Investigation_ID),

    CONSTRAINT fk_investigation_claim
        FOREIGN KEY (Claim_ID)
        REFERENCES `Claim` (Claim_ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_investigation_investigator
        FOREIGN KEY (Investigator_ID)
        REFERENCES Investigator (Investigator_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 9. FRAUD_RULE
-- =========================================================
CREATE TABLE Fraud_Rule (
    Rule_ID INT AUTO_INCREMENT,
    Rule_Name VARCHAR(100) NOT NULL,
    Severity ENUM('Low', 'Medium', 'High') NOT NULL,
    Description TEXT,

    CONSTRAINT pk_fraud_rule PRIMARY KEY (Rule_ID),
    CONSTRAINT uq_fraud_rule_name UNIQUE (Rule_Name)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 10. FRAUD_FLAG
-- =========================================================
CREATE TABLE Fraud_Flag (
    Flag_ID INT AUTO_INCREMENT,
    Claim_ID INT NOT NULL,
    Rule_ID INT NOT NULL,
    Flag_Date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status ENUM('Open', 'Reviewed', 'Dismissed', 'Confirmed')
        NOT NULL DEFAULT 'Open',

    CONSTRAINT pk_fraud_flag PRIMARY KEY (Flag_ID),

    CONSTRAINT fk_fraud_flag_claim
        FOREIGN KEY (Claim_ID)
        REFERENCES `Claim` (Claim_ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_fraud_flag_rule
        FOREIGN KEY (Rule_ID)
        REFERENCES Fraud_Rule (Rule_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 11. PAYMENT
-- =========================================================
CREATE TABLE Payment (
    Payment_ID INT AUTO_INCREMENT,
    Claim_ID INT NOT NULL,
    Amount DECIMAL(12,2) NOT NULL,
    Payment_Date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Payment_Status ENUM('Pending', 'Completed', 'Failed')
        NOT NULL DEFAULT 'Pending',

    CONSTRAINT pk_payment PRIMARY KEY (Payment_ID),

    CONSTRAINT fk_payment_claim
        FOREIGN KEY (Claim_ID)
        REFERENCES `Claim` (Claim_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_payment_amount CHECK (Amount >= 0)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 12. CLAIM_STATUS_AUDIT
-- =========================================================
CREATE TABLE Claim_Status_Audit (
    Audit_ID INT AUTO_INCREMENT,
    Claim_ID INT NOT NULL,
    Old_Status VARCHAR(50) NOT NULL,
    New_Status VARCHAR(50) NOT NULL,
    Change_Timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_claim_status_audit PRIMARY KEY (Audit_ID),

    CONSTRAINT fk_claim_status_audit_claim
        FOREIGN KEY (Claim_ID)
        REFERENCES `Claim` (Claim_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_claim_audit_status_change
        CHECK (Old_Status <> New_Status)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


-- =========================================================
-- 13. EXPLICIT PERFORMANCE INDEXES
-- =========================================================

-- Required indexes
CREATE INDEX idx_claim_claim_date
    ON `Claim` (Claim_Date);

CREATE INDEX idx_claim_policy_id
    ON `Claim` (Policy_ID);

CREATE INDEX idx_policy_customer_id
    ON Policy (Customer_ID);

CREATE INDEX idx_investigation_investigator_id
    ON Investigation (Investigator_ID);

-- Additional indexes for common joins and filters
CREATE INDEX idx_claim_status_date
    ON `Claim` (Status, Claim_Date);

CREATE INDEX idx_document_claim_id
    ON Document (Claim_ID);

CREATE INDEX idx_document_doc_hash
    ON Document (Doc_Hash);

CREATE INDEX idx_claim_facility_facility_id
    ON Claim_Facility (Facility_ID);

CREATE INDEX idx_investigation_claim_id
    ON Investigation (Claim_ID);

CREATE INDEX idx_fraud_flag_claim_id
    ON Fraud_Flag (Claim_ID);

CREATE INDEX idx_fraud_flag_rule_id
    ON Fraud_Flag (Rule_ID);

CREATE INDEX idx_fraud_flag_status_date
    ON Fraud_Flag (Status, Flag_Date);

CREATE INDEX idx_payment_claim_id
    ON Payment (Claim_ID);

CREATE INDEX idx_payment_status_date
    ON Payment (Payment_Status, Payment_Date);

CREATE INDEX idx_claim_status_audit_claim_timestamp
    ON Claim_Status_Audit (Claim_ID, Change_Timestamp);
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
-- Disable foreign key checks temporarily to guarantee clean seeding execution
SET FOREIGN_KEY_CHECKS = 0;

-- -------------------------------------------------------------
-- 1. FRAUD RULES
-- -------------------------------------------------------------
INSERT INTO `Fraud_Rule` (`Rule_ID`, `Rule_Name`, `Severity`, `Description`) VALUES
(1, 'Claim Exceeds Policy Coverage', 'High', 'Claim amount is greater than the total policy coverage limit'),
(2, 'Frequent Filing in Short Window', 'Medium', 'Multiple claims submitted by same customer within 30 days'),
(3, 'Duplicate Bill Document', 'High', 'Identical bill hash uploaded across multiple distinct claims'),
(4, 'Suspicious Facility Cluster', 'Medium', 'High concentration of flagged claims tied to this facility');

-- -------------------------------------------------------------
-- 2. CUSTOMERS
-- -------------------------------------------------------------
INSERT INTO `Customer` (`Customer_ID`, `First_Name`, `Last_Name`, `Email`, `Phone_Number`, `Created_At`) VALUES
(1, 'Marcus', 'Vance', 'marcus.vance@example.com', '+1-555-019-2831', '2025-01-10 09:00:00'),
(2, 'Elena', 'Rostova', 'elena.rostova@example.com', '+1-555-014-9923', '2025-02-14 11:30:00'),
(3, 'Devon', 'Brooks', 'devon.brooks@example.com', '+1-555-017-4482', '2025-03-01 08:15:00'),
(4, 'Amina', 'Patel', 'amina.patel@example.com', '+1-555-012-7731', '2025-03-20 14:45:00'),
(5, 'Lucas', 'Gomez', 'lucas.gomez@example.com', '+1-555-018-6610', '2025-04-05 10:20:00');

-- -------------------------------------------------------------
-- 3. POLICIES
-- -------------------------------------------------------------
INSERT INTO `Policy` (`Policy_ID`, `Customer_ID`, `Policy_Type`, `Coverage_Limit`, `Start_Date`, `End_Date`, `Status`) VALUES
(101, 1, 'Auto', 15000.00, '2025-01-15', '2026-01-15', 'Active'),
(102, 2, 'Health', 50000.00, '2025-02-15', '2026-02-15', 'Active'),
(103, 3, 'Property', 25000.00, '2025-03-05', '2026-03-05', 'Active'),
(104, 4, 'Health', 30000.00, '2025-03-25', '2026-03-25', 'Active'),
(105, 5, 'Auto', 5000.00, '2025-04-10', '2026-04-10', 'Active');

-- -------------------------------------------------------------
-- 4. FACILITIES & INVESTIGATORS
-- -------------------------------------------------------------
INSERT INTO `Facility` (`Facility_ID`, `Facility_Name`, `Facility_Type`, `Address`, `Contact_Number`) VALUES
(201, 'Metropolitan General Hospital', 'Hospital', '742 Evergreen Terrace, Springfield', '+1-555-900-1111'),
(202, 'St. Jude Specialty Clinic', 'Hospital', '1204 Pine Ridge Ave, Chicago', '+1-555-900-2222'),
(203, 'Apex Collision & Repair Works', 'Auto Garage', '88 Industry Blvd, Detroit', '+1-555-900-3333');

INSERT INTO `Investigator` (`Investigator_ID`, `First_Name`, `Last_Name`, `Experience_Level`, `Email`, `Phone_Number`) VALUES
(301, 'Rachel', 'Adams', 'Senior', 'rachel.adams@frauddept.com', '+1-555-888-1001'),
(302, 'David', 'Kim', 'Mid-Level', 'david.kim@frauddept.com', '+1-555-888-1002'),
(303, 'Sofia', 'Hernandez', 'Junior', 'sofia.hernandez@frauddept.com', '+1-555-888-1003');

-- -------------------------------------------------------------
-- 5. CLAIMS
-- -------------------------------------------------------------
-- Claim 1001: Clean (Approved/Paid)
-- Claim 1002: Clean (Approved/Paid)
-- Claim 1003: Clean (Approved/Paid)
-- Claim 1004: Clean (Approved/Paid)
-- Claim 1005: Planted - Exceeds Coverage (Policy 105 limit $5,000 vs Claim $12,500)
-- Claim 1006: Planted - Customer 1, Frequent window #1 (Date: 2025-06-02) tied to Apex Garage (203)
-- Claim 1007: Planted - Customer 1, Frequent window #2 (Date: 2025-06-08, 6 days later) tied to Apex Garage (203)
-- Claim 1008: Auto Garage cluster claim (Apex Garage 203) flagged for duplicate documentation
INSERT INTO `Claim` (`Claim_ID`, `Policy_ID`, `Facility_ID`, `Claim_Amount`, `Incident_Date`, `Filing_Date`, `Claim_Status`) VALUES
(1001, 102, 201, 4200.00, '2025-05-01', '2025-05-03', 'Approved'),
(1002, 103, NULL, 1850.00, '2025-05-10', '2025-05-12', 'Approved'),
(1003, 104, 202, 7300.00, '2025-05-18', '2025-05-20', 'Approved'),
(1004, 101, 203, 3100.00, '2025-05-22', '2025-05-25', 'Approved'),
(1005, 105, 203, 12500.00, '2025-06-01', '2025-06-03', 'Flagged'),
(1006, 101, 203, 4500.00, '2025-05-30', '2025-06-02', 'Under Review'),
(1007, 101, 203, 4800.00, '2025-06-06', '2025-06-08', 'Flagged'),
(1008, 101, 203, 6200.00, '2025-06-15', '2025-06-17', 'Flagged');

-- -------------------------------------------------------------
-- 6. DOCUMENTS
-- -------------------------------------------------------------
INSERT INTO `Document` (`Document_ID`, `Claim_ID`, `Document_Type`, `File_Hash`, `Uploaded_At`) VALUES
(401, 1001, 'Medical Invoice', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', '2025-05-03 10:00:00'),
(402, 1002, 'Property Assessment', 'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0', '2025-05-12 11:20:00'),
(403, 1003, 'Hospital Discharge', 'b2c3d4e5f60123456789abcdef0123456789abcdef0123456789abcdef01234a', '2025-05-20 15:45:00'),
(404, 1004, 'Repair Invoice', 'c3d4e5f601123456789abcdef0123456789abcdef0123456789abcdef01234ab', '2025-05-25 16:10:00'),
(405, 1005, 'Repair Invoice', 'd4e5f60123223456789abcdef0123456789abcdef0123456789abcdef01234abc', '2025-06-03 09:30:00'),
(406, 1006, 'Repair Invoice', 'e5f6012345333456789abcdef0123456789abcdef0123456789abcdef01234abcd', '2025-06-02 14:00:00'),
(407, 1007, 'Repair Invoice', 'f601234567444456789abcdef0123456789abcdef0123456789abcdef01234abcde', '2025-06-08 17:05:00'),
-- Planted duplicate bill hash matching Claim 1006 to trigger duplicate document rule on Claim 1008
(408, 1008, 'Repair Invoice', 'e5f6012345333456789abcdef0123456789abcdef0123456789abcdef01234abcd', '2025-06-17 12:15:00');

-- -------------------------------------------------------------
-- 7. FRAUD AUDIT / CLAIM FLAGS
-- -------------------------------------------------------------
INSERT INTO `Claim_Fraud_Flag` (`Flag_ID`, `Claim_ID`, `Rule_ID`, `Flagged_At`) VALUES
(501, 1005, 1, '2025-06-03 09:35:00'),
(502, 1007, 2, '2025-06-08 17:10:00'),
(503, 1008, 3, '2025-06-17 12:20:00'),
(504, 1008, 4, '2025-06-17 12:20:00');

-- -------------------------------------------------------------
-- 8. ACTIVE INVESTIGATIONS
-- -------------------------------------------------------------
INSERT INTO `Investigation` (`Investigation_ID`, `Claim_ID`, `Investigator_ID`, `Status`, `Assigned_Date`, `Notes`) VALUES
(601, 1005, 301, 'Active', '2025-06-03 11:00:00', 'Claim amount of $12,500 exceeds $5,000 policy maximum. Verifying coverage riders.'),
(602, 1007, 302, 'Active', '2025-06-09 09:00:00', 'Second auto damage claim by Marcus Vance within 6 calendar days. Collision consistency check needed.'),
(603, 1008, 303, 'Active', '2025-06-17 14:00:00', 'Identical bill hash matched with Claim 1006. Inspecting facility Apex Collision for billing ring activity.');

-- -------------------------------------------------------------
-- 9. PAYMENTS (CLEAN CLAIMS ONLY)
-- -------------------------------------------------------------
INSERT INTO `Payment` (`Payment_ID`, `Claim_ID`, `Amount_Paid`, `Payment_Date`, `Payment_Method`, `Status`) VALUES
(701, 1001, 4200.00, '2025-05-06 14:00:00', 'ACH Transfer', 'Settled'),
(702, 1002, 1850.00, '2025-05-15 10:30:00', 'Direct Deposit', 'Settled'),
(703, 1003, 7300.00, '2025-05-23 16:15:00', 'ACH Transfer', 'Settled'),
(704, 1004, 3100.00, '2025-05-28 11:45:00', 'Check', 'Settled');

-- Re-enable foreign key constraints
SET FOREIGN_KEY_CHECKS = 1;