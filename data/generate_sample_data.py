#!/usr/bin/env python3
"""
Generate realistic sample data for TDC Net Snowflake Demo
Creates network fault logs and SOP documents for demonstration purposes
"""

import pandas as pd
import random
import json
from datetime import datetime, timedelta
from faker import Faker
import os

fake = Faker()

# Configuration
NUM_FAULT_RECORDS = 1000
START_DATE = datetime.now() - timedelta(days=90)
END_DATE = datetime.now()

# Network equipment and fault types
EQUIPMENT_TYPES = {
    'COAX': ['Cisco cBR-8', 'Arris E6000', 'Casa C100G', 'Harmonic CableOS'],
    'FIBER': ['Nokia 7750', 'Juniper MX960', 'Cisco ASR9000', 'Huawei MA5800']
}

FAULT_CODES = {
    'Minor': {
        'codes': ['100.1', '200.2', '300.5', '400.1', '500.3'],
        'descriptions': [
            'Signal level deviation',
            'Minor packet loss detected',
            'Configuration drift',
            'Low bandwidth utilization',
            'Routine maintenance alert'
        ],
        'severity': 'Low',
        'customer_impact': 'Minimal'
    },
    'Major': {
        'codes': ['600.1', '700.2', '800.3', '900.1', '150.4'],
        'descriptions': [
            'Service degradation detected',
            'High error rate on interface',
            'Power supply fluctuation',
            'Temperature threshold exceeded',
            'Multiple customer complaints'
        ],
        'severity': 'Medium',
        'customer_impact': 'Moderate'
    },
    'Cable Fault': {
        'codes': ['812.3', '813.1', '814.2', '815.5', '816.1'],
        'descriptions': [
            'Cable cut detected',
            'Fiber break in main trunk',
            'Coax cable degradation',
            'Underground cable damage',
            'Aerial cable fault'
        ],
        'severity': 'High',
        'customer_impact': 'Severe'
    }
}

LOCATIONS = [
    'Copenhagen Central', 'Aarhus North', 'Odense West', 'Aalborg East',
    'Esbjerg South', 'Roskilde', 'Kolding', 'Horsens', 'Vejle', 'Silkeborg'
]

def generate_fault_logs():
    """Generate realistic network fault log data"""
    records = []
    
    for i in range(NUM_FAULT_RECORDS):
        # Randomly select fault category with weighted distribution
        # More minor faults, fewer cable faults (realistic)
        fault_category = random.choices(
            list(FAULT_CODES.keys()),
            weights=[60, 30, 10],  # 60% minor, 30% major, 10% cable faults
            k=1
        )[0]
        
        fault_info = FAULT_CODES[fault_category]
        fault_code = random.choice(fault_info['codes'])
        fault_description = random.choice(fault_info['descriptions'])
        
        # Select network type and equipment
        network_type = random.choice(['COAX', 'FIBER'])
        equipment = random.choice(EQUIPMENT_TYPES[network_type])
        
        # Generate timestamps
        fault_timestamp = fake.date_time_between(start_date=START_DATE, end_date=END_DATE)
        
        # Resolution time varies by fault type
        if fault_category == 'Minor':
            resolution_hours = random.uniform(0.5, 4)
        elif fault_category == 'Major':
            resolution_hours = random.uniform(2, 12)
        else:  # Cable Fault
            resolution_hours = random.uniform(8, 48)
            
        resolution_timestamp = fault_timestamp + timedelta(hours=resolution_hours)
        
        # Customer impact metrics
        if fault_category == 'Minor':
            customers_affected = random.randint(1, 50)
            service_calls = random.randint(0, 5)
        elif fault_category == 'Major':
            customers_affected = random.randint(50, 500)
            service_calls = random.randint(5, 50)
        else:  # Cable Fault
            customers_affected = random.randint(500, 5000)
            service_calls = random.randint(50, 500)
        
        # First time fix - cable faults have lower FTF rate
        if fault_category == 'Cable Fault':
            first_time_fix = random.choice([True, False]) if random.random() < 0.4 else False
        elif fault_category == 'Major':
            first_time_fix = random.choice([True, False]) if random.random() < 0.7 else False
        else:
            first_time_fix = random.choice([True, False]) if random.random() < 0.85 else False
        
        record = {
            'fault_id': f'F{i+1:06d}',
            'fault_timestamp': fault_timestamp.isoformat(),
            'fault_code': fault_code,
            'fault_description': fault_description,
            'fault_category': fault_category,
            'network_type': network_type,
            'equipment_type': equipment,
            'location': random.choice(LOCATIONS),
            'severity': fault_info['severity'],
            'customer_impact': fault_info['customer_impact'],
            'customers_affected': customers_affected,
            'service_calls_generated': service_calls,
            'resolution_timestamp': resolution_timestamp.isoformat() if resolution_timestamp <= END_DATE else None,
            'resolution_time_hours': round(resolution_hours, 2),
            'first_time_fix': first_time_fix,
            'technician_type_required': 'Specialist' if fault_category == 'Cable Fault' else 'General',
            'estimated_revenue_impact': customers_affected * random.uniform(10, 100),  # DKK per customer
            'priority_score': random.uniform(0.1, 1.0) if fault_category == 'Minor' else 
                            random.uniform(0.4, 0.8) if fault_category == 'Major' else 
                            random.uniform(0.7, 1.0)
        }
        
        records.append(record)
    
    return pd.DataFrame(records)

