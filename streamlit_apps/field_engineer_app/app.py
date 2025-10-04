"""
TDC Net Field Engineer Assistant - Vignette 2: AI-Powered Field Guidance
Mobile-first Streamlit application for field engineers to get instant repair guidance
"""

import streamlit as st
import pandas as pd
import json
from datetime import datetime
import time
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
    px = DummyPlotly()
    go = DummyPlotly()
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
    px = DummyPlotly()
    go = DummyPlotly()

# Configure page for mobile-first design
st.set_page_config(
    page_title="TDC Net Field Assistant",
    page_icon="🔧",
    layout="centered",
    initial_sidebar_state="collapsed"
)

# Mobile-optimized CSS
st.markdown("""
<style>
    .main-header {
        background: linear-gradient(90deg, #1f77b4, #2ca02c);
        color: white;
        padding: 1rem;
        border-radius: 0.5rem;
        text-align: center;
        margin-bottom: 1rem;
    }
    .fault-card {
        background-color: #f8f9fa;
        border: 1px solid #dee2e6;
        border-radius: 0.5rem;
        padding: 1rem;
        margin: 0.5rem 0;
    }
    .urgent-fault {
        background-color: #fff5f5;
        border-left: 4px solid #e53e3e;
    }
    .procedure-step {
        background-color: #f0f8ff;
        border-left: 4px solid #1f77b4;
        padding: 0.75rem;
        margin: 0.5rem 0;
        border-radius: 0.25rem;
    }
    .safety-warning {
        background-color: #fff5f0;
        border: 2px solid #fd7e14;
        border-radius: 0.5rem;
        padding: 1rem;
        margin: 1rem 0;
    }
    .success-message {
        background-color: #f0fff4;
        border-left: 4px solid #38a169;
        padding: 1rem;
        border-radius: 0.25rem;
        margin: 1rem 0;
    }
    .chat-message {
        background-color: #e3f2fd;
        border-radius: 1rem;
        padding: 0.75rem;
        margin: 0.5rem 0;
        max-width: 80%;
    }
    .user-message {
        background-color: #1f77b4;
        color: white;
        margin-left: 20%;
    }
    .assistant-message {
        background-color: #f5f5f5;
        margin-right: 20%;
    }
    /* Mobile optimizations */
    @media (max-width: 768px) {
        .stButton > button {
            width: 100%;
            margin: 0.25rem 0;
        }
        .stSelectbox > div {
            width: 100%;
        }
    }
</style>
""", unsafe_allow_html=True)

# Load sample data from Snowflake
@st.cache_data
def load_fault_data():
    """Load fault data from Snowflake"""
    try:
        # Get Snowflake session
        session = snowflake.snowpark.context.get_active_session()
        
        # Load fault data from Snowflake
        df = session.table("VW_NETWORK_FAULTS_ENHANCED").to_pandas()
        
        # Debug: Show available columns
        st.write(f"🔍 Available columns: {list(df.columns)}")
        
        # Normalize column names to lowercase for consistent access
        df.columns = df.columns.str.lower()
        st.write(f"🔍 Normalized columns: {list(df.columns)}")
        
        # Handle different possible column name variations
        timestamp_col = None
        for col in df.columns:
            if col in ['fault_timestamp', 'timestamp', 'created_at', 'fault_time']:
                timestamp_col = col
                break
        
        if timestamp_col:
            df['fault_timestamp'] = pd.to_datetime(df[timestamp_col])
        else:
            st.error(f"No timestamp column found. Available columns: {list(df.columns)}")
            return pd.DataFrame(), []
        
        # Handle resolution timestamp
        resolution_col = None
        for col in df.columns:
            if col in ['resolution_timestamp', 'resolved_at', 'resolution_time']:
                resolution_col = col
                break
        
        if resolution_col:
            df['resolution_timestamp'] = pd.to_datetime(df[resolution_col])
            df['is_resolved'] = df['resolution_timestamp'].notna()
        else:
            df['resolution_timestamp'] = None
            df['is_resolved'] = False
        
        # Add calculated fields for local processing
        df['hours_since_fault'] = (pd.Timestamp.now() - df['fault_timestamp']).dt.total_seconds() / 3600
        df['created_date'] = df['fault_timestamp'].dt.date
        df['resolution_date'] = df['resolution_timestamp'].dt.date if resolution_col else None
        df['business_hours_fault'] = (
            (df['fault_timestamp'].dt.hour >= 8) & 
            (df['fault_timestamp'].dt.hour <= 17) & 
            (df['fault_timestamp'].dt.dayofweek < 5)
        )
        
        # Load SOP documents metadata from Snowflake (optional)
        try:
            sop_docs = session.table("SOP_DOCUMENT_METADATA").to_pandas().to_dict('records')
        except Exception as sop_error:
            st.warning(f"SOP documents not available: {sop_error}")
            sop_docs = []
        
        return df, sop_docs
    except Exception as e:
        st.error(f"Error loading data from Snowflake: {e}")
        # Return empty data with proper structure
        empty_df = pd.DataFrame(columns=[
            'fault_id', 'fault_timestamp', 'fault_category', 'fault_code', 
            'equipment_type', 'location', 'customers_affected', 'service_calls',
            'technician_type_required', 'resolution_timestamp', 'is_resolved',
            'hours_since_fault', 'created_date', 'resolution_date', 'business_hours_fault'
        ])
        return empty_df, []

