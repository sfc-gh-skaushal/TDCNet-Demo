# TDC Net Snowflake Demo

## Overview
This demo showcases how TDC Net can leverage Snowflake's AI capabilities to transform their fault resolution process from reactive to proactive and predictive, significantly reducing operational costs and improving customer satisfaction.

## Business Problem
- Low First-Time Fix (FTF) Rate - the primary KPI
- Inefficient field operations with excessive manual documentation searches
- Reactive maintenance model without predictive capabilities
- Lack of fault prioritization and sub-optimal technician dispatch

## Solution Architecture
The demo presents two integrated value vignettes:

### Vignette 1: Proactive Fault Triage
- **Target Audience**: Product Managers, Network Operations Managers
- **Value**: Proactively identify and prioritize high-impact network faults
- **Technology**: Cortex Analyst for ML-based fault classification

### Vignette 2: AI-Powered Field Guidance
- **Target Audience**: Field Engineers, Operations Leadership
- **Value**: Instant AI-summarized repair steps from technical documentation
- **Technology**: Cortex Search for LLM-powered Q&A and summarization

## Project Structure
```
├── data/
│   ├── sample_fault_logs/          # Network fault data (COAX & Fiber)
│   └── sample_sop_documents/       # Technical manuals and SOPs
├── sql/
│   ├── setup/                      # Database and table creation scripts
│   ├── data_loading/              # Data ingestion and preparation
│   └── cortex_models/             # ML model definitions
├── streamlit_apps/
│   ├── manager_dashboard/         # Vignette 1: Manager's triage dashboard
│   └── field_engineer_app/       # Vignette 2: Mobile field assistant
├── demo_scripts/
│   ├── presentation_flow.md       # Demo presentation guide
│   └── setup_instructions.md      # Technical setup guide
└── requirements.txt               # Python dependencies
```

## Quick Start
1. Set up Snowflake environment (Enterprise+ with Cortex AI enabled)
2. Run setup scripts in `sql/setup/`
3. Load sample data using scripts in `sql/data_loading/`
4. Deploy Streamlit applications
5. Follow demo presentation flow

## Key Features Demonstrated
- **Cortex Analyst**: SQL-based ML classification for fault prediction
- **Cortex Search**: Natural language querying of technical documents
- **Streamlit Integration**: Native Snowflake app development
- **Unified Platform**: End-to-end solution within Snowflake ecosystem

## Business Impact
- Reduced Mean Time to Resolution (MTTR)
- Improved First-Time Fix rate
- Optimized technician dispatch
- Enhanced customer satisfaction
- Lower operational costs
