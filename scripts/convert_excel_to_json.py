#!/usr/bin/env python3
"""
Script to convert Excel files to JSON for Flutter app.
Converts LCS and TS sheets from lcschainage1.xlsm to JSON format.
"""

import pandas as pd
import json
import sys
import os
from pathlib import Path

def convert_lcs_ts_sheets():
    """Convert LCS and TS sheets from Excel to JSON."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    excel_path = project_root / "assets" / "extra" / "lcschainage1.xlsm"
    output_dir = project_root / "assets" / "data"
    
    if not excel_path.exists():
        print(f"Error: Excel file not found at {excel_path}")
        return False
    
    try:
        # Read LCS sheet
        print("Reading LCS sheet...")
        lcs_df = pd.read_excel(excel_path, sheet_name="LCS", engine="openpyxl")
        
        # Clean column names and select relevant columns
        lcs_df.columns = lcs_df.columns.str.strip()
        
        # Map column names (handle variations)
        column_mapping = {}
        for col in lcs_df.columns:
            col_clean = col.strip().replace('\n', ' ').replace('\r', ' ')
            if 'CURRENT' in col_clean.upper() and 'LCS' in col_clean.upper():
                column_mapping[col] = 'currentLcsCode'
            elif 'LEGACY' in col_clean.upper() and 'LCS' in col_clean.upper():
                column_mapping[col] = 'legacyLcsCode'
            elif col_clean.upper() == 'VCC':
                column_mapping[col] = 'vcc'
            elif col_clean == 'Chainage' and 'Chainage.1' not in lcs_df.columns:
                column_mapping[col] = 'chainageStart'
            elif col_clean == 'Chainage.1' or col_clean == 'Chainage End':
                column_mapping[col] = 'chainageEnd'
            elif 'LENGTH' in col_clean.upper() or 'LCS LENGTH' in col_clean.upper():
                column_mapping[col] = 'lcsLength'
            elif 'DESCRIPTION' in col_clean.upper() or 'SHORT' in col_clean.upper():
                column_mapping[col] = 'shortDescription'
        
        # Rename columns
        lcs_df = lcs_df.rename(columns=column_mapping)
        
        # Select only the columns we need
        required_cols = ['currentLcsCode', 'legacyLcsCode', 'vcc', 'chainageStart', 
                        'chainageEnd', 'lcsLength', 'shortDescription']
        available_cols = [col for col in required_cols if col in lcs_df.columns]
        
        lcs_out = lcs_df[available_cols].copy()
        
        # Fill missing columns with defaults
        for col in required_cols:
            if col not in lcs_out.columns:
                if col in ['currentLcsCode', 'legacyLcsCode', 'shortDescription']:
                    lcs_out[col] = ''
                else:
                    lcs_out[col] = 0.0
        
        # Clean data
        lcs_out = lcs_out.fillna({
            'currentLcsCode': '',
            'legacyLcsCode': '',
            'shortDescription': '',
            'vcc': 0.0,
            'chainageStart': 0.0,
            'chainageEnd': 0.0,
            'lcsLength': 0.0,
        })
        
        # Convert numeric columns
        numeric_cols = ['vcc', 'chainageStart', 'chainageEnd', 'lcsLength']
        for col in numeric_cols:
            lcs_out[col] = pd.to_numeric(lcs_out[col], errors='coerce').fillna(0.0)
        
        # Read TS sheet
        print("Reading TS sheet...")
        ts_df = pd.read_excel(excel_path, sheet_name="TS", engine="openpyxl")
        
        # Clean column names
        ts_df.columns = ts_df.columns.str.strip()
        
        # Map TS columns
        ts_column_mapping = {}
        for col in ts_df.columns:
            col_clean = col.strip().replace('\n', ' ').replace('\r', ' ')
            if col_clean.upper() == 'TS' or 'TS' in col_clean.upper():
                ts_column_mapping[col] = 'tsId'
            elif 'SEGMENT' in col_clean.upper():
                ts_column_mapping[col] = 'segment'
            elif 'CHAINAGE' in col_clean.upper() and 'START' in col_clean.upper():
                ts_column_mapping[col] = 'chainageStart'
            elif col_clean.upper() == 'VCC':
                ts_column_mapping[col] = 'vcc'
        
        ts_df = ts_df.rename(columns=ts_column_mapping)
        
        # Select required columns
        ts_required_cols = ['tsId', 'segment', 'chainageStart', 'vcc']
        ts_available_cols = [col for col in ts_required_cols if col in ts_df.columns]
        
        ts_out = ts_df[ts_available_cols].copy()
        
        # Fill missing columns
        for col in ts_required_cols:
            if col not in ts_out.columns:
                if col == 'segment':
                    ts_out[col] = ''
                else:
                    ts_out[col] = 0
        
        # Clean TS data
        ts_out = ts_out.fillna({
            'tsId': 0,
            'segment': '',
            'chainageStart': 0.0,
            'vcc': 0.0,
        })
        
        # Convert numeric columns
        ts_out['tsId'] = pd.to_numeric(ts_out['tsId'], errors='coerce').fillna(0).astype(int)
        ts_out['chainageStart'] = pd.to_numeric(ts_out['chainageStart'], errors='coerce').fillna(0.0)
        ts_out['vcc'] = pd.to_numeric(ts_out['vcc'], errors='coerce').fillna(0.0)
        
        # Convert to JSON
        lcs_json = lcs_out.to_dict(orient='records')
        ts_json = ts_out.to_dict(orient='records')
        
        # Write JSON files
        output_dir.mkdir(parents=True, exist_ok=True)
        lcs_output_path = output_dir / "lcs.json"
        ts_output_path = output_dir / "ts.json"
        
        with open(lcs_output_path, 'w', encoding='utf-8') as f:
            json.dump(lcs_json, f, indent=2, ensure_ascii=False)
        
        with open(ts_output_path, 'w', encoding='utf-8') as f:
            json.dump(ts_json, f, indent=2, ensure_ascii=False)
        
        print(f"✓ Saved {len(lcs_json)} LCS records to {lcs_output_path}")
        print(f"✓ Saved {len(ts_json)} TS records to {ts_output_path}")
        
        return True
        
    except Exception as e:
        print(f"Error converting Excel to JSON: {e}")
        import traceback
        traceback.print_exc()
        return False

def convert_platform_pdf():
    """
    Note: PDF parsing requires additional libraries.
    For now, this is a placeholder. The user should manually extract
    the platform/TS table from plat_TS.pdf and save as CSV first.
    """
    print("\nNote: Platform data conversion from PDF requires manual extraction.")
    print("Please extract the Platform/Track Sections table from plat_TS.pdf")
    print("and save it as platform_ts.csv with columns: Platform, TrackSectionsRaw")
    print("Then run convert_platform_csv_to_json.py")

if __name__ == "__main__":
    print("Converting Excel files to JSON...")
    success = convert_lcs_ts_sheets()
    if success:
        print("\n✓ Conversion complete!")
        convert_platform_pdf()
    else:
        print("\n✗ Conversion failed!")
        sys.exit(1)

