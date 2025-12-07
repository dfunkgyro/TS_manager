# Batch Track Section Entry & TSR Management Features

## Overview

This update introduces powerful new features to speed up dataset population and improve TSR (Temporary Speed Restriction) management in the Track Sections Manager app.

## 🚀 Key Features

### 1. **Batch Track Section Entry**
Speed up data population by creating multiple track sections at once with automatic interpolation.

#### Features:
- **Interpolation**: Automatically fills in track sections between start and end points
- **Equal Spacing**: Evenly distributes chainage values across all generated sections
- **Conflict Detection**: Identifies existing track sections before insertion
- **Preview**: View all generated sections before committing
- **Multiple Resolution Strategies**:
  - **Skip Conflicts**: Insert only non-conflicting sections
  - **Stop on Conflict**: Halt operation to adjust parameters
  - **Preview Statistics**: See total sections, distance, and average spacing

#### How to Use:
1. Navigate to **⚡ Batch Entry** from the home screen
2. Fill in the batch parameters:
   - **Start Track Section**: e.g., 10501
   - **End Track Section**: e.g., 10520
   - **Start Chainage**: e.g., 24567.8 meters
   - **End Chainage**: e.g., 26789.4 meters
   - **LCS Code**: e.g., D011
   - **Operating Line**: District Line, Circle Line, etc.
   - **Road Direction**: EB, WB, NB, SB
   - **Station** (Optional): e.g., Upminster
   - **VCC** (Optional): e.g., 4
3. Click **Generate Preview** to see what will be created
4. Review the preview and conflict warnings
5. Choose your conflict resolution strategy
6. Execute the batch operation

#### Example Workflow:
```
Input:
- Start TS: 10501 @ 24567.8m
- End TS: 10520 @ 26789.4m
- LCS: D011
- Line: District Line EB

Output:
- Creates 20 track sections (10501-10520)
- Equally spaces chainage from 24567.8m to 26789.4m
- Average spacing: ~116.1 meters per section
- Automatically calculates meterage from LCS code
```

---

### 2. **Track Section Groupings Manager**
Manage track section groupings by LCS code and meterage for efficient TSR application.

#### Features:
- **Automatic Grouping**: Groups track sections by LCS code + meterage proximity
- **Count Display**: Shows how many track sections are in each grouping
- **Add/Remove Sections**: Manually adjust groupings to fix data issues
- **Verification**: Mark groupings as verified once confirmed
- **Search & Filter**: Find groupings by LCS code, station, or line
- **Visual Indicators**: Color-coded verification status

#### How to Use:
1. Navigate to **Grouping Manager** from the home screen
2. Browse existing groupings or create new ones
3. Each grouping shows:
   - LCS Code @ Meterage (e.g., "D011 @ 45.0m")
   - Track section count
   - All track section numbers in the grouping
   - Verification status
4. **To Add a Track Section**:
   - Expand the grouping
   - Click "Add Track Section"
   - Enter the track section number
5. **To Remove a Track Section**:
   - Click the × on the track section chip
   - Confirm removal
6. **To Verify a Grouping**:
   - Review all track sections
   - Click "Verify" to mark as accurate

#### Example Grouping:
```
LCS Code: D011 @ 45.0m
Operating Line: District Line EB
Track Sections: 10501, 10502, 10503 (3 sections)
Status: Verified ✓

Purpose: When applying a TSR at "D011 @ 45m",
the app will show these 3 track sections need the restriction.
```

---

### 3. **TSR (Temporary Speed Restriction) Support**
Foundation for applying and managing temporary speed restrictions.

#### Database Schema Includes:
- **TSR Records**: Store speed restrictions with location data
- **Affected Track Sections**: Links TSRs to specific track sections
- **Status Tracking**: Planned, Active, Ended, Cancelled
- **Effective Dates**: Start and end dates for restrictions
- **Speed Information**: Normal and restricted speeds
- **Reason Tracking**: Construction, inspection, maintenance, etc.

#### Data Model Features:
- LCS Code + Meterage range
- Multiple track sections per TSR
- Approval and contact information
- Notes and attachments support

---

## 🗄️ Database Schema Updates

### New Tables:

