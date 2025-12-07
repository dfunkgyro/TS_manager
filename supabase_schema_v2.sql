-- Supabase SQL Schema for Track Sections Manager V2
-- Enhanced schema with TSR support, batch operations, and grouping management
-- This schema includes tables for track sections, TSR, batch operations, and groupings

-- ============================================
-- 0. CLEANUP (Drop existing tables to ensure schema matches)
-- ============================================
DROP VIEW IF EXISTS public.maintenance_summary_by_line CASCADE;
DROP VIEW IF EXISTS public.track_sections_with_stations CASCADE;
DROP VIEW IF EXISTS public.tsr_summary_by_line CASCADE;
DROP VIEW IF EXISTS public.track_section_groupings_view CASCADE;

DROP TABLE IF EXISTS public.batch_operation_items CASCADE;
DROP TABLE IF EXISTS public.batch_operations CASCADE;
DROP TABLE IF EXISTS public.track_section_groupings CASCADE;
DROP TABLE IF EXISTS public.temporary_speed_restrictions CASCADE;
DROP TABLE IF EXISTS public.exports CASCADE;
DROP TABLE IF EXISTS public.maintenance_records CASCADE;
DROP TABLE IF EXISTS public.favorites CASCADE;
DROP TABLE IF EXISTS public.search_history CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.stations CASCADE;
DROP TABLE IF EXISTS public.track_sections CASCADE;

-- ============================================
-- 1. TRACK SECTIONS TABLE (Enhanced)
-- ============================================
CREATE TABLE IF NOT EXISTS public.track_sections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- LCS Codes (Multiple formats supported)
    lcs_code TEXT NOT NULL,
    legacy_lcs_code TEXT,
    legacy_jnp_lcs_code TEXT,

    -- Track Section Identification
    track_section_number INTEGER NOT NULL,  -- Track section number (e.g., 10501)

    -- Location Information
    road_status TEXT,                       -- 'Active', 'Commissioned', 'Decommissioned'
    operating_line_code TEXT,               -- Single letter (D, C, M, H)
    operating_line TEXT NOT NULL,           -- Full line name
    road_direction TEXT,                    -- 'EB', 'WB', 'NB', 'SB'
    station TEXT,                           -- Associated station

    -- Descriptions
    new_long_description TEXT,
    new_short_description TEXT,

    -- Technical Data
    vcc TEXT,                              -- VCC Code
    thales_chainage NUMERIC NOT NULL,      -- Absolute chainage in meters
    segment_id TEXT,

    -- Meterage Information (critical for TSR)
    lcs_meterage NUMERIC NOT NULL,         -- Meterage from LCS code
    lcs_meterage_end NUMERIC,              -- End meterage (for sections with range)
    length_meters NUMERIC,                 -- Length of section in meters

    -- Track Information
    track TEXT,                            -- Track designation
    physical_assets TEXT,                  -- Assets in section (signals, points, etc.)

    -- Metadata
    notes TEXT,
    data_source TEXT DEFAULT 'manual',    -- 'manual', 'batch', 'import'
    batch_operation_id UUID,              -- Reference to batch operation if created via batch
    verified BOOLEAN DEFAULT false,        -- User verified this data

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    UNIQUE(track_section_number, operating_line, road_direction)
);

-- Create indexes for faster queries
CREATE INDEX idx_track_sections_lcs_code ON public.track_sections(lcs_code);
CREATE INDEX idx_track_sections_track_section_number ON public.track_sections(track_section_number);
CREATE INDEX idx_track_sections_operating_line ON public.track_sections(operating_line);
CREATE INDEX idx_track_sections_road_direction ON public.track_sections(road_direction);
CREATE INDEX idx_track_sections_station ON public.track_sections(station);
CREATE INDEX idx_track_sections_meterage ON public.track_sections(lcs_code, lcs_meterage);
CREATE INDEX idx_track_sections_meterage_range ON public.track_sections(lcs_meterage, lcs_meterage_end);
CREATE INDEX idx_track_sections_chainage ON public.track_sections(thales_chainage);
CREATE INDEX idx_track_sections_batch_id ON public.track_sections(batch_operation_id);
CREATE INDEX idx_track_sections_legacy_codes ON public.track_sections(legacy_lcs_code, legacy_jnp_lcs_code);

