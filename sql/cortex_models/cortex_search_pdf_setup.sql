-- TDC Net Snowflake Demo - Cortex Search Setup for PDF Documents
-- Implements AI-powered search on PDF document chunks using Snowflake Cortex Search

USE DATABASE TELCO_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE SID_WH;

-- Create dedicated warehouse for Cortex Search operations on PDF content
CREATE OR REPLACE WAREHOUSE CORTEX_PDF_SEARCH_WH WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for PDF-based Cortex Search operations';

-- Create Cortex Search Service for PDF document chunks
-- This service enables hybrid search over extracted PDF content
CREATE OR REPLACE CORTEX SEARCH SERVICE PDF_SOP_SEARCH_SERVICE
    ON CHUNK_TEXT                          -- Primary search column (extracted PDF text)
    ATTRIBUTES CHUNK_ID, DOCUMENT_ID, DOCUMENT_TITLE, CATEGORY, CHUNK_TYPE, 
               SECTION_NAME, PAGE_NUMBER, EQUIPMENT_TYPES, FAULT_CODES, TAGS
    WAREHOUSE = CORTEX_PDF_SEARCH_WH       -- Dedicated warehouse
    TARGET_LAG = '30 minutes'              -- Faster refresh for PDF updates
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'  -- High-quality embeddings
    AS (
        SELECT
            CHUNK_ID,
            DOCUMENT_ID,
            DOCUMENT_TITLE,
            CATEGORY,
            EQUIPMENT_TYPES,
            FAULT_CODES,
            CHUNK_TEXT,
            CHUNK_TITLE,
            CHUNK_TYPE,
            SECTION_NAME,
            PAGE_NUMBER,
            WORD_COUNT,
            EXTRACTION_CONFIDENCE,
            TAGS
        FROM VW_SEARCHABLE_SOP_CONTENT
        WHERE EXTRACTION_CONFIDENCE > 0.8  -- Only high-confidence extractions
    );

-- Grant usage permissions for the PDF search service
GRANT USAGE ON CORTEX SEARCH SERVICE PDF_SOP_SEARCH_SERVICE TO ROLE SYSADMIN;

-- Enhanced search function for PDF chunks with semantic capabilities
CREATE OR REPLACE FUNCTION SEARCH_PDF_SOP_CHUNKS(
    QUERY_TEXT VARCHAR,
    CHUNK_TYPE_FILTER VARCHAR DEFAULT NULL,
    CATEGORY_FILTER VARCHAR DEFAULT NULL,
    DOCUMENT_ID_FILTER VARCHAR DEFAULT NULL,
    LIMIT_RESULTS INTEGER DEFAULT 10
)
RETURNS TABLE (
    CHUNK_ID VARCHAR,
    DOCUMENT_ID VARCHAR,
    DOCUMENT_TITLE VARCHAR,
    CHUNK_TEXT VARCHAR,
    CHUNK_TYPE VARCHAR,
    SECTION_NAME VARCHAR,
    PAGE_NUMBER INTEGER,
    RELEVANCE_SCORE FLOAT,
    EXTRACTION_CONFIDENCE FLOAT
)
LANGUAGE SQL
AS
$$
    WITH search_results AS (
        SELECT 
            PARSE_JSON(
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'TELCO_DEMO.NETWORK_OPS.PDF_SOP_SEARCH_SERVICE',
                    OBJECT_CONSTRUCT(
                        'query', QUERY_TEXT,
                        'columns', ARRAY_CONSTRUCT(
                            'CHUNK_ID', 'DOCUMENT_ID', 'DOCUMENT_TITLE', 'CHUNK_TEXT',
                            'CHUNK_TYPE', 'SECTION_NAME', 'PAGE_NUMBER', 'EXTRACTION_CONFIDENCE'
                        ),
                        'filter', CASE 
                            WHEN CHUNK_TYPE_FILTER IS NOT NULL AND CATEGORY_FILTER IS NOT NULL THEN
                                OBJECT_CONSTRUCT(
                                    '@and', ARRAY_CONSTRUCT(
                                        OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CHUNK_TYPE', CHUNK_TYPE_FILTER)),
                                        OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CATEGORY', CATEGORY_FILTER))
                                    )
                                )
                            WHEN CHUNK_TYPE_FILTER IS NOT NULL THEN
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CHUNK_TYPE', CHUNK_TYPE_FILTER))
                            WHEN CATEGORY_FILTER IS NOT NULL THEN
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('CATEGORY', CATEGORY_FILTER))
                            WHEN DOCUMENT_ID_FILTER IS NOT NULL THEN
                                OBJECT_CONSTRUCT('@eq', OBJECT_CONSTRUCT('DOCUMENT_ID', DOCUMENT_ID_FILTER))
                            ELSE NULL
                        END,
                        'limit', LIMIT_RESULTS
                    )::VARCHAR
                )
            ) AS search_response
    )
    SELECT 
        result.value:CHUNK_ID::VARCHAR AS CHUNK_ID,
        result.value:DOCUMENT_ID::VARCHAR AS DOCUMENT_ID,
        result.value:DOCUMENT_TITLE::VARCHAR AS DOCUMENT_TITLE,
        result.value:CHUNK_TEXT::VARCHAR AS CHUNK_TEXT,
        result.value:CHUNK_TYPE::VARCHAR AS CHUNK_TYPE,
        result.value:SECTION_NAME::VARCHAR AS SECTION_NAME,
        result.value:PAGE_NUMBER::INTEGER AS PAGE_NUMBER,
        result.value:score::FLOAT AS RELEVANCE_SCORE,
        result.value:EXTRACTION_CONFIDENCE::FLOAT AS EXTRACTION_CONFIDENCE
    FROM search_results,
    LATERAL FLATTEN(input => search_response:results) AS result
