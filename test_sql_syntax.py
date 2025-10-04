#!/usr/bin/env python3
"""
Simple SQL syntax validation for TDC Net demo scripts
Checks for common syntax issues that might cause compilation errors
"""

import os
import re

def check_sql_file(filepath):
    """Check SQL file for common syntax issues"""
    print(f"\n🔍 Checking {filepath}:")
    
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        issues = []
        
        # Check for GENERATED ALWAYS AS syntax (not supported in all Snowflake versions)
        if 'GENERATED ALWAYS AS' in content:
            issues.append("❌ GENERATED ALWAYS AS syntax found (may not be supported)")
        
        # Check for unmatched parentheses
        open_parens = content.count('(')
        close_parens = content.count(')')
        if open_parens != close_parens:
            issues.append(f"❌ Unmatched parentheses: {open_parens} open, {close_parens} close")
        
        # Check for common SQL syntax patterns
        if re.search(r'CREATE\s+TABLE.*\(\s*$', content, re.MULTILINE | re.IGNORECASE):
            issues.append("⚠️ Possible incomplete CREATE TABLE statement")
        
        # Check for proper statement termination
        statements = [s.strip() for s in content.split(';') if s.strip()]
        for i, stmt in enumerate(statements):
            if stmt and not stmt.upper().startswith(('--', '/*')):
                # Check if statement looks complete
                if not any(keyword in stmt.upper() for keyword in ['CREATE', 'INSERT', 'SELECT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'SHOW', 'USE']):
                    if len(stmt) > 20:  # Ignore short comments
                        issues.append(f"⚠️ Statement {i+1} may be incomplete: {stmt[:50]}...")
        
        if not issues:
            print("   ✅ No syntax issues detected")
        else:
            for issue in issues:
                print(f"   {issue}")
                
        return len(issues) == 0
        
    except Exception as e:
        print(f"   ❌ Error reading file: {e}")
        return False

def main():
    """Check all SQL files in the project"""
    print("🔧 TDC Net Demo - SQL Syntax Validation")
    print("=" * 50)
    
    sql_files = [
        "sql/setup/01_database_setup.sql",
        "sql/setup/02_table_creation.sql", 
        "sql/data_loading/load_fault_data.sql",
        "sql/data_loading/load_sop_documents.sql",
        "sql/cortex_models/fault_classification.sql",
        "sql/cortex_models/cortex_search_setup.sql"
    ]
    
    all_good = True
    for sql_file in sql_files:
        if os.path.exists(sql_file):
            if not check_sql_file(sql_file):
                all_good = False
        else:
            print(f"\n❌ File not found: {sql_file}")
            all_good = False
    
    print("\n" + "=" * 50)
    if all_good:
        print("✅ All SQL files passed syntax validation!")
    else:
        print("❌ Some SQL files have potential issues - please review")
    
    print("\n📝 Note: This is a basic syntax check. Full validation requires Snowflake execution.")

if __name__ == "__main__":
    main()
