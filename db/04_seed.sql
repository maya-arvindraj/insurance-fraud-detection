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