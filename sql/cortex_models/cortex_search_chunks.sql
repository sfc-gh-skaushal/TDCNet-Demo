-- TDC Net Snowflake Demo - Cortex Search Service on Chunked Data
-- Creates Cortex Search Service using the SOP_DOCUMENT_CHUNKS table

USE DATABASE TELCO_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE SID_WH;

-- Ensure change tracking is enabled on the chunks table (required for Cortex Search)
ALTER TABLE SOP_DOCUMENT_CHUNKS SET CHANGE_TRACKING = TRUE;

-- Create Cortex Search Service on the chunked data
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

-- Function to search chunks with filters
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
        CHUNK_ID,
        DOCUMENT_ID,
        DOCUMENT_TITLE,
        CATEGORY,
        CHUNK_TEXT,
        CHUNK_TYPE,
        SECTION_NAME,
        PAGE_NUMBER,
        CHUNK_SEQUENCE,
        RELEVANCE_SCORE,
        CASE 
            WHEN EQUIPMENT_TYPE IS NOT NULL THEN 
                ARRAYS_OVERLAP(EQUIPMENT_TYPES, ARRAY_CONSTRUCT(EQUIPMENT_TYPE))
            ELSE TRUE
        END AS EQUIPMENT_MATCH
    FROM TABLE(SNOWFLAKE.CORTEX.SEARCH(
        'SOP_CHUNKS_SEARCH_SERVICE',
        CASE 
            WHEN CHUNK_TYPE IS NOT NULL OR DOCUMENT_CATEGORY IS NOT NULL THEN
                OBJECT_CONSTRUCT(
                    'query', QUERY_TEXT,
                    'filter', OBJECT_CONSTRUCT(
                        'and', ARRAY_COMPACT(ARRAY_CONSTRUCT(
                            CASE WHEN CHUNK_TYPE IS NOT NULL THEN 
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CHUNK_TYPE', CHUNK_TYPE))
                            END,
                            CASE WHEN DOCUMENT_CATEGORY IS NOT NULL THEN 
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CATEGORY', DOCUMENT_CATEGORY))
                            END
                        ))
                    ),
                    'limit', RESULT_LIMIT
                )
            ELSE
                OBJECT_CONSTRUCT(
                    'query', QUERY_TEXT,
                    'limit', RESULT_LIMIT
                )
        END
    ))
    WHERE CASE 
        WHEN EQUIPMENT_TYPE IS NOT NULL THEN 
            ARRAYS_OVERLAP(EQUIPMENT_TYPES, ARRAY_CONSTRUCT(EQUIPMENT_TYPE))
        ELSE TRUE
    END
    ORDER BY RELEVANCE_SCORE DESC
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
    WITH target_chunk AS (
        SELECT DOCUMENT_ID, CHUNK_SEQUENCE
        FROM SOP_DOCUMENT_CHUNKS
        WHERE CHUNK_ID = TARGET_CHUNK_ID
    )
    SELECT
        c.CHUNK_ID,
        c.DOCUMENT_ID,
        c.CHUNK_SEQUENCE,
        c.CHUNK_TEXT,
        c.CHUNK_TYPE,
        c.CHUNK_ID = TARGET_CHUNK_ID AS IS_TARGET_CHUNK,
        ABS(c.CHUNK_SEQUENCE - t.CHUNK_SEQUENCE) AS DISTANCE_FROM_TARGET
    FROM SOP_DOCUMENT_CHUNKS c
    JOIN target_chunk t ON c.DOCUMENT_ID = t.DOCUMENT_ID
    WHERE c.CHUNK_SEQUENCE BETWEEN 
        t.CHUNK_SEQUENCE - CONTEXT_WINDOW AND 
        t.CHUNK_SEQUENCE + CONTEXT_WINDOW
    ORDER BY c.CHUNK_SEQUENCE
$$;

