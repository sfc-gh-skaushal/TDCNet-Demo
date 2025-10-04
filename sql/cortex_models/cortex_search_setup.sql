-- TDC Net Snowflake Demo - Cortex Search Setup
-- Implements AI-powered search and Q&A for SOP documents using Snowflake Cortex Search
-- Based on: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview

USE DATABASE TELCO_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE SID_WH;

-- Enable change tracking on SOP_DOCUMENTS table (required for Cortex Search)
ALTER TABLE SOP_DOCUMENTS SET CHANGE_TRACKING = TRUE;

-- Create a dedicated warehouse for Cortex Search operations
-- Snowflake recommends using a dedicated warehouse of size no larger than MEDIUM
CREATE OR REPLACE WAREHOUSE CORTEX_SEARCH_WH WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for Cortex Search operations';

-- Create Cortex Search Service for SOP Documents
-- This service will enable hybrid (vector and keyword) search over technical documentation
CREATE OR REPLACE CORTEX SEARCH SERVICE SOP_SEARCH_SERVICE
    ON CONTENT                              -- Column to search in
    ATTRIBUTES DOCUMENT_ID, TITLE, CATEGORY, EQUIPMENT_TYPES, FAULT_CODES  -- Columns to return and filter by
    WAREHOUSE = CORTEX_SEARCH_WH           -- Dedicated warehouse for search operations
    TARGET_LAG = '1 hour'                  -- Refresh frequency for search index
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'  -- High-quality embedding model
    AS (
        SELECT
            DOCUMENT_ID,
            TITLE,
            CATEGORY,
            EQUIPMENT_TYPES,
            FAULT_CODES,
            CONTENT,
            DOCUMENT_VERSION,
            IS_ACTIVE
        FROM SOP_DOCUMENTS
        WHERE IS_ACTIVE = TRUE
    );

-- Grant usage permissions for the search service
GRANT USAGE ON CORTEX SEARCH SERVICE SOP_SEARCH_SERVICE TO ROLE SYSADMIN;

-- Create wrapper function for SOP document search using Cortex Search
CREATE OR REPLACE FUNCTION SEARCH_SOP_DOCUMENTS(
    QUERY_TEXT VARCHAR,
    FILTER_CATEGORY VARCHAR DEFAULT NULL,
    LIMIT_RESULTS INTEGER DEFAULT 10
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
    WITH search_results AS (
        SELECT 
            PARSE_JSON(
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'TELCO_DEMO.NETWORK_OPS.SOP_SEARCH_SERVICE',
                    OBJECT_CONSTRUCT(
                        'query', QUERY_TEXT,
                        'columns', ARRAY_CONSTRUCT('DOCUMENT_ID', 'TITLE', 'CATEGORY', 'CONTENT'),
                        'filter', CASE 
                            WHEN FILTER_CATEGORY IS NOT NULL THEN 
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CATEGORY', FILTER_CATEGORY))
                            ELSE NULL
                        END,
                        'limit', LIMIT_RESULTS
                    )::VARCHAR
                )
            ) AS search_response
    )
    SELECT 
        result.value:DOCUMENT_ID::VARCHAR AS DOCUMENT_ID,
        result.value:TITLE::VARCHAR AS TITLE,
        result.value:CATEGORY::VARCHAR AS CATEGORY,
        result.value:score::FLOAT AS RELEVANCE_SCORE,
        SUBSTR(result.value:CONTENT::VARCHAR, 1, 500) AS CONTENT_EXCERPT
    FROM search_results,
    LATERAL FLATTEN(input => search_response:results) AS result
$$;

