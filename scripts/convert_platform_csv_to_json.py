#!/usr/bin/env python3
"""
Script to convert platform_ts.csv to JSON for Flutter app.
The CSV should have columns: Platform, TrackSectionsRaw
"""

import csv
import json
import sys
from pathlib import Path

def convert_platform_csv():
    """Convert platform_ts.csv to platform_ts.json."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    csv_path = project_root / "assets" / "extra" / "platform_ts.csv"
    output_path = project_root / "assets" / "data" / "platform_ts.json"
    
    if not csv_path.exists():
        print(f"Error: CSV file not found at {csv_path}")
        print("Please extract the Platform/Track Sections table from plat_TS.pdf")
        print("and save it as platform_ts.csv with columns: Platform, TrackSectionsRaw")
        return False
    
    rows = []
    
    try:
        with open(csv_path, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for r in reader:
                platform = r.get("Platform", "").strip()
                raw = r.get("TrackSectionsRaw", "").strip()
                
                if not platform:
                    continue
                
                # Parse track section IDs from comma-separated string
                ts_ids = []
                for part in raw.split(","):
                    part = part.strip()
                    if not part:
                        continue
                    try:
                        ts_ids.append(int(part))
                    except ValueError:
                        # Skip any non-numeric parts
                        pass
                
                rows.append({
                    "platform": platform,
                    "trackSections": ts_ids,
                })
        
        # Write JSON file
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2, ensure_ascii=False)
        
        print(f"✓ Saved {len(rows)} platform records to {output_path}")
        return True
        
    except Exception as e:
        print(f"Error converting CSV to JSON: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("Converting platform CSV to JSON...")
    success = convert_platform_csv()
    if success:
        print("\n✓ Conversion complete!")
    else:
        print("\n✗ Conversion failed!")
        sys.exit(1)

