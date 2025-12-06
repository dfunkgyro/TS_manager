-- Supabase SQL Schema for Track Sections Manager
-- This schema includes tables for track sections, stations, user data, and search history

-- ============================================
-- 0. CLEANUP (Drop existing tables to ensure schema matches)
-- ============================================
DROP VIEW IF EXISTS public.maintenance_summary_by_line CASCADE;
DROP VIEW IF EXISTS public.track_sections_with_stations CASCADE;
DROP TABLE IF EXISTS public.exports CASCADE;
DROP TABLE IF EXISTS public.maintenance_records CASCADE;
DROP TABLE IF EXISTS public.favorites CASCADE;
DROP TABLE IF EXISTS public.search_history CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.stations CASCADE;
DROP TABLE IF EXISTS public.track_sections CASCADE;

-- ============================================
-- 1. TRACK SECTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.track_sections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lcs_code TEXT NOT NULL UNIQUE,
    legacy_lcs_code TEXT,
    legacy_jnp_lcs_code TEXT,
    road_status TEXT,
    operating_line_code TEXT,
    operating_line TEXT NOT NULL,
    new_long_description TEXT,
    new_short_description TEXT,
    vcc TEXT,
    thales_chainage TEXT,
    segment_id TEXT,
    lcs_meterage_start NUMERIC NOT NULL,
    lcs_meterage_end NUMERIC NOT NULL,
    track TEXT,
    track_section TEXT,
    physical_assets TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX idx_track_sections_lcs_code ON public.track_sections(lcs_code);
CREATE INDEX idx_track_sections_operating_line ON public.track_sections(operating_line);
CREATE INDEX idx_track_sections_meterage_range ON public.track_sections(lcs_meterage_start, lcs_meterage_end);
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
WITH CHECK (auth.role() = 'authenticated');

-- Policy: Allow authenticated users to update
CREATE POLICY "Allow authenticated users to update track sections"
ON public.track_sections FOR UPDATE
USING (auth.role() = 'authenticated');

-- Policy: Allow authenticated users to delete
CREATE POLICY "Allow authenticated users to delete track sections"
ON public.track_sections FOR DELETE
USING (auth.role() = 'authenticated');

-- ============================================
-- 2. STATIONS TABLE
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
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to update stations"
ON public.stations FOR UPDATE
USING (auth.role() = 'authenticated');

-- ============================================
-- 3. USER PROFILES TABLE
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
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.user_profiles FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
ON public.user_profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- ============================================
-- 4. SEARCH HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.search_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    search_type TEXT NOT NULL, -- 'meterage', 'lcs_code', 'station'
    search_value TEXT NOT NULL,
    result_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_search_history_user_id ON public.search_history(user_id);
CREATE INDEX idx_search_history_created_at ON public.search_history(created_at DESC);
CREATE INDEX idx_search_history_type ON public.search_history(search_type);

-- Enable Row Level Security
ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;

-- Policies for search history
CREATE POLICY "Users can view their own search history"
ON public.search_history FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own search history"
ON public.search_history FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own search history"
ON public.search_history FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 5. FAVORITES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL, -- 'track_section', 'station'
    item_id TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, item_type, item_id)
);