-- Enable Row Level Security
ALTER TABLE public.track_sections ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access
CREATE POLICY "Allow public read access to track sections"
ON public.track_sections FOR SELECT
USING (true);

-- Policy: Allow authenticated users to insert
CREATE POLICY "Allow authenticated users to insert track sections"
ON public.track_sections FOR INSERT
WITH CHECK (auth.role() = 'authenticated' OR true);  -- Allow unauthenticated for now

-- Policy: Allow authenticated users to update
CREATE POLICY "Allow authenticated users to update track sections"
ON public.track_sections FOR UPDATE
USING (auth.role() = 'authenticated' OR true);

-- Policy: Allow authenticated users to delete
CREATE POLICY "Allow authenticated users to delete track sections"
ON public.track_sections FOR DELETE
USING (auth.role() = 'authenticated' OR true);

-- ============================================
-- 2. TEMPORARY SPEED RESTRICTIONS (TSR) TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.temporary_speed_restrictions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- TSR Identification
    tsr_number TEXT UNIQUE,                -- TSR reference number
    tsr_name TEXT,                         -- Descriptive name

    -- Location (LCS Code + Meterage)
    lcs_code TEXT NOT NULL,
    start_meterage NUMERIC NOT NULL,
    end_meterage NUMERIC NOT NULL,

    -- Operating Details
    operating_line TEXT NOT NULL,
    road_direction TEXT,                   -- 'EB', 'WB', 'NB', 'SB'

    -- Speed Information
    normal_speed_mph INTEGER,              -- Normal line speed
    restricted_speed_mph INTEGER NOT NULL, -- Restricted speed

    -- Dates & Status
    effective_from TIMESTAMPTZ NOT NULL,
    effective_until TIMESTAMPTZ,           -- NULL = indefinite
    status TEXT DEFAULT 'planned',         -- 'planned', 'active', 'ended', 'cancelled'

    -- Reason & Details
    reason TEXT NOT NULL,                  -- 'construction', 'inspection', 'maintenance', 'emergency'
    description TEXT,

    -- Contact & Authority
    requested_by TEXT,
    approved_by TEXT,
    contact_info TEXT,

    -- Associated Track Sections
    affected_track_sections INTEGER[],     -- Array of track section numbers

    -- Metadata
    notes TEXT,
    attachments JSONB,                     -- URLs or file references

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_tsr_lcs_code ON public.temporary_speed_restrictions(lcs_code);
CREATE INDEX idx_tsr_meterage_range ON public.temporary_speed_restrictions(start_meterage, end_meterage);
CREATE INDEX idx_tsr_operating_line ON public.temporary_speed_restrictions(operating_line);
CREATE INDEX idx_tsr_status ON public.temporary_speed_restrictions(status);
CREATE INDEX idx_tsr_effective_dates ON public.temporary_speed_restrictions(effective_from, effective_until);
CREATE INDEX idx_tsr_track_sections ON public.temporary_speed_restrictions USING GIN(affected_track_sections);

-- Enable Row Level Security
ALTER TABLE public.temporary_speed_restrictions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow public read access to TSR"
ON public.temporary_speed_restrictions FOR SELECT
USING (true);

CREATE POLICY "Allow authenticated users to manage TSR"
ON public.temporary_speed_restrictions FOR ALL
USING (auth.role() = 'authenticated' OR true);

-- ============================================
-- 3. TRACK SECTION GROUPINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.track_section_groupings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Grouping Identification
    lcs_code TEXT NOT NULL,
    meterage_from_lcs NUMERIC NOT NULL,
    tolerance_meters NUMERIC DEFAULT 10,   -- Grouping tolerance

    -- Track Sections in this grouping
    track_section_numbers INTEGER[] NOT NULL,
    track_section_count INTEGER NOT NULL,

    -- Location Details
    operating_line TEXT NOT NULL,
    road_direction TEXT,
    station TEXT,

    -- Grouping Metadata
    description TEXT,
    verified BOOLEAN DEFAULT false,
    auto_generated BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    UNIQUE(lcs_code, meterage_from_lcs, operating_line, road_direction)
);

-- Create indexes
CREATE INDEX idx_groupings_lcs_meterage ON public.track_section_groupings(lcs_code, meterage_from_lcs);
CREATE INDEX idx_groupings_operating_line ON public.track_section_groupings(operating_line);
CREATE INDEX idx_groupings_track_sections ON public.track_section_groupings USING GIN(track_section_numbers);

