-- TDC Net Snowflake Demo - Load PDF SOP Documents
-- Loads PDF documents into stages and processes them for Cortex Search

USE DATABASE TELCO_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE SID_WH;

-- Step 1: Upload PDF files to stage
-- Note: In practice, you would use PUT command or Snowsight to upload files
-- PUT file://data/sample_sop_documents_pdf/*.pdf @SOP_PDF_STAGE;

-- For demo purposes, we'll simulate the file upload and create sample data

-- Step 2: Refresh directory table to capture uploaded files
CALL REFRESH_SOP_DIRECTORY();

-- Step 3: Insert sample directory data (simulating uploaded PDFs)
INSERT INTO SOP_DIRECTORY (
    RELATIVE_PATH, FILE_URL, SIZE, LAST_MODIFIED, ETAG, MD5, FILE_TYPE
) VALUES 
('SOP-001_Cable_Fault_Resolution_Procedures.pdf', 
 'sfc-demo-stage/sop-001.pdf', 245760, CURRENT_TIMESTAMP(), 
 'abc123def456', 'a1b2c3d4e5f6', 'PDF'),
('SOP-002_Service_Degradation_Troubleshooting.pdf', 
 'sfc-demo-stage/sop-002.pdf', 198432, CURRENT_TIMESTAMP(), 
 'def456ghi789', 'b2c3d4e5f6g7', 'PDF'),
('SOP-003_Signal_Level_Adjustment_Procedures.pdf', 
 'sfc-demo-stage/sop-003.pdf', 156789, CURRENT_TIMESTAMP(), 
 'ghi789jkl012', 'c3d4e5f6g7h8', 'PDF'),
('SOP-004_Emergency_Network_Response_Procedures.pdf', 
 'sfc-demo-stage/sop-004.pdf', 312456, CURRENT_TIMESTAMP(), 
 'jkl012mno345', 'd4e5f6g7h8i9', 'PDF'),
('SOP-005_Network_Security_Incident_Response.pdf', 
 'sfc-demo-stage/sop-005.pdf', 278901, CURRENT_TIMESTAMP(), 
 'mno345pqr678', 'e5f6g7h8i9j0', 'PDF')
ON CONFLICT (RELATIVE_PATH) DO NOTHING;

-- Step 4: Insert document metadata
INSERT INTO SOP_DOCUMENT_METADATA (
    DOCUMENT_ID, RELATIVE_PATH, TITLE, CATEGORY, EQUIPMENT_TYPES, FAULT_CODES,
    AUTHOR, CREATION_DATE, LAST_REVIEWED, PAGE_COUNT, FILE_SIZE_BYTES, TAGS
) VALUES 
('SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf',
 'Cable Fault Resolution Procedures', 'Cable Fault',
 ARRAY_CONSTRUCT('Cisco cBR-8', 'Arris E6000', 'Casa C100G'),
 ARRAY_CONSTRUCT('812.3', '813.1', '814.2', '815.5', '816.1'),
 'TDC Net Engineering', '2024-01-15', '2024-12-01', 8, 245760,
 ARRAY_CONSTRUCT('cable', 'fault', 'repair', 'emergency', 'fiber', 'coax')),

('SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf',
 'Service Degradation Troubleshooting', 'Major',
 ARRAY_CONSTRUCT('Nokia 7750', 'Juniper MX960', 'Cisco ASR9000'),
 ARRAY_CONSTRUCT('600.1', '700.2', '800.3', '900.1'),
 'TDC Net Engineering', '2024-02-10', '2024-11-15', 6, 198432,
 ARRAY_CONSTRUCT('service', 'degradation', 'troubleshooting', 'router', 'interface')),

('SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf',
 'Signal Level Adjustment Procedures', 'Minor',
 ARRAY_CONSTRUCT('Casa C100G', 'Harmonic CableOS', 'Cisco cBR-8'),
 ARRAY_CONSTRUCT('100.1', '200.2', '300.5', '400.1', '500.3'),
 'TDC Net Engineering', '2024-03-05', '2024-10-20', 4, 156789,
 ARRAY_CONSTRUCT('signal', 'level', 'adjustment', 'calibration', 'rf')),

('SOP-004', 'SOP-004_Emergency_Network_Response_Procedures.pdf',
 'Emergency Network Response Procedures', 'Emergency',
 ARRAY_CONSTRUCT('All Network Equipment'),
 ARRAY_CONSTRUCT('EMERGENCY', 'CRITICAL', 'OUTAGE'),
 'TDC Net Operations', '2024-01-01', '2024-12-15', 12, 312456,
 ARRAY_CONSTRUCT('emergency', 'response', 'outage', 'critical', 'escalation')),