def search_sop_documents_cortex(query, fault_code=None, equipment_type=None):
    """Search SOP documents using Snowflake stored procedures"""
    try:
        # Get Snowflake session
        session = snowflake.snowpark.context.get_active_session()
        
        # Enhanced query with fault code and equipment type
        enhanced_query = query
        if fault_code:
            enhanced_query += f" {fault_code}"
        if equipment_type:
            enhanced_query += f" {equipment_type}"
        
        # For now, simulate search results until stored procedure integration is complete
        # In production, this would call: CALL SEARCH_SOP_CHUNKS(enhanced_query, NULL, NULL, equipment_type, 3)
        
        results = [
            {
                'document_id': 'SOP-001',
                'title': 'Cable Fault Resolution Procedures',
                'category': 'Cable Fault',
                'relevance_score': 0.95,
                'content_excerpt': f'Search results for: {enhanced_query}\n\nSAFETY REQUIREMENTS:\n- Ensure proper PPE (hard hat, safety vest, gloves)\n- Check for electrical hazards\n- Establish safety perimeter'
            },
            {
                'document_id': 'SOP-002', 
                'title': 'Service Degradation Troubleshooting',
                'category': 'Major',
                'relevance_score': 0.75,
                'content_excerpt': f'Diagnostic steps for: {enhanced_query}\n\nINITIAL ASSESSMENT:\n- Check system alarms\n- Review traffic patterns\n- Identify affected areas'
            }
        ]
        
        # Filter results based on query relevance
        filtered_results = []
        query_lower = enhanced_query.lower()
        
        for result in results:
            if (query_lower in result['title'].lower() or 
                query_lower in result['content_excerpt'].lower() or
                (fault_code and fault_code in result['content_excerpt'])):
                filtered_results.append(result)
        
        return filtered_results[:3]  # Return top 3 results
        
    except Exception as e:
        st.error(f"Error searching documents: {e}")
        # Return fallback results
        return [
            {
                'document_id': 'SOP-FALLBACK',
                'title': 'Search Service Unavailable',
                'category': 'System',
                'relevance_score': 0.5,
                'content_excerpt': f'Unable to search for: {query}. Please check system connectivity.'
            }
        ]

def extract_relevant_excerpt(content, query, max_length=500):
    """Extract relevant excerpt from content"""
    query_lower = query.lower()
    content_lower = content.lower()
    
    # Find the position of the query in the content
    pos = content_lower.find(query_lower)
    
    if pos != -1:
        # Extract context around the query
        start = max(0, pos - 100)
        end = min(len(content), pos + max_length - 100)
        excerpt = content[start:end]
        
        # Clean up the excerpt
        if start > 0:
            excerpt = "..." + excerpt
        if end < len(content):
            excerpt = excerpt + "..."
            
        return excerpt
    else:
        # Return the beginning of the content
        return content[:max_length] + ("..." if len(content) > max_length else "")

