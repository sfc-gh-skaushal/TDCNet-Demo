"""
TDC Net Manager Dashboard - Vignette 1: Proactive Fault Triage
Streamlit application for network operations managers to identify and prioritize faults
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
import numpy as np
import snowflake.snowpark.context

# Conditional import for Plotly with fallback
try:
    import plotly.express as px
    import plotly.graph_objects as go
    PLOTLY_AVAILABLE = True
except ImportError as e:
    PLOTLY_AVAILABLE = False
    # Create dummy objects to prevent errors
    class DummyPlotly:
        def bar(self, *args, **kwargs):
            return None
        def line(self, *args, **kwargs):
            return None
        def pie(self, *args, **kwargs):
            return None
        def scatter(self, *args, **kwargs):
            return None
        def histogram(self, *args, **kwargs):
            return None
    px = DummyPlotly()
    
    class DummyGO:
        def Figure(self, *args, **kwargs):
            return None
        def Bar(self, *args, **kwargs):
            return None
        def Scatter(self, *args, **kwargs):
            return None
    go = DummyGO()
except Exception as e:
    # Catch any other exceptions during import
    PLOTLY_AVAILABLE = False
    class DummyPlotly:
        def bar(self, *args, **kwargs):
            return None
        def line(self, *args, **kwargs):
            return None
        def pie(self, *args, **kwargs):
            return None
        def scatter(self, *args, **kwargs):
            return None
        def histogram(self, *args, **kwargs):
            return None
    px = DummyPlotly()
    
    class DummyGO:
        def Figure(self, *args, **kwargs):
            return None
        def Bar(self, *args, **kwargs):
            return None
        def Scatter(self, *args, **kwargs):
            return None
    go = DummyGO()

# Configure page
st.set_page_config(
    page_title="TDC Net - Network Operations Dashboard",
    page_icon="🔧",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
<style>
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .critical-alert {
        background-color: #ffebee;
        border-left: 4px solid #f44336;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 1rem 0;
    }
    .high-priority {
        background-color: #fff3e0;
        border-left: 4px solid #ff9800;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 1rem 0;
    }
    .stDataFrame {
        border: 1px solid #e0e0e0;
        border-radius: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Load data from Snowflake using native Snowpark session
@st.cache_data
def load_fault_data():
    """Load fault data from Snowflake"""
    try:
        # Get Snowflake session
        session = snowflake.snowpark.context.get_active_session()
        
        # Load fault data from Snowflake enhanced view
        df = session.table("VW_NETWORK_FAULTS_ENHANCED").to_pandas()
        df['fault_timestamp'] = pd.to_datetime(df['fault_timestamp'])
        df['resolution_timestamp'] = pd.to_datetime(df['resolution_timestamp'])
        
        # Add calculated fields for local processing
        df['hours_since_fault'] = (pd.Timestamp.now() - df['fault_timestamp']).dt.total_seconds() / 3600
        df['is_resolved'] = df['resolution_timestamp'].notna()
        df['created_date'] = df['fault_timestamp'].dt.date
        df['resolution_date'] = df['resolution_timestamp'].dt.date
        df['business_hours_fault'] = (
            (df['fault_timestamp'].dt.hour >= 8) & 
            (df['fault_timestamp'].dt.hour <= 17) & 
            (df['fault_timestamp'].dt.dayofweek < 5)  # Monday=0, Sunday=6
        )
        
        # Load ML predictions from Snowflake views
        try:
            # Get fault classification and triage data
            triage_df = session.table("VW_FAULT_TRIAGE").to_pandas()
            
            # Merge ML predictions with fault data
            df = df.merge(
                triage_df[['FAULT_ID', 'PREDICTED_CATEGORY', 'CALCULATED_PRIORITY_SCORE']], 
                left_on='fault_id', 
                right_on='FAULT_ID', 
                how='left'
            )
            
            # Use ML predictions or fallback to original values
            df['predicted_category'] = df['PREDICTED_CATEGORY'].fillna(df['fault_category'])
            df['calculated_priority_score'] = df['CALCULATED_PRIORITY_SCORE'].fillna(df['priority_score'])
            
        except Exception as ml_error:
            st.warning(f"ML predictions unavailable, using original data: {ml_error}")
            # Fallback to original values
            df['predicted_category'] = df['fault_category']
            df['calculated_priority_score'] = df['priority_score']
        
        # Risk level calculation
        df['risk_level'] = df['calculated_priority_score'].apply(
            lambda x: 'CRITICAL' if x > 0.8 else 'HIGH' if x > 0.6 else 'MEDIUM' if x > 0.4 else 'LOW'
        )
        
        # SLA breach risk calculation
        df['sla_breach_risk'] = (
            ((df['fault_category'] == 'Cable Fault') & (df['hours_since_fault'] > 4)) |
            ((df['fault_category'] == 'Major') & (df['hours_since_fault'] > 2)) |
            ((df['fault_category'] == 'Minor') & (df['hours_since_fault'] > 1))
        )
        
        return df
        
    except Exception as e:
        st.error(f"Error loading data from Snowflake: {e}")
        # Return empty DataFrame with proper structure for graceful degradation
        empty_df = pd.DataFrame(columns=[
            'fault_id', 'fault_timestamp', 'fault_category', 'fault_code', 
            'equipment_type', 'location', 'customers_affected', 'service_calls',
            'technician_type_required', 'resolution_timestamp', 'priority_score',
            'is_resolved', 'hours_since_fault', 'created_date', 'resolution_date', 
            'business_hours_fault', 'predicted_category', 'calculated_priority_score',
            'risk_level', 'sla_breach_risk'
        ])
        return empty_df

def create_kpi_metrics(df):
    """Create KPI metrics display"""
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        total_active = len(df[~df['is_resolved']])
        st.metric(
            label="🚨 Active Faults",
            value=total_active,
            delta=f"{len(df[df['hours_since_fault'] < 24])} in last 24h"
        )
    
    with col2:
        critical_faults = len(df[(~df['is_resolved']) & (df['risk_level'] == 'CRITICAL')])
        st.metric(
            label="🔥 Critical Faults",
            value=critical_faults,
            delta=f"{len(df[df['sla_breach_risk']])} SLA risk"
        )
    
    with col3:
        avg_ftf = df[df['is_resolved']]['first_time_fix'].mean() * 100
        st.metric(
            label="🎯 First Time Fix Rate",
            value=f"{avg_ftf:.1f}%",
            delta=f"Target: 85%"
        )
    
    with col4:
        total_customers = df[~df['is_resolved']]['customers_affected'].sum()
        st.metric(
            label="👥 Customers Affected",
            value=f"{total_customers:,}",
            delta=f"Revenue at risk: {df[~df['is_resolved']]['estimated_revenue_impact'].sum():,.0f} DKK"
        )

def create_fault_distribution_chart(df):
    """Create fault category distribution chart"""
    active_faults = df[~df['is_resolved']]
    
    if PLOTLY_AVAILABLE:
        fig = px.pie(
            active_faults,
            names='fault_category',
            values='customers_affected',
            title="Active Faults by Category (Customer Impact)",
            color_discrete_map={
                'Cable Fault': '#f44336',
                'Major': '#ff9800', 
                'Minor': '#4caf50'
            }
        )
        fig.update_traces(textposition='inside', textinfo='percent+label')
        return fig
    else:
        # Fallback: Return data for Streamlit native chart
        return active_faults.groupby('fault_category')['customers_affected'].sum()

def create_priority_timeline(df):
    """Create priority timeline chart"""
    active_faults = df[~df['is_resolved']].copy()
    active_faults = active_faults.sort_values('calculated_priority_score', ascending=False).head(20)
    
    if PLOTLY_AVAILABLE:
        fig = go.Figure()
        
        colors = {
            'CRITICAL': '#f44336',
            'HIGH': '#ff9800',
            'MEDIUM': '#2196f3',
            'LOW': '#4caf50'
        }
        
        for risk_level in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
            data = active_faults[active_faults['risk_level'] == risk_level]
            if not data.empty:
                fig.add_trace(go.Scatter(
                    x=data['hours_since_fault'],
                    y=data['calculated_priority_score'],
                    mode='markers',
                    marker=dict(
                        size=data['customers_affected'] / 50,
                        color=colors[risk_level],
                        opacity=0.7,
                        line=dict(width=2, color='white')
                    ),
                    text=data['fault_id'] + '<br>' + data['fault_description'],
                    name=risk_level,
                    hovertemplate='<b>%{text}</b><br>Priority: %{y:.2f}<br>Hours: %{x:.1f}<extra></extra>'
                ))
        
        fig.update_layout(
            title="Fault Priority vs Time Since Occurrence",
            xaxis_title="Hours Since Fault",
            yaxis_title="Priority Score",
            height=400
        )
        
        return fig
    else:
        # Fallback: Return data for Streamlit native scatter chart
        return active_faults[['hours_since_fault', 'calculated_priority_score', 'risk_level', 'fault_id']]

def create_location_heatmap(df):
    """Create location-based fault heatmap"""
    location_stats = df[~df['is_resolved']].groupby(['location', 'fault_category']).agg({
        'fault_id': 'count',
        'customers_affected': 'sum',
        'calculated_priority_score': 'mean'
    }).reset_index()
    
    if PLOTLY_AVAILABLE:
        fig = px.treemap(
            location_stats,
            path=['location', 'fault_category'],
            values='customers_affected',
            color='calculated_priority_score',
            color_continuous_scale='RdYlBu_r',
            title="Fault Impact by Location and Category"
        )
        return fig
    else:
        # Fallback: Return data for Streamlit native chart
        return location_stats

def display_critical_alerts(df):
    """Display critical fault alerts"""
    critical_faults = df[
        (~df['is_resolved']) & 
        ((df['risk_level'] == 'CRITICAL') | (df['sla_breach_risk']))
    ].sort_values('calculated_priority_score', ascending=False)
    
    if not critical_faults.empty:
        st.markdown("### 🚨 Critical Alerts Requiring Immediate Action")
        
        for _, fault in critical_faults.head(5).iterrows():
            alert_type = "critical-alert" if fault['risk_level'] == 'CRITICAL' else "high-priority"
            
            st.markdown(f"""
            <div class="{alert_type}">
                <h4>🔥 {fault['fault_id']} - {fault['fault_description']}</h4>
                <p><strong>Location:</strong> {fault['location']} | 
                   <strong>Equipment:</strong> {fault['equipment_type']} | 
                   <strong>Priority:</strong> {fault['calculated_priority_score']:.2f}</p>
                <p><strong>Impact:</strong> {fault['customers_affected']:,} customers affected | 
                   <strong>Revenue Risk:</strong> {fault['estimated_revenue_impact']:,.0f} DKK</p>
                <p><strong>Recommended Action:</strong> Deploy {fault['technician_type_required']} technician immediately</p>
            </div>
            """, unsafe_allow_html=True)

def display_fault_triage_table(df):
    """Display detailed fault triage table"""
    active_faults = df[~df['is_resolved']].copy()
    
    # Select and format columns for display
    display_columns = [
        'fault_id', 'fault_timestamp', 'fault_code', 'fault_description',
        'predicted_category', 'location', 'equipment_type', 'customers_affected',
        'calculated_priority_score', 'risk_level', 'technician_type_required',
        'hours_since_fault'
    ]
    
    display_df = active_faults[display_columns].copy()
    display_df['fault_timestamp'] = display_df['fault_timestamp'].dt.strftime('%Y-%m-%d %H:%M')
    display_df['hours_since_fault'] = display_df['hours_since_fault'].round(1)
    display_df['calculated_priority_score'] = display_df['calculated_priority_score'].round(3)
    
    # Sort by priority
    display_df = display_df.sort_values('calculated_priority_score', ascending=False)
    
    # Style the dataframe
    def highlight_priority(row):
        if row['risk_level'] == 'CRITICAL':
            return ['background-color: #ffebee'] * len(row)
        elif row['risk_level'] == 'HIGH':
            return ['background-color: #fff3e0'] * len(row)
        else:
            return [''] * len(row)
    
    styled_df = display_df.style.apply(highlight_priority, axis=1)
    
    st.dataframe(
        styled_df,
        use_container_width=True,
        height=400,
        column_config={
            "fault_id": "Fault ID",
            "fault_timestamp": "Timestamp",
            "fault_code": "Code",
            "fault_description": "Description",
            "predicted_category": "Category",
            "location": "Location",
            "equipment_type": "Equipment",
            "customers_affected": st.column_config.NumberColumn("Customers", format="%d"),
            "calculated_priority_score": st.column_config.NumberColumn("Priority", format="%.3f"),
            "risk_level": "Risk Level",
            "technician_type_required": "Technician Type",
            "hours_since_fault": st.column_config.NumberColumn("Hours Since", format="%.1f")
        }
    )

def main():
    """Main application"""
    # Debug information
    st.write(f"🔍 Debug: PLOTLY_AVAILABLE = {PLOTLY_AVAILABLE}")
    
    # Header
    st.title("🔧 TDC Net Network Operations Dashboard")
    st.markdown("**Proactive Fault Triage & Technician Dispatch Optimization**")
    
    # Display chart availability status
    if PLOTLY_AVAILABLE:
        st.success("📊 Advanced interactive charts enabled (Plotly loaded successfully)")
    else:
        st.warning("📊 Using Streamlit native charts - Plotly not available in this environment")
    
    # Load data
    df = load_fault_data()
    
    if df.empty:
        st.error("No data available. Please check the data source.")
        return
    
    # Sidebar filters
    st.sidebar.header("🔍 Filters")
    
    # Date range filter
    date_range = st.sidebar.date_input(
        "Date Range",
        value=(datetime.now() - timedelta(days=7), datetime.now()),
        max_value=datetime.now().date()
    )
    
    # Location filter
    locations = ['All'] + sorted(df['location'].unique().tolist())
    selected_location = st.sidebar.selectbox("Location", locations)
    
    # Fault category filter
    categories = ['All'] + sorted(df['fault_category'].unique().tolist())
    selected_category = st.sidebar.selectbox("Fault Category", categories)
    
    # Risk level filter
    risk_levels = ['All'] + ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
    selected_risk = st.sidebar.selectbox("Risk Level", risk_levels)
    
    # Apply filters
    filtered_df = df.copy()
    
    if len(date_range) == 2:
        start_date, end_date = date_range
        filtered_df = filtered_df[
            (filtered_df['fault_timestamp'].dt.date >= start_date) &
            (filtered_df['fault_timestamp'].dt.date <= end_date)
        ]
    
    if selected_location != 'All':
        filtered_df = filtered_df[filtered_df['location'] == selected_location]
    
    if selected_category != 'All':
        filtered_df = filtered_df[filtered_df['fault_category'] == selected_category]
    
    if selected_risk != 'All':
        filtered_df = filtered_df[filtered_df['risk_level'] == selected_risk]
    
    # Main dashboard
    create_kpi_metrics(filtered_df)
    
    st.markdown("---")
    
    # Critical alerts
    display_critical_alerts(filtered_df)
    
    st.markdown("---")
    
    # Charts
    col1, col2 = st.columns(2)
    
    with col1:
        if PLOTLY_AVAILABLE:
            st.plotly_chart(create_fault_distribution_chart(filtered_df), use_container_width=True)
        else:
            st.subheader("Active Faults by Category (Customer Impact)")
            chart_data = create_fault_distribution_chart(filtered_df)
            st.bar_chart(chart_data)
    
    with col2:
        if PLOTLY_AVAILABLE:
            st.plotly_chart(create_priority_timeline(filtered_df), use_container_width=True)
        else:
            st.subheader("Fault Priority vs Time Since Occurrence")
            chart_data = create_priority_timeline(filtered_df)
            st.scatter_chart(chart_data, x='hours_since_fault', y='calculated_priority_score', color='risk_level')
    
    if PLOTLY_AVAILABLE:
        st.plotly_chart(create_location_heatmap(filtered_df), use_container_width=True)
    else:
        st.subheader("Fault Impact by Location and Category")
        chart_data = create_location_heatmap(filtered_df)
        st.bar_chart(chart_data.set_index('location')['customers_affected'])
    
    st.markdown("---")
    
    # Detailed table
    st.markdown("### 📋 Active Fault Triage Queue")
    display_fault_triage_table(filtered_df)
    
    # Demo information
    with st.expander("ℹ️ Demo Information"):
        st.markdown("""
        **Vignette 1: From Reactive Alarms to Proactive Triage**
        
        This dashboard demonstrates how TDC Net can leverage Snowflake Cortex Analyst to:
        - **Predict and classify** network faults using ML models
        - **Prioritize** faults based on customer impact and business rules
        - **Recommend** optimal technician types for specialized dispatch
        - **Prevent SLA breaches** through proactive monitoring
        
        **Key Features:**
        - Real-time fault classification using `SNOWFLAKE.ML.CLASSIFICATION`
        - Priority scoring algorithm considering multiple factors
        - Automated technician recommendations
        - Visual analytics for operational insights
        
        **Business Impact:**
        - Reduced Mean Time to Resolution (MTTR)
        - Improved resource allocation
        - Higher customer satisfaction
        - Lower operational costs
        """)

if __name__ == "__main__":
    main()
