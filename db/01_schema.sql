CREATE DATABASE IF NOT EXISTS insurance_claim_fraud
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE insurance_claim_fraud;

-- =========================================================
-- 1. CUSTOMER
-- =========================================================
CREATE TABLE Customer (
    Customer_ID INT AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    DOB DATE NOT NULL,
    Address TEXT,
    Phone VARCHAR(20),
    Email VARCHAR(100) NOT NULL,

    CONSTRAINT pk_customer PRIMARY KEY (Customer_ID),
    CONSTRAINT uq_customer_email UNIQUE (Email),
    CONSTRAINT chk_customer_dob CHECK (DOB <= CURRENT_DATE)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;


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
