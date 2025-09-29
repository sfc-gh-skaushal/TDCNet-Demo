-- TDC Net Snowflake Demo - Load SOP Documents
-- Loads SOP documents and technical manuals for Cortex Search

USE DATABASE TDCNET_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE TDCNET_DEMO_WH;

-- Load SOP documents from JSON files
-- First, put the JSON files into the stage
-- PUT file:///path/to/SOP-*.json @SOP_DOCUMENTS_STAGE;

-- Load SOP documents from stage
-- Note: This is a template - actual loading would be done via PUT command and then COPY INTO

-- For demo purposes, we'll insert the SOP data directly
-- In production, you would load from files in the stage

INSERT INTO SOP_DOCUMENTS (
    DOCUMENT_ID,
    TITLE,
    CATEGORY,
    EQUIPMENT_TYPES,
    FAULT_CODES,
    CONTENT
) VALUES 
(
    'SOP-001',
    'Cable Fault Resolution Procedures',
    'Cable Fault',
    ARRAY_CONSTRUCT('Cisco cBR-8', 'Arris E6000'),
    ARRAY_CONSTRUCT('812.3', '813.1', '814.2'),
    'CABLE FAULT RESOLUTION - ERROR CODE 812.3

SAFETY FIRST:
1. Ensure proper PPE (hard hat, safety vest, gloves)
2. Check for electrical hazards before accessing equipment
3. Notify traffic control if working near roadways

DIAGNOSTIC STEPS:
1. Verify fault code 812.3 on Cisco cBR-8 router display
2. Check signal levels using spectrum analyzer
   - Forward path: Should be -7 to +7 dBmV
   - Return path: Should be 16 to 54 dBmV
3. Perform cable continuity test using TDR (Time Domain Reflectometer)
4. Identify fault location within 2-meter accuracy

REPAIR PROCEDURE:
1. Isolate affected cable segment
2. If underground cable:
   - Contact utility marking service (mandatory)
   - Use cable locator to trace exact path
   - Excavate carefully using hand tools near cable
3. If aerial cable:
   - Inspect for physical damage, animal interference
   - Check guy wires and support structures
4. Replace damaged cable section with approved splice kit
5. Test signal integrity before restoration
6. Document GPS coordinates of repair location

VERIFICATION:
1. Confirm error code 812.3 clears from system
2. Test downstream signal levels at customer premises
3. Verify no packet loss over 15-minute test period
4. Update network topology database

ESTIMATED TIME: 4-8 hours depending on access complexity
REQUIRED SKILLS: Cable splicing certification, TDR operation
TOOLS REQUIRED: TDR, spectrum analyzer, splice kit, excavation tools'
),
(
    'SOP-002',
    'Service Degradation Troubleshooting',
    'Major',
    ARRAY_CONSTRUCT('Nokia 7750', 'Juniper MX960'),
    ARRAY_CONSTRUCT('600.1', '700.2', '800.3'),
    'SERVICE DEGRADATION RESOLUTION - ERROR CODE 600.1

INITIAL ASSESSMENT:
1. Check system alarms on Nokia 7750 SR router
2. Review traffic patterns for last 24 hours
3. Identify affected service areas and customer count
4. Determine if issue is localized or widespread

DIAGNOSTIC PROCEDURE:
1. Access router CLI and run diagnostic commands:
   - show router interface
   - show router bgp summary
   - show router ospf neighbor
2. Check interface utilization and error counters
3. Verify routing table consistency
4. Test connectivity to upstream providers

RESOLUTION STEPS:
1. If interface errors detected:
   - Clean fiber connections
   - Replace suspect SFP modules
   - Check cable integrity
2. If routing issues identified:
   - Restart BGP sessions if necessary
   - Verify route advertisements
   - Check for configuration drift
3. If hardware issues suspected:
   - Schedule maintenance window
   - Prepare backup equipment
   - Coordinate with NOC for traffic rerouting

MONITORING:
1. Monitor interface statistics for 30 minutes
2. Verify customer service restoration
3. Check for recurring alarms
4. Update incident tracking system

ESTIMATED TIME: 2-4 hours
REQUIRED SKILLS: Router configuration, fiber optics
TOOLS REQUIRED: Optical power meter, laptop with console access'
),
(
    'SOP-003',
    'Signal Level Adjustment Procedures',
    'Minor',
    ARRAY_CONSTRUCT('Casa C100G', 'Harmonic CableOS'),
    ARRAY_CONSTRUCT('100.1', '200.2', '300.5'),
    'SIGNAL LEVEL DEVIATION - ERROR CODE 100.1

OVERVIEW:
Signal level deviations are common and usually indicate minor equipment drift
or environmental changes. These issues rarely affect customer service but
should be corrected to prevent escalation.

QUICK DIAGNOSTIC:
1. Check current signal levels on Casa C100G CMTS
2. Compare with baseline measurements from last maintenance
3. Identify if deviation is upstream or downstream
4. Check weather conditions and temperature logs

ADJUSTMENT PROCEDURE:
1. Access CMTS web interface or CLI
2. Navigate to RF configuration section
3. For downstream adjustment:
   - Modify output level in 0.5 dB increments
   - Target range: 45-50 dBmV at amplifier output
4. For upstream adjustment:
   - Adjust input attenuator settings
   - Target range: 0 to -10 dBmV at CMTS input
5. Allow 5 minutes for system stabilization
6. Verify modem registration levels

VERIFICATION:
1. Confirm error code 100.1 clears within 10 minutes
2. Check that all modems remain online
3. Verify no new alarms generated
4. Document changes in maintenance log

ESTIMATED TIME: 30 minutes to 1 hour
REQUIRED SKILLS: Basic RF knowledge, CMTS operation
TOOLS REQUIRED: Signal level meter, laptop'
);

