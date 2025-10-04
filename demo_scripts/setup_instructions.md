# TDC Net Snowflake Demo - Setup Instructions

## Prerequisites

### Snowflake Environment
- **Edition:** Enterprise or higher (required for Cortex AI functions)
- **Region:** Any region with Cortex AI availability
- **Permissions:** SYSADMIN or equivalent role with ability to:
  - Create databases, schemas, and warehouses
  - Create and execute functions
  - Access Cortex AI functions (`SNOWFLAKE.ML.*`)
  - Deploy Streamlit applications

### Local Development Environment
- **Python:** 3.8 or higher
- **Git:** For cloning the repository
- **Text Editor:** VS Code, PyCharm, or similar
- **Web Browser:** Chrome, Firefox, or Safari (for Streamlit apps)

---

## Step 1: Snowflake Environment Setup

### 1.1 Create Database and Schema
```sql
-- Execute in Snowflake worksheet
USE ROLE SYSADMIN;

-- Run the database setup script
-- Copy and paste contents from: sql/setup/01_database_setup.sql
```

### 1.2 Create Tables and Objects
```sql
-- Execute table creation script
-- Copy and paste contents from: sql/setup/02_table_creation.sql
```

### 1.3 Verify Cortex AI Functions
```sql
-- Check available Cortex functions
SHOW FUNCTIONS LIKE 'SNOWFLAKE.ML%';

-- Expected functions:
-- SNOWFLAKE.ML.CLASSIFICATION
-- SNOWFLAKE.ML.COMPLETE  
-- SNOWFLAKE.ML.EXTRACT_ANSWER
```

**Note:** If Cortex functions are not available, contact your Snowflake administrator to enable them.

---

## Step 2: Data Loading

### 2.1 Upload Sample Data Files

#### Option A: Using Snowflake Web Interface
1. Navigate to **Data > Databases > TELCO_DEMO > NETWORK_OPS > Stages**
2. Click on **FAULT_DATA_STAGE**
3. Click **+ Files** and upload `data/sample_fault_logs/network_faults.csv`
4. Click on **SOP_DOCUMENTS_STAGE**  
5. Upload all files from `data/sample_sop_documents/`

#### Option B: Using SnowSQL
```bash
# Install SnowSQL if not already installed
# Configure connection to your Snowflake account

# Upload fault data
PUT file://data/sample_fault_logs/network_faults.csv @TELCO_DEMO.NETWORK_OPS.FAULT_DATA_STAGE;

# Upload SOP documents
PUT file://data/sample_sop_documents/*.json @TELCO_DEMO.NETWORK_OPS.SOP_DOCUMENTS_STAGE;
```

### 2.2 Create PDF Document Tables
```sql
-- Execute PDF document table setup
-- Copy and paste contents from: sql/setup/03_pdf_document_tables.sql
```

### 2.3 Load Data into Tables
```sql
-- Execute data loading scripts
-- Copy and paste contents from: sql/data_loading/load_fault_data.sql
-- Copy and paste contents from: sql/data_loading/load_pdf_sop_documents.sql
```

**Note:** The new approach uses PDF documents stored in Snowflake stages with content extracted into chunks for better search performance.

### 2.4 Upload PDF Documents to Stage
```bash
# Upload PDF SOP documents to Snowflake stage
PUT file://data/sample_sop_documents_pdf/*.pdf @TELCO_DEMO.NETWORK_OPS.SOP_PDF_STAGE;

# Verify upload
LIST @TELCO_DEMO.NETWORK_OPS.SOP_PDF_STAGE;
```

### 2.5 Verify Data Load
```sql
-- Check record counts
SELECT 'NETWORK_FAULTS' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT FROM NETWORK_FAULTS
UNION ALL
SELECT 'SOP_DIRECTORY' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT FROM SOP_DIRECTORY
UNION ALL
SELECT 'SOP_DOCUMENT_METADATA' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT FROM SOP_DOCUMENT_METADATA
UNION ALL
SELECT 'SOP_DOCUMENT_CHUNKS' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT FROM SOP_DOCUMENT_CHUNKS
UNION ALL
SELECT 'FAULT_CLASSIFICATION_TRAINING' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT FROM FAULT_CLASSIFICATION_TRAINING;

-- Expected results:
-- NETWORK_FAULTS: 1000 records
-- SOP_DIRECTORY: 5 PDF files
-- SOP_DOCUMENT_METADATA: 5 documents
-- SOP_DOCUMENT_CHUNKS: ~15-20 chunks
-- FAULT_CLASSIFICATION_TRAINING: 1000 records

-- Also verify the enhanced view
SELECT COUNT(*) FROM VW_NETWORK_FAULTS_ENHANCED;
SELECT COUNT(*) FROM VW_SEARCHABLE_SOP_CONTENT;
```

---

## Step 3: Cortex AI Model Setup

### 3.1 Deploy Classification Functions
```sql
-- Execute Cortex Analyst setup
-- Copy and paste contents from: sql/cortex_models/fault_classification.sql
```

