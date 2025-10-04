-- TDC Net Snowflake Demo - Fault Classification with Cortex Analyst
-- Implements ML-based fault classification using Snowflake's Cortex AI

USE DATABASE TDCNET_DEMO;
USE SCHEMA NETWORK_OPS;
USE WAREHOUSE TDCNET_DEMO_WH;

-- Create a view for model training features
CREATE OR REPLACE VIEW VW_FAULT_FEATURES AS
SELECT 
    FAULT_ID,
    FAULT_CODE,
    NETWORK_TYPE,
    EQUIPMENT_TYPE,
    LOCATION,
    CUSTOMERS_AFFECTED,
    SERVICE_CALLS_GENERATED,
    HOUR(FAULT_TIMESTAMP) AS HOUR_OF_DAY,
    DAYOFWEEK(FAULT_TIMESTAMP) AS DAY_OF_WEEK,
    BUSINESS_HOURS_FAULT,
    FAULT_CATEGORY AS ACTUAL_CATEGORY,
    -- Create feature vector for ML model
    OBJECT_CONSTRUCT(
        'fault_code', FAULT_CODE,
        'network_type', NETWORK_TYPE,
        'equipment_type', EQUIPMENT_TYPE,
        'location', LOCATION,
        'customers_affected', CUSTOMERS_AFFECTED,
        'service_calls', SERVICE_CALLS_GENERATED,
        'hour_of_day', HOUR_OF_DAY,
        'day_of_week', DAY_OF_WEEK,
        'business_hours', BUSINESS_HOURS_FAULT
    ) AS FEATURES
FROM VW_NETWORK_FAULTS_ENHANCED
WHERE FAULT_CATEGORY IS NOT NULL;

-- Create training and test datasets (80/20 split)
CREATE OR REPLACE VIEW VW_TRAINING_DATA AS
SELECT *
FROM VW_FAULT_FEATURES
WHERE MOD(ABS(HASH(FAULT_ID)), 10) < 8;

CREATE OR REPLACE VIEW VW_TEST_DATA AS
SELECT *
FROM VW_FAULT_FEATURES
WHERE MOD(ABS(HASH(FAULT_ID)), 10) >= 8;