-- Verify SOP documents load
SELECT COUNT(*) AS TOTAL_SOP_DOCUMENTS FROM SOP_DOCUMENTS;

-- Show loaded documents
SELECT 
    DOCUMENT_ID,
    TITLE,
    CATEGORY,
    ARRAY_SIZE(EQUIPMENT_TYPES) AS NUM_EQUIPMENT_TYPES,
    ARRAY_SIZE(FAULT_CODES) AS NUM_FAULT_CODES,
    LENGTH(CONTENT) AS CONTENT_LENGTH
FROM SOP_DOCUMENTS;

-- Create a search-optimized view for Cortex Search
CREATE OR REPLACE VIEW VW_SOP_SEARCH AS
SELECT 
    DOCUMENT_ID,
    TITLE,
    CATEGORY,
    EQUIPMENT_TYPES,
    FAULT_CODES,
    CONTENT,
    -- Create searchable text combining all relevant fields
    TITLE || ' ' || CATEGORY || ' ' || 
    ARRAY_TO_STRING(EQUIPMENT_TYPES, ' ') || ' ' ||
    ARRAY_TO_STRING(FAULT_CODES, ' ') || ' ' ||
    CONTENT AS SEARCHABLE_TEXT
FROM SOP_DOCUMENTS
WHERE IS_ACTIVE = TRUE;

-- Create additional technical documents for more comprehensive search results
INSERT INTO SOP_DOCUMENTS (
    DOCUMENT_ID,
    TITLE,
    CATEGORY,
    EQUIPMENT_TYPES,
    FAULT_CODES,
    CONTENT
) VALUES 
(
    'SOP-004',
    'Emergency Response Procedures',
    'Cable Fault',
    ARRAY_CONSTRUCT('All Equipment Types'),
    ARRAY_CONSTRUCT('815.5', '816.1'),
    'EMERGENCY RESPONSE - CABLE FAULTS

IMMEDIATE ACTIONS:
1. Assess safety risks to personnel and public
2. Establish safety perimeter if necessary
3. Contact emergency services if required
4. Notify network operations center immediately

CUSTOMER COMMUNICATION:
1. Activate mass notification system for affected areas
2. Provide estimated restoration time (initial estimate: 8-12 hours)
3. Set up customer service hotline for updates
4. Coordinate with public relations team for media response

RESOURCE MOBILIZATION:
1. Deploy specialist cable repair teams
2. Arrange for backup power if needed
3. Coordinate with local authorities for road closures
4. Prepare temporary service restoration options

RESTORATION PRIORITY:
1. Critical infrastructure (hospitals, emergency services)
2. Business customers with SLA commitments
3. High-density residential areas
4. Standard residential customers

DOCUMENTATION:
1. Photograph damage before and after repair
2. Document cause of failure for trend analysis
3. Record actual vs estimated restoration time
4. Conduct post-incident review within 48 hours'
),
(
    'SOP-005',
    'Preventive Maintenance Guidelines',
    'Minor',
    ARRAY_CONSTRUCT('Cisco cBR-8', 'Nokia 7750', 'Casa C100G'),
    ARRAY_CONSTRUCT('400.1', '500.3'),
    'PREVENTIVE MAINTENANCE - ROUTINE PROCEDURES

MONTHLY INSPECTIONS:
1. Visual inspection of all equipment racks
2. Check environmental conditions (temperature, humidity)
3. Verify backup power systems functionality
4. Review alarm logs for recurring issues
5. Test emergency shutdown procedures

QUARTERLY MAINTENANCE:
1. Clean fiber optic connections
2. Replace air filters in cooling systems
3. Calibrate test equipment
4. Update firmware and software patches
5. Perform cable integrity tests

ANNUAL OVERHAUL:
1. Complete equipment performance assessment
2. Replace aging components per manufacturer recommendations
3. Update network topology documentation
4. Conduct comprehensive disaster recovery test
5. Review and update maintenance procedures

PERFORMANCE MONITORING:
1. Track key performance indicators monthly
2. Identify equipment showing degradation trends
3. Schedule proactive replacements before failure
4. Maintain spare parts inventory
5. Document all maintenance activities

TOOLS AND EQUIPMENT:
- Optical time domain reflectometer (OTDR)
- Spectrum analyzer
- Power meters
- Cable fault locators
- Environmental monitoring equipment'
);

-- Display final summary
SELECT 
    'SOP Documents Loaded Successfully!' AS STATUS,
    COUNT(*) AS TOTAL_DOCUMENTS,
    SUM(LENGTH(CONTENT)) AS TOTAL_CONTENT_LENGTH
FROM SOP_DOCUMENTS;

-- Show document categories and coverage
SELECT 
    CATEGORY,
    COUNT(*) AS DOCUMENT_COUNT,
    AVG(LENGTH(CONTENT)) AS AVG_CONTENT_LENGTH
FROM SOP_DOCUMENTS
GROUP BY CATEGORY
ORDER BY DOCUMENT_COUNT DESC;