-- Enable Row Level Security
ALTER TABLE public.track_section_groupings ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow public read access to groupings"
ON public.track_section_groupings FOR SELECT
USING (true);

CREATE POLICY "Allow authenticated users to manage groupings"
ON public.track_section_groupings FOR ALL
USING (auth.role() = 'authenticated' OR true);

-- ============================================
-- 4. BATCH OPERATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.batch_operations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Batch Details
    operation_type TEXT NOT NULL,          -- 'track_section_batch_insert', 'bulk_edit', 'import'
    status TEXT DEFAULT 'pending',         -- 'pending', 'processing', 'completed', 'failed', 'partial'

    -- Input Parameters
    start_track_section INTEGER NOT NULL,
    end_track_section INTEGER NOT NULL,
    start_chainage NUMERIC NOT NULL,
    end_chainage NUMERIC NOT NULL,

    -- Shared Parameters
    lcs_code TEXT NOT NULL,
    station TEXT,
    operating_line TEXT NOT NULL,
    road_direction TEXT NOT NULL,
    vcc TEXT,

    -- Results
    total_items INTEGER DEFAULT 0,
    successful_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    conflicted_items INTEGER DEFAULT 0,

    -- Conflict Resolution
    conflict_resolution TEXT,              -- 'keep_existing', 'replace_all', 'skip_conflicts'
    conflicts_data JSONB,                  -- Details of conflicts found

    -- User & Metadata
    user_id UUID REFERENCES auth.users(id),
    notes TEXT,
    error_log TEXT,

    -- Timestamps
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_batch_ops_status ON public.batch_operations(status);
CREATE INDEX idx_batch_ops_user_id ON public.batch_operations(user_id);
CREATE INDEX idx_batch_ops_created_at ON public.batch_operations(created_at DESC);
CREATE INDEX idx_batch_ops_operating_line ON public.batch_operations(operating_line);

-- Enable Row Level Security
ALTER TABLE public.batch_operations ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own batch operations"
ON public.batch_operations FOR SELECT
USING (auth.uid() = user_id OR true);  -- Allow public read for now

CREATE POLICY "Users can create batch operations"
ON public.batch_operations FOR INSERT
WITH CHECK (auth.uid() = user_id OR true);

CREATE POLICY "Users can update their own batch operations"
ON public.batch_operations FOR UPDATE
USING (auth.uid() = user_id OR true);

-- ============================================
-- 5. BATCH OPERATION ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.batch_operation_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    batch_operation_id UUID NOT NULL REFERENCES public.batch_operations(id) ON DELETE CASCADE,

    -- Item Details
    track_section_number INTEGER NOT NULL,
    chainage NUMERIC NOT NULL,
    lcs_meterage NUMERIC NOT NULL,

    -- Status
    status TEXT DEFAULT 'pending',         -- 'pending', 'inserted', 'skipped', 'failed', 'conflict'
    conflict_type TEXT,                    -- 'duplicate_number', 'chainage_overlap'
    existing_data JSONB,                   -- Data of existing conflicting record

    -- Error Details
    error_message TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

-- Create indexes
CREATE INDEX idx_batch_items_batch_id ON public.batch_operation_items(batch_operation_id);
CREATE INDEX idx_batch_items_status ON public.batch_operation_items(status);
CREATE INDEX idx_batch_items_track_section ON public.batch_operation_items(track_section_number);

-- Enable Row Level Security
ALTER TABLE public.batch_operation_items ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read access to batch operation items"
ON public.batch_operation_items FOR SELECT
USING (true);

CREATE POLICY "Allow insert batch operation items"
ON public.batch_operation_items FOR INSERT
WITH CHECK (true);

CREATE POLICY "Allow update batch operation items"
ON public.batch_operation_items FOR UPDATE
USING (true);

-- ============================================
-- 6. STATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.stations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lcs_code TEXT NOT NULL UNIQUE,
    station TEXT NOT NULL,
    line TEXT NOT NULL,
    branch TEXT,
    aliases TEXT[],
    latitude NUMERIC,
    longitude NUMERIC,
    zone INTEGER,
    interchanges TEXT[],
    platforms JSONB,                       -- Platform details
    additional_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_stations_lcs_code ON public.stations(lcs_code);