$$;

-- AI-powered answer extraction from PDF chunks
CREATE OR REPLACE FUNCTION EXTRACT_ANSWER_FROM_PDF_SOPS(
    QUESTION VARCHAR,
    FAULT_CODE VARCHAR DEFAULT NULL,
    EQUIPMENT_TYPE VARCHAR DEFAULT NULL,
    PREFERRED_CHUNK_TYPE VARCHAR DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH relevant_chunks AS (
        SELECT 
            CHUNK_TEXT,
            DOCUMENT_TITLE,
            CHUNK_TYPE,
            SECTION_NAME,
            PAGE_NUMBER,
            RELEVANCE_SCORE,
            EXTRACTION_CONFIDENCE
        FROM TABLE(SEARCH_PDF_SOP_CHUNKS(
            COALESCE(FAULT_CODE, '') || ' ' || 
            COALESCE(EQUIPMENT_TYPE, '') || ' ' || 
            QUESTION,
            PREFERRED_CHUNK_TYPE,
            NULL,
            NULL,
            5
        ))
        WHERE RELEVANCE_SCORE > 0.4
        ORDER BY RELEVANCE_SCORE DESC
    ),
    context_assembly AS (
        SELECT 
            LISTAGG(
                'Document: ' || DOCUMENT_TITLE || 
                ' (Page ' || PAGE_NUMBER || ', Section: ' || SECTION_NAME || ')\n' ||
                CHUNK_TEXT, 
                '\n\n---\n\n'
            ) AS COMBINED_CONTEXT,
            ARRAY_AGG(
                OBJECT_CONSTRUCT(
                    'document_title', DOCUMENT_TITLE,
                    'chunk_type', CHUNK_TYPE,
                    'section_name', SECTION_NAME,
                    'page_number', PAGE_NUMBER,
                    'relevance_score', RELEVANCE_SCORE,
                    'confidence', EXTRACTION_CONFIDENCE
                )
            ) AS SOURCE_CHUNKS,
            AVG(RELEVANCE_SCORE) AS AVG_RELEVANCE,
            AVG(EXTRACTION_CONFIDENCE) AS AVG_CONFIDENCE
        FROM relevant_chunks
    ),
    ai_response AS (
        SELECT 
            SNOWFLAKE.CORTEX.COMPLETE(
                'mixtral-8x7b',
                CONCAT(
                    'You are a technical support expert for TDC Net telecommunications. ',
                    'Based on the following technical documentation excerpts, provide a clear, ',
                    'step-by-step answer to the technician''s question. Include safety considerations ',
                    'when relevant. If the information is incomplete, mention what additional ',
                    'information might be needed.\n\n',
                    'QUESTION: ', QUESTION, '\n\n',
                    'TECHNICAL DOCUMENTATION:\n',
                    COMBINED_CONTEXT,
                    '\n\nPROVIDE A STRUCTURED ANSWER:'
                )
            ) AS AI_ANSWER,
            SOURCE_CHUNKS,
            AVG_RELEVANCE,
            AVG_CONFIDENCE
        FROM context_assembly
        WHERE COMBINED_CONTEXT IS NOT NULL
    )
    SELECT OBJECT_CONSTRUCT(
        'answer_found', CASE WHEN AI_ANSWER IS NOT NULL THEN TRUE ELSE FALSE END,
        'question', QUESTION,
        'answer_text', AI_ANSWER,
        'source_chunks', SOURCE_CHUNKS,
        'search_quality', OBJECT_CONSTRUCT(
            'avg_relevance_score', AVG_RELEVANCE,
            'avg_extraction_confidence', AVG_CONFIDENCE,
            'total_sources', ARRAY_SIZE(SOURCE_CHUNKS)
        ),
        'search_parameters', OBJECT_CONSTRUCT(
            'fault_code', FAULT_CODE,
            'equipment_type', EQUIPMENT_TYPE,
            'preferred_chunk_type', PREFERRED_CHUNK_TYPE
        )
    )
    FROM ai_response
$$;

-- Generate comprehensive repair procedures from PDF chunks
CREATE OR REPLACE FUNCTION GENERATE_PDF_REPAIR_PROCEDURE(
    FAULT_CODE VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    FAULT_DESCRIPTION VARCHAR
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    WITH procedure_chunks AS (
        -- Get safety chunks
        SELECT 'SAFETY' AS CHUNK_CATEGORY, CHUNK_TEXT, RELEVANCE_SCORE, PAGE_NUMBER, DOCUMENT_TITLE
        FROM TABLE(SEARCH_PDF_SOP_CHUNKS(
            FAULT_CODE || ' ' || EQUIPMENT_TYPE || ' safety',
            'SAFETY', NULL, NULL, 3
        ))
        UNION ALL
        -- Get diagnostic chunks
        SELECT 'DIAGNOSTIC' AS CHUNK_CATEGORY, CHUNK_TEXT, RELEVANCE_SCORE, PAGE_NUMBER, DOCUMENT_TITLE
        FROM TABLE(SEARCH_PDF_SOP_CHUNKS(
            FAULT_CODE || ' ' || EQUIPMENT_TYPE || ' diagnostic',
            'DIAGNOSTIC', NULL, NULL, 3
        ))
        UNION ALL
        -- Get procedure chunks
        SELECT 'PROCEDURE' AS CHUNK_CATEGORY, CHUNK_TEXT, RELEVANCE_SCORE, PAGE_NUMBER, DOCUMENT_TITLE
        FROM TABLE(SEARCH_PDF_SOP_CHUNKS(
            FAULT_CODE || ' ' || EQUIPMENT_TYPE || ' repair',
            'PROCEDURE', NULL, NULL, 3
        ))
        UNION ALL
        -- Get verification chunks
        SELECT 'VERIFICATION' AS CHUNK_CATEGORY, CHUNK_TEXT, RELEVANCE_SCORE, PAGE_NUMBER, DOCUMENT_TITLE
        FROM TABLE(SEARCH_PDF_SOP_CHUNKS(
            FAULT_CODE || ' ' || EQUIPMENT_TYPE || ' verification',
            'VERIFICATION', NULL, NULL, 3
        ))
    ),
    categorized_content AS (
        SELECT 
            CHUNK_CATEGORY,
            LISTAGG(CHUNK_TEXT, '\n\n') AS COMBINED_TEXT,
            AVG(RELEVANCE_SCORE) AS AVG_RELEVANCE,
            ARRAY_AGG(DISTINCT DOCUMENT_TITLE) AS SOURCE_DOCUMENTS
        FROM procedure_chunks
        WHERE RELEVANCE_SCORE > 0.3
        GROUP BY CHUNK_CATEGORY
    ),
    structured_procedure AS (
        SELECT 
            SNOWFLAKE.CORTEX.COMPLETE(
                'mixtral-8x7b',
                CONCAT(
                    'Create a comprehensive repair procedure for TDC Net technicians:\n',
                    'Fault Code: ', FAULT_CODE, '\n',
                    'Equipment: ', EQUIPMENT_TYPE, '\n',
                    'Issue: ', FAULT_DESCRIPTION, '\n\n',
                    'Based on the following technical documentation, create a structured procedure:\n\n',
                    (SELECT COMBINED_TEXT FROM categorized_content WHERE CHUNK_CATEGORY = 'SAFETY'),
                    '\n\n',
                    (SELECT COMBINED_TEXT FROM categorized_content WHERE CHUNK_CATEGORY = 'DIAGNOSTIC'),
                    '\n\n',
                    (SELECT COMBINED_TEXT FROM categorized_content WHERE CHUNK_CATEGORY = 'PROCEDURE'),
                    '\n\n',
                    (SELECT COMBINED_TEXT FROM categorized_content WHERE CHUNK_CATEGORY = 'VERIFICATION'),
                    '\n\nFormat as:\n',
                    '1. SAFETY REQUIREMENTS (bullet points)\n',
                    '2. DIAGNOSTIC STEPS (numbered steps)\n',
                    '3. REPAIR PROCEDURE (numbered steps)\n',
                    '4. VERIFICATION STEPS (numbered steps)\n',
                    '5. ESTIMATED TIME AND TOOLS NEEDED'
                )
            ) AS STRUCTURED_PROCEDURE,
            OBJECT_CONSTRUCT(
                'safety_sources', (SELECT SOURCE_DOCUMENTS FROM categorized_content WHERE CHUNK_CATEGORY = 'SAFETY'),
                'diagnostic_sources', (SELECT SOURCE_DOCUMENTS FROM categorized_content WHERE CHUNK_CATEGORY = 'DIAGNOSTIC'),
                'procedure_sources', (SELECT SOURCE_DOCUMENTS FROM categorized_content WHERE CHUNK_CATEGORY = 'PROCEDURE'),
                'verification_sources', (SELECT SOURCE_DOCUMENTS FROM categorized_content WHERE CHUNK_CATEGORY = 'VERIFICATION')
            ) AS SOURCE_MAPPING,
            (SELECT AVG(AVG_RELEVANCE) FROM categorized_content) AS OVERALL_RELEVANCE
    )
    SELECT OBJECT_CONSTRUCT(
        'procedure_found', CASE WHEN STRUCTURED_PROCEDURE IS NOT NULL THEN TRUE ELSE FALSE END,
        'fault_details', OBJECT_CONSTRUCT(
            'fault_code', FAULT_CODE,
            'equipment_type', EQUIPMENT_TYPE,
            'description', FAULT_DESCRIPTION
        ),
        'structured_procedure', STRUCTURED_PROCEDURE,
        'source_documents', SOURCE_MAPPING,
        'procedure_quality', OBJECT_CONSTRUCT(
            'overall_relevance', OVERALL_RELEVANCE,
            'source_coverage', CASE 
                WHEN (SELECT COUNT(*) FROM categorized_content) >= 3 THEN 'COMPREHENSIVE'
                WHEN (SELECT COUNT(*) FROM categorized_content) >= 2 THEN 'PARTIAL'
                ELSE 'LIMITED'
            END
        ),
        'estimated_completion_time', 
            CASE 
                WHEN FAULT_CODE LIKE '81%' THEN '4-8 hours'
                WHEN FAULT_CODE LIKE '6%' OR FAULT_CODE LIKE '7%' THEN '2-4 hours'
                ELSE '30 minutes - 2 hours'
            END
    )
    FROM structured_procedure
$$;

-- Create enhanced view for field engineer PDF-based search
CREATE OR REPLACE VIEW VW_PDF_FIELD_ENGINEER_SEARCH AS
SELECT 
    f.FAULT_ID,
    f.FAULT_CODE,
    f.FAULT_DESCRIPTION,
    f.FAULT_CATEGORY,
    f.EQUIPMENT_TYPE,
    f.LOCATION,
    f.CUSTOMERS_AFFECTED,
    f.PRIORITY_SCORE,
    
    -- Get AI-generated repair procedure from PDF chunks
    GENERATE_PDF_REPAIR_PROCEDURE(
        f.FAULT_CODE,
        f.EQUIPMENT_TYPE,
        f.FAULT_DESCRIPTION
    ) AS PDF_REPAIR_PROCEDURE,
    
    -- Get related PDF chunks
    (
        SELECT ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'chunk_id', CHUNK_ID,
                'document_title', DOCUMENT_TITLE,
                'chunk_type', CHUNK_TYPE,
                'section_name', SECTION_NAME,
                'page_number', PAGE_NUMBER,
                'relevance_score', RELEVANCE_SCORE,
                'text_preview', SUBSTR(CHUNK_TEXT, 1, 200)
            )
        )
        FROM TABLE(SEARCH_PDF_SOP_CHUNKS(
            f.FAULT_CODE || ' ' || f.EQUIPMENT_TYPE, 
            NULL, f.FAULT_CATEGORY, NULL, 8
        ))
        WHERE RELEVANCE_SCORE > 0.3
    ) AS RELATED_PDF_CHUNKS

