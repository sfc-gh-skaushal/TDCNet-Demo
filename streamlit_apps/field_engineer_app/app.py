"""
TDC Net Field Engineer Assistant - Vignette 2: AI-Powered Field Guidance
Mobile-first Streamlit application for field engineers to get instant repair guidance
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
from datetime import datetime
import time

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

# Load sample data
@st.cache_data
def load_fault_data():
    """Load fault data and SOP documents"""
    try:
        # Load fault data
        df = pd.read_csv('/Users/siddharthkaushal/TDCNet Demo/data/sample_fault_logs/network_faults.csv')
        df['fault_timestamp'] = pd.to_datetime(df['fault_timestamp'])
        df['is_resolved'] = df['resolution_timestamp'].notna()
        
        # Load SOP documents
        sop_docs = []
        sop_files = [
            'SOP-001_Cable_Fault_Resolution_Procedures.json',
            'SOP-002_Service_Degradation_Troubleshooting.json',
            'SOP-003_Signal_Level_Adjustment_Procedures.json'
        ]
        
        for filename in sop_files:
            try:
                with open(f'/Users/siddharthkaushal/TDCNet Demo/data/sample_sop_documents/{filename}', 'r') as f:
                    sop_docs.append(json.load(f))
            except FileNotFoundError:
                continue
        
        return df, sop_docs
    except Exception as e:
        st.error(f"Error loading data: {e}")
        return pd.DataFrame(), []

def search_sop_documents_cortex(query, fault_code=None, equipment_type=None):
    """Search SOP documents using Cortex Search (simulated for local demo)"""
    # In real Snowflake environment, this would call:
    # SELECT * FROM TABLE(SEARCH_SOP_DOCUMENTS(query, category, limit))
    
    # For local demo, simulate Cortex Search results
    enhanced_query = query
    if fault_code:
        enhanced_query += f" {fault_code}"
    if equipment_type:
        enhanced_query += f" {equipment_type}"
    
    # Simulate AI-powered search results with higher relevance
    results = [
        {
            'document_id': 'SOP-001',
            'title': 'Cable Fault Resolution Procedures',
            'category': 'Cable Fault',
            'relevance_score': 0.95,
            'content_excerpt': 'CABLE FAULT RESOLUTION - ERROR CODE 812.3\n\nSAFETY FIRST:\n1. Ensure proper PPE...'
        },
        {
            'document_id': 'SOP-002', 
            'title': 'Service Degradation Troubleshooting',
            'category': 'Major',
            'relevance_score': 0.75,
            'content_excerpt': 'SERVICE DEGRADATION RESOLUTION - ERROR CODE 600.1\n\nINITIAL ASSESSMENT...'
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
        
        # Check content relevance
        if fault_code in doc['content']:
            score += 0.4
        
        if score > best_score:
            best_score = score
            best_match = doc
    
    if not best_match:
        return None
    
    # Extract procedure steps from content
    content = best_match['content']
    
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
        
        for step in procedure['safety_steps']:
            st.markdown(f"- {step}")
    
    # Estimated time and tools
    col1, col2 = st.columns(2)
    with col1:
        st.metric("⏱️ Estimated Time", procedure['estimated_time'])
    with col2:
        st.metric("🔧 Tools Required", f"{len(procedure['required_tools'])} items")
    
    # Required tools
    st.markdown("**Required Tools:**")
    for tool in procedure['required_tools']:
        st.markdown(f"- {tool}")
    
    # Diagnostic steps
    if procedure['diagnostic_steps']:
        st.markdown("#### 🔍 Diagnostic Steps")
        for i, step in enumerate(procedure['diagnostic_steps'], 1):
            st.markdown(f"""
            <div class="procedure-step">
                <strong>Step {i}:</strong> {step}
            </div>
            """, unsafe_allow_html=True)
    
    # Repair steps
    if procedure['repair_steps']:
        st.markdown("#### 🔧 Repair Steps")
        for i, step in enumerate(procedure['repair_steps'], 1):
            st.markdown(f"""
            <div class="procedure-step">
                <strong>Step {i}:</strong> {step}
            </div>
            """, unsafe_allow_html=True)
    
    # Verification steps
    if procedure['verification_steps']:
        st.markdown("#### ✅ Verification Steps")
        for i, step in enumerate(procedure['verification_steps'], 1):
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
    # Header
    st.markdown("""
    <div class="main-header">
        <h1>🔧 TDC Net Field Assistant</h1>
        <p>AI-Powered Repair Guidance at Your Fingertips</p>
    </div>
    """, unsafe_allow_html=True)
    
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
        
        for doc in sop_docs:
            with st.expander(f"{doc['document_id']} - {doc['title']}"):
                st.markdown(f"**Category:** {doc['category']}")
                st.markdown(f"**Equipment Types:** {', '.join(doc['equipment_types'])}")
                st.markdown(f"**Fault Codes:** {', '.join(doc['fault_codes'])}")
                
                if st.button(f"View Procedure", key=f"view_{doc['document_id']}"):
                    st.text(doc['content'])
    
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