#### `track_sections` (Enhanced)
- Added `track_section_number` (INTEGER) for direct numeric tracking
- Added `road_direction` (EB/WB/NB/SB)
- Added `lcs_meterage` for precise meterage tracking
- Added `data_source` (manual, batch, import)
- Added `batch_operation_id` for tracking batch-created sections
- Added `verified` flag

#### `batch_operations`
- Tracks all batch creation operations
- Stores parameters (start/end track sections, chainage)
- Records success/failure/conflict counts
- Links to created track sections

#### `batch_operation_items`
- Individual items in each batch operation
- Conflict detection results
- Status tracking per item

#### `temporary_speed_restrictions`
- Complete TSR management
- LCS code + meterage range
- Speed information (normal & restricted)
- Status and effective dates
- Affected track sections array

#### `track_section_groupings`
- Groups track sections by LCS + meterage
- Track section count
- Verification status
- Auto-generated vs manual

### Helper Functions:
```sql
-- Find track sections by LCS + meterage range
find_track_sections_by_meterage(lcs_code, start_meterage, end_meterage)

-- Check for conflicts before insertion
check_track_section_conflict(track_section_number, operating_line, road_direction)

-- Get or create a grouping
get_or_create_grouping(lcs_code, meterage, operating_line, road_direction)
```

---

## 🔧 Configuration

### Environment Variables (.env)
Create a `.env` file in `/assets/` directory:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_project_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here

# OpenAI Configuration (Optional)
OPENAI_API_KEY=your_openai_api_key_here