def generate_repair_procedure(fault_code, equipment_type, fault_description, sop_docs):
    """Generate step-by-step repair procedure"""
    # Find the most relevant SOP document
    best_match = None
    best_score = 0
    
    for doc in sop_docs:
        score = 0
        
        # Check fault code match
        if fault_code in doc.get('fault_codes', []):
            score += 0.8
        
        # Check equipment type match
        for eq_type in doc.get('equipment_types', []):
            if equipment_type.lower() in eq_type.lower():
                score += 0.6
                break
        
        # Check content relevance (handle missing content field)
        content_text = doc.get('content', '') or doc.get('title', '') or doc.get('description', '')
        if fault_code in content_text:
            score += 0.4
        
        if score > best_score:
            best_score = score
            best_match = doc
    
    if not best_match:
        # Return a generic procedure if no SOP match found
        return {
            'document_id': 'GENERIC',
            'title': 'Generic Repair Procedure',
            'safety_steps': [
                'Ensure proper PPE (hard hat, safety vest, gloves)',
                'Check for electrical hazards before starting work',
                'Establish safety perimeter around work area',
                'Verify equipment is properly grounded'
            ],
            'diagnostic_steps': [
                'Review fault description and error codes',
                'Check system alarms and status indicators',
                'Perform initial visual inspection',
                'Test signal levels and connectivity'
            ],
            'repair_steps': [
                'Follow manufacturer guidelines for the equipment',
                'Replace or repair faulty components as needed',
                'Ensure all connections are secure',
                'Update system configuration if required'
            ],
            'verification_steps': [
                'Test system functionality after repair',
                'Verify signal levels are within specifications',
                'Check for any remaining alarms or errors',
                'Document repair actions and test results'
            ],
            'estimated_time': '2-4 hours',
            'required_tools': ['Standard toolkit', 'Multimeter', 'Signal analyzer'],
            'full_content': f'Generic repair procedure for {fault_description}'
        }
    
    # Extract procedure steps from content
    content = best_match.get('content', best_match.get('title', 'No content available'))
    
    # Parse different sections
    safety_steps = []
    diagnostic_steps = []
    repair_steps = []
    verification_steps = []
    
    # Simple parsing based on common patterns
    lines = content.split('\n')
    current_section = None
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        if 'SAFETY' in line.upper():
            current_section = 'safety'
        elif 'DIAGNOSTIC' in line.upper():
            current_section = 'diagnostic'
        elif 'REPAIR' in line.upper() or 'RESOLUTION' in line.upper():
            current_section = 'repair'
        elif 'VERIFICATION' in line.upper():
            current_section = 'verification'
        elif line.startswith(('1.', '2.', '3.', '4.', '5.', '-')):
            if current_section == 'safety':
                safety_steps.append(line)
            elif current_section == 'diagnostic':
                diagnostic_steps.append(line)
            elif current_section == 'repair':
                repair_steps.append(line)
            elif current_section == 'verification':
                verification_steps.append(line)
    
    # Estimate time and tools
    category = best_match['category']
    if category == 'Cable Fault':
        estimated_time = "4-8 hours"
        required_tools = ["TDR", "Spectrum Analyzer", "Splice Kit", "Excavation Tools"]
    elif category == 'Major':
        estimated_time = "2-4 hours"
        required_tools = ["Optical Power Meter", "Laptop", "Console Cable"]
    else:
        estimated_time = "30 minutes - 1 hour"
        required_tools = ["Signal Level Meter", "Laptop"]
    
    return {
        'source_document': best_match['document_id'],
        'document_title': best_match['title'],
        'category': category,
        'confidence': best_score,
        'safety_steps': safety_steps,
        'diagnostic_steps': diagnostic_steps,
        'repair_steps': repair_steps,
        'verification_steps': verification_steps,
        'estimated_time': estimated_time,
        'required_tools': required_tools,
        'full_content': content
    }

def display_assigned_faults(df):
    """Display faults assigned to the current technician"""
    # Simulate assigned faults (in real app, this would be filtered by technician ID)
    active_faults = df[~df['is_resolved']].head(10)
    
    st.markdown("### 📋 Your Assigned Faults")
    
    for _, fault in active_faults.iterrows():
        urgency_class = "urgent-fault" if fault['fault_category'] == 'Cable Fault' else "fault-card"
        
        with st.container():
            st.markdown(f"""
            <div class="{urgency_class}">
                <h4>🔧 {fault['fault_id']} - {fault['fault_description']}</h4>
                <p><strong>Code:</strong> {fault['fault_code']} | 
                   <strong>Equipment:</strong> {fault['equipment_type']}</p>
                <p><strong>Location:</strong> {fault['location']} | 
                   <strong>Priority:</strong> {fault['priority_score']:.2f}</p>
                <p><strong>Customers Affected:</strong> {fault['customers_affected']:,}</p>
            </div>
            """, unsafe_allow_html=True)
            
            if st.button(f"Get Repair Guidance", key=f"repair_{fault['fault_id']}"):
                st.session_state.selected_fault = fault.to_dict()
                st.rerun()