FROM VW_NETWORK_FAULTS_ENHANCED f
WHERE f.IS_RESOLVED = FALSE;

-- Function for natural language queries about PDF-based procedures
CREATE OR REPLACE FUNCTION ASK_PDF_TECHNICAL_QUESTION(
    QUESTION VARCHAR,
    CONTEXT_FAULT_ID VARCHAR DEFAULT NULL,
    FOCUS_CHUNK_TYPE VARCHAR DEFAULT NULL
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
                    QUESTION || ' ' || FAULT_CODE || ' ' || EQUIPMENT_TYPE
                ELSE QUESTION
            END AS SEARCH_QUERY,
            FAULT_CATEGORY AS FILTER_CATEGORY
        FROM fault_context
        UNION ALL
        SELECT QUESTION AS SEARCH_QUERY, NULL AS FILTER_CATEGORY
        WHERE CONTEXT_FAULT_ID IS NULL
    )
    SELECT EXTRACT_ANSWER_FROM_PDF_SOPS(
        SEARCH_QUERY,
        (SELECT FAULT_CODE FROM fault_context),
        (SELECT EQUIPMENT_TYPE FROM fault_context),
        FOCUS_CHUNK_TYPE
    )
    FROM enhanced_query
    LIMIT 1
$$;

-- Wait for the PDF search service to be ready
SELECT 'Waiting for PDF Cortex Search Service to initialize...' AS STATUS;

