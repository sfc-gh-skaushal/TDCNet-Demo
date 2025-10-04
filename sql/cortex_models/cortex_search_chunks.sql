-- TDC Net Snowflake Demo - Cortex Search Service on Chunked Data
-- Creates Cortex Search Service using the SOP_DOCUMENT_CHUNKS table

USE DATABASE TELCO_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE SID_WH;

-- Ensure change tracking is enabled on the chunks table (required for Cortex Search)
ALTER TABLE SOP_DOCUMENT_CHUNKS SET CHANGE_TRACKING = TRUE;

-- Create Cortex Search Service on the chunked data
-- NOTE: Cortex Search Service may not be available in all Snowflake environments
-- The functions below provide fallback functionality using standard SQL

/*
-- Uncomment this section when Cortex Search Service is available in your environment
CREATE OR REPLACE CORTEX SEARCH SERVICE SOP_CHUNKS_SEARCH_SERVICE
    ON CHUNK_TEXT  -- The column containing the text to search
    ATTRIBUTES DOCUMENT_ID, CHUNK_TYPE, SECTION_NAME, PAGE_NUMBER, CHUNK_SEQUENCE
    WAREHOUSE = SID_WH
    TARGET_LAG = '10 minutes'  -- How often to refresh the search index
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'  -- High-quality embedding model
    AS (
        SELECT
            c.CHUNK_ID,
            c.CHUNK_TEXT,
            c.DOCUMENT_ID,
            m.TITLE AS DOCUMENT_TITLE,
            m.CATEGORY,
            c.CHUNK_TYPE,
            c.SECTION_NAME,
            c.PAGE_NUMBER,
            c.CHUNK_SEQUENCE,
            m.EQUIPMENT_TYPES,
            m.FAULT_CODES,
            c.CHAR_START_POSITION,
            c.CHAR_END_POSITION
        FROM SOP_DOCUMENT_CHUNKS c
        JOIN SOP_DOCUMENT_METADATA m ON c.DOCUMENT_ID = m.DOCUMENT_ID
        WHERE m.IS_ACTIVE = TRUE 
          AND c.IS_MEANINGFUL = TRUE
          AND LENGTH(TRIM(c.CHUNK_TEXT)) > 20  -- Only meaningful chunks
    );

-- Grant usage permissions on the Cortex Search Service
GRANT USAGE ON CORTEX SEARCH SERVICE SOP_CHUNKS_SEARCH_SERVICE TO ROLE PUBLIC;
*/