### 3.2 Deploy PDF-based Cortex Search Service  
```sql
-- Execute PDF Cortex Search setup
-- Copy and paste contents from: sql/cortex_models/cortex_search_pdf_setup.sql
-- Note: This creates a Cortex Search Service over PDF document chunks
```

**Important:** The PDF Cortex Search Service creation may take several minutes to complete as it builds the search index over document chunks. Monitor the progress and wait for completion before proceeding.

### 3.3 Test AI Functions
```sql
-- Test fault classification
SELECT CLASSIFY_FAULT('812.3', 'COAX', 'Cisco cBR-8', 'Copenhagen Central', 1000, 50, 14, 3, TRUE) AS PREDICTED_CATEGORY;

-- Test PDF-based Cortex Search Service
SELECT * FROM TABLE(SEARCH_PDF_SOP_CHUNKS('cable fault 812.3', NULL, 'Cable Fault', NULL, 3));

-- Test AI-powered answer extraction from PDF chunks
SELECT ASK_PDF_TECHNICAL_QUESTION('What safety equipment is required for cable fault repair?', NULL, 'SAFETY') AS PDF_AI_ANSWER;

-- Test AI procedure generation from PDF chunks
SELECT GENERATE_PDF_REPAIR_PROCEDURE('812.3', 'Cisco cBR-8', 'Underground cable cut detected') AS PDF_AI_PROCEDURE;

-- Verify PDF Cortex Search Service status
SHOW CORTEX SEARCH SERVICES;
DESCRIBE CORTEX SEARCH SERVICE PDF_SOP_SEARCH_SERVICE;

-- Test searchable content view
SELECT * FROM VW_SEARCHABLE_SOP_CONTENT LIMIT 5;
```

---

## Step 4: Streamlit Applications Setup

### 4.1 Local Development Setup

#### Install Dependencies
```bash
# Navigate to project directory
cd "/path/to/TDCNet Demo"

# Install Python dependencies for local testing
pip install streamlit pandas plotly numpy

# Or use the requirements files
pip install -r streamlit_apps/manager_dashboard/requirements.txt
pip install -r streamlit_apps/field_engineer_app/requirements.txt
```

#### Test Applications Locally
```bash
# Test Manager Dashboard
cd streamlit_apps/manager_dashboard
streamlit run app.py

# Test Field Engineer App (in new terminal)
cd streamlit_apps/field_engineer_app  
streamlit run app.py
```

### 4.2 Deploy to Snowflake (Recommended for Demo)

#### Manager Dashboard Deployment
1. **Navigate to Snowflake Web Interface**
2. **Go to Streamlit > + Streamlit App**
3. **Create new app:**
   - **Name:** `TDC_Net_Manager_Dashboard`
   - **Warehouse:** `SID_WH`
   - **App location:** `TELCO_DEMO.NETWORK_OPS`
4. **Copy contents of `streamlit_apps/manager_dashboard/app.py`**
5. **Replace the data loading function with Snowflake connector:**

```python
# Replace the load_fault_data() function with:
@st.cache_data
def load_fault_data():
    """Load fault data from Snowflake"""
    session = snowflake.snowpark.context.get_active_session()
    
    df = session.table("NETWORK_FAULTS").to_pandas()
    df['fault_timestamp'] = pd.to_datetime(df['fault_timestamp'])
    df['resolution_timestamp'] = pd.to_datetime(df['resolution_timestamp'])
    
    # Add calculated fields
    df['hours_since_fault'] = (datetime.now() - df['fault_timestamp']).dt.total_seconds() / 3600
    df['is_resolved'] = df['resolution_timestamp'].notna()
    
    # Get ML predictions from views
    analysis_df = session.table("VW_FAULT_ANALYSIS").to_pandas()
    
    # Merge predictions
    df = df.merge(analysis_df[['FAULT_ID', 'PREDICTED_CATEGORY', 'CALCULATED_PRIORITY_SCORE']], 
                  left_on='fault_id', right_on='FAULT_ID', how='left')
    
    return df
```

#### Field Engineer App Deployment
1. **Create second Streamlit app:**
   - **Name:** `TDC_Net_Field_Assistant`
   - **Warehouse:** `SID_WH`
   - **App location:** `TELCO_DEMO.NETWORK_OPS`
2. **Copy contents of `streamlit_apps/field_engineer_app/app.py`**
3. **Update data loading functions for Snowflake:**

```python
# Replace load_fault_data() and SOP loading with Snowflake queries
@st.cache_data
def load_fault_data():
    session = snowflake.snowpark.context.get_active_session()
    
    # Load fault data
    df = session.table("NETWORK_FAULTS").to_pandas()
    
    # Load SOP documents  
    sop_df = session.table("SOP_DOCUMENTS").to_pandas()
    sop_docs = sop_df.to_dict('records')
    
    return df, sop_docs
```

---

## Step 5: Demo Environment Verification

### 5.1 Data Verification Checklist
- [ ] 1,000 network fault records loaded
- [ ] 5 SOP documents loaded  
- [ ] Fault classification training data populated
- [ ] All views and functions created successfully