CREATE INDEX idx_stations_station_name ON public.stations(station);
CREATE INDEX idx_stations_line ON public.stations(line);
CREATE INDEX idx_stations_coordinates ON public.stations(latitude, longitude);

-- Enable Row Level Security
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;

-- Policies for stations
CREATE POLICY "Allow public read access to stations"
ON public.stations FOR SELECT
USING (true);

CREATE POLICY "Allow authenticated users to insert stations"
ON public.stations FOR INSERT
WITH CHECK (auth.role() = 'authenticated' OR true);

CREATE POLICY "Allow authenticated users to update stations"
ON public.stations FOR UPDATE
USING (auth.role() = 'authenticated' OR true);

-- ============================================
-- 7. USER PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    display_name TEXT,
    avatar_url TEXT,
    role TEXT DEFAULT 'user',
    preferences JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Policies for user profiles
CREATE POLICY "Users can view their own profile"
ON public.user_profiles FOR SELECT
USING (auth.uid() = id OR true);

CREATE POLICY "Users can update their own profile"
ON public.user_profiles FOR UPDATE
USING (auth.uid() = id OR true);

CREATE POLICY "Users can insert their own profile"
ON public.user_profiles FOR INSERT
WITH CHECK (auth.uid() = id OR true);

-- ============================================
-- 8. SEARCH HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.search_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    search_type TEXT NOT NULL,
    search_value TEXT NOT NULL,
    result_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_search_history_user_id ON public.search_history(user_id);
CREATE INDEX idx_search_history_created_at ON public.search_history(created_at DESC);
CREATE INDEX idx_search_history_type ON public.search_history(search_type);

ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own search history"
ON public.search_history FOR SELECT
USING (auth.uid() = user_id OR true);

CREATE POLICY "Users can insert their own search history"
ON public.search_history FOR INSERT
WITH CHECK (auth.uid() = user_id OR true);

CREATE POLICY "Users can delete their own search history"
ON public.search_history FOR DELETE
USING (auth.uid() = user_id OR true);

-- ============================================
-- 9. FAVORITES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    item_id TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, item_type, item_id)
);

CREATE INDEX idx_favorites_user_id ON public.favorites(user_id);
CREATE INDEX idx_favorites_item_type ON public.favorites(item_type);
CREATE INDEX idx_favorites_created_at ON public.favorites(created_at DESC);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own favorites"
ON public.favorites FOR SELECT
USING (auth.uid() = user_id OR true);

CREATE POLICY "Users can insert their own favorites"
ON public.favorites FOR INSERT
WITH CHECK (auth.uid() = user_id OR true);

CREATE POLICY "Users can delete their own favorites"
ON public.favorites FOR DELETE
USING (auth.uid() = user_id OR true);

-- ============================================
-- 10. MAINTENANCE RECORDS TABLE (Enhanced for TSR)
-- ============================================
CREATE TABLE IF NOT EXISTS public.maintenance_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    track_section_id UUID REFERENCES public.track_sections(id) ON DELETE CASCADE,
    tsr_id UUID REFERENCES public.temporary_speed_restrictions(id),
    maintenance_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled',
    scheduled_date DATE,
    completed_date DATE,
    performed_by TEXT,
    description TEXT,
    notes TEXT,
    cost NUMERIC,
    attachments JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_maintenance_track_section ON public.maintenance_records(track_section_id);
CREATE INDEX idx_maintenance_tsr ON public.maintenance_records(tsr_id);
CREATE INDEX idx_maintenance_status ON public.maintenance_records(status);
CREATE INDEX idx_maintenance_scheduled_date ON public.maintenance_records(scheduled_date);

ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to maintenance records"
ON public.maintenance_records FOR SELECT
USING (true);

CREATE POLICY "Allow authenticated users to manage maintenance records"
ON public.maintenance_records FOR ALL
USING (auth.role() = 'authenticated' OR true);

-- ============================================
-- 11. EXPORTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.exports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    export_type TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_url TEXT,
    filters JSONB,
    record_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_exports_user_id ON public.exports(user_id);
CREATE INDEX idx_exports_created_at ON public.exports(created_at DESC);