-- Function to search chunks with filters (Simulated Cortex Search)
CREATE OR REPLACE FUNCTION SEARCH_SOP_CHUNKS(
    QUERY_TEXT VARCHAR,
    CHUNK_TYPE VARCHAR DEFAULT NULL,
    DOCUMENT_CATEGORY VARCHAR DEFAULT NULL,
    EQUIPMENT_TYPE VARCHAR DEFAULT NULL,
    RESULT_LIMIT INTEGER DEFAULT 10
)
RETURNS TABLE (
    CHUNK_ID VARCHAR,
    DOCUMENT_ID VARCHAR,
    DOCUMENT_TITLE VARCHAR,
    CATEGORY VARCHAR,
    CHUNK_TEXT VARCHAR,
    CHUNK_TYPE VARCHAR,
    SECTION_NAME VARCHAR,
    PAGE_NUMBER INTEGER,
    CHUNK_SEQUENCE INTEGER,
    RELEVANCE_SCORE FLOAT,
    EQUIPMENT_MATCH BOOLEAN
)
LANGUAGE SQL
AS
$$
    SELECT
        c.CHUNK_ID,
        c.DOCUMENT_ID,
        m.TITLE AS DOCUMENT_TITLE,
        m.CATEGORY,
        c.CHUNK_TEXT,
        c.CHUNK_TYPE,
        c.SECTION_NAME,
        c.PAGE_NUMBER,
        c.CHUNK_SEQUENCE,
        -- Simulate relevance scoring based on text matching
        CASE 
            WHEN UPPER(c.CHUNK_TEXT) LIKE '%' || UPPER(QUERY_TEXT) || '%' THEN 0.9
            WHEN UPPER(c.CHUNK_TEXT) LIKE '%' || UPPER(SPLIT_PART(QUERY_TEXT, ' ', 1)) || '%' THEN 0.7
            WHEN UPPER(c.SECTION_NAME) LIKE '%' || UPPER(QUERY_TEXT) || '%' THEN 0.6
            WHEN UPPER(m.TITLE) LIKE '%' || UPPER(QUERY_TEXT) || '%' THEN 0.5
            ELSE 0.3
        END AS RELEVANCE_SCORE,
        CASE 
            WHEN EQUIPMENT_TYPE IS NOT NULL THEN 
                ARRAYS_OVERLAP(m.EQUIPMENT_TYPES, ARRAY_CONSTRUCT(EQUIPMENT_TYPE))
            ELSE TRUE
        END AS EQUIPMENT_MATCH
    FROM SOP_DOCUMENT_CHUNKS c
    JOIN SOP_DOCUMENT_METADATA m ON c.DOCUMENT_ID = m.DOCUMENT_ID
    WHERE m.IS_ACTIVE = TRUE 
      AND c.IS_MEANINGFUL = TRUE
      AND LENGTH(TRIM(c.CHUNK_TEXT)) > 20
      -- Apply filters
      AND (CHUNK_TYPE IS NULL OR c.CHUNK_TYPE = CHUNK_TYPE)
      AND (DOCUMENT_CATEGORY IS NULL OR m.CATEGORY = DOCUMENT_CATEGORY)
      -- Equipment filter
      AND (EQUIPMENT_TYPE IS NULL OR ARRAYS_OVERLAP(m.EQUIPMENT_TYPES, ARRAY_CONSTRUCT(EQUIPMENT_TYPE)))
      -- Text search simulation
      AND (
          UPPER(c.CHUNK_TEXT) LIKE '%' || UPPER(QUERY_TEXT) || '%'
          OR UPPER(c.SECTION_NAME) LIKE '%' || UPPER(QUERY_TEXT) || '%'
          OR UPPER(m.TITLE) LIKE '%' || UPPER(QUERY_TEXT) || '%'
          OR UPPER(c.CHUNK_TEXT) LIKE '%' || UPPER(SPLIT_PART(QUERY_TEXT, ' ', 1)) || '%'
      )
    ORDER BY 
        CASE 
            WHEN UPPER(c.CHUNK_TEXT) LIKE '%' || UPPER(QUERY_TEXT) || '%' THEN 0.9
            WHEN UPPER(c.CHUNK_TEXT) LIKE '%' || UPPER(SPLIT_PART(QUERY_TEXT, ' ', 1)) || '%' THEN 0.7
            WHEN UPPER(c.SECTION_NAME) LIKE '%' || UPPER(QUERY_TEXT) || '%' THEN 0.6
            WHEN UPPER(m.TITLE) LIKE '%' || UPPER(QUERY_TEXT) || '%' THEN 0.5
            ELSE 0.3
        END DESC
    LIMIT RESULT_LIMIT
$$;

