-- TDC Net Snowflake Demo - Database Setup
-- This script creates the database, schema, and core objects for the demo

-- Create database and schema
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS TELCO_DEMO;
USE DATABASE TELCO_DEMO;

CREATE SCHEMA IF NOT EXISTS NETWORK_OPS;
USE SCHEMA NETWORK_OPS;

-- Create warehouse for demo workloads

USE WAREHOUSE SID_WH;

-- Grant necessary privileges (adjust as needed for your environment)

-- Enable Cortex AI functions (requires Enterprise edition or higher)
-- These functions will be used in subsequent scripts
-- SNOWFLAKE.ML.CLASSIFICATION for fault prediction
-- SNOWFLAKE.ML.COMPLETE for text generation
-- SNOWFLAKE.ML.EXTRACT_ANSWER for document Q&A

SHOW FUNCTIONS LIKE 'SNOWFLAKE.ML%';

-- Create file format for CSV data loading
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
NULL_IF = ('NULL', 'null', '')
EMPTY_FIELD_AS_NULL = TRUE
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
TRIM_SPACE = TRUE;

-- Create file format for JSON documents
CREATE OR REPLACE FILE FORMAT JSON_FORMAT
TYPE = 'JSON'
STRIP_OUTER_ARRAY = FALSE
COMMENT = 'File format for SOP documents and other JSON data';

-- Create stages for data loading
CREATE OR REPLACE STAGE FAULT_DATA_STAGE
FILE_FORMAT = CSV_FORMAT
COMMENT = 'Stage for network fault log data';

CREATE OR REPLACE STAGE SOP_DOCUMENTS_STAGE
FILE_FORMAT = JSON_FORMAT
DIRECTORY = (ENABLE = TRUE)
ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
COMMENT = 'Stage for SOP documents and technical manuals';

-- Display setup completion
SELECT 'TDC Net Demo database setup completed successfully!' AS STATUS;
