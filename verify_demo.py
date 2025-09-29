#!/usr/bin/env python3
"""
TDC Net Demo Verification Script
Verifies that all demo components are properly set up and functional
"""

import os
import pandas as pd
import json
from pathlib import Path

def check_file_exists(filepath, description):
    """Check if a file exists and report status"""
    if os.path.exists(filepath):
        print(f"✅ {description}: {filepath}")
        return True
    else:
        print(f"❌ {description}: {filepath} - NOT FOUND")
        return False

def check_data_quality():
    """Verify sample data quality and completeness"""
    print("\n📊 Data Quality Verification:")
    
    # Check fault data
    fault_file = "data/sample_fault_logs/network_faults.csv"
    if check_file_exists(fault_file, "Network fault data"):
        try:
            df = pd.read_csv(fault_file)
            print(f"   - Records: {len(df)}")
            print(f"   - Fault categories: {df['fault_category'].value_counts().to_dict()}")
            print(f"   - Network types: {df['network_type'].value_counts().to_dict()}")
            print(f"   - First-time fix rate: {df['first_time_fix'].mean():.2%}")
            
            # Check for required columns
            required_columns = [
                'fault_id', 'fault_code', 'fault_category', 'network_type',
                'equipment_type', 'location', 'customers_affected', 'priority_score'
            ]
            missing_columns = [col for col in required_columns if col not in df.columns]
            if missing_columns:
                print(f"   ❌ Missing columns: {missing_columns}")
            else:
                print("   ✅ All required columns present")
                
        except Exception as e:
            print(f"   ❌ Error reading fault data: {e}")
    
    # Check SOP documents
    sop_dir = "data/sample_sop_documents"
    if os.path.exists(sop_dir):
        sop_files = [f for f in os.listdir(sop_dir) if f.endswith('.json')]
        print(f"   - SOP documents: {len(sop_files)}")
        
        for sop_file in sop_files:
            try:
                with open(os.path.join(sop_dir, sop_file), 'r') as f:
                    doc = json.load(f)
                    required_fields = ['document_id', 'title', 'category', 'content']
                    if all(field in doc for field in required_fields):
                        print(f"   ✅ {sop_file}: Valid structure")
                    else:
                        print(f"   ❌ {sop_file}: Missing required fields")
            except Exception as e:
                print(f"   ❌ {sop_file}: Error reading - {e}")

def check_sql_scripts():
    """Verify SQL scripts are present and properly structured"""
    print("\n🗄️ SQL Scripts Verification:")
    
    sql_files = [
        ("sql/setup/01_database_setup.sql", "Database setup script"),
        ("sql/setup/02_table_creation.sql", "Table creation script"),
        ("sql/data_loading/load_fault_data.sql", "Fault data loading script"),
        ("sql/data_loading/load_sop_documents.sql", "SOP document loading script"),
        ("sql/cortex_models/fault_classification.sql", "Fault classification model"),
        ("sql/cortex_models/cortex_search_setup.sql", "Cortex Search setup")
    ]
    
    all_present = True
    for filepath, description in sql_files:
        if not check_file_exists(filepath, description):
            all_present = False
    
    if all_present:
        print("   ✅ All SQL scripts present")
    else:
        print("   ❌ Some SQL scripts missing")

def check_streamlit_apps():
    """Verify Streamlit applications are properly structured"""
    print("\n📱 Streamlit Applications Verification:")
    
    apps = [
        ("streamlit_apps/manager_dashboard/app.py", "Manager Dashboard"),
        ("streamlit_apps/field_engineer_app/app.py", "Field Engineer App")
    ]
    
    for app_path, app_name in apps:
        if check_file_exists(app_path, f"{app_name} main file"):
            # Check for required imports
            try:
                with open(app_path, 'r') as f:
                    content = f.read()
                    required_imports = ['streamlit', 'pandas', 'plotly']
                    missing_imports = [imp for imp in required_imports if f"import {imp}" not in content]
                    
                    if missing_imports:
                        print(f"   ⚠️ {app_name}: Missing imports - {missing_imports}")
                    else:
                        print(f"   ✅ {app_name}: Required imports present")
                        
                    # Check for main function
                    if 'def main():' in content:
                        print(f"   ✅ {app_name}: Main function found")
                    else:
                        print(f"   ⚠️ {app_name}: Main function not found")
                        
            except Exception as e:
                print(f"   ❌ {app_name}: Error reading file - {e}")

def check_demo_documentation():
    """Verify demo documentation is complete"""
    print("\n📚 Documentation Verification:")
    
    docs = [
        ("README.md", "Project README"),
        ("DEMO_SUMMARY.md", "Demo summary document"),
        ("demo_scripts/presentation_flow.md", "Presentation flow script"),
        ("demo_scripts/setup_instructions.md", "Setup instructions"),
        ("demo_scripts/demo_checklist.md", "Demo checklist")
    ]
    
    all_present = True
    for filepath, description in docs:
        if not check_file_exists(filepath, description):
            all_present = False
    
    if all_present:
        print("   ✅ All documentation present")

def check_dependencies():
    """Check if required Python packages are available"""
    print("\n📦 Dependencies Verification:")
    
    required_packages = ['pandas', 'numpy', 'faker', 'streamlit', 'plotly']
    
    for package in required_packages:
        try:
            __import__(package)
            print(f"   ✅ {package}: Available")
        except ImportError:
            print(f"   ❌ {package}: Not installed")

def main():
    """Run all verification checks"""
    print("🔧 TDC Net Snowflake Demo Verification")
    print("=" * 50)
    
    # Change to project directory
    project_dir = Path(__file__).parent
    os.chdir(project_dir)
    
    # Run all checks
    check_data_quality()
    check_sql_scripts()
    check_streamlit_apps()
    check_demo_documentation()
    check_dependencies()
    
    print("\n" + "=" * 50)
    print("🎯 Demo Verification Complete!")
    print("\nNext Steps:")
    print("1. Set up Snowflake environment using sql/setup/ scripts")
    print("2. Load data using sql/data_loading/ scripts")
    print("3. Deploy Streamlit apps to Snowflake")
    print("4. Review demo_scripts/presentation_flow.md for demo execution")
    print("\n🚀 Ready to demonstrate TDC Net's AI-powered fault resolution!")

if __name__ == "__main__":
    main()
