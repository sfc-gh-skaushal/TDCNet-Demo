-- TDC Net Snowflake Demo - Cortex Search Setup
-- Implements AI-powered search and Q&A for SOP documents using Cortex Search

USE DATABASE TDCNET_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE TDCNET_DEMO_WH;

-- Create a search service for SOP documents
-- Note: Cortex Search requires specific setup in Snowflake
-- This script provides the framework and functions for the demo

-- Document Search Function using Cortex AI
-- Simulates SNOWFLAKE.ML.COMPLETE for document search and summarization
CREATE OR REPLACE FUNCTION SEARCH_SOP_DOCUMENTS(
    QUERY_TEXT VARCHAR
)
RETURNS TABLE (
    DOCUMENT_ID VARCHAR,
    TITLE VARCHAR,
    CATEGORY VARCHAR,
    RELEVANCE_SCORE FLOAT,
    CONTENT_EXCERPT VARCHAR
)
LANGUAGE SQL
AS
$$
    SELECT 
        DOCUMENT_ID,
        TITLE,
        CATEGORY,
        -- Simple relevance scoring based on keyword matching
        (
            CASE WHEN UPPER(TITLE) LIKE UPPER('%' || QUERY_TEXT || '%') THEN 0.9
                 WHEN UPPER(CATEGORY) LIKE UPPER('%' || QUERY_TEXT || '%') THEN 0.8
                 WHEN UPPER(CONTENT) LIKE UPPER('%' || QUERY_TEXT || '%') THEN 0.7
                 ELSE 0.1
            END +
            -- Boost score for exact fault code matches
            CASE WHEN EXISTS (
                SELECT 1 FROM TABLE(FLATTEN(FAULT_CODES)) f 
                WHERE UPPER(f.VALUE::VARCHAR) LIKE UPPER('%' || QUERY_TEXT || '%')
            ) THEN 0.3 ELSE 0.0 END +
            -- Boost score for equipment type matches
            CASE WHEN EXISTS (
                SELECT 1 FROM TABLE(FLATTEN(EQUIPMENT_TYPES)) e 
                WHERE UPPER(e.VALUE::VARCHAR) LIKE UPPER('%' || QUERY_TEXT || '%')
            ) THEN 0.2 ELSE 0.0 END
        ) AS RELEVANCE_SCORE,
        
        -- Extract relevant content excerpt (first 500 characters containing query)
        CASE 
            WHEN UPPER(CONTENT) LIKE UPPER('%' || QUERY_TEXT || '%') THEN
                SUBSTR(CONTENT, 
                    GREATEST(1, POSITION(UPPER(QUERY_TEXT), UPPER(CONTENT)) - 100),
                    500
                )
            ELSE SUBSTR(CONTENT, 1, 500)
        END AS CONTENT_EXCERPT
        
    FROM SOP_DOCUMENTS
    WHERE IS_ACTIVE = TRUE
      AND (
          UPPER(TITLE) LIKE UPPER('%' || QUERY_TEXT || '%') OR
          UPPER(CATEGORY) LIKE UPPER('%' || QUERY_TEXT || '%') OR
          UPPER(CONTENT) LIKE UPPER('%' || QUERY_TEXT || '%') OR
          EXISTS (
              SELECT 1 FROM TABLE(FLATTEN(FAULT_CODES)) f 
              WHERE UPPER(f.VALUE::VARCHAR) LIKE UPPER('%' || QUERY_TEXT || '%')
          ) OR
          EXISTS (
              SELECT 1 FROM TABLE(FLATTEN(EQUIPMENT_TYPES)) e 
              WHERE UPPER(e.VALUE::VARCHAR) LIKE UPPER('%' || QUERY_TEXT || '%')
          )
      )
    ORDER BY RELEVANCE_SCORE DESC
    LIMIT 10
$$;