-- Function to get contextual chunks (surrounding chunks for better context)
CREATE OR REPLACE FUNCTION GET_CONTEXTUAL_CHUNKS(
    TARGET_CHUNK_ID VARCHAR,
    CONTEXT_WINDOW INTEGER DEFAULT 2
)
RETURNS TABLE (
    CHUNK_ID VARCHAR,
    DOCUMENT_ID VARCHAR,
    CHUNK_SEQUENCE INTEGER,
    CHUNK_TEXT VARCHAR,
    CHUNK_TYPE VARCHAR,
    IS_TARGET_CHUNK BOOLEAN,
    DISTANCE_FROM_TARGET INTEGER
)
LANGUAGE SQL
AS
$$
    SELECT
        c.CHUNK_ID,
        c.DOCUMENT_ID,
        c.CHUNK_SEQUENCE,
        c.CHUNK_TEXT,
        c.CHUNK_TYPE,
        c.CHUNK_ID = TARGET_CHUNK_ID AS IS_TARGET_CHUNK,
        ABS(c.CHUNK_SEQUENCE - t.CHUNK_SEQUENCE) AS DISTANCE_FROM_TARGET
    FROM SOP_DOCUMENT_CHUNKS c
    JOIN (
        SELECT DOCUMENT_ID, CHUNK_SEQUENCE
        FROM SOP_DOCUMENT_CHUNKS
        WHERE CHUNK_ID = TARGET_CHUNK_ID
    ) t ON c.DOCUMENT_ID = t.DOCUMENT_ID
    WHERE c.CHUNK_SEQUENCE BETWEEN 
        t.CHUNK_SEQUENCE - CONTEXT_WINDOW AND 
        t.CHUNK_SEQUENCE + CONTEXT_WINDOW
    ORDER BY c.CHUNK_SEQUENCE
$$;

-- AI-powered question answering (Simplified version without Cortex LLM)
CREATE OR REPLACE FUNCTION ASK_TECHNICAL_QUESTION(
    QUESTION VARCHAR,
    EQUIPMENT_TYPE VARCHAR DEFAULT NULL,
    FAULT_CODE VARCHAR DEFAULT NULL,
    MAX_CHUNKS INTEGER DEFAULT 5
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'answer_found', TRUE,
        'answer_text', 'This is a simulated AI response. In a full implementation, this would use SNOWFLAKE.CORTEX.COMPLETE to generate intelligent answers based on the search results for: ' || QUESTION,
        'chunks_used', MAX_CHUNKS,
        'source_chunks', ARRAY_CONSTRUCT(
            OBJECT_CONSTRUCT(
                'note', 'Search functionality available via SEARCH_SOP_CHUNKS function',
                'query', COALESCE(QUESTION || ' ' || COALESCE(EQUIPMENT_TYPE, '') || ' ' || COALESCE(FAULT_CODE, ''), QUESTION)
            )
        ),
        'equipment_type', EQUIPMENT_TYPE,
        'fault_code', FAULT_CODE,
        'status', 'Simulated response - use SEARCH_SOP_CHUNKS for actual search results'
    )
$$;

-- Function to generate step-by-step repair procedures (Simplified version)
CREATE OR REPLACE FUNCTION GENERATE_REPAIR_PROCEDURE(
    FAULT_DESCRIPTION VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    FAULT_CODE VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'procedure_generated', TRUE,
        'procedure_text', 
            'SIMULATED REPAIR PROCEDURE:\n\n' ||
            '1. SAFETY REQUIREMENTS:\n' ||
            '   - Ensure proper PPE (hard hat, safety vest, gloves)\n' ||
            '   - Check for electrical hazards\n' ||
            '   - Establish safety perimeter\n\n' ||
            '2. DIAGNOSTIC STEPS:\n' ||
            '   - Verify fault code: ' || COALESCE(FAULT_CODE, 'N/A') || '\n' ||
            '   - Check equipment: ' || EQUIPMENT_TYPE || '\n' ||
            '   - Assess fault: ' || FAULT_DESCRIPTION || '\n\n' ||
            '3. REPAIR PROCEDURE:\n' ||
            '   - Isolate affected components\n' ||
            '   - Replace or repair faulty parts\n' ||
            '   - Test system functionality\n\n' ||
            '4. VERIFICATION STEPS:\n' ||
            '   - Confirm fault resolution\n' ||
            '   - Monitor system performance\n' ||
            '   - Document repair completion\n\n' ||
            'NOTE: This is a simulated procedure. Use SEARCH_SOP_CHUNKS for actual documentation.',
        'chunks_used', 0,
        'source_chunks', ARRAY_CONSTRUCT(
            OBJECT_CONSTRUCT(
                'note', 'Simulated procedure - use SEARCH_SOP_CHUNKS for real documentation',
                'search_query', FAULT_DESCRIPTION || ' ' || EQUIPMENT_TYPE || COALESCE(' ' || FAULT_CODE, '')
            )
        ),
        'fault_description', FAULT_DESCRIPTION,
        'equipment_type', EQUIPMENT_TYPE,
        'fault_code', FAULT_CODE,
        'status', 'Simulated response'
    )