-- Create indexes
CREATE INDEX idx_favorites_user_id ON public.favorites(user_id);
CREATE INDEX idx_favorites_item_type ON public.favorites(item_type);
CREATE INDEX idx_favorites_created_at ON public.favorites(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Policies for favorites
CREATE POLICY "Users can view their own favorites"
ON public.favorites FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites"
ON public.favorites FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
ON public.favorites FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 6. MAINTENANCE RECORDS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.maintenance_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    track_section_id UUID REFERENCES public.track_sections(id) ON DELETE CASCADE,
    maintenance_type TEXT NOT NULL, -- 'inspection', 'repair', 'upgrade', 'replacement'
    status TEXT NOT NULL DEFAULT 'scheduled', -- 'scheduled', 'in_progress', 'completed', 'cancelled'
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

-- Create indexes
CREATE INDEX idx_maintenance_track_section ON public.maintenance_records(track_section_id);
CREATE INDEX idx_maintenance_status ON public.maintenance_records(status);
CREATE INDEX idx_maintenance_scheduled_date ON public.maintenance_records(scheduled_date);

-- Enable Row Level Security
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;

-- Policies for maintenance records
CREATE POLICY "Allow public read access to maintenance records"
ON public.maintenance_records FOR SELECT
USING (true);

CREATE POLICY "Allow authenticated users to manage maintenance records"
ON public.maintenance_records FOR ALL
USING (auth.role() = 'authenticated');

-- ============================================
-- 7. EXPORTS TABLE (Track export history)
-- ============================================
CREATE TABLE IF NOT EXISTS public.exports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    export_type TEXT NOT NULL, -- 'csv', 'pdf', 'excel', 'json'
    file_name TEXT NOT NULL,
    file_url TEXT,
    filters JSONB,
    record_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_exports_user_id ON public.exports(user_id);
CREATE INDEX idx_exports_created_at ON public.exports(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.exports ENABLE ROW LEVEL SECURITY;

-- Policies for exports
CREATE POLICY "Users can view their own exports"
ON public.exports FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can create exports"
ON public.exports FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 8. FUNCTIONS & TRIGGERS
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 9. VIEWS FOR REPORTING
-- ============================================

-- View for track sections with station info
CREATE OR REPLACE VIEW public.track_sections_with_stations AS
SELECT
    ts.*,
    s.station,
    s.line AS station_line,
    s.zone,
    s.latitude,
    s.longitude
FROM public.track_sections ts
LEFT JOIN public.stations s ON ts.lcs_code = s.lcs_code;

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
-- 10. SAMPLE DATA INSERTION
-- ============================================

-- Insert sample track sections
INSERT INTO public.track_sections (
    lcs_code, legacy_lcs_code, legacy_jnp_lcs_code, road_status,
    operating_line_code, operating_line, new_long_description,
    new_short_description, vcc, thales_chainage, segment_id,
    lcs_meterage_start, lcs_meterage_end, track, track_section,
    physical_assets, notes
) VALUES
    ('M189-M-RD21', 'M189', 'M189-JNP', 'Active', 'MET', 'Metropolitan Line',
     'Metropolitan Line - Royal Oak to Paddington', 'Royal Oak - Paddington',
     'VCC-M-01', 'TC-15000', 'SEG-M-189', 15000.0, 15250.0, 'EB', 'RD21',
     'Signals, Points', 'Main line section'),

    ('D011-D-UP01', 'D011', 'D011-JNP', 'Active', 'DIS', 'District Line',
     'District Line - Upminster Station', 'Upminster Station',
     'VCC-D-01', 'TC-10000', 'SEG-D-011', 10000.0, 10150.0, 'EB', 'UP01',
     'Platform, Signals', 'Terminal station'),

    ('C055-C-BST01', 'C055', 'C055-JNP', 'Active', 'CIR', 'Circle Line',
     'Circle Line - Baker Street Station', 'Baker Street',
     'VCC-C-01', 'TC-20000', 'SEG-C-055', 20000.0, 20300.0, 'IR', 'BST01',
     'Platform, Interchange', 'Major interchange')
ON CONFLICT (lcs_code) DO NOTHING;

-- Insert sample stations
INSERT INTO public.stations (
    lcs_code, station, line, latitude, longitude, zone, interchanges
) VALUES
    ('M189', 'Royal Oak', 'Metropolitan Line', 51.5191, -0.1880, 2,
     ARRAY['Hammersmith & City Line']),

    ('D011', 'Upminster', 'District Line', 51.5590, 0.2509, 6,
     ARRAY[]::TEXT[]),

    ('C055', 'Baker Street', 'Circle Line', 51.5226, -0.1571, 1,
     ARRAY['Metropolitan Line', 'Hammersmith & City Line', 'Jubilee Line', 'Bakerloo Line'])
ON CONFLICT (lcs_code) DO NOTHING;

-- ============================================
-- 11. COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE public.track_sections IS 'Railway track sections with LCS codes and meterage information';
COMMENT ON TABLE public.stations IS 'Railway stations with LCS codes, coordinates, and interchange information';
COMMENT ON TABLE public.user_profiles IS 'User profile data and preferences';
COMMENT ON TABLE public.search_history IS 'User search history for track sections and stations';
COMMENT ON TABLE public.favorites IS 'User favorite track sections and stations';
COMMENT ON TABLE public.maintenance_records IS 'Maintenance and inspection records for track sections';
COMMENT ON TABLE public.exports IS 'Export history for data downloads';

-- ============================================
-- END OF SCHEMA
-- ============================================
