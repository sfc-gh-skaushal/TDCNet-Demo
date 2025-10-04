-- TDC Net Snowflake Demo - PDF Pipeline Data Loading
-- Complete pipeline: PDF files → Directory table → Snowflake tables → Chunks → Cortex Search

USE DATABASE TELCO_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE SID_WH;

-- Step 1: Upload PDF files to stage (done via PUT command or Snowsight)
-- PUT file://data/sample_sop_documents/*.pdf @SOP_DOCUMENTS_STAGE;

-- Step 2: Refresh PDF files table from directory table
CALL REFRESH_PDF_FILES();

-- Step 3: Insert sample PDF file data (simulating uploaded files)
INSERT INTO SOP_PDF_FILES (
    FILE_PATH, FILE_URL, FILE_SIZE, LAST_MODIFIED, ETAG, MD5
) VALUES 
('SOP-001_Cable_Fault_Resolution_Procedures.pdf', 
 'sfc-demo-stage/sop-001.pdf', 3980, CURRENT_TIMESTAMP(), 
 'abc123def456', 'a1b2c3d4e5f6'),
('SOP-002_Service_Degradation_Troubleshooting.pdf', 
 'sfc-demo-stage/sop-002.pdf', 3861, CURRENT_TIMESTAMP(), 
 'def456ghi789', 'b2c3d4e5f6g7'),
('SOP-003_Signal_Level_Adjustment_Procedures.pdf', 
 'sfc-demo-stage/sop-003.pdf', 3755, CURRENT_TIMESTAMP(), 
 'ghi789jkl012', 'c3d4e5f6g7h8'),
('SOP-004_Emergency_Network_Response_Procedures.pdf', 
 'sfc-demo-stage/sop-004.pdf', 3666, CURRENT_TIMESTAMP(), 
 'jkl012mno345', 'd4e5f6g7h8i9'),
('SOP-005_Network_Security_Incident_Response.pdf', 
 'sfc-demo-stage/sop-005.pdf', 3522, CURRENT_TIMESTAMP(), 
 'mno345pqr678', 'e5f6g7h8i9j0')
ON CONFLICT (FILE_PATH) DO NOTHING;

-- Step 4: Insert document metadata
INSERT INTO SOP_DOCUMENT_METADATA (
    DOCUMENT_ID, FILE_PATH, TITLE, CATEGORY, EQUIPMENT_TYPES, FAULT_CODES,
    PAGE_COUNT, WORD_COUNT
) VALUES 
('SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf',
 'Cable Fault Resolution Procedures', 'Cable Fault',
 ARRAY_CONSTRUCT('Cisco cBR-8', 'Arris E6000', 'Casa C100G'),
 ARRAY_CONSTRUCT('812.3', '813.1', '814.2', '815.5', '816.1'),
 8, 1200),

('SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf',
 'Service Degradation Troubleshooting', 'Major',
 ARRAY_CONSTRUCT('Nokia 7750', 'Juniper MX960', 'Cisco ASR9000'),
 ARRAY_CONSTRUCT('600.1', '700.2', '800.3', '900.1'),
 6, 950),

('SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf',
 'Signal Level Adjustment Procedures', 'Minor',
 ARRAY_CONSTRUCT('Casa C100G', 'Harmonic CableOS', 'Cisco cBR-8'),
 ARRAY_CONSTRUCT('100.1', '200.2', '300.5', '400.1', '500.3'),
 4, 650),

('SOP-004', 'SOP-004_Emergency_Network_Response_Procedures.pdf',
 'Emergency Network Response Procedures', 'Emergency',
 ARRAY_CONSTRUCT('All Network Equipment'),
 ARRAY_CONSTRUCT('EMERGENCY', 'CRITICAL', 'OUTAGE'),
 12, 1800),

('SOP-005', 'SOP-005_Network_Security_Incident_Response.pdf',
 'Network Security Incident Response', 'Security',
 ARRAY_CONSTRUCT('Firewalls', 'Routers', 'Switches', 'Monitoring Systems'),
 ARRAY_CONSTRUCT('SEC-001', 'SEC-002', 'SEC-003'),
 10, 1400)
ON CONFLICT (DOCUMENT_ID) DO NOTHING;

-- Step 5: Create meaningful chunks with exactly 200 characters
-- Simulating PDF text extraction and chunking process