-- Test the PDF-based Cortex Search functionality
SELECT 'Testing PDF Cortex Search Service' AS TEST_PHASE;

-- Test 1: Basic chunk search
SELECT 'Test 1: Basic PDF Chunk Search' AS TEST_NAME;
SELECT * FROM TABLE(SEARCH_PDF_SOP_CHUNKS('cable fault 812.3', NULL, 'Cable Fault', NULL, 3));

-- Test 2: Safety-focused search
SELECT 'Test 2: Safety Chunk Search' AS TEST_NAME;
SELECT * FROM TABLE(SEARCH_PDF_SOP_CHUNKS('safety requirements PPE', 'SAFETY', NULL, NULL, 3));

-- Test 3: AI answer from PDF chunks
SELECT 'Test 3: AI Answer from PDF Chunks' AS TEST_NAME;
SELECT ASK_PDF_TECHNICAL_QUESTION(
    'What safety equipment is required for cable fault repair?',
    NULL,
    'SAFETY'
) AS PDF_AI_ANSWER;

-- Test 4: Comprehensive procedure generation from PDFs
SELECT 'Test 4: PDF-based Procedure Generation' AS TEST_NAME;
SELECT GENERATE_PDF_REPAIR_PROCEDURE(
    '812.3',
    'Cisco cBR-8',
    'Underground cable cut detected'
) AS PDF_AI_PROCEDURE;

-- Display service status and summary
SELECT 
    'PDF Cortex Search Setup Complete' AS STATUS,
    (SELECT COUNT(*) FROM SOP_DOCUMENT_CHUNKS) AS TOTAL_PDF_CHUNKS,
    (SELECT COUNT(DISTINCT DOCUMENT_ID) FROM SOP_DOCUMENT_CHUNKS) AS TOTAL_PDF_DOCUMENTS,
    (SELECT COUNT(DISTINCT CHUNK_TYPE) FROM SOP_DOCUMENT_CHUNKS) AS CHUNK_TYPES_AVAILABLE;

-- Show available Cortex Search services
SHOW CORTEX SEARCH SERVICES;

-- Display PDF search service details
DESCRIBE CORTEX SEARCH SERVICE PDF_SOP_SEARCH_SERVICE;