ALTER TABLE public.exports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own exports"
ON public.exports FOR SELECT
USING (auth.uid() = user_id OR true);

CREATE POLICY "Users can create exports"
ON public.exports FOR INSERT
WITH CHECK (auth.uid() = user_id OR true);

-- ============================================
-- 12. FUNCTIONS & TRIGGERS
-- ============================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER set_updated_at_track_sections
    BEFORE UPDATE ON public.track_sections
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_stations
    BEFORE UPDATE ON public.stations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_user_profiles
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_maintenance_records
    BEFORE UPDATE ON public.maintenance_records
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_tsr
    BEFORE UPDATE ON public.temporary_speed_restrictions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_groupings
    BEFORE UPDATE ON public.track_section_groupings
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_batch_ops
    BEFORE UPDATE ON public.batch_operations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Function to auto-update grouping count
CREATE OR REPLACE FUNCTION public.update_grouping_count()
RETURNS TRIGGER AS $$
BEGIN
    NEW.track_section_count = array_length(NEW.track_section_numbers, 1);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_grouping_count_trigger
    BEFORE INSERT OR UPDATE ON public.track_section_groupings
    FOR EACH ROW
    EXECUTE FUNCTION public.update_grouping_count();

-- Function to create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, display_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NEW;  -- Continue even if profile creation fails
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup (only if auth.users exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'auth'
        AND table_name = 'users'
    ) THEN
        DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_new_user();
    END IF;
END $$;

-- ============================================
-- 13. HELPER FUNCTIONS
-- ============================================