-- Enhanced answer extraction function using Cortex Complete
CREATE OR REPLACE FUNCTION EXTRACT_ANSWER_FROM_SOP(
    QUESTION VARCHAR,
    FAULT_CODE VARCHAR DEFAULT NULL,
    EQUIPMENT_TYPE VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH search_context AS (
        SELECT 
            LISTAGG(CONTENT_EXCERPT, '\n\n---\n\n') AS COMBINED_CONTENT,
            ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'document_id', DOCUMENT_ID,
                    'title', TITLE,
                    'relevance', RELEVANCE_SCORE
                )
            ) AS SOURCE_DOCUMENTS
        FROM TABLE(SEARCH_SOP_DOCUMENTS(
            COALESCE(FAULT_CODE, '') || ' ' || 
            COALESCE(EQUIPMENT_TYPE, '') || ' ' || 
            QUESTION,
            NULL,
            3
        ))
        WHERE RELEVANCE_SCORE > 0.3
    ),
    ai_response AS (
        SELECT 
            SNOWFLAKE.CORTEX.COMPLETE(
                'mixtral-8x7b',
                CONCAT(
                    'Based on the following technical documentation, provide a clear and concise answer to the question. ',
                    'If the information is not available in the documentation, say so.\n\n',
                    'QUESTION: ', QUESTION, '\n\n',
                    'TECHNICAL DOCUMENTATION:\n',
                    COMBINED_CONTENT,
                    '\n\nANSWER:'
                )
            ) AS AI_ANSWER,
            SOURCE_DOCUMENTS
        FROM search_context
        WHERE COMBINED_CONTENT IS NOT NULL
    )
    SELECT OBJECT_CONSTRUCT(
        'answer_found', CASE WHEN AI_ANSWER IS NOT NULL THEN TRUE ELSE FALSE END,
        'question', QUESTION,
        'answer_text', AI_ANSWER,
        'source_documents', SOURCE_DOCUMENTS,
        'search_parameters', OBJECT_CONSTRUCT(
            'fault_code', FAULT_CODE,
            'equipment_type', EQUIPMENT_TYPE
        )
    )
    FROM ai_response
$$;

-- Enhanced repair procedure generation using Cortex Search and Complete
CREATE OR REPLACE FUNCTION GENERATE_REPAIR_PROCEDURE(
    FAULT_CODE VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    FAULT_DESCRIPTION VARCHAR
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH relevant_sop AS (
        SELECT 
            DOCUMENT_ID,
            TITLE,
            CATEGORY,
            CONTENT_EXCERPT,
            RELEVANCE_SCORE
        FROM TABLE(SEARCH_SOP_DOCUMENTS(
            FAULT_CODE || ' ' || EQUIPMENT_TYPE || ' ' || FAULT_DESCRIPTION,
            NULL,
            1
        ))
        ORDER BY RELEVANCE_SCORE DESC
        LIMIT 1
    ),
    structured_procedure AS (
        SELECT 
            SNOWFLAKE.CORTEX.COMPLETE(
                'mixtral-8x7b',
                CONCAT(
                    'Based on the following SOP documentation, create a structured repair procedure for:\n',
                    'Fault Code: ', FAULT_CODE, '\n',
                    'Equipment: ', EQUIPMENT_TYPE, '\n',
                    'Description: ', FAULT_DESCRIPTION, '\n\n',
                    'SOP Documentation:\n', CONTENT_EXCERPT, '\n\n',
                    'Please provide a structured response with the following sections:\n',
                    '1. Safety Requirements (3-4 bullet points)\n',
                    '2. Diagnostic Steps (4-5 bullet points)\n',
                    '3. Repair Steps (4-6 bullet points)\n',
                    '4. Verification Steps (3-4 bullet points)\n',
                    '5. Estimated Time\n',
                    '6. Required Tools\n\n',
                    'Format as clear, actionable steps.'
                )
            ) AS STRUCTURED_PROCEDURE,
            DOCUMENT_ID,
            TITLE,
            CATEGORY,
            RELEVANCE_SCORE
        FROM relevant_sop
    )
    SELECT OBJECT_CONSTRUCT(
        'procedure_found', CASE WHEN STRUCTURED_PROCEDURE IS NOT NULL THEN TRUE ELSE FALSE END,
        'source_document', DOCUMENT_ID,
        'document_title', TITLE,
        'fault_category', CATEGORY,
        'match_confidence', RELEVANCE_SCORE,
        'fault_details', OBJECT_CONSTRUCT(
            'fault_code', FAULT_CODE,
            'equipment_type', EQUIPMENT_TYPE,
            'description', FAULT_DESCRIPTION
        ),
        'structured_procedure', STRUCTURED_PROCEDURE,
        'estimated_time_hours',
            CASE 
                WHEN CATEGORY = 'Cable Fault' THEN 6.0
                WHEN CATEGORY = 'Major' THEN 3.0
                ELSE 1.5
            END,
        'required_skills',
            CASE 
                WHEN CATEGORY = 'Cable Fault' THEN ARRAY_CONSTRUCT('Cable Splicing', 'TDR Operation', 'Excavation Safety')
                WHEN CATEGORY = 'Major' THEN ARRAY_CONSTRUCT('Router Configuration', 'Fiber Optics', 'Network Troubleshooting')
                ELSE ARRAY_CONSTRUCT('Basic RF Knowledge', 'Equipment Operation')
            END
    )
    FROM structured_procedure
$$;

-- Create enhanced view for field engineer search with Cortex Search integration
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
    
    -- Get AI-generated repair procedure using Cortex Search
    GENERATE_REPAIR_PROCEDURE(
        f.FAULT_CODE,
        f.EQUIPMENT_TYPE,
        f.FAULT_DESCRIPTION
    ) AS AI_REPAIR_PROCEDURE,
    
    -- Get related SOP documents using Cortex Search
    (
        SELECT ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'document_id', DOCUMENT_ID,
                'title', TITLE,
                'relevance_score', RELEVANCE_SCORE,
                'content_preview', SUBSTR(CONTENT_EXCERPT, 1, 200)
            )
        )
        FROM TABLE(SEARCH_SOP_DOCUMENTS(f.FAULT_CODE || ' ' || f.EQUIPMENT_TYPE, f.FAULT_CATEGORY, 5))
        WHERE RELEVANCE_SCORE > 0.2
    ) AS RELATED_DOCUMENTS