-- Answer Extraction Function
-- Simulates SNOWFLAKE.ML.EXTRACT_ANSWER for specific question answering
CREATE OR REPLACE FUNCTION EXTRACT_ANSWER_FROM_SOP(
    QUESTION VARCHAR,
    FAULT_CODE VARCHAR DEFAULT NULL,
    EQUIPMENT_TYPE VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH relevant_docs AS (
        SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS(
            COALESCE(FAULT_CODE, '') || ' ' || 
            COALESCE(EQUIPMENT_TYPE, '') || ' ' || 
            QUESTION
        ))
        WHERE RELEVANCE_SCORE > 0.5
        LIMIT 3
    ),
    best_match AS (
        SELECT 
            DOCUMENT_ID,
            TITLE,
            CATEGORY,
            CONTENT_EXCERPT,
            RELEVANCE_SCORE
        FROM relevant_docs
        ORDER BY RELEVANCE_SCORE DESC
        LIMIT 1
    )
    SELECT OBJECT_CONSTRUCT(
        'answer_found', CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END,
        'confidence_score', MAX(RELEVANCE_SCORE),
        'source_document', MAX(DOCUMENT_ID),
        'document_title', MAX(TITLE),
        'category', MAX(CATEGORY),
        'answer_text', MAX(CONTENT_EXCERPT),
        'related_documents', ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'document_id', DOCUMENT_ID,
                'title', TITLE,
                'relevance', RELEVANCE_SCORE
            )
        )
    )
    FROM best_match
$$;