def generate_sop_documents():
    """Generate sample SOP documents content"""
    sop_documents = []
    
    # Cable Fault SOPs
    cable_fault_sop = {
        'document_id': 'SOP-001',
        'title': 'Cable Fault Resolution Procedures',
        'category': 'Cable Fault',
        'equipment_types': ['Cisco cBR-8', 'Arris E6000'],
        'fault_codes': ['812.3', '813.1', '814.2'],
        'content': """
CABLE FAULT RESOLUTION - ERROR CODE 812.3

SAFETY FIRST:
1. Ensure proper PPE (hard hat, safety vest, gloves)
2. Check for electrical hazards before accessing equipment
3. Notify traffic control if working near roadways

DIAGNOSTIC STEPS:
1. Verify fault code 812.3 on Cisco cBR-8 router display
2. Check signal levels using spectrum analyzer
   - Forward path: Should be -7 to +7 dBmV
   - Return path: Should be 16 to 54 dBmV
3. Perform cable continuity test using TDR (Time Domain Reflectometer)
4. Identify fault location within 2-meter accuracy

REPAIR PROCEDURE:
1. Isolate affected cable segment
2. If underground cable:
   - Contact utility marking service (mandatory)
   - Use cable locator to trace exact path
   - Excavate carefully using hand tools near cable
3. If aerial cable:
   - Inspect for physical damage, animal interference
   - Check guy wires and support structures
4. Replace damaged cable section with approved splice kit
5. Test signal integrity before restoration
6. Document GPS coordinates of repair location

VERIFICATION:
1. Confirm error code 812.3 clears from system
2. Test downstream signal levels at customer premises
3. Verify no packet loss over 15-minute test period
4. Update network topology database

ESTIMATED TIME: 4-8 hours depending on access complexity
REQUIRED SKILLS: Cable splicing certification, TDR operation
TOOLS REQUIRED: TDR, spectrum analyzer, splice kit, excavation tools
        """
    }
    
    # Major Fault SOP
    major_fault_sop = {
        'document_id': 'SOP-002',
        'title': 'Service Degradation Troubleshooting',
        'category': 'Major',
        'equipment_types': ['Nokia 7750', 'Juniper MX960'],
        'fault_codes': ['600.1', '700.2', '800.3'],
        'content': """
SERVICE DEGRADATION RESOLUTION - ERROR CODE 600.1

INITIAL ASSESSMENT:
1. Check system alarms on Nokia 7750 SR router
2. Review traffic patterns for last 24 hours
3. Identify affected service areas and customer count
4. Determine if issue is localized or widespread

DIAGNOSTIC PROCEDURE:
1. Access router CLI and run diagnostic commands:
   - show router interface
   - show router bgp summary
   - show router ospf neighbor
2. Check interface utilization and error counters
3. Verify routing table consistency
4. Test connectivity to upstream providers

RESOLUTION STEPS:
1. If interface errors detected:
   - Clean fiber connections
   - Replace suspect SFP modules
   - Check cable integrity
2. If routing issues identified:
   - Restart BGP sessions if necessary
   - Verify route advertisements
   - Check for configuration drift
3. If hardware issues suspected:
   - Schedule maintenance window
   - Prepare backup equipment
   - Coordinate with NOC for traffic rerouting

MONITORING:
1. Monitor interface statistics for 30 minutes
2. Verify customer service restoration
3. Check for recurring alarms
4. Update incident tracking system

ESTIMATED TIME: 2-4 hours
REQUIRED SKILLS: Router configuration, fiber optics
TOOLS REQUIRED: Optical power meter, laptop with console access
        """
    }
    
    # Minor Fault SOP
    minor_fault_sop = {
        'document_id': 'SOP-003',
        'title': 'Signal Level Adjustment Procedures',
        'category': 'Minor',
        'equipment_types': ['Casa C100G', 'Harmonic CableOS'],
        'fault_codes': ['100.1', '200.2', '300.5'],
        'content': """
SIGNAL LEVEL DEVIATION - ERROR CODE 100.1

OVERVIEW:
Signal level deviations are common and usually indicate minor equipment drift
or environmental changes. These issues rarely affect customer service but
should be corrected to prevent escalation.

QUICK DIAGNOSTIC:
1. Check current signal levels on Casa C100G CMTS
2. Compare with baseline measurements from last maintenance
3. Identify if deviation is upstream or downstream
4. Check weather conditions and temperature logs

ADJUSTMENT PROCEDURE:
1. Access CMTS web interface or CLI
2. Navigate to RF configuration section
3. For downstream adjustment:
   - Modify output level in 0.5 dB increments
   - Target range: 45-50 dBmV at amplifier output
4. For upstream adjustment:
   - Adjust input attenuator settings
   - Target range: 0 to -10 dBmV at CMTS input
5. Allow 5 minutes for system stabilization
6. Verify modem registration levels

VERIFICATION:
1. Confirm error code 100.1 clears within 10 minutes
2. Check that all modems remain online
3. Verify no new alarms generated
4. Document changes in maintenance log

ESTIMATED TIME: 30 minutes to 1 hour
REQUIRED SKILLS: Basic RF knowledge, CMTS operation
TOOLS REQUIRED: Signal level meter, laptop
        """
    }
    
    sop_documents = [cable_fault_sop, major_fault_sop, minor_fault_sop]
    
    return sop_documents

