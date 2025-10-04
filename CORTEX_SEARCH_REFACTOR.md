# Cortex Search Refactoring - Implementation Guide

## Overview
This document outlines the refactoring of the TDC Net demo's search functionality to use Snowflake's native Cortex Search service instead of custom search functions. The refactoring aligns with [Snowflake's official Cortex Search documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview).

## Key Changes Made

### 1. From Custom Functions to Cortex Search Service

**Before (Custom Implementation):**
```sql
-- Custom function with basic keyword matching
CREATE OR REPLACE FUNCTION SEARCH_SOP_DOCUMENTS(QUERY_TEXT VARCHAR)
RETURNS TABLE (...)
LANGUAGE SQL
AS $$
    SELECT ... FROM SOP_DOCUMENTS
    WHERE UPPER(CONTENT) LIKE UPPER('%' || QUERY_TEXT || '%')
    ORDER BY relevance_score DESC
$$;
```

**After (Native Cortex Search):**
```sql
-- Native Cortex Search Service with hybrid vector/keyword search
CREATE OR REPLACE CORTEX SEARCH SERVICE SOP_SEARCH_SERVICE
    ON CONTENT
    ATTRIBUTES DOCUMENT_ID, TITLE, CATEGORY, EQUIPMENT_TYPES, FAULT_CODES
    WAREHOUSE = CORTEX_SEARCH_WH
    TARGET_LAG = '1 hour'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (SELECT ... FROM SOP_DOCUMENTS WHERE IS_ACTIVE = TRUE);
```

### 2. Enhanced AI-Powered Features

#### AI Answer Extraction
- **Integration:** Uses `SNOWFLAKE.CORTEX.COMPLETE` with Mixtral-8x7b model
- **Context-Aware:** Combines search results with LLM for intelligent responses
- **Structured Output:** Returns JSON objects with source attribution

#### AI Procedure Generation
- **Dynamic:** Generates structured repair procedures based on fault context
- **Comprehensive:** Includes safety, diagnostic, repair, and verification steps
- **Contextual:** Adapts content based on fault category and equipment type

### 3. Architecture Improvements

#### Dedicated Infrastructure
```sql
-- Dedicated warehouse for search operations (Snowflake best practice)
CREATE OR REPLACE WAREHOUSE CORTEX_SEARCH_WH WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;
```

#### Change Tracking
```sql
-- Required for Cortex Search service
ALTER TABLE SOP_DOCUMENTS SET CHANGE_TRACKING = TRUE;
```

#### Hybrid Search Capabilities
- **Vector Search:** Semantic understanding using embeddings
- **Keyword Search:** Traditional text matching
- **Filtering:** Category-based result filtering
- **Real-time Updates:** Automatic index refresh with 1-hour lag

## New Functions and Capabilities

### 1. Enhanced Search Function
```sql
SEARCH_SOP_DOCUMENTS(
    QUERY_TEXT VARCHAR,
    FILTER_CATEGORY VARCHAR DEFAULT NULL,
    LIMIT_RESULTS INTEGER DEFAULT 10
)
```
- Uses native `SNOWFLAKE.CORTEX.SEARCH_PREVIEW`
- Supports category filtering
- Returns structured results with relevance scores

### 2. AI Question Answering
```sql
ASK_TECHNICAL_QUESTION(
    QUESTION VARCHAR,
    CONTEXT_FAULT_ID VARCHAR DEFAULT NULL
)
```
- Natural language question processing
- Context-aware responses using fault data
- Integration with Cortex Complete for intelligent answers

### 3. AI Procedure Generation
```sql
GENERATE_REPAIR_PROCEDURE(
    FAULT_CODE VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    FAULT_DESCRIPTION VARCHAR
)
```
- AI-generated structured procedures
- Context-specific safety and repair steps
- Estimated time and required skills

## Business Value Enhancements

### 1. Improved Search Quality
- **Semantic Search:** Understanding of context and meaning, not just keywords
- **Relevance Scoring:** Advanced algorithms for better result ranking
- **Fuzzy Matching:** Handles typos and variations in search terms

### 2. AI-Powered Insights
- **Natural Language Processing:** Field engineers can ask questions in plain English
- **Contextual Responses:** Answers tailored to specific fault scenarios
- **Structured Guidance:** Step-by-step procedures generated dynamically

### 3. Scalability and Performance
- **Native Integration:** No external dependencies or custom infrastructure
- **Auto-scaling:** Snowflake handles capacity management
- **Real-time Updates:** Search index stays current with document changes

## Implementation Requirements

### Prerequisites
- Snowflake Enterprise edition or higher
- Cortex AI features enabled in the region
- `SNOWFLAKE.CORTEX_USER` database role granted

### Regional Availability
The refactored solution works in all regions supporting Cortex Search:
- AWS: US West 2, US East 1, US East 2, Europe (Ireland), Asia Pacific (Tokyo), etc.
- Azure: East US 2, West Europe, Japan East, etc.
- GCP: US Central 1, Europe West 2, etc.

### Embedding Models
- **Primary:** `snowflake-arctic-embed-l-v2.0` (high quality, recommended)
- **Alternative:** `snowflake-arctic-embed-m-v1.5` (faster, smaller)
- **Multilingual:** `voyage-multilingual-2` (selected regions)

## Demo Experience Improvements

### For Field Engineers
1. **Natural Language Queries:** "How do I fix cable fault 812.3 on Cisco equipment?"
2. **Contextual Responses:** AI understands fault context and provides relevant answers
3. **Structured Procedures:** Step-by-step guidance with safety requirements
4. **Source Attribution:** Clear references to authoritative documentation

### For Managers
1. **Search Analytics:** Understanding of what technicians are searching for
2. **Content Gaps:** Identification of missing or inadequate documentation
3. **Usage Patterns:** Insights into common fault resolution scenarios

## Migration Path

### Phase 1: Service Creation
1. Enable change tracking on SOP_DOCUMENTS table
2. Create dedicated Cortex Search warehouse
3. Deploy Cortex Search service (may take several minutes)
4. Verify service creation and indexing completion

### Phase 2: Function Deployment
1. Deploy new AI-powered search functions
2. Update existing views to use new functions
3. Test search functionality and AI responses

### Phase 3: Application Updates
1. Update Streamlit applications to use new search capabilities
2. Enhance user interfaces with AI-powered features
3. Add natural language query interfaces

## Testing and Validation

### Search Quality Tests
```sql
-- Test basic search functionality
SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS('cable fault 812.3 Cisco', NULL, 3));

-- Test category filtering
SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS('signal adjustment', 'Minor', 2));

-- Test AI question answering
SELECT ASK_TECHNICAL_QUESTION('How to troubleshoot network connectivity issues?');
```

### Performance Benchmarks
- **Search Latency:** < 500ms for typical queries
- **Index Refresh:** 1-hour lag for document updates
- **Concurrent Users:** Scales automatically with warehouse size

## Cost Considerations

### Compute Costs
- **Search Warehouse:** Small warehouse for search operations (~$2-4/hour when active)
- **LLM Usage:** Cortex Complete charges per token for AI responses
- **Storage:** Minimal additional cost for search indexes

### Optimization Strategies
- **Auto-suspend:** Warehouse suspends after 5 minutes of inactivity
- **Right-sizing:** Small warehouse sufficient for most search workloads
- **Query Optimization:** Efficient search patterns and result limiting

## Future Enhancements

### Planned Features
1. **Multi-language Support:** Using multilingual embedding models
2. **Visual Search:** Integration with Document AI for image-based procedures
3. **Feedback Loop:** Learning from user interactions to improve search quality
4. **Analytics Dashboard:** Search usage and effectiveness metrics

### Integration Opportunities
1. **Cortex Analyst:** Enhanced fault prediction using search insights
2. **Snowflake Intelligence:** Natural language queries across all data
3. **External Systems:** API integration with field service management tools

## Conclusion

The refactored Cortex Search implementation provides:
- **Native Snowflake Integration:** No external dependencies
- **AI-Powered Intelligence:** Advanced search and response capabilities  
- **Scalable Architecture:** Enterprise-ready performance and reliability
- **Enhanced User Experience:** Natural language interfaces and contextual responses

This refactoring transforms the TDC Net demo from a basic keyword search to an intelligent, AI-powered technical assistance system that significantly improves the field engineer experience and operational efficiency.