-- Procedure Generation Function
-- Creates step-by-step procedures based on fault information
CREATE OR REPLACE FUNCTION GENERATE_REPAIR_PROCEDURE(
    FAULT_CODE VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    FAULT_DESCRIPTION VARCHAR
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH sop_match AS (
        SELECT 
            DOCUMENT_ID,
            TITLE,
            CATEGORY,
            CONTENT,
            -- Score based on fault code and equipment match
            (
                CASE WHEN EXISTS (
                    SELECT 1 FROM TABLE(FLATTEN(FAULT_CODES)) f 
                    WHERE f.VALUE::VARCHAR = FAULT_CODE
                ) THEN 0.8 ELSE 0.0 END +
                CASE WHEN EXISTS (
                    SELECT 1 FROM TABLE(FLATTEN(EQUIPMENT_TYPES)) e 
                    WHERE UPPER(e.VALUE::VARCHAR) LIKE UPPER('%' || EQUIPMENT_TYPE || '%')
                ) THEN 0.6 ELSE 0.0 END +
                CASE WHEN UPPER(CONTENT) LIKE UPPER('%' || FAULT_CODE || '%') THEN 0.4 ELSE 0.0 END
            ) AS MATCH_SCORE
        FROM SOP_DOCUMENTS
        WHERE IS_ACTIVE = TRUE
        ORDER BY MATCH_SCORE DESC
        LIMIT 1
    )
    SELECT OBJECT_CONSTRUCT(
        'procedure_found', CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END,
        'source_document', MAX(DOCUMENT_ID),
        'document_title', MAX(TITLE),
        'fault_category', MAX(CATEGORY),
        'match_confidence', MAX(MATCH_SCORE),
        'safety_requirements', 
            CASE WHEN MAX(CATEGORY) = 'Cable Fault' THEN
                ARRAY_CONSTRUCT(
                    'Ensure proper PPE (hard hat, safety vest, gloves)',
                    'Check for electrical hazards before accessing equipment',
                    'Notify traffic control if working near roadways'
                )
            ELSE
                ARRAY_CONSTRUCT(
                    'Follow standard safety protocols',
                    'Ensure equipment is properly grounded',
                    'Have emergency contact information available'
                )
            END,
        'diagnostic_steps',
            CASE WHEN MAX(CATEGORY) = 'Cable Fault' THEN
                ARRAY_CONSTRUCT(
                    'Verify fault code ' || FAULT_CODE || ' on ' || EQUIPMENT_TYPE || ' display',
                    'Check signal levels using spectrum analyzer',
                    'Perform cable continuity test using TDR',
                    'Identify fault location within 2-meter accuracy'
                )
            WHEN MAX(CATEGORY) = 'Major' THEN
                ARRAY_CONSTRUCT(
                    'Check system alarms on ' || EQUIPMENT_TYPE,
                    'Review traffic patterns for last 24 hours',
                    'Access router CLI and run diagnostic commands',
                    'Check interface utilization and error counters'
                )
            ELSE
                ARRAY_CONSTRUCT(
                    'Check current signal levels on ' || EQUIPMENT_TYPE,
                    'Compare with baseline measurements',
                    'Identify if deviation is upstream or downstream',
                    'Check environmental conditions'
                )
            END,
        'repair_steps',
            CASE WHEN MAX(CATEGORY) = 'Cable Fault' THEN
                ARRAY_CONSTRUCT(
                    'Isolate affected cable segment',
                    'Contact utility marking service if underground',
                    'Use appropriate tools for cable access',
                    'Replace damaged cable section with approved splice kit',
                    'Test signal integrity before restoration'
                )
            WHEN MAX(CATEGORY) = 'Major' THEN
                ARRAY_CONSTRUCT(
                    'Clean fiber connections if applicable',
                    'Replace suspect modules as needed',
                    'Restart services if configuration issues detected',
                    'Monitor interface statistics for 30 minutes'
                )
            ELSE
                ARRAY_CONSTRUCT(
                    'Access equipment web interface or CLI',
                    'Adjust signal levels in small increments',
                    'Allow system stabilization time',
                    'Verify no new alarms generated'
                )
            END,
        'verification_steps',
            ARRAY_CONSTRUCT(
                'Confirm error code ' || FAULT_CODE || ' clears from system',
                'Test signal levels at customer premises',
                'Verify no packet loss over test period',
                'Update maintenance documentation'
            ),
        'estimated_time_hours',
            CASE WHEN MAX(CATEGORY) = 'Cable Fault' THEN 6.0
                 WHEN MAX(CATEGORY) = 'Major' THEN 3.0
                 ELSE 1.5
            END,
        'required_tools',
            CASE WHEN MAX(CATEGORY) = 'Cable Fault' THEN
                ARRAY_CONSTRUCT('TDR', 'Spectrum Analyzer', 'Splice Kit', 'Excavation Tools')
            WHEN MAX(CATEGORY) = 'Major' THEN
                ARRAY_CONSTRUCT('Optical Power Meter', 'Laptop', 'Console Cable')
            ELSE
                ARRAY_CONSTRUCT('Signal Level Meter', 'Laptop')
            END,
        'full_procedure_text', MAX(CONTENT)
    )
    FROM sop_match
$$;

-- Create a comprehensive search view for the field engineer app
CREATE OR REPLACE VIEW VW_FIELD_ENGINEER_SEARCH AS
SELECT 
    f.FAULT_ID,
    f.FAULT_CODE,
    f.FAULT_DESCRIPTION,
    f.FAULT_CATEGORY,
    f.EQUIPMENT_TYPE,
    f.LOCATION,
    f.CUSTOMERS_AFFECTED,
    f.PRIORITY_SCORE,
    
    -- Get repair procedure
    GENERATE_REPAIR_PROCEDURE(
        f.FAULT_CODE,
        f.EQUIPMENT_TYPE,
        f.FAULT_DESCRIPTION
    ) AS REPAIR_PROCEDURE,
    
    -- Get related SOP documents
    (
        SELECT ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'document_id', DOCUMENT_ID,
                'title', TITLE,
                'relevance_score', RELEVANCE_SCORE
            )
        )
        FROM TABLE(SEARCH_SOP_DOCUMENTS(f.FAULT_CODE || ' ' || f.EQUIPMENT_TYPE))
        WHERE RELEVANCE_SCORE > 0.3
    ) AS RELATED_DOCUMENTS

FROM NETWORK_FAULTS f
WHERE f.IS_RESOLVED = FALSE;

-- Test the search functionality
SELECT 
    'Testing Cortex Search Functions' AS TEST_PHASE,
    'Cable Fault Search' AS TEST_TYPE;

-- Test cable fault search
SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS('812.3 cable fault Cisco'));

-- Test answer extraction
SELECT EXTRACT_ANSWER_FROM_SOP(
    'How to fix a cable fault with error code 812.3?',
    '812.3',
    'Cisco cBR-8'
) AS ANSWER_RESULT;

-- Test procedure generation
SELECT GENERATE_REPAIR_PROCEDURE(
    '812.3',
    'Cisco cBR-8',
    'Cable cut detected'
) AS PROCEDURE_RESULT;

-- Show search capabilities summary
SELECT 
    'Cortex Search Setup Complete' AS STATUS,
    COUNT(*) AS TOTAL_SOP_DOCUMENTS,
    COUNT(DISTINCT CATEGORY) AS DOCUMENT_CATEGORIES
FROM SOP_DOCUMENTS
WHERE IS_ACTIVE = TRUE;