-- SOP-001 Cable Fault Resolution - Create chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, FILE_PATH, CHUNK_SEQUENCE, CHUNK_TEXT, 
    CHUNK_TYPE, SECTION_NAME, PAGE_NUMBER, CHAR_START_POSITION, CHAR_END_POSITION
) VALUES 
('SOP-001-C001', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 1,
 'CABLE FAULT RESOLUTION - ERROR CODE 812.3\n\nThis procedure covers the resolution of cable faults identified by error code 812.3 on Cisco cBR-8 and Arris E6000 equipment. Cable faults are c',
 'HEADER', 'Introduction', 1, 1, 200),

('SOP-001-C002', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 2,
 'ritical issues that can affect thousands of customers and require immediate specialist attention.\n\nSAFETY FIRST:\n1. Ensure proper PPE (hard hat, safety vest, gloves)\n2. Check for elec',
 'SAFETY', 'Safety Requirements', 2, 201, 400),

('SOP-001-C003', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 3,
 'trical hazards before accessing equipment\n3. Notify traffic control if working near roadways\n4. Contact utility marking service for underground work\n5. Establish safety perimeter around',
 'SAFETY', 'Safety Requirements', 2, 401, 600),

('SOP-001-C004', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 4,
 ' work area\n\nDIAGNOSTIC STEPS:\n1. Verify fault code 812.3 on Cisco cBR-8 router display\n2. Check signal levels using spectrum analyzer - Forward path: -7 to +7 dBmV, Return path: 16',
 'DIAGNOSTIC', 'Diagnostic Steps', 3, 601, 800),

('SOP-001-C005', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 5,
 ' to 54 dBmV\n3. Perform cable continuity test using TDR (Time Domain Reflectometer)\n4. Identify fault location within 2-meter accuracy\n5. Document GPS coordinates of fault location\n\nREP',
 'DIAGNOSTIC', 'Diagnostic Steps', 3, 801, 1000),

('SOP-001-C006', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 6,
 'AIR PROCEDURE:\n1. Isolate affected cable segment\n2. For underground cable: Use cable locator to trace exact path, excavate carefully using hand tools\n3. For aerial cable: Inspect for ph',
 'PROCEDURE', 'Repair Procedure', 4, 1001, 1200);

-- SOP-002 Service Degradation - Create chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, FILE_PATH, CHUNK_SEQUENCE, CHUNK_TEXT, 
    CHUNK_TYPE, SECTION_NAME, PAGE_NUMBER, CHAR_START_POSITION, CHAR_END_POSITION
) VALUES 
('SOP-002-C001', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 1,
 'SERVICE DEGRADATION RESOLUTION - ERROR CODE 600.1\n\nService degradation issues affect network performance and customer experience. This procedure addresses systematic troubleshooting of degr',
 'HEADER', 'Introduction', 1, 1, 200),

('SOP-002-C002', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 2,
 'adation issues on Nokia 7750 and Juniper MX960 equipment.\n\nINITIAL ASSESSMENT:\n1. Check system alarms on Nokia 7750 SR router\n2. Review traffic patterns for last 24 hours\n3. Identif',
 'DIAGNOSTIC', 'Initial Assessment', 2, 201, 400),

('SOP-002-C003', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 3,
 'y affected service areas and customer count\n4. Determine if issue is localized or widespread\n5. Check interface utilization levels\n\nDIAGNOSTIC PROCEDURE:\n1. Access router CLI and run',
 'DIAGNOSTIC', 'Problem Assessment', 2, 401, 600),

('SOP-002-C004', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 4,
 ': show router interface, show router bgp summary, show router ospf neighbor\n2. Check interface utilization and error counters\n3. Verify routing table consistency\n4. Test connectivity',
 'DIAGNOSTIC', 'Technical Diagnosis', 3, 601, 800);

-- SOP-003 Signal Level Adjustment - Create chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, FILE_PATH, CHUNK_SEQUENCE, CHUNK_TEXT, 
    CHUNK_TYPE, SECTION_NAME, PAGE_NUMBER, CHAR_START_POSITION, CHAR_END_POSITION
) VALUES 
('SOP-003-C001', 'SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf', 1,
 'SIGNAL LEVEL DEVIATION - ERROR CODE 100.1\n\nSignal level deviations are common issues that indicate equipment drift or environmental changes. These issues rarely affect customer service im',
 'HEADER', 'Introduction', 1, 1, 200),

('SOP-003-C002', 'SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf', 2,
 'mediately but should be corrected to prevent escalation.\n\nADJUSTMENT PROCEDURE:\n1. Access CMTS web interface or CLI\n2. Navigate to RF configuration section\n3. For downstream: Modify',
 'PROCEDURE', 'Signal Adjustment', 2, 201, 400),