def main():
    """Generate all sample data files"""
    print("Generating TDC Net demo sample data...")
    
    # Create fault logs
    print("Creating network fault logs...")
    fault_df = generate_fault_logs()
    fault_df.to_csv('/Users/siddharthkaushal/TDCNet Demo/data/sample_fault_logs/network_faults.csv', index=False)
    print(f"Generated {len(fault_df)} fault records")
    
    # Create SOP documents
    print("Creating SOP documents...")
    sop_docs = generate_sop_documents()
    
    for doc in sop_docs:
        filename = f"/Users/siddharthkaushal/TDCNet Demo/data/sample_sop_documents/{doc['document_id']}_{doc['title'].replace(' ', '_')}.json"
        with open(filename, 'w') as f:
            json.dump(doc, f, indent=2)
    
    print(f"Generated {len(sop_docs)} SOP documents")
    
    # Create summary statistics
    print("\nData Summary:")
    print(f"Total fault records: {len(fault_df)}")
    print(f"Fault categories: {fault_df['fault_category'].value_counts().to_dict()}")
    print(f"Network types: {fault_df['network_type'].value_counts().to_dict()}")
    print(f"First-time fix rate: {fault_df['first_time_fix'].mean():.2%}")
    print(f"Average resolution time: {fault_df['resolution_time_hours'].mean():.1f} hours")
    
    print("\nSample data generation complete!")

if __name__ == "__main__":
    main()