-- AI-powered question answering using Cortex LLM with chunked context
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
    WITH search_query AS (
        SELECT COALESCE(QUESTION || ' ' || COALESCE(EQUIPMENT_TYPE, '') || ' ' || COALESCE(FAULT_CODE, ''), QUESTION) AS QUERY
    ),
    relevant_chunks AS (
        SELECT
            c.CHUNK_TEXT,
            c.DOCUMENT_TITLE,
            c.CHUNK_TYPE,
            c.SECTION_NAME,
            c.PAGE_NUMBER,
            c.CHUNK_SEQUENCE,
            c.RELEVANCE_SCORE
        FROM search_query sq,
        TABLE(SEARCH_SOP_CHUNKS(sq.QUERY, NULL, NULL, EQUIPMENT_TYPE, MAX_CHUNKS)) c
        WHERE c.RELEVANCE_SCORE > 0.2  -- Filter for relevant chunks
        ORDER BY c.RELEVANCE_SCORE DESC
    ),
    llm_context AS (
        SELECT
            'Based on the following technical documentation chunks, provide a comprehensive answer to the question. ' ||
            'Each chunk is 200 characters and comes from TDC Net SOP documents. ' ||
            'If the answer requires information not in the chunks, state that clearly.\n\n' ||
            'QUESTION: ' || QUESTION || '\n\n' ||
            'DOCUMENTATION CHUNKS:\n' ||
            LISTAGG(
                'Chunk ' || CHUNK_SEQUENCE || ' (' || CHUNK_TYPE || ' - ' || SECTION_NAME || ', Page ' || PAGE_NUMBER || '):\n' ||
                CHUNK_TEXT || '\n',
                '\n---\n'
            ) WITHIN GROUP (ORDER BY RELEVANCE_SCORE DESC) ||
            '\n\nANSWER:' AS PROMPT_TEXT,
            ARRAY_AGG(OBJECT_CONSTRUCT(
                'document_title', DOCUMENT_TITLE,
                'chunk_type', CHUNK_TYPE,
                'section_name', SECTION_NAME,
                'page_number', PAGE_NUMBER,
                'chunk_sequence', CHUNK_SEQUENCE,
                'relevance_score', RELEVANCE_SCORE
            )) AS SOURCE_CHUNKS,
            COUNT(*) AS CHUNKS_FOUND
        FROM relevant_chunks
    )
    SELECT OBJECT_CONSTRUCT(
        'answer_found', CASE WHEN lc.CHUNKS_FOUND > 0 THEN TRUE ELSE FALSE END,
        'answer_text', CASE 
            WHEN lc.CHUNKS_FOUND > 0 THEN 
                SNOWFLAKE.CORTEX.COMPLETE('mixtral-8x7b', lc.PROMPT_TEXT)
            ELSE 
                'No relevant information found in the technical documentation for this question.'
        END,
        'chunks_used', lc.CHUNKS_FOUND,
        'source_chunks', lc.SOURCE_CHUNKS,
        'equipment_type', EQUIPMENT_TYPE,
        'fault_code', FAULT_CODE
    )
    FROM llm_context lc
$$;

