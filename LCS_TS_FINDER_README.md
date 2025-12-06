# LCS/TS Finder Feature

This feature replicates the functionality of the Excel workbook (`lcschainage1.xlsm`) with a modern, user-friendly Flutter interface.

## Features

### 1. LCS-based Track Section Search
- **Input**: LCS code (e.g., M134/MIRLO) and meterage range (start/end)
- **Output**: List of matching Track Sections with:
  - TS ID
  - Segment
  - Chainage Start
  - Associated Platforms (if platform data is available)

### 2. Platform-based Track Section Search
- **Input**: Platform name (e.g., "Edgware Road plt 1 (WB)")
- **Output**: All Track Sections associated with that platform

## How It Works

The app replicates the Excel macro logic:

1. User enters:
   - LCS code
   - Start & End meterage along that LCS

2. App:
   - Finds the LCS record
   - Takes LCS start chainage: `lcsChainageStart`
   - Converts meterage to absolute chainage:
     - `absStart = lcsChainageStart + startMeterage`
     - `absEnd = lcsChainageStart + endMeterage`
   - Filters TS records for:
     - `TS.VCC == LCS.VCC`
     - `TS.Chainage Start` between `absStart` and `absEnd`
   - Displays matching TS IDs

## Setup Instructions

### Step 1: Convert Excel Data to JSON

1. Install Python dependencies:
   ```bash
   pip install pandas openpyxl
   ```

2. Run the conversion script:
   ```bash
   cd scripts
   python convert_excel_to_json.py
   ```

   This creates:
   - `assets/data/lcs.json` - LCS records
   - `assets/data/ts.json` - Track Section records

### Step 2: Convert Platform Data (Optional)

1. Extract the Platform/Track Sections table from `plat_TS.pdf`:
   - Open the PDF
   - Copy the table (pages 3-12)
   - Paste into Excel/LibreOffice
   - Create two columns: `Platform` and `TrackSectionsRaw`
   - Save as `assets/extra/platform_ts.csv`

2. Run the conversion script:
   ```bash
   cd scripts
   python convert_platform_csv_to_json.py
   ```

   This creates:
   - `assets/data/platform_ts.json` - Platform records

### Step 3: Run the App

The feature is accessible from the home screen via the "LCS/TS Finder" card.

## User Interface

### By LCS Tab
- **LCS Code Input**: Autocomplete field that searches both legacy and current LCS codes
- **Meterage Inputs**: Start and end meterage fields
- **Results Table**: Shows matching track sections with:
  - TS ID
  - Segment
  - Chainage Start
  - Platforms (if available)
- **Copy Button**: Copies TS IDs to clipboard

### By Platform Tab
- **Platform Search**: Autocomplete field to search platform names
- **Results List**: Expandable list showing all platforms and their associated track sections
- **Track Section Chips**: Visual chips for each track section ID

## Data Models

- **LcsRecord**: Represents an LCS with chainage, VCC, and description
- **TsRecord**: Represents a Track Section with ID, segment, chainage, and VCC
- **PlatformRecord**: Represents a Platform with associated track section IDs
- **LcsTsAppData**: Container for all loaded data with reverse index (TS → Platforms)

## Files Created

- `lib/models/lcs_ts_models.dart` - Data models
- `lib/services/lcs_ts_service.dart` - Data loading and search logic
- `lib/screens/lcs_ts_finder_screen.dart` - Main UI screen
- `scripts/convert_excel_to_json.py` - Excel to JSON converter
- `scripts/convert_platform_csv_to_json.py` - Platform CSV to JSON converter

## Notes

- The app gracefully handles missing platform data - it will work without it, just won't show platform information
- All numeric values are parsed safely with fallbacks
- The UI is responsive and works on both mobile and tablet/desktop
- Results can be copied to clipboard for easy sharing