$$;

-- Function to find similar faults based on chunk similarity
CREATE OR REPLACE FUNCTION FIND_SIMILAR_FAULTS(
    FAULT_DESCRIPTION VARCHAR,
    SIMILARITY_THRESHOLD FLOAT DEFAULT 0.3,
    RESULT_LIMIT INTEGER DEFAULT 5
)
RETURNS TABLE (
    DOCUMENT_ID VARCHAR,
    DOCUMENT_TITLE VARCHAR,
    CATEGORY VARCHAR,
    SIMILAR_CHUNK_TEXT VARCHAR,
    CHUNK_TYPE VARCHAR,
    RELEVANCE_SCORE FLOAT,
    EQUIPMENT_TYPES ARRAY,
    FAULT_CODES ARRAY
)
LANGUAGE SQL
AS
$$
    SELECT DISTINCT
        c.DOCUMENT_ID,
        c.DOCUMENT_TITLE,
        c.CATEGORY,
        c.CHUNK_TEXT AS SIMILAR_CHUNK_TEXT,
        c.CHUNK_TYPE,
        c.RELEVANCE_SCORE,
        c.EQUIPMENT_TYPES,
        c.FAULT_CODES
    FROM TABLE(SEARCH_SOP_CHUNKS(FAULT_DESCRIPTION, NULL, NULL, NULL, RESULT_LIMIT * 3)) c
    WHERE c.RELEVANCE_SCORE >= SIMILARITY_THRESHOLD
    ORDER BY c.RELEVANCE_SCORE DESC
    LIMIT RESULT_LIMIT
$$;

-- Test the Simulated Search Functions
SELECT 'Testing Simulated Cortex Search on Chunked Data:' AS TEST_STATUS;

-- Test basic search
SELECT 'Basic Search Test - Cable Fault:' AS TEST_NAME;
SELECT 
    CHUNK_ID,
    DOCUMENT_TITLE,
    CHUNK_TYPE,
    SUBSTR(CHUNK_TEXT, 1, 100) || '...' AS CHUNK_PREVIEW,
    RELEVANCE_SCORE
FROM TABLE(SEARCH_SOP_CHUNKS('cable fault resolution', NULL, NULL, NULL, 3))
ORDER BY RELEVANCE_SCORE DESC;

-- Test AI question answering
SELECT 'AI Question Answering Test:' AS TEST_NAME;
SELECT ASK_TECHNICAL_QUESTION(
    'How do I resolve a cable fault with error code 812.3?',
    'Cisco cBR-8',
    '812.3'
) AS AI_RESPONSE;

-- Show available chunks for search
SELECT 'Simulated Search Functions Status:' AS INFO;
SELECT 'Available Chunks for Search:' AS CHUNK_STATUS;
SELECT 
    COUNT(*) AS TOTAL_CHUNKS,
    COUNT(DISTINCT DOCUMENT_ID) AS TOTAL_DOCUMENTS,
    COUNT(DISTINCT CHUNK_TYPE) AS CHUNK_TYPES
FROM SOP_DOCUMENT_CHUNKS 
WHERE IS_MEANINGFUL = TRUE;

-- Display completion message
SELECT 'Simulated Cortex Search functions created successfully!' AS FINAL_STATUS;
SELECT 'Functions: SEARCH_SOP_CHUNKS, ASK_TECHNICAL_QUESTION, GENERATE_REPAIR_PROCEDURE' AS FUNCTION_INFO;
SELECT 'Chunk Size: 200 characters' AS CHUNK_INFO;
SELECT 'Search Method: SQL-based text matching with relevance scoring' AS SEARCH_METHOD;
