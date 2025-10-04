#!/usr/bin/env python3
"""
Generate PDF SOP documents for TDC Net Snowflake Demo
Creates realistic PDF technical manuals for Cortex Search demonstration
"""

import json
import os
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from datetime import datetime

def create_pdf_from_sop(sop_data, output_path):
    """Create a PDF document from SOP data"""
    
    # Create PDF document
    doc = SimpleDocTemplate(output_path, pagesize=A4,
                          rightMargin=72, leftMargin=72,
                          topMargin=72, bottomMargin=18)
    
    # Get styles
    styles = getSampleStyleSheet()
    
    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=18,
        spaceAfter=30,
        alignment=TA_CENTER,
        textColor='darkblue'
    )
    
    header_style = ParagraphStyle(
        'CustomHeader',
        parent=styles['Heading2'],
        fontSize=14,
        spaceAfter=12,
        spaceBefore=20,
        textColor='darkred'
    )
    
    body_style = ParagraphStyle(
        'CustomBody',
        parent=styles['Normal'],
        fontSize=11,
        spaceAfter=6,
        alignment=TA_JUSTIFY
    )
    
    # Build document content
    story = []
    
    # Document header
    story.append(Paragraph("TDC NET", title_style))
    story.append(Paragraph("TECHNICAL OPERATIONS MANUAL", styles['Heading2']))
    story.append(Spacer(1, 20))
    
    # Document info
    story.append(Paragraph(f"<b>Document ID:</b> {sop_data['document_id']}", body_style))
    story.append(Paragraph(f"<b>Title:</b> {sop_data['title']}", body_style))
    story.append(Paragraph(f"<b>Category:</b> {sop_data['category']}", body_style))
    story.append(Paragraph(f"<b>Equipment Types:</b> {', '.join(sop_data['equipment_types'])}", body_style))
    story.append(Paragraph(f"<b>Applicable Fault Codes:</b> {', '.join(sop_data['fault_codes'])}", body_style))
    story.append(Paragraph(f"<b>Last Updated:</b> {datetime.now().strftime('%Y-%m-%d')}", body_style))
    story.append(Spacer(1, 20))
    
    # Process content sections
    content = sop_data['content'].strip()
    sections = content.split('\n\n')
    
    for section in sections:
        if not section.strip():
            continue
            
        lines = section.split('\n')
        section_title = lines[0].strip()
        
        # Check if this is a section header (all caps or ends with colon)
        if (section_title.isupper() and len(section_title) < 50) or section_title.endswith(':'):
            story.append(Paragraph(section_title, header_style))
            
            # Process remaining lines in section
            for line in lines[1:]:
                line = line.strip()
                if line:
                    # Format numbered lists and bullet points
                    if line.startswith(('1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.')):
                        story.append(Paragraph(f"<b>{line}</b>", body_style))
                    elif line.startswith('-'):
                        story.append(Paragraph(f"&nbsp;&nbsp;&nbsp;&nbsp;{line}", body_style))
                    else:
                        story.append(Paragraph(line, body_style))
        else:
            # Regular paragraph
            story.append(Paragraph(section, body_style))
        
        story.append(Spacer(1, 12))
    
    # Footer
    story.append(Spacer(1, 30))
    story.append(Paragraph("---", styles['Normal']))
    story.append(Paragraph("This document contains proprietary information of TDC Net.", 
                          styles['Normal']))
    story.append(Paragraph("Unauthorized distribution is prohibited.", styles['Normal']))
    
    # Build PDF
    doc.build(story)
    print(f"Created PDF: {output_path}")

