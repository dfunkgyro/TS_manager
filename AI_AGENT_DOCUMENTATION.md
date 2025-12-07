# Enhanced AI Agent - Technical Documentation

## Overview

The AI service has been significantly enhanced to provide intelligent query processing with deep understanding of railway track sections, LCS codes, chainage calculations, and contextual awareness.

## New Capabilities

### 1. Intelligent Query Processing

The `processIntelligentQuery()` method now provides:

- **Natural Language Understanding**: Parses user queries to extract LCS codes, stations, lines, districts, and meterage adjustments
- **Chainage Calculation**: Automatically calculates new chainage values when user adds or subtracts meterage
- **Boundary Detection**: Identifies when calculated chainage crosses into a different station/LCS
- **Track Section Identification**: Extracts 5-digit track section numbers from queries
- **Context-Aware Responses**: Provides comprehensive results with all associated data

### 2. Query Examples

The AI agent now handles complex queries like:

```
"Find LCS M187"
→ Returns: LCS code, station name, line, chainage range, all track sections

"Goldhawk Road +50m"
→ Returns: Base chainage, calculated chainage (base + 50m),
   checks if crosses into different station, shows all relevant data

"District line track section 10501"
→ Returns: Track section 10501 details, associated LCS codes, line info

"BAK/A -25m"
→ Returns: Base chainage, calculated chainage (base - 25m),
   boundary crossing detection, new station if crossed
```

### 3. Chainage Mathematics

The system understands:

- **Chainage**: Absolute position measurement along the railway
- **Meterage**: Relative measurement from an LCS code's chainage start
- **Calculations**:
  - Adding meterage: `calculated_chainage = lcs.chainageStart + meterage`
  - Subtracting meterage: `calculated_chainage = lcs.chainageStart - meterage`
- **Boundary Crossing**: When calculated chainage falls within another LCS's range

### 4. Track Section Validation

- Only recognizes **5-digit numbers** as track sections (e.g., 10501, 12345)
- Filters out other numeric values
- Links track sections to their LCS codes, stations, and lines

## API Structure

### `processIntelligentQuery()`

**Parameters:**
- `query` (String): Natural language query from user
- `dataService` (UnifiedDataService): Access to all railway data

**Returns:** `Map<String, dynamic>` containing:

```json
{
  "understood_query": "Natural language summary of what was understood",
  "extracted_data": {
    "lcs_code": "M187",
    "station": "Goldhawk Road",
    "line": "District",
    "district": "District",
    "meterage_adjustment": 50.0,
    "base_chainage": 12500.0,
    "calculated_chainage": 12550.0,
    "track_sections": [10501, 10502],
    "crosses_boundary": true,
    "new_station": "Hammersmith"
  },
  "actual_data": {
    "lcs": {
      "code": "M187",
      "description": "Goldhawk Road",
      "chainage_start": 12500.0,
      "chainage_end": 12700.0,
      "vcc": 1234
    },
    "station": "Goldhawk Road",
    "line": "District",
    "track_sections": [
      {
        "id": 10501,
        "description": "Main line track",
        "line": "District",
        "lcs_current": "M187",
        "lcs_legacy": "M/187"
      }
    ],
    "calculated_chainage": 12550.0,
    "crosses_boundary": true,
    "new_lcs": {
      "code": "M188",
      "description": "Hammersmith approach"
    },
    "new_station": "Hammersmith",
    "new_line": "District"
  },
  "search_strategy": "Look up LCS M187, add 50m to chainage, check for boundary crossing",
  "results_summary": "Results show Goldhawk Road (M187) + 50m = 12550.0m chainage, which crosses into Hammersmith station area"
}
```

## Fallback Mode

When AI is not connected, the service provides intelligent fallback processing:

- **Pattern Matching**: Uses regex to extract LCS codes, track sections, meterage
- **Station Matching**: Searches station names in query
- **Suggestions**: Provides actionable suggestions for what to search

### Fallback Patterns

```dart
// LCS Code Pattern (e.g., M187, BAK/A, M-187)
RegExp(r'\b[A-Z]{1,3}[/_-]?[A-Z0-9]{1,4}\b')

// Track Section Pattern (5 digits)
RegExp(r'\b\d{5}\b')

// Meterage Adjustment Pattern (e.g., +50m, -25m)
RegExp(r'[+-]\s*(\d+(?:\.\d+)?)\s*m')
```

## Integration with Unified Search

The AI agent is integrated into the unified search screen:

1. User enters query in search box
2. System calls `processIntelligentQuery()`
3. AI processes query and returns structured data
4. Results enhanced with actual database lookups
5. UI displays comprehensive results with:
   - Original query understanding
   - All extracted information
   - Calculated chainages
   - Boundary crossing alerts
   - All relevant track sections

## Real-Time Query Updates

The system supports real-time updates when query changes:

- Live parsing of meterage adjustments
- Instant chainage recalculation
- Immediate boundary crossing detection
- Dynamic result updates

## Example Flow

```
User Query: "Goldhawk Road +50m"

1. AI Parses Query:
   - Station: "Goldhawk Road"
   - Meterage: +50m

2. Data Lookup:
   - Find station "Goldhawk Road"
   - Get LCS code: M187
   - Get base chainage: 12500.0m

3. Calculate:
   - New chainage: 12500.0 + 50 = 12550.0m

4. Check Boundaries:
   - M187 range: 12500.0 - 12700.0
   - 12550.0 is within M187 ✓
   - No boundary crossing

5. Find Track Sections:
   - Get all track sections for M187
   - Filter by chainage range
   - Return: [10501, 10502, 10503]

6. Display Results:
   - Show station info
   - Show calculated position
   - Show all track sections
   - Show platforms if any
```

## Error Handling

- **No AI Connection**: Falls back to pattern matching
- **Invalid Query**: Provides suggestions
- **No Data Found**: Offers to add missing data
- **API Errors**: Graceful degradation with helpful messages

## Performance

- **AI Response Time**: ~2-3 seconds for complex queries
- **Fallback Response Time**: <100ms
- **Chainage Calculation**: Instant
- **Database Lookups**: O(1) via HashMap indices

## Future Enhancements

- [ ] Multi-step query processing (e.g., "Find M187, add 50m, then subtract 10m")
- [ ] Historical chainage changes
- [ ] Predictive suggestions based on query patterns
- [ ] Voice input support
- [ ] Map visualization of chainage positions
- [ ] Export AI query results directly

## Security

- API keys stored in `.env` file (not committed)
- All queries sanitized before sending to OpenAI
- No sensitive railway operational data sent to API
- Only structural queries and responses processed

## Testing

To test the AI agent:

1. Add valid OpenAI API key to `assets/.env`
2. Run app and navigate to Unified Search
3. Enter complex queries with meterage adjustments
4. Verify chainage calculations are correct
5. Check boundary crossing detection
6. Confirm track section identification (5-digit validation)

## Troubleshooting

### "AI service not connected"
- Check `assets/.env` file exists
- Verify OPENAI_API_KEY is valid
- Check internet connection
- Review error message in lastError property

### "Incorrect chainage calculations"
- Verify LCS chainage_start values are correct
- Check meterage extraction regex
- Confirm sign of adjustment (+/-)

### "Track sections not found"
- Ensure track sections are 5-digit numbers
- Verify data in comprehensive_track_sections.json
- Check LCS to track section mappings

## API Costs

Using GPT-4:
- Average query: ~500 tokens input, ~300 tokens output
- Cost per query: ~$0.02
- Recommended: Use fallback for simple queries
- AI only for complex natural language processing