('SOP-003-C003', 'SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf', 3,
 ' output level in 0.5 dB increments, target 45-50 dBmV\n4. For upstream: Adjust input attenuator, target 0 to -10 dBmV\n5. Allow 5 minutes for stabilization\n\nVERIFICATION:\n1. Confirm',
 'PROCEDURE', 'Signal Adjustment', 2, 401, 600);

-- SOP-004 Emergency Response - Create chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, FILE_PATH, CHUNK_SEQUENCE, CHUNK_TEXT, 
    CHUNK_TYPE, SECTION_NAME, PAGE_NUMBER, CHAR_START_POSITION, CHAR_END_POSITION
) VALUES 
('SOP-004-C001', 'SOP-004', 'SOP-004_Emergency_Network_Response_Procedures.pdf', 1,
 'EMERGENCY NETWORK RESPONSE PROCEDURES\n\nIMMEDIATE RESPONSE PROTOCOL:\n1. Assess the scope and severity of the network outage\n2. Activate the Emergency Response Team (ERT)\n3. Establish co',
 'HEADER', 'Emergency Protocol', 1, 1, 200),

('SOP-004-C002', 'SOP-004', 'SOP-004_Emergency_Network_Response_Procedures.pdf', 2,
 'mmunication with Network Operations Center (NOC)\n4. Implement emergency communication procedures\n\nSEVERITY CLASSIFICATION:\nLevel 1 - Critical: Complete network outage affecting >10,000',
 'PROCEDURE', 'Response Protocol', 1, 201, 400);

-- SOP-005 Security Incident - Create chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, FILE_PATH, CHUNK_SEQUENCE, CHUNK_TEXT, 
    CHUNK_TYPE, SECTION_NAME, PAGE_NUMBER, CHAR_START_POSITION, CHAR_END_POSITION
) VALUES 
('SOP-005-C001', 'SOP-005', 'SOP-005_Network_Security_Incident_Response.pdf', 1,
 'NETWORK SECURITY INCIDENT RESPONSE\n\nSECURITY THREAT IDENTIFICATION:\n1. Monitor security alerts and anomalies\n2. Analyze traffic patterns for suspicious activity\n3. Review access logs',
 'HEADER', 'Security Overview', 1, 1, 200),

('SOP-005-C002', 'SOP-005', 'SOP-005_Network_Security_Incident_Response.pdf', 2,
 ' for unauthorized attempts\n4. Coordinate with cybersecurity team\n\nIMMEDIATE CONTAINMENT:\n1. Isolate affected network segments\n2. Block suspicious IP addresses\n3. Disable compromised',
 'PROCEDURE', 'Containment Steps', 2, 201, 400);

-- Step 6: Verify data loading
SELECT 'PDF Pipeline Data Loading Verification:' AS STATUS;

SELECT 
    'PDF Files' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM SOP_PDF_FILES
UNION ALL
SELECT 
    'Document Metadata' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM SOP_DOCUMENT_METADATA
UNION ALL
SELECT 
    'Document Chunks (200 chars)' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM SOP_DOCUMENT_CHUNKS;

-- Show chunk statistics
SELECT 'Chunk Statistics by Type:' AS INFO;
SELECT 
    CHUNK_TYPE,
    COUNT(*) AS CHUNK_COUNT,
    AVG(LENGTH(CHUNK_TEXT)) AS AVG_CHUNK_LENGTH,
    MIN(LENGTH(CHUNK_TEXT)) AS MIN_CHUNK_LENGTH,
    MAX(LENGTH(CHUNK_TEXT)) AS MAX_CHUNK_LENGTH
FROM SOP_DOCUMENT_CHUNKS
GROUP BY CHUNK_TYPE
ORDER BY CHUNK_COUNT DESC;

-- Show searchable content summary
SELECT 'Searchable Content Summary:' AS INFO;
SELECT 
    CATEGORY,
    COUNT(*) AS CHUNK_COUNT,
    COUNT(DISTINCT DOCUMENT_ID) AS DOCUMENT_COUNT
FROM VW_SEARCHABLE_CHUNKS
GROUP BY CATEGORY
ORDER BY CHUNK_COUNT DESC;

-- Sample chunks for verification
SELECT 'Sample Chunks (200 characters each):' AS INFO;
SELECT 
    CHUNK_ID,
    DOCUMENT_ID,
    CHUNK_TYPE,
    LENGTH(CHUNK_TEXT) AS CHUNK_LENGTH,
    SUBSTR(CHUNK_TEXT, 1, 50) || '...' AS CHUNK_PREVIEW
FROM SOP_DOCUMENT_CHUNKS
LIMIT 10;

SELECT 'PDF Pipeline data loading completed successfully!' AS FINAL_STATUS;
