# Data Conversion Scripts

These scripts convert Excel and CSV files to JSON format for use in the Flutter app.

## Prerequisites

Install required Python packages:

```bash
pip install pandas openpyxl
```

## Converting Excel Files (LCS and TS data)

1. Ensure the Excel file `lcschainage1.xlsm` is in `assets/extra/`
2. Run the conversion script:

```bash
cd scripts
python convert_excel_to_json.py
```

This will:
- Read the "LCS" sheet from `lcschainage1.xlsm`
- Read the "TS" sheet from `lcschainage1.xlsm`
- Convert both to JSON format
- Save to `assets/data/lcs.json` and `assets/data/ts.json`

## Converting Platform Data

The platform data needs to be extracted from the PDF first:

1. Open `plat_TS.pdf` in a PDF viewer
2. Copy the Platform/Track Sections table (pages 3-12)
3. Paste into Excel or LibreOffice
4. Clean the data to have two columns:
   - `Platform` (e.g., "Edgware Road plt 1 (WB)")
   - `TrackSectionsRaw` (e.g., "10046, 10047, 10048, ...")
5. Save as CSV: `assets/extra/platform_ts.csv`
6. Run the conversion script:

```bash
cd scripts
python convert_platform_csv_to_json.py
```

This will save to `assets/data/platform_ts.json`

## Troubleshooting

- If you get "Excel file not found", ensure the file path is correct
- If column names don't match, the script tries to auto-detect them, but you may need to adjust the mapping in `convert_excel_to_json.py`
- If platform data is missing, the app will still work but won't show platform information