def main():
    """Generate all PDF SOP documents"""
    print("Generating PDF SOP documents for TDC Net Demo...")
    
    # Create PDF output directory
    pdf_dir = "/Users/siddharthkaushal/TDCNet Demo/data/sample_sop_documents_pdf"
    os.makedirs(pdf_dir, exist_ok=True)
    
    # Load existing JSON SOP documents
    json_dir = "/Users/siddharthkaushal/TDCNet Demo/data/sample_sop_documents"
    json_files = [f for f in os.listdir(json_dir) if f.endswith('.json')]
    
    for json_file in json_files:
        try:
            # Load JSON data
            with open(os.path.join(json_dir, json_file), 'r') as f:
                sop_data = json.load(f)
            
            # Create PDF filename
            pdf_filename = json_file.replace('.json', '.pdf')
            pdf_path = os.path.join(pdf_dir, pdf_filename)
            
            # Generate PDF
            create_pdf_from_sop(sop_data, pdf_path)
            
        except Exception as e:
            print(f"Error processing {json_file}: {e}")
    
    # Create additional comprehensive PDF documents
    create_additional_sop_documents(pdf_dir)
    
    print(f"\nPDF generation complete! Files created in: {pdf_dir}")
    print("Files ready for upload to Snowflake stage.")

def create_additional_sop_documents(pdf_dir):
    """Create additional comprehensive SOP documents"""
    
    # Emergency Response SOP
    emergency_sop = {
        "document_id": "SOP-004",
        "title": "Emergency Network Response Procedures",
        "category": "Emergency",
        "equipment_types": ["All Network Equipment"],
        "fault_codes": ["EMERGENCY", "CRITICAL", "OUTAGE"],
        "content": """EMERGENCY NETWORK RESPONSE PROCEDURES

IMMEDIATE RESPONSE PROTOCOL:
1. Assess the scope and severity of the network outage
2. Activate the Emergency Response Team (ERT)
3. Establish communication with Network Operations Center (NOC)
4. Implement emergency communication procedures

SEVERITY CLASSIFICATION:
Level 1 - Critical: Complete network outage affecting >10,000 customers
Level 2 - Major: Significant service degradation affecting >1,000 customers  
Level 3 - Minor: Localized issues affecting <1,000 customers

ESCALATION PROCEDURES:
1. Level 1: Immediate executive notification required
2. Level 2: Management notification within 30 minutes
3. Level 3: Standard operational response

CUSTOMER COMMUNICATION:
1. Activate mass notification systems
2. Update customer service portals
3. Coordinate with public relations team
4. Provide regular status updates

RESOURCE MOBILIZATION:
1. Deploy emergency response vehicles
2. Activate backup power systems
3. Coordinate with external contractors
4. Establish temporary communication links

DOCUMENTATION REQUIREMENTS:
1. Maintain detailed incident log
2. Document all actions taken
3. Record timeline of events
4. Prepare post-incident analysis report"""
    }
    
    # Network Security SOP
    security_sop = {
        "document_id": "SOP-005", 
        "title": "Network Security Incident Response",
        "category": "Security",
        "equipment_types": ["Firewalls", "Routers", "Switches", "Monitoring Systems"],
        "fault_codes": ["SEC-001", "SEC-002", "SEC-003"],
        "content": """NETWORK SECURITY INCIDENT RESPONSE

SECURITY THREAT IDENTIFICATION:
1. Monitor security alerts and anomalies
2. Analyze traffic patterns for suspicious activity
3. Review access logs for unauthorized attempts
4. Coordinate with cybersecurity team

IMMEDIATE CONTAINMENT:
1. Isolate affected network segments
2. Block suspicious IP addresses
3. Disable compromised user accounts
4. Activate additional monitoring

INVESTIGATION PROCEDURES:
1. Preserve evidence for forensic analysis
2. Document all security events
3. Identify attack vectors and methods
4. Assess potential data exposure

RECOVERY ACTIONS:
1. Restore services from clean backups
2. Apply security patches and updates
3. Reset compromised credentials
4. Implement additional security controls

REPORTING REQUIREMENTS:
1. Notify regulatory authorities if required
2. Inform affected customers
3. Document lessons learned
4. Update security procedures"""
    }
    
    # Create PDFs for additional documents
    for sop_data in [emergency_sop, security_sop]:
        pdf_filename = f"{sop_data['document_id']}_{sop_data['title'].replace(' ', '_')}.pdf"
        pdf_path = os.path.join(pdf_dir, pdf_filename)
        create_pdf_from_sop(sop_data, pdf_path)

if __name__ == "__main__":
    main()