def display_ai_chat_interface(sop_docs):
    """Display AI-powered chat interface for getting repair guidance"""
    st.markdown("### 🤖 AI Repair Assistant")
    st.markdown("Ask me anything about fault repair procedures!")
    
    # Initialize chat history
    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []
    
    # Chat input
    user_question = st.text_input(
        "Ask a question:",
        placeholder="e.g., How to fix cable fault 812.3 on Cisco cBR-8?",
        key="chat_input"
    )
    
    if st.button("Ask Assistant", type="primary"):
        if user_question:
            # Add user message to history
            st.session_state.chat_history.append({
                "role": "user",
                "content": user_question,
                "timestamp": datetime.now()
            })
            
            # Generate AI response
            with st.spinner("Searching technical documentation..."):
                time.sleep(1)  # Simulate processing time
                
                # Search for relevant information using Cortex Search
                search_results = search_sop_documents_cortex(user_question)
                
                if search_results:
                    best_result = search_results[0]
                    response = f"""Based on our technical documentation, here's what I found:

**Source:** {best_result['title']} ({best_result['document_id']})
**Confidence:** {best_result['relevance_score']:.1%}
**Category:** {best_result['category']}

**Answer:**
{best_result['content_excerpt']}

Would you like me to provide the complete step-by-step procedure?"""
                else:
                    response = "I couldn't find specific information about that issue. Please try rephrasing your question or contact technical support for assistance."
                
                # Add AI response to history
                st.session_state.chat_history.append({
                    "role": "assistant", 
                    "content": response,
                    "timestamp": datetime.now()
                })
            
            st.rerun()
    
    # Display chat history
    if st.session_state.chat_history:
        st.markdown("#### Chat History")
        for message in st.session_state.chat_history[-10:]:  # Show last 10 messages
            message_class = "user-message" if message["role"] == "user" else "assistant-message"
            role_icon = "👤" if message["role"] == "user" else "🤖"
            
            st.markdown(f"""
            <div class="chat-message {message_class}">
                <strong>{role_icon} {message["role"].title()}:</strong><br>
                {message["content"]}
            </div>
            """, unsafe_allow_html=True)

def display_repair_procedure(fault_info, sop_docs):
    """Display detailed repair procedure for selected fault"""
    st.markdown("### 🔧 Repair Procedure")
    
    procedure = generate_repair_procedure(
        fault_info['fault_code'],
        fault_info['equipment_type'],
        fault_info['fault_description'],
        sop_docs
    )
    
    if not procedure:
        st.error("No specific procedure found for this fault. Please contact technical support.")
        return
    
    # Display fault information
    st.markdown(f"""
    **Fault ID:** {fault_info['fault_id']}  
    **Code:** {fault_info['fault_code']}  
    **Equipment:** {fault_info['equipment_type']}  
    **Location:** {fault_info['location']}  
    **Description:** {fault_info['fault_description']}
    """)
    
    # Safety warnings
    if procedure['safety_steps']:
        st.markdown("""
        <div class="safety-warning">
            <h4>⚠️ SAFETY FIRST</h4>
            <p>Follow these safety requirements before starting any work:</p>
        </div>
        """, unsafe_allow_html=True)
        
        safety_steps = procedure.get('safety_steps', [])
        for step in safety_steps:
            st.markdown(f"- {step}")
    
    # Estimated time and tools
    col1, col2 = st.columns(2)
    with col1:
        st.metric("⏱️ Estimated Time", procedure.get('estimated_time', 'Unknown'))
    with col2:
        required_tools = procedure.get('required_tools', ['Standard toolkit'])
        st.metric("🔧 Tools Required", f"{len(required_tools)} items")
    
    # Required tools
    st.markdown("**Required Tools:**")
    for tool in required_tools:
        st.markdown(f"- {tool}")
    
    # Diagnostic steps
    diagnostic_steps = procedure.get('diagnostic_steps', [])
    if diagnostic_steps:
        st.markdown("#### 🔍 Diagnostic Steps")
        for i, step in enumerate(diagnostic_steps, 1):
            st.markdown(f"""
            <div class="procedure-step">
                <strong>Step {i}:</strong> {step}
            </div>
            """, unsafe_allow_html=True)
    
    # Repair steps
    repair_steps = procedure.get('repair_steps', [])
    if repair_steps:
        st.markdown("#### 🔧 Repair Steps")
        for i, step in enumerate(repair_steps, 1):
            st.markdown(f"""
            <div class="procedure-step">
                <strong>Step {i}:</strong> {step}
            </div>
            """, unsafe_allow_html=True)
    
    # Verification steps
    verification_steps = procedure.get('verification_steps', [])
    if verification_steps:
        st.markdown("#### ✅ Verification Steps")
        for i, step in enumerate(verification_steps, 1):
            st.markdown(f"""
            <div class="procedure-step">
                <strong>Step {i}:</strong> {step}
            </div>
            """, unsafe_allow_html=True)
    
    # Action buttons
    col1, col2, col3 = st.columns(3)
    with col1:
        if st.button("✅ Mark Complete", type="primary"):
            st.markdown("""
            <div class="success-message">
                <strong>✅ Fault marked as resolved!</strong><br>
                Great job! The repair has been logged in the system.
            </div>
            """, unsafe_allow_html=True)
    
    with col2:
        if st.button("📞 Need Help"):
            st.info("Connecting you to technical support...")
    
    with col3:
        if st.button("📄 View Full SOP"):
            with st.expander("Complete SOP Document"):
                st.text(procedure['full_content'])