('SOP-005', 'SOP-005_Network_Security_Incident_Response.pdf',
 'Network Security Incident Response', 'Security',
 ARRAY_CONSTRUCT('Firewalls', 'Routers', 'Switches', 'Monitoring Systems'),
 ARRAY_CONSTRUCT('SEC-001', 'SEC-002', 'SEC-003'),
 'TDC Net Security', '2024-04-01', '2024-11-30', 10, 278901,
 ARRAY_CONSTRUCT('security', 'incident', 'response', 'breach', 'forensics'))
ON CONFLICT (DOCUMENT_ID) DO NOTHING;

-- Step 5: Insert sample document chunks (simulating Document AI extraction)
-- In practice, this would be done by Document AI processing the PDFs

-- SOP-001 Cable Fault Resolution Chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, RELATIVE_PATH, CHUNK_SEQUENCE, PAGE_NUMBER,
    CHUNK_TEXT, CHUNK_TITLE, CHUNK_TYPE, SECTION_NAME, WORD_COUNT, CHARACTER_COUNT, EXTRACTION_CONFIDENCE
) VALUES 
('SOP-001-C001', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 1, 1,
 'CABLE FAULT RESOLUTION - ERROR CODE 812.3\n\nThis procedure covers the resolution of cable faults identified by error code 812.3 on Cisco cBR-8 and Arris E6000 equipment. Cable faults are critical issues that can affect thousands of customers and require immediate specialist attention.',
 'Cable Fault Resolution Overview', 'HEADER', 'Introduction', 45, 280, 0.95),

('SOP-001-C002', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 2, 2,
 'SAFETY FIRST:\n1. Ensure proper PPE (hard hat, safety vest, gloves)\n2. Check for electrical hazards before accessing equipment\n3. Notify traffic control if working near roadways\n4. Contact utility marking service for underground work\n5. Establish safety perimeter around work area',
 'Safety Requirements', 'SAFETY', 'Safety Procedures', 38, 245, 0.98),

('SOP-001-C003', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 3, 3,
 'DIAGNOSTIC STEPS:\n1. Verify fault code 812.3 on Cisco cBR-8 router display\n2. Check signal levels using spectrum analyzer - Forward path: -7 to +7 dBmV, Return path: 16 to 54 dBmV\n3. Perform cable continuity test using TDR (Time Domain Reflectometer)\n4. Identify fault location within 2-meter accuracy\n5. Document GPS coordinates of fault location',
 'Diagnostic Procedures', 'DIAGNOSTIC', 'Fault Diagnosis', 52, 340, 0.92),

('SOP-001-C004', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 4, 4,
 'REPAIR PROCEDURE:\n1. Isolate affected cable segment\n2. For underground cable: Use cable locator to trace exact path, excavate carefully using hand tools\n3. For aerial cable: Inspect for physical damage, animal interference, check guy wires\n4. Replace damaged cable section with approved splice kit\n5. Test signal integrity before restoration\n6. Document repair location with GPS coordinates',
 'Repair Steps', 'PROCEDURE', 'Repair Process', 58, 380, 0.94),

('SOP-001-C005', 'SOP-001', 'SOP-001_Cable_Fault_Resolution_Procedures.pdf', 5, 5,
 'VERIFICATION:\n1. Confirm error code 812.3 clears from system\n2. Test downstream signal levels at customer premises\n3. Verify no packet loss over 15-minute test period\n4. Update network topology database\n5. Complete work order documentation\n6. Notify NOC of repair completion',
 'Verification Steps', 'VERIFICATION', 'Quality Assurance', 42, 285, 0.96);

-- SOP-002 Service Degradation Chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, RELATIVE_PATH, CHUNK_SEQUENCE, PAGE_NUMBER,
    CHUNK_TEXT, CHUNK_TITLE, CHUNK_TYPE, SECTION_NAME, WORD_COUNT, CHARACTER_COUNT, EXTRACTION_CONFIDENCE
) VALUES 
('SOP-002-C001', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 1, 1,
 'SERVICE DEGRADATION RESOLUTION - ERROR CODE 600.1\n\nService degradation issues affect network performance and customer experience. This procedure addresses systematic troubleshooting of degradation issues on Nokia 7750 and Juniper MX960 equipment.',
 'Service Degradation Overview', 'HEADER', 'Introduction', 32, 210, 0.93),