-- Function to find track sections by LCS + meterage
CREATE OR REPLACE FUNCTION public.find_track_sections_by_meterage(
    p_lcs_code TEXT,
    p_start_meterage NUMERIC,
    p_end_meterage NUMERIC,
    p_tolerance NUMERIC DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    track_section_number INTEGER,
    lcs_meterage NUMERIC,
    chainage NUMERIC,
    operating_line TEXT,
    road_direction TEXT,
    station TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ts.id,
        ts.track_section_number,
        ts.lcs_meterage,
        ts.thales_chainage,
        ts.operating_line,
        ts.road_direction,
        ts.station
    FROM public.track_sections ts
    WHERE ts.lcs_code = p_lcs_code
      AND ts.lcs_meterage >= (p_start_meterage - p_tolerance)
      AND ts.lcs_meterage <= (p_end_meterage + p_tolerance)
    ORDER BY ts.lcs_meterage;
END;
$$ LANGUAGE plpgsql;

-- Function to check for track section conflicts
CREATE OR REPLACE FUNCTION public.check_track_section_conflict(
    p_track_section_number INTEGER,
    p_operating_line TEXT,
    p_road_direction TEXT
)
RETURNS TABLE (
    exists BOOLEAN,
    existing_id UUID,
    existing_lcs_code TEXT,
    existing_chainage NUMERIC,
    existing_meterage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        true,
        ts.id,
        ts.lcs_code,
        ts.thales_chainage,
        ts.lcs_meterage
    FROM public.track_sections ts
    WHERE ts.track_section_number = p_track_section_number
      AND ts.operating_line = p_operating_line
      AND ts.road_direction = p_road_direction
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, NULL::NUMERIC, NULL::NUMERIC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get or create grouping
CREATE OR REPLACE FUNCTION public.get_or_create_grouping(
    p_lcs_code TEXT,
    p_meterage NUMERIC,
    p_operating_line TEXT,
    p_road_direction TEXT,
    p_tolerance NUMERIC DEFAULT 10
)
RETURNS UUID AS $$
DECLARE
    v_grouping_id UUID;
    v_track_sections INTEGER[];
BEGIN
    -- Try to find existing grouping
    SELECT id, track_section_numbers INTO v_grouping_id, v_track_sections
    FROM public.track_section_groupings
    WHERE lcs_code = p_lcs_code
      AND meterage_from_lcs >= (p_meterage - p_tolerance)
      AND meterage_from_lcs <= (p_meterage + p_tolerance)
      AND operating_line = p_operating_line
      AND (road_direction = p_road_direction OR road_direction IS NULL)
    LIMIT 1;

    IF v_grouping_id IS NULL THEN
        -- Create new grouping
        -- Find track sections in this meterage range
        SELECT ARRAY_AGG(track_section_number) INTO v_track_sections
        FROM public.track_sections
        WHERE lcs_code = p_lcs_code
          AND lcs_meterage >= (p_meterage - p_tolerance)
          AND lcs_meterage <= (p_meterage + p_tolerance)
          AND operating_line = p_operating_line
          AND (road_direction = p_road_direction OR road_direction IS NULL);

        -- Insert new grouping
        INSERT INTO public.track_section_groupings (
            lcs_code,
            meterage_from_lcs,
            operating_line,
            road_direction,
            track_section_numbers,
            track_section_count
        ) VALUES (
            p_lcs_code,
            p_meterage,
            p_operating_line,
            p_road_direction,
            COALESCE(v_track_sections, ARRAY[]::INTEGER[]),
            COALESCE(array_length(v_track_sections, 1), 0)
        )
        RETURNING id INTO v_grouping_id;
    END IF;

    RETURN v_grouping_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 14. VIEWS FOR REPORTING
-- ============================================

-- View for track sections with station info
CREATE OR REPLACE VIEW public.track_sections_with_stations AS
SELECT
    ts.*,
    s.station AS station_full_name,
    s.line AS station_line,
    s.zone,
    s.latitude,
    s.longitude,
    s.interchanges
FROM public.track_sections ts
LEFT JOIN public.stations s ON ts.lcs_code = s.lcs_code;

-- View for TSR summary by line
CREATE OR REPLACE VIEW public.tsr_summary_by_line AS
SELECT
    operating_line,
    COUNT(*) AS total_tsr,
    COUNT(CASE WHEN status = 'active' THEN 1 END) AS active_tsr,
    COUNT(CASE WHEN status = 'planned' THEN 1 END) AS planned_tsr,
    COUNT(CASE WHEN status = 'ended' THEN 1 END) AS ended_tsr,
    AVG(restricted_speed_mph) AS avg_restricted_speed
FROM public.temporary_speed_restrictions
GROUP BY operating_line;

-- View for track section groupings
CREATE OR REPLACE VIEW public.track_section_groupings_view AS
SELECT
    g.id,
    g.lcs_code,
    g.meterage_from_lcs,
    g.track_section_count,
    g.operating_line,
    g.road_direction,
    g.station,
    g.verified,
    g.track_section_numbers,
    array_to_string(g.track_section_numbers, ', ') AS track_sections_display
FROM public.track_section_groupings g
ORDER BY g.operating_line, g.lcs_code, g.meterage_from_lcs;

-- View for maintenance summary by line
CREATE OR REPLACE VIEW public.maintenance_summary_by_line AS
SELECT
    ts.operating_line,
    COUNT(mr.id) AS total_maintenance,
    COUNT(CASE WHEN mr.status = 'completed' THEN 1 END) AS completed_maintenance,
    COUNT(CASE WHEN mr.status = 'scheduled' THEN 1 END) AS scheduled_maintenance,
    COUNT(CASE WHEN mr.status = 'in_progress' THEN 1 END) AS in_progress_maintenance,
    SUM(mr.cost) AS total_cost
FROM public.maintenance_records mr
JOIN public.track_sections ts ON mr.track_section_id = ts.id
GROUP BY ts.operating_line;

-- ============================================
-- 15. COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE public.track_sections IS 'Railway track sections with LCS codes and meterage information';
COMMENT ON TABLE public.temporary_speed_restrictions IS 'Temporary Speed Restrictions (TSR) for track sections';
COMMENT ON TABLE public.track_section_groupings IS 'Track section groupings by LCS code and meterage';
COMMENT ON TABLE public.batch_operations IS 'Batch operations for bulk track section creation';
COMMENT ON TABLE public.batch_operation_items IS 'Individual items in batch operations';
COMMENT ON TABLE public.stations IS 'Railway stations with LCS codes, coordinates, and interchange information';
COMMENT ON TABLE public.user_profiles IS 'User profile data and preferences';
COMMENT ON TABLE public.search_history IS 'User search history for track sections and stations';
COMMENT ON TABLE public.favorites IS 'User favorite track sections and stations';
COMMENT ON TABLE public.maintenance_records IS 'Maintenance and inspection records for track sections';
COMMENT ON TABLE public.exports IS 'Export history for data downloads';

-- ============================================
-- END OF SCHEMA V2
-- ============================================