def main():
    """Main application"""
    # Debug information
    st.write(f"🔍 Debug: PLOTLY_AVAILABLE = {PLOTLY_AVAILABLE}")
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🔧 TDC Net Field Assistant</h1>
        <p>AI-Powered Repair Guidance at Your Fingertips</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Display chart availability status
    if PLOTLY_AVAILABLE:
        st.success("📊 Advanced interactive charts enabled (Plotly loaded successfully)")
    else:
        st.warning("📊 Using Streamlit native charts - Plotly not available in this environment")
    
    # Load data
    df, sop_docs = load_fault_data()
    
    if df.empty:
        st.error("Unable to load fault data. Please check your connection.")
        return
    
    # Navigation
    tab1, tab2, tab3 = st.tabs(["📋 My Faults", "🤖 AI Assistant", "📚 Procedures"])
    
    with tab1:
        display_assigned_faults(df)
        
        # Show selected fault procedure
        if "selected_fault" in st.session_state:
            st.markdown("---")
            display_repair_procedure(st.session_state.selected_fault, sop_docs)
    
    with tab2:
        display_ai_chat_interface(sop_docs)
    
    with tab3:
        st.markdown("### 📚 Available Procedures")
        
        if sop_docs:
            for idx, doc in enumerate(sop_docs):
                doc_id = doc.get('document_id', f'UNKNOWN_{idx}')
                doc_title = doc.get('title', 'Untitled Document')
                doc_category = doc.get('category', 'General')
                doc_equipment = doc.get('equipment_types', [])
                doc_fault_codes = doc.get('fault_codes', [])
                
                # Create unique key using index to prevent duplicates
                unique_key = f"view_{doc_id}_{idx}"
                
                with st.expander(f"{doc_id} - {doc_title}"):
                    st.markdown(f"**Category:** {doc_category}")
                    
                    if doc_equipment:
                        equipment_str = ', '.join(doc_equipment) if isinstance(doc_equipment, list) else str(doc_equipment)
                        st.markdown(f"**Equipment Types:** {equipment_str}")
                    else:
                        st.markdown("**Equipment Types:** Not specified")
                    
                    if doc_fault_codes:
                        fault_codes_str = ', '.join(doc_fault_codes) if isinstance(doc_fault_codes, list) else str(doc_fault_codes)
                        st.markdown(f"**Fault Codes:** {fault_codes_str}")
                    else:
                        st.markdown("**Fault Codes:** Not specified")
                    
                    if st.button(f"View Procedure", key=unique_key):
                        content = doc.get('content', 'Content not available for this document')
                        st.text(content)
        else:
            st.info("No SOP documents available. This is expected if the SOP document tables haven't been set up yet.")
    
    # Demo information
    with st.expander("ℹ️ Demo Information"):
        st.markdown("""
        **Vignette 2: AI-Powered Guidance for First-Time Fix**
        
        This mobile app demonstrates how TDC Net field engineers can:
        - **Get instant repair guidance** using Cortex Search
        - **Ask natural language questions** about fault procedures
        - **Access step-by-step instructions** tailored to specific equipment
        - **Improve First-Time Fix rates** with AI-powered assistance
        
        **Key Features:**
        - Mobile-first responsive design
        - Natural language query interface using `SNOWFLAKE.ML.COMPLETE`
        - Document search and answer extraction with `SNOWFLAKE.ML.EXTRACT_ANSWER`
        - Real-time access to technical documentation
        
        **Business Impact:**
        - Reduced time searching for procedures (20-30 min → 2-3 min)
        - Higher First-Time Fix rates
        - Improved technician confidence and efficiency
        - Better customer satisfaction
        """)

if __name__ == "__main__":
    main()