-- Fault Classification Function using Cortex ML
-- This function predicts fault category based on input features
CREATE OR REPLACE FUNCTION CLASSIFY_FAULT(
    FAULT_CODE VARCHAR,
    NETWORK_TYPE VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    LOCATION VARCHAR,
    CUSTOMERS_AFFECTED INTEGER,
    SERVICE_CALLS INTEGER,
    HOUR_OF_DAY INTEGER,
    DAY_OF_WEEK INTEGER,
    BUSINESS_HOURS BOOLEAN
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    -- Use Cortex ML classification
    -- Note: In a real implementation, you would train a model first
    -- For demo purposes, we'll use rule-based logic that mimics ML predictions
    
    CASE 
        -- Cable Fault indicators
        WHEN FAULT_CODE LIKE '81%' 
             OR CUSTOMERS_AFFECTED > 1000 
             OR SERVICE_CALLS > 100 
        THEN 'Cable Fault'
        
        -- Major Fault indicators  
        WHEN FAULT_CODE LIKE '6%' 
             OR FAULT_CODE LIKE '7%' 
             OR FAULT_CODE LIKE '8%' 
             OR FAULT_CODE LIKE '9%'
             OR CUSTOMERS_AFFECTED > 100
             OR SERVICE_CALLS > 10
        THEN 'Major'
        
        -- Minor Fault (default)
        ELSE 'Minor'
    END
$$;

-- Priority Scoring Function
-- Calculates priority score for fault triage
CREATE OR REPLACE FUNCTION CALCULATE_PRIORITY_SCORE(
    FAULT_CATEGORY VARCHAR,
    CUSTOMERS_AFFECTED INTEGER,
    SERVICE_CALLS INTEGER,
    BUSINESS_HOURS BOOLEAN,
    EQUIPMENT_TYPE VARCHAR
)
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    -- Base score by category
    CASE FAULT_CATEGORY
        WHEN 'Cable Fault' THEN 0.8
        WHEN 'Major' THEN 0.5
        WHEN 'Minor' THEN 0.2
        ELSE 0.1
    END
    +
    -- Customer impact multiplier
    LEAST(CUSTOMERS_AFFECTED / 1000.0, 0.2)
    +
    -- Service calls multiplier  
    LEAST(SERVICE_CALLS / 100.0, 0.1)
    +
    -- Business hours boost
    CASE WHEN BUSINESS_HOURS THEN 0.1 ELSE 0.0 END
    +
    -- Critical equipment boost
    CASE 
        WHEN EQUIPMENT_TYPE LIKE '%Cisco%' THEN 0.05
        WHEN EQUIPMENT_TYPE LIKE '%Nokia%' THEN 0.05
        ELSE 0.0
    END
$$;

-- Technician Recommendation Function
-- Suggests optimal technician type based on fault characteristics
CREATE OR REPLACE FUNCTION RECOMMEND_TECHNICIAN(
    FAULT_CATEGORY VARCHAR,
    EQUIPMENT_TYPE VARCHAR,
    LOCATION VARCHAR,
    PRIORITY_SCORE FLOAT
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    OBJECT_CONSTRUCT(
        'technician_type', 
        CASE 
            WHEN FAULT_CATEGORY = 'Cable Fault' THEN 'Specialist'
            WHEN PRIORITY_SCORE > 0.7 THEN 'Senior'
            ELSE 'General'
        END,
        'skill_requirements',
        CASE FAULT_CATEGORY
            WHEN 'Cable Fault' THEN ARRAY_CONSTRUCT('Cable Splicing', 'TDR Operation', 'Excavation Safety')
            WHEN 'Major' THEN ARRAY_CONSTRUCT('Router Configuration', 'Fiber Optics', 'Network Troubleshooting')
            ELSE ARRAY_CONSTRUCT('Basic RF Knowledge', 'Equipment Operation')
        END,
        'estimated_duration_hours',
        CASE FAULT_CATEGORY
            WHEN 'Cable Fault' THEN 6.0
            WHEN 'Major' THEN 3.0
            ELSE 1.5
        END,
        'tools_required',
        CASE FAULT_CATEGORY
            WHEN 'Cable Fault' THEN ARRAY_CONSTRUCT('TDR', 'Spectrum Analyzer', 'Splice Kit', 'Excavation Tools')
            WHEN 'Major' THEN ARRAY_CONSTRUCT('Optical Power Meter', 'Laptop', 'Console Cable')
            ELSE ARRAY_CONSTRUCT('Signal Level Meter', 'Laptop')
        END
    )
$$;

-- Create a comprehensive fault analysis view
CREATE OR REPLACE VIEW VW_FAULT_ANALYSIS AS
SELECT 
    f.FAULT_ID,
    f.FAULT_TIMESTAMP,
    f.FAULT_CODE,
    f.FAULT_DESCRIPTION,
    f.FAULT_CATEGORY AS ACTUAL_CATEGORY,
    
    -- ML Predictions
    CLASSIFY_FAULT(
        f.FAULT_CODE,
        f.NETWORK_TYPE,
        f.EQUIPMENT_TYPE,
        f.LOCATION,
        f.CUSTOMERS_AFFECTED,
        f.SERVICE_CALLS_GENERATED,
        HOUR(f.FAULT_TIMESTAMP),
        DAYOFWEEK(f.FAULT_TIMESTAMP),
        f.BUSINESS_HOURS_FAULT
    ) AS PREDICTED_CATEGORY,
    
    CALCULATE_PRIORITY_SCORE(
        f.FAULT_CATEGORY,
        f.CUSTOMERS_AFFECTED,
        f.SERVICE_CALLS_GENERATED,
        f.BUSINESS_HOURS_FAULT,
        f.EQUIPMENT_TYPE
    ) AS CALCULATED_PRIORITY_SCORE,
    
    RECOMMEND_TECHNICIAN(
        f.FAULT_CATEGORY,
        f.EQUIPMENT_TYPE,
        f.LOCATION,
        f.PRIORITY_SCORE
    ) AS TECHNICIAN_RECOMMENDATION,
    
    -- Original data
    f.NETWORK_TYPE,
    f.EQUIPMENT_TYPE,
    f.LOCATION,
    f.SEVERITY,
    f.CUSTOMERS_AFFECTED,
    f.SERVICE_CALLS_GENERATED,
    f.PRIORITY_SCORE AS ORIGINAL_PRIORITY_SCORE,
    f.TECHNICIAN_TYPE_REQUIRED,
    f.ESTIMATED_REVENUE_IMPACT,
    f.IS_RESOLVED,
    f.FIRST_TIME_FIX,
    f.RESOLUTION_TIME_HOURS,
    
    -- Time-based features
    DATEDIFF('hour', f.FAULT_TIMESTAMP, CURRENT_TIMESTAMP()) AS HOURS_SINCE_FAULT,
    f.BUSINESS_HOURS_FAULT
    
FROM VW_NETWORK_FAULTS_ENHANCED f;

-- Create a real-time fault triage view for the manager dashboard
CREATE OR REPLACE VIEW VW_FAULT_TRIAGE AS
SELECT 
    FAULT_ID,
    FAULT_TIMESTAMP,
    FAULT_CODE,
    FAULT_DESCRIPTION,
    PREDICTED_CATEGORY,
    CALCULATED_PRIORITY_SCORE,
    TECHNICIAN_RECOMMENDATION:technician_type::VARCHAR AS RECOMMENDED_TECHNICIAN_TYPE,
    TECHNICIAN_RECOMMENDATION:estimated_duration_hours::FLOAT AS ESTIMATED_DURATION,
    NETWORK_TYPE,
    EQUIPMENT_TYPE,
    LOCATION,
    CUSTOMERS_AFFECTED,
    ESTIMATED_REVENUE_IMPACT,
    HOURS_SINCE_FAULT,
    
    -- Risk indicators
    CASE 
        WHEN CALCULATED_PRIORITY_SCORE > 0.8 THEN 'CRITICAL'
        WHEN CALCULATED_PRIORITY_SCORE > 0.6 THEN 'HIGH'
        WHEN CALCULATED_PRIORITY_SCORE > 0.4 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS RISK_LEVEL,
    
    -- SLA breach prediction
    CASE 
        WHEN PREDICTED_CATEGORY = 'Cable Fault' AND HOURS_SINCE_FAULT > 4 THEN TRUE
        WHEN PREDICTED_CATEGORY = 'Major' AND HOURS_SINCE_FAULT > 2 THEN TRUE
        WHEN PREDICTED_CATEGORY = 'Minor' AND HOURS_SINCE_FAULT > 1 THEN TRUE
        ELSE FALSE
    END AS SLA_BREACH_RISK

FROM VW_FAULT_ANALYSIS
WHERE IS_RESOLVED = FALSE
ORDER BY CALCULATED_PRIORITY_SCORE DESC, HOURS_SINCE_FAULT DESC;

-- Model accuracy assessment
CREATE OR REPLACE VIEW VW_MODEL_ACCURACY AS
SELECT 
    ACTUAL_CATEGORY,
    PREDICTED_CATEGORY,
    COUNT(*) AS PREDICTION_COUNT,
    COUNT(*) / SUM(COUNT(*)) OVER() AS PERCENTAGE
FROM VW_FAULT_ANALYSIS
WHERE ACTUAL_CATEGORY IS NOT NULL
GROUP BY ACTUAL_CATEGORY, PREDICTED_CATEGORY
ORDER BY ACTUAL_CATEGORY, PREDICTED_CATEGORY;

-- Performance metrics for the classification model
SELECT 
    'Model Performance Summary' AS METRIC_TYPE,
    COUNT(*) AS TOTAL_PREDICTIONS,
    SUM(CASE WHEN ACTUAL_CATEGORY = PREDICTED_CATEGORY THEN 1 ELSE 0 END) AS CORRECT_PREDICTIONS,
    SUM(CASE WHEN ACTUAL_CATEGORY = PREDICTED_CATEGORY THEN 1 ELSE 0 END) / COUNT(*) AS ACCURACY
FROM VW_FAULT_ANALYSIS
WHERE ACTUAL_CATEGORY IS NOT NULL;

-- Show sample predictions
SELECT 
    FAULT_ID,
    FAULT_CODE,
    ACTUAL_CATEGORY,
    PREDICTED_CATEGORY,
    CALCULATED_PRIORITY_SCORE,
    TECHNICIAN_RECOMMENDATION:technician_type::VARCHAR AS RECOMMENDED_TECHNICIAN
FROM VW_FAULT_ANALYSIS
LIMIT 20;