('SOP-002-C002', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 2, 2,
 'INITIAL ASSESSMENT:\n1. Check system alarms on Nokia 7750 SR router\n2. Review traffic patterns for last 24 hours\n3. Identify affected service areas and customer count\n4. Determine if issue is localized or widespread\n5. Check interface utilization levels',
 'Initial Assessment', 'DIAGNOSTIC', 'Problem Assessment', 40, 260, 0.91),

('SOP-002-C003', 'SOP-002', 'SOP-002_Service_Degradation_Troubleshooting.pdf', 3, 3,
 'DIAGNOSTIC PROCEDURE:\n1. Access router CLI and run: show router interface, show router bgp summary, show router ospf neighbor\n2. Check interface utilization and error counters\n3. Verify routing table consistency\n4. Test connectivity to upstream providers\n5. Analyze packet loss patterns',
 'Diagnostic Commands', 'DIAGNOSTIC', 'Technical Diagnosis', 48, 315, 0.89);

-- SOP-003 Signal Level Adjustment Chunks
INSERT INTO SOP_DOCUMENT_CHUNKS (
    CHUNK_ID, DOCUMENT_ID, RELATIVE_PATH, CHUNK_SEQUENCE, PAGE_NUMBER,
    CHUNK_TEXT, CHUNK_TITLE, CHUNK_TYPE, SECTION_NAME, WORD_COUNT, CHARACTER_COUNT, EXTRACTION_CONFIDENCE
) VALUES 
('SOP-003-C001', 'SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf', 1, 1,
 'SIGNAL LEVEL DEVIATION - ERROR CODE 100.1\n\nSignal level deviations are common issues that indicate equipment drift or environmental changes. These issues rarely affect customer service immediately but should be corrected to prevent escalation.',
 'Signal Level Overview', 'HEADER', 'Introduction', 35, 225, 0.94),

('SOP-003-C002', 'SOP-003', 'SOP-003_Signal_Level_Adjustment_Procedures.pdf', 2, 2,
 'ADJUSTMENT PROCEDURE:\n1. Access CMTS web interface or CLI\n2. Navigate to RF configuration section\n3. For downstream: Modify output level in 0.5 dB increments, target 45-50 dBmV\n4. For upstream: Adjust input attenuator, target 0 to -10 dBmV\n5. Allow 5 minutes for stabilization',
 'Adjustment Steps', 'PROCEDURE', 'Signal Adjustment', 44, 290, 0.92);

-- Step 6: Verify data loading
SELECT 'Data loading verification:' AS STATUS;

SELECT 
    'Directory Files' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM SOP_DIRECTORY
UNION ALL
SELECT 
    'Document Metadata' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM SOP_DOCUMENT_METADATA
UNION ALL
SELECT 
    'Document Chunks' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM SOP_DOCUMENT_CHUNKS;

-- Show sample data
SELECT 'Sample Directory Data:' AS INFO;
SELECT RELATIVE_PATH, SIZE, FILE_TYPE, DOCUMENT_STATUS FROM SOP_DIRECTORY LIMIT 5;

SELECT 'Sample Metadata:' AS INFO;
SELECT DOCUMENT_ID, TITLE, CATEGORY, PAGE_COUNT FROM SOP_DOCUMENT_METADATA LIMIT 5;

SELECT 'Sample Chunks:' AS INFO;
SELECT CHUNK_ID, DOCUMENT_ID, CHUNK_TYPE, WORD_COUNT FROM SOP_DOCUMENT_CHUNKS LIMIT 10;

-- Test search functionality
SELECT 'Testing chunk search:' AS INFO;
SELECT * FROM TABLE(SEARCH_DOCUMENT_CHUNKS('cable fault 812.3', NULL, 'Cable Fault', 3));

-- Show searchable content view
SELECT 'Searchable Content Summary:' AS INFO;
SELECT 
    CATEGORY,
    COUNT(*) AS CHUNK_COUNT,
    AVG(WORD_COUNT) AS AVG_WORDS_PER_CHUNK,
    AVG(EXTRACTION_CONFIDENCE) AS AVG_CONFIDENCE
FROM VW_SEARCHABLE_SOP_CONTENT
GROUP BY CATEGORY
ORDER BY CHUNK_COUNT DESC;

SELECT 'PDF SOP document loading completed successfully!' AS FINAL_STATUS;
