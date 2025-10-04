# Streamlit Apps Deployment Guide for Snowflake

## Overview
This guide covers deploying the TDC Net Streamlit applications in Snowflake's native Streamlit environment.

## Prerequisites

### Snowflake Environment
- **Snowflake Account**: Enterprise edition or higher
- **Streamlit Support**: Enabled in your Snowflake account
- **Database Setup**: `TELCO_DEMO` database with all tables and views created
- **Permissions**: Ability to create and deploy Streamlit applications

## Deployment Steps

### 1. Manager Dashboard Deployment

#### Create Streamlit App in Snowflake
1. **Navigate to Snowflake Web Interface**
2. **Go to Streamlit > + Streamlit App**
3. **Create new app:**
   - **Name:** `TDC_Net_Manager_Dashboard`
   - **Warehouse:** `SID_WH`
   - **App location:** `TELCO_DEMO.NETWORK_OPS`
   - **Stage:** Create new stage or use existing

#### Upload App Files
1. **Copy the contents** of `streamlit_apps/manager_dashboard/app.py`
2. **Paste into Streamlit editor** in Snowflake
3. **Upload requirements.txt** or specify dependencies in Snowflake

#### Dependencies for Manager Dashboard
```
streamlit>=1.30.0
pandas>=2.0.0
plotly>=5.0.0
numpy>=1.24.0
```

### 2. Field Engineer App Deployment

#### Create Second Streamlit App
1. **Create new app:**
   - **Name:** `TDC_Net_Field_Engineer_Assistant`
   - **Warehouse:** `SID_WH`
   - **App location:** `TELCO_DEMO.NETWORK_OPS`

#### Upload App Files
1. **Copy the contents** of `streamlit_apps/field_engineer_app/app.py`
2. **Paste into Streamlit editor** in Snowflake

#### Dependencies for Field Engineer App
```
streamlit>=1.30.0
pandas>=2.0.0
plotly>=5.0.0
numpy>=1.24.0
```

## Dependency Management

### Option 1: Requirements.txt in Snowflake
When creating the Streamlit app in Snowflake, you can specify a `requirements.txt` file:

```txt
streamlit>=1.30.0
pandas>=2.0.0
plotly>=5.0.0
numpy>=1.24.0
```

### Option 2: Conda Environment (Advanced)
For more complex dependencies, you can create a custom conda environment:

```yaml
name: tdcnet_demo
dependencies:
  - python>=3.8
  - streamlit>=1.30.0
  - pandas>=2.0.0
  - plotly>=5.0.0
  - numpy>=1.24.0
```

### Option 3: Manual Installation
If dependencies are not automatically installed, you may need to contact your Snowflake administrator to install packages.

## Troubleshooting

### Common Issues and Solutions

#### Issue: `ModuleNotFoundError: No module named 'plotly'`
**Solutions:**
1. **Check requirements.txt**: Ensure `plotly>=5.0.0` is listed
2. **Verify app deployment**: Make sure requirements.txt was uploaded with the app
3. **Contact admin**: Snowflake admin may need to install packages manually
4. **Alternative approach**: Use Streamlit's built-in charting instead of Plotly

#### Issue: `No module named 'snowflake.snowpark.context'`
**Solutions:**
1. **Snowpark is pre-installed** in Snowflake Streamlit environment
2. **Check import syntax**: Ensure correct import statement
3. **Verify Snowflake version**: Ensure your Snowflake account supports Snowpark

#### Issue: Data loading errors
**Solutions:**
1. **Check database/schema**: Ensure `TELCO_DEMO.NETWORK_OPS` exists
2. **Verify tables**: Ensure all required tables and views are created
3. **Check permissions**: Ensure app has access to required objects

## Alternative Deployment (Fallback)

### If Plotly is Not Available
Replace Plotly charts with Streamlit native charts:

```python
# Instead of Plotly
# fig = px.bar(df, x='category', y='count')
# st.plotly_chart(fig)

# Use Streamlit native charts
st.bar_chart(df.set_index('category')['count'])
```

### Simplified Requirements
Minimal requirements if advanced packages are unavailable:

```txt
streamlit>=1.30.0
pandas>=2.0.0
numpy>=1.24.0
```

## Data Integration

### Snowflake Session
Both apps use Snowflake's native session:

```python
import snowflake.snowpark.context

# Get active session (automatically available in Snowflake Streamlit)
session = snowflake.snowpark.context.get_active_session()

# Load data from tables
df = session.table("VW_NETWORK_FAULTS_ENHANCED").to_pandas()
```

### Required Database Objects
Ensure these objects exist before deploying:

#### Tables
- `NETWORK_FAULTS`
- `SOP_DOCUMENT_METADATA`
- `SOP_DOCUMENT_CHUNKS`
- `FAULT_CLASSIFICATION_TRAINING`
- `TECHNICIAN_METRICS`

#### Views
- `VW_NETWORK_FAULTS_ENHANCED`
- `VW_FAULT_TRIAGE`
- `VW_SEARCHABLE_CHUNKS`

#### Functions/Procedures
- `ASK_TECHNICAL_QUESTION()`
- `GENERATE_REPAIR_PROCEDURE()`
- `SEARCH_SOP_CHUNKS()` (stored procedure)

## Testing

### Pre-Deployment Checklist
- [ ] All SQL objects created successfully
- [ ] Sample data loaded
- [ ] Streamlit apps run locally (optional)
- [ ] Dependencies verified
- [ ] Permissions configured

### Post-Deployment Verification
- [ ] Apps load without errors
- [ ] Data displays correctly
- [ ] Charts render properly
- [ ] Search functionality works
- [ ] Error handling functions correctly

## Performance Optimization

### Caching
Both apps use Streamlit caching:

```python
@st.cache_data
def load_fault_data():
    # Cached data loading
```

### Warehouse Management
- **Use appropriate warehouse size** for data processing
- **Consider auto-suspend** for cost optimization
- **Monitor query performance** in Snowflake

## Security Considerations

### Data Access
- Apps inherit permissions from the Snowflake user/role
- Ensure appropriate role-based access control
- Consider row-level security if needed

### Network Security
- Apps run within Snowflake's secure environment
- No external network access required
- All data remains within Snowflake

## Support

### Documentation
- [Snowflake Streamlit Documentation](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Streamlit Documentation](https://docs.streamlit.io/)

### Contact Points
- **Technical Issues**: Snowflake Support
- **App Issues**: Development team
- **Permissions**: Snowflake Administrator

## Appendix

### Complete File Structure
```
streamlit_apps/
├── manager_dashboard/
│   ├── app.py                 # Manager dashboard application
│   └── requirements.txt       # Dependencies
└── field_engineer_app/
    ├── app.py                 # Field engineer application
    └── requirements.txt       # Dependencies
```

### Environment Variables
No environment variables required - apps use Snowflake's native session context.

### Backup Strategy
- **Source code**: Maintained in Git repository
- **Data**: Backed up through Snowflake's native backup features
- **App configuration**: Documented in this guide