### 5.2 Application Verification Checklist
- [ ] Manager Dashboard loads without errors
- [ ] Fault metrics display correctly
- [ ] Charts and visualizations render properly
- [ ] Critical alerts section shows high-priority faults
- [ ] Field Engineer App loads on mobile/desktop
- [ ] AI chat interface responds to queries
- [ ] Repair procedures generate correctly

### 5.3 AI Function Verification
```sql
-- Test all key functions
SELECT 
    'Classification Test' AS TEST_TYPE,
    CLASSIFY_FAULT('812.3', 'COAX', 'Cisco cBR-8', 'Copenhagen', 1000, 50, 14, 3, TRUE) AS RESULT
UNION ALL
SELECT 
    'Priority Scoring Test' AS TEST_TYPE,
    CALCULATE_PRIORITY_SCORE('Cable Fault', 1000, 50, TRUE, 'Cisco cBR-8')::VARCHAR AS RESULT
UNION ALL  
SELECT
    'Search Test' AS TEST_TYPE,
    (SELECT COUNT(*) FROM TABLE(SEARCH_SOP_DOCUMENTS('cable fault')))::VARCHAR AS RESULT;
```

---

## Step 6: Demo Presentation Setup

### 6.1 Browser Setup
- **Open two browser tabs/windows:**
  1. Manager Dashboard (for Vignette 1)
  2. Field Engineer App (for Vignette 2)
- **Bookmark both applications for quick access**
- **Test navigation between applications**

### 6.2 Demo Data Preparation
- **Identify 2-3 critical faults to highlight**
- **Prepare specific search queries for AI assistant**
- **Test the complete user journey end-to-end**

### 6.3 Backup Preparation
- **Take screenshots of key dashboard views**
- **Prepare static data in case of connectivity issues**
- **Have presentation slides ready as backup**

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: Cortex AI functions not available
**Solution:** 
- Verify Snowflake edition (Enterprise+ required)
- Check region availability for Cortex AI
- Contact Snowflake support to enable features

#### Issue: Data loading fails
**Solution:**
- Check file format specifications
- Verify stage permissions
- Ensure CSV headers match table columns exactly

#### Issue: Streamlit app won't start
**Solution:**
- Check Python version (3.8+ required)
- Verify all dependencies installed
- Check file paths in data loading functions

#### Issue: Charts not displaying
**Solution:**
- Update Plotly version: `pip install plotly --upgrade`
- Clear browser cache
- Check data types in DataFrame

#### Issue: Mobile app not responsive
**Solution:**
- Test in different browsers
- Check CSS media queries
- Verify Streamlit version compatibility

### Performance Optimization

#### For Large Datasets
```sql
-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS IDX_FAULT_TIMESTAMP ON NETWORK_FAULTS(FAULT_TIMESTAMP);
CREATE INDEX IF NOT EXISTS IDX_FAULT_CATEGORY ON NETWORK_FAULTS(FAULT_CATEGORY);
```

#### For Streamlit Apps
```python
# Use caching for expensive operations
@st.cache_data(ttl=300)  # Cache for 5 minutes
def expensive_computation():
    # Your computation here
    pass
```

---

## Security Considerations

### Data Privacy
- **Anonymize sensitive data** in demo environment
- **Use sample customer IDs** instead of real identifiers  
- **Mask location details** if required by privacy policies

### Access Control
```sql
-- Create demo-specific roles
CREATE ROLE DEMO_MANAGER;
CREATE ROLE DEMO_FIELD_ENGINEER;

-- Grant appropriate permissions
GRANT USAGE ON DATABASE TDCNET_DEMO TO ROLE DEMO_MANAGER;
GRANT SELECT ON ALL TABLES IN SCHEMA NETWORK_OPS TO ROLE DEMO_MANAGER;
```

### Network Security
- **Use HTTPS** for all Streamlit applications
- **Configure firewall rules** if deploying externally
- **Enable MFA** for Snowflake accounts used in demo

---

## Post-Demo Cleanup (Optional)

### Remove Demo Environment
```sql
-- Clean up demo objects
DROP DATABASE IF EXISTS TDCNET_DEMO;
DROP WAREHOUSE IF EXISTS TDCNET_DEMO_WH;

-- Remove Streamlit apps from Snowflake interface
-- Navigate to Streamlit > Apps and delete created applications
```

### Preserve for Future Use
```sql
-- Alternatively, suspend warehouse to save costs
ALTER WAREHOUSE TDCNET_DEMO_WH SUSPEND;

-- Keep data and applications for future demonstrations
```

---

## Support and Resources

### Documentation Links
- [Snowflake Cortex AI Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex)
- [Streamlit in Snowflake Guide](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Snowpark Python Documentation](https://docs.snowflake.com/en/developer-guide/snowpark/python/index)

### Contact Information
- **Technical Issues:** [Your technical contact]
- **Business Questions:** [Your business contact]  
- **Snowflake Support:** [Snowflake account team]

### Additional Resources
- **Architecture Diagrams:** Available in project documentation
- **Sample Queries:** See `sql/` directory for examples
- **Extended Datasets:** Contact team for larger sample datasets