# DeepSeek AI Configuration (Optional)
DEEPSEEK_API_KEY=your_deepseek_api_key_here
```

### Offline Mode
The app works fully offline if Supabase is not configured. All data is stored locally using SharedPreferences.

---

## 📊 Data Persistence

### Local Storage (SharedPreferences)
- `user_track_sections`: User-added track sections
- `user_station_mappings`: Custom station mappings
- `user_lcs_to_track_sections`: LCS to track section links

### Cloud Storage (Supabase)
- Automatic sync when authenticated
- Real-time updates
- Conflict resolution
- Export history tracking

---

## 🎯 Use Cases

### Use Case 1: Populate Missing Track Sections
**Scenario**: You know track sections 10501-10520 exist between two stations but they're missing from the dataset.

**Solution**:
1. Open Batch Entry
2. Enter start (10501 @ 24567.8m) and end (10520 @ 26789.4m)
3. Specify LCS code and line
4. Generate preview
5. Review for conflicts
6. Execute batch insert
7. All 20 sections created with interpolated chainage

### Use Case 2: Fix Incorrect TSR Application
**Scenario**: TSR was applied at "D011 @ 45m" but the app only showed 2 track sections when there should be 4.

**Solution**:
1. Open Grouping Manager
2. Search for "D011 @ 45m"
3. See current grouping has 2 sections
4. Click "Add Track Section"
5. Add the 2 missing track section numbers
6. Verify the grouping
7. Next time a TSR is applied here, all 4 sections will be included

### Use Case 3: Handle Anomalies
**Scenario**: Some areas have irregular track section numbering (e.g., 10501, 10503, 10506 - skipping numbers).

**Solution**:
1. Use batch entry for the regular sections
2. When conflicts appear, choose "Skip Conflicts"
3. Batch creates non-conflicting sections
4. Manually add the anomalies using the regular entry screen
5. Or adjust the batch parameters to handle the gap

### Use Case 4: Verify Data Accuracy
**Scenario**: Need to ensure all track section groupings are correct before deploying TSRs.

**Solution**:
1. Open Grouping Manager
2. Filter by operating line
3. Review each grouping
4. Add/remove track sections as needed
5. Mark each as "Verified"
6. Export verified groupings for records

---

## 🔍 Advanced Features

### Conflict Resolution Strategies

#### 1. Skip Conflicts
- Inserts only non-conflicting track sections
- Preserves existing data
- Best for filling gaps in existing dataset

#### 2. Stop on Conflict
- Halts the entire operation if any conflicts found
- Shows user all conflicts
- User must adjust parameters and retry
- Best for ensuring 100% accuracy

#### 3. Replace All (Future Feature)
- Deletes existing conflicting sections
- Inserts all new sections
- Best for correcting known bad data

### Data Validation

The app validates:
- Track section number ranges
- Chainage values (must be numeric and increasing/decreasing consistently)
- LCS code format
- Operating line selection
- Road direction selection
- Duplicate detection across line and direction

### Export Capabilities

Export your data in multiple formats:
- **CSV**: For Excel analysis
- **JSON**: For data migration
- **PDF**: For documentation
- **XML**: For system integration

---

## 📱 Navigation

### From Home Screen:
- **⚡ Batch Entry** → Speed up data population
- **Grouping Manager** → Manage TSR groupings

### Key Features Access:
1. **Unified Search** → Find track sections
2. **Batch Entry** → Create multiple sections
3. **Grouping Manager** → Manage groupings
4. **Track Section Training** → Link individual sections
5. **Data Management** → Manage stations and mappings

---

## 🔐 Security & Permissions

### Supabase Row Level Security (RLS)
- Public read access to all track data
- Authenticated write access
- User profile isolation
- Search history privacy

### Local Data
- Persists across app restarts
- No authentication required
- Can be exported anytime

---

## 🐛 Troubleshooting

### Issue: Batch operation fails
**Solution**:
- Check all required fields are filled
- Ensure start/end values are different
- Verify network connection (if using Supabase)
- Check Activity Logger for detailed errors

### Issue: Conflicts not showing
**Solution**:
- Ensure you have existing track section data loaded
- Try refreshing the data service
- Check if track sections are on the same line and direction

### Issue: Groupings not saving
**Solution**:
- Check Supabase configuration
- Verify authentication status
- Groupings are saved locally if Supabase unavailable

### Issue: App runs slow with large batches
**Solution**:
- Break large batches (>100 sections) into smaller chunks
- Use conflict detection selectively
- Consider running on device with more memory

---

## 🚧 Future Enhancements

### Planned Features:
1. **TSR Application UI**: Apply TSRs directly from groupings
2. **Bulk Edit**: Modify multiple track sections at once
3. **Import from CSV**: Load track sections from external files
4. **Auto-grouping**: Automatically create groupings from existing data
5. **Conflict Auto-resolution**: AI-powered conflict resolution suggestions
6. **Version History**: Track changes to track sections over time
7. **Collaboration**: Multi-user editing with change tracking

---

## 📖 Technical Documentation

### Key Files:

#### Models:
- `/lib/models/batch_models.dart` - Batch operation data models
- `/lib/models/tsr_models.dart` - TSR data models
- `/lib/models/grouping_models.dart` - Grouping data models

#### Services:
- `/lib/services/batch_operation_service.dart` - Batch logic & interpolation
- `/lib/services/supabase_service.dart` - Database operations
- `/lib/services/app_config.dart` - Configuration management

#### Screens:
- `/lib/screens/batch_entry_screen.dart` - Batch entry UI
- `/lib/screens/grouping_management_screen.dart` - Grouping management UI

#### Database:
- `/supabase_schema_v2.sql` - Enhanced database schema with all new tables

---

## 💡 Tips & Best Practices

### For Best Results:

1. **Always Preview First**: Use the preview feature to verify before executing
2. **Handle Conflicts Wisely**: Choose "Stop on Conflict" when data accuracy is critical
3. **Verify Groupings**: Mark groupings as verified after manual review
4. **Use Batch for Regular Patterns**: Batch entry works best for evenly-spaced track sections
5. **Manual for Anomalies**: Use regular entry for irregular or special cases
6. **Export Regularly**: Back up your data by exporting periodically
7. **Check Activity Logger**: Monitor for any issues or unusual behavior

### Data Quality Tips:

1. **Consistent Naming**: Use consistent LCS code formats
2. **Accurate Chainage**: Double-check chainage values before batch operations
3. **Verify Meterages**: Ensure meterage calculations are correct
4. **Station Mapping**: Link stations properly for better search results
5. **Regular Verification**: Periodically review and verify groupings

---

## 📞 Support

For issues or questions:
1. Check the Activity Logger for detailed error messages
2. Review this documentation
3. Check the app's built-in help (Info button on home screen)
4. Report issues via the GitHub repository

---

## 📄 License

This feature set is part of the Track Sections Manager application.

---

**Version**: 2.0
**Last Updated**: December 2024
**Author**: Claude (Anthropic AI Assistant)