FROM VW_NETWORK_FAULTS_ENHANCED f
WHERE f.IS_RESOLVED = FALSE;

-- Create a function for natural language queries about faults and procedures
CREATE OR REPLACE FUNCTION ASK_TECHNICAL_QUESTION(
    QUESTION VARCHAR,
    CONTEXT_FAULT_ID VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH fault_context AS (
        SELECT 
            FAULT_CODE,
            EQUIPMENT_TYPE,
            FAULT_DESCRIPTION,
            FAULT_CATEGORY
        FROM VW_NETWORK_FAULTS_ENHANCED
        WHERE FAULT_ID = CONTEXT_FAULT_ID
        LIMIT 1
    ),
    enhanced_query AS (
        SELECT 
            CASE 
                WHEN CONTEXT_FAULT_ID IS NOT NULL THEN
                    QUESTION || ' ' || FAULT_CODE || ' ' || EQUIPMENT_TYPE || ' ' || FAULT_DESCRIPTION
                ELSE QUESTION
            END AS SEARCH_QUERY,
            FAULT_CATEGORY AS FILTER_CATEGORY
        FROM fault_context
        UNION ALL
        SELECT QUESTION AS SEARCH_QUERY, NULL AS FILTER_CATEGORY
        WHERE CONTEXT_FAULT_ID IS NULL
    )
    SELECT EXTRACT_ANSWER_FROM_SOP(
        SEARCH_QUERY,
        (SELECT FAULT_CODE FROM fault_context),
        (SELECT EQUIPMENT_TYPE FROM fault_context)
    )
    FROM enhanced_query
    LIMIT 1
$$;

-- Wait for the search service to be ready
-- Note: In practice, you would check the service status before proceeding
SELECT 'Waiting for Cortex Search Service to initialize...' AS STATUS;

-- Test the Cortex Search functionality
SELECT 
    'Testing Cortex Search Service' AS TEST_PHASE,
    'SOP Document Search' AS TEST_TYPE;

-- Test 1: Basic search functionality
SELECT 'Test 1: Basic Cable Fault Search' AS TEST_NAME;
SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS('cable fault 812.3 Cisco', NULL, 3));

-- Test 2: Category-filtered search
SELECT 'Test 2: Category-Filtered Search' AS TEST_NAME;
SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS('signal level adjustment', 'Minor', 2));

-- Test 3: AI-powered answer extraction
SELECT 'Test 3: AI Answer Extraction' AS TEST_NAME;
SELECT ASK_TECHNICAL_QUESTION(
    'How do I fix a cable fault with error code 812.3 on a Cisco cBR-8 router?'
) AS AI_ANSWER;

-- Test 4: Structured procedure generation
SELECT 'Test 4: AI Procedure Generation' AS TEST_NAME;
SELECT GENERATE_REPAIR_PROCEDURE(
    '812.3',
    'Cisco cBR-8',
    'Cable cut detected'
) AS AI_PROCEDURE;

-- Display service status and summary
SELECT 
    'Cortex Search Setup Complete' AS STATUS,
    COUNT(*) AS TOTAL_SOP_DOCUMENTS,
    COUNT(DISTINCT CATEGORY) AS DOCUMENT_CATEGORIES
FROM SOP_DOCUMENTS
WHERE IS_ACTIVE = TRUE;

-- Show available Cortex Search services
SHOW CORTEX SEARCH SERVICES;

-- Display service details
DESCRIBE CORTEX SEARCH SERVICE SOP_SEARCH_SERVICE;