-- Function to generate step-by-step repair procedures
CREATE OR REPLACE FUNCTION GENERATE_REPAIR_PROCEDURE(
    FAULT_DESCRIPTION VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    FAULT_CODE VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH search_terms AS (
        SELECT 
            FAULT_DESCRIPTION || ' ' || EQUIPMENT_TYPE || 
            COALESCE(' ' || FAULT_CODE, '') AS SEARCH_QUERY
    ),
    procedure_chunks AS (
        SELECT
            c.CHUNK_TEXT,
            c.DOCUMENT_TITLE,
            c.CHUNK_TYPE,
            c.SECTION_NAME,
            c.PAGE_NUMBER,
            c.CHUNK_SEQUENCE,
            c.RELEVANCE_SCORE
        FROM search_terms st,
        TABLE(SEARCH_SOP_CHUNKS(st.SEARCH_QUERY, NULL, NULL, EQUIPMENT_TYPE, 15)) c
        WHERE c.RELEVANCE_SCORE > 0.15
        ORDER BY 
            CASE c.CHUNK_TYPE
                WHEN 'SAFETY' THEN 1
                WHEN 'DIAGNOSTIC' THEN 2
                WHEN 'PROCEDURE' THEN 3
                WHEN 'VERIFICATION' THEN 4
                ELSE 5
            END,
            c.RELEVANCE_SCORE DESC
    ),
    procedure_prompt AS (
        SELECT
            'Generate a comprehensive step-by-step repair procedure for the following fault:\n' ||
            'FAULT: ' || FAULT_DESCRIPTION || '\n' ||
            'EQUIPMENT: ' || EQUIPMENT_TYPE || '\n' ||
            CASE WHEN FAULT_CODE IS NOT NULL THEN 'FAULT CODE: ' || FAULT_CODE || '\n' ELSE '' END ||
            '\nBased on these 200-character documentation chunks from TDC Net SOPs, create a structured procedure with:\n' ||
            '1. Safety Requirements\n2. Diagnostic Steps\n3. Repair Procedure\n4. Verification Steps\n\n' ||
            'DOCUMENTATION CHUNKS:\n' ||
            LISTAGG(
                CHUNK_TYPE || ' - ' || SECTION_NAME || ' (Page ' || PAGE_NUMBER || '):\n' ||
                CHUNK_TEXT || '\n',
                '\n---\n'
            ) WITHIN GROUP (ORDER BY 
                CASE CHUNK_TYPE
                    WHEN 'SAFETY' THEN 1
                    WHEN 'DIAGNOSTIC' THEN 2
                    WHEN 'PROCEDURE' THEN 3
                    WHEN 'VERIFICATION' THEN 4
                    ELSE 5
                END,
                RELEVANCE_SCORE DESC
            ) ||
            '\n\nSTRUCTURED REPAIR PROCEDURE:' AS PROMPT_TEXT,
            ARRAY_AGG(OBJECT_CONSTRUCT(
                'document_title', DOCUMENT_TITLE,
                'chunk_type', CHUNK_TYPE,
                'section_name', SECTION_NAME,
                'page_number', PAGE_NUMBER,
                'relevance_score', RELEVANCE_SCORE
            )) AS SOURCE_CHUNKS,
            COUNT(*) AS CHUNKS_USED
        FROM procedure_chunks
    )
    SELECT OBJECT_CONSTRUCT(
        'procedure_generated', CASE WHEN pp.CHUNKS_USED > 0 THEN TRUE ELSE FALSE END,
        'procedure_text', CASE 
            WHEN pp.CHUNKS_USED > 0 THEN 
                SNOWFLAKE.CORTEX.COMPLETE('mixtral-8x7b', pp.PROMPT_TEXT)
            ELSE 
                'No specific repair procedure found for this fault and equipment combination.'
        END,
        'chunks_used', pp.CHUNKS_USED,
        'source_chunks', pp.SOURCE_CHUNKS,
        'fault_description', FAULT_DESCRIPTION,
        'equipment_type', EQUIPMENT_TYPE,
        'fault_code', FAULT_CODE
    )
    FROM procedure_prompt pp
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

-- Test the Cortex Search Service
SELECT 'Testing Cortex Search Service on Chunked Data:' AS TEST_STATUS;

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

-- Show service status
SELECT 'Cortex Search Service Status:' AS INFO;
SHOW CORTEX SEARCH SERVICES LIKE 'SOP_CHUNKS_SEARCH_SERVICE';

-- Display completion message
SELECT 'Cortex Search Service on chunked data created successfully!' AS FINAL_STATUS;
SELECT 'Service Name: SOP_CHUNKS_SEARCH_SERVICE' AS SERVICE_INFO;
SELECT 'Chunk Size: 200 characters' AS CHUNK_INFO;
SELECT 'Total Chunks Indexed: ' || COUNT(*) || ' chunks' AS TOTAL_CHUNKS
FROM VW_SEARCHABLE_CHUNKS;
