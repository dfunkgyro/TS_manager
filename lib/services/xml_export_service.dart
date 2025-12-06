import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' as simple_models show LocationInfo, NearestChainageResult, EnhancedTrackSection;

/// Service for exporting data to XML format
class XmlExportService {
  /// Export LCS/TS search results to XML
  String exportSearchResults({
    required LcsRecord lcs,
    required double startMeterage,
    required double endMeterage,
    required List<TsRecord> trackSections,
    simple_models.LocationInfo? locationInfo,
    simple_models.NearestChainageResult? chainageCorrection,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<SearchResults>');
    buffer.writeln('    <Metadata>');
    buffer.writeln('        <ExportDate>${DateTime.now().toIso8601String()}</ExportDate>');
    buffer.writeln('        <Source>Track Sections Manager App</Source>');
    buffer.writeln('    </Metadata>');
    
    buffer.writeln('    <SearchParameters>');
    buffer.writeln('        <LCS_Code>${lcs.displayCode}</LCS_Code>');
    buffer.writeln('        <LCS_Description>${lcs.shortDescription}</LCS_Description>');
    buffer.writeln('        <VCC>${lcs.vcc.toStringAsFixed(0)}</VCC>');
    buffer.writeln('        <StartMeterage>${startMeterage.toStringAsFixed(3)}</StartMeterage>');
    buffer.writeln('        <EndMeterage>${endMeterage.toStringAsFixed(3)}</EndMeterage>');
    buffer.writeln('        <LCS_ChainageStart>${lcs.chainageStart.toStringAsFixed(3)}</LCS_ChainageStart>');
    buffer.writeln('        <LCS_ChainageEnd>${lcs.chainageEnd.toStringAsFixed(3)}</LCS_ChainageEnd>');
    if (chainageCorrection != null && chainageCorrection.wasCorrected) {
      buffer.writeln('        <ChainageCorrection>');
      buffer.writeln('            <OriginalMeterage>${chainageCorrection.originalMeterage.toStringAsFixed(3)}</OriginalMeterage>');
      buffer.writeln('            <CorrectedMeterage>${chainageCorrection.correctedMeterage.toStringAsFixed(3)}</CorrectedMeterage>');
      buffer.writeln('            <Distance>${chainageCorrection.distance.toStringAsFixed(3)}</Distance>');
      buffer.writeln('        </ChainageCorrection>');
    }
    buffer.writeln('    </SearchParameters>');
    
    if (locationInfo != null) {
      buffer.writeln('    <LocationInfo>');
      buffer.writeln('        <Station>${_escapeXml(locationInfo.station)}</Station>');
      buffer.writeln('        <Line>${_escapeXml(locationInfo.line)}</Line>');
      buffer.writeln('        <LCS_Code>${locationInfo.lcsCode}</LCS_Code>');
      buffer.writeln('        <Chainage>${locationInfo.chainage.toStringAsFixed(3)}</Chainage>');
      buffer.writeln('        <Meterage>${locationInfo.meterage.toStringAsFixed(3)}</Meterage>');
      if (locationInfo.platforms.isNotEmpty) {
        buffer.writeln('        <Platforms>');
        for (final platform in locationInfo.platforms) {
          buffer.writeln('            <Platform>${_escapeXml(platform)}</Platform>');
        }
        buffer.writeln('        </Platforms>');
      }
      buffer.writeln('    </LocationInfo>');
    }
    
    buffer.writeln('    <TrackSections>');
    buffer.writeln('        <Count>${trackSections.length}</Count>');
    for (final ts in trackSections) {
      buffer.writeln('        <TrackSection>');
      buffer.writeln('            <TS_ID>${ts.tsId}</TS_ID>');
      buffer.writeln('            <Segment>${_escapeXml(ts.segment)}</Segment>');
      buffer.writeln('            <ChainageStart>${ts.chainageStart.toStringAsFixed(3)}</ChainageStart>');
      buffer.writeln('            <VCC>${ts.vcc.toStringAsFixed(0)}</VCC>');
      buffer.writeln('        </TrackSection>');
    }
    buffer.writeln('    </TrackSections>');
    
    buffer.writeln('</SearchResults>');
    return buffer.toString();
  }

  /// Export enhanced track sections to XML (using simple version from enhanced_lcs_ts_models)
  String exportEnhancedTrackSections(List<simple_models.EnhancedTrackSection> sections) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<TrackSections>');
    buffer.writeln('    <Metadata>');
    buffer.writeln('        <Version>3.0</Version>');
    buffer.writeln('        <ExportDate>${DateTime.now().toIso8601String()}</ExportDate>');
    buffer.writeln('        <Count>${sections.length}</Count>');
    buffer.writeln('    </Metadata>');
    
    for (final section in sections) {
      buffer.writeln('    <TrackSection>');
      buffer.writeln('        <ID>${section.id}</ID>');
      buffer.writeln('        <CURRENT_LCS_CODE>${_escapeXml(section.currentLcsCode)}</CURRENT_LCS_CODE>');
      buffer.writeln('        <LEGACY_LCS_CODE>${_escapeXml(section.legacyLcsCode)}</LEGACY_LCS_CODE>');
      if (section.legacyJnpLcsCode != null && section.legacyJnpLcsCode!.isNotEmpty) {
        buffer.writeln('        <LEGACY_JNP_LCS_Code>${_escapeXml(section.legacyJnpLcsCode!)}</LEGACY_JNP_LCS_Code>');
      }
      buffer.writeln('        <RoadStatus>${_escapeXml(section.roadStatus)}</RoadStatus>');
      buffer.writeln('        <OperatingLineCode>${section.operatingLineCode}</OperatingLineCode>');
      buffer.writeln('        <OperatingLine>${_escapeXml(section.operatingLine)}</OperatingLine>');
      buffer.writeln('        <NEW_LONG_DESCRIPION>${_escapeXml(section.newLongDescription)}</NEW_LONG_DESCRIPION>');
      buffer.writeln('        <NEW_SHORT_DESCRIPION>${_escapeXml(section.newShortDescription)}</NEW_SHORT_DESCRIPION>');
      buffer.writeln('        <VCC>${section.vcc.toStringAsFixed(0)}</VCC>');
      buffer.writeln('        <ThalesChainage>${section.thalesChainage.toStringAsFixed(3)}</ThalesChainage>');
      buffer.writeln('        <SegmentID>${_escapeXml(section.segmentId)}</SegmentID>');
      buffer.writeln('        <LCS_MeterageStart>${section.lcsMeterageStart.toStringAsFixed(3)}</LCS_MeterageStart>');
      buffer.writeln('        <LCS_MeterageEnd>${section.lcsMeterageEnd.toStringAsFixed(3)}</LCS_MeterageEnd>');
      buffer.writeln('        <Track>${_escapeXml(section.track)}</Track>');
      buffer.writeln('        <TrackSection>${section.trackSection}</TrackSection>');
      if (section.physicalAssets != null && section.physicalAssets!.isNotEmpty) {
        buffer.writeln('        <PhysicalAssets>${_escapeXml(section.physicalAssets!)}</PhysicalAssets>');
      }
      if (section.notes != null && section.notes!.isNotEmpty) {
        buffer.writeln('        <Notes>${_escapeXml(section.notes!)}</Notes>');
      }
      buffer.writeln('    </TrackSection>');
    }
    
    buffer.writeln('</TrackSections>');
    return buffer.toString();
  }

  /// Export all data to XML format
  String exportToXml(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<TSManagerData>');
    buffer.writeln('  <Metadata>');

    if (data.containsKey('metadata')) {
      final metadata = data['metadata'] as Map<String, dynamic>;
      buffer.writeln('    <ExportedAt>${metadata['exported_at']}</ExportedAt>');
      buffer.writeln('    <Version>${metadata['version']}</Version>');
    }

    buffer.writeln('  </Metadata>');

    // Export station mappings
    if (data.containsKey('station_mappings')) {
      buffer.writeln('  <StationMappings>');
      final mappings = data['station_mappings'] as List<dynamic>;
      for (final mapping in mappings) {
        buffer.writeln('    <Mapping>');
        buffer.writeln('      <LcsCode>${_escapeXml(mapping['lcsCode'])}</LcsCode>');
        buffer.writeln('      <Station>${_escapeXml(mapping['station'])}</Station>');
        buffer.writeln('      <Line>${_escapeXml(mapping['line'])}</Line>');
        buffer.writeln('    </Mapping>');
      }
      buffer.writeln('  </StationMappings>');
    }

    // Export track sections
    if (data.containsKey('track_sections')) {
      buffer.writeln('  <TrackSections>');
      final sections = data['track_sections'] as List<dynamic>;
      for (final section in sections) {
        buffer.writeln('    <TrackSection>');
        if (section.containsKey('id')) buffer.writeln('      <ID>${section['id']}</ID>');
        if (section.containsKey('currentLcsCode')) buffer.writeln('      <CurrentLcsCode>${_escapeXml(section['currentLcsCode'])}</CurrentLcsCode>');
        if (section.containsKey('legacyLcsCode')) buffer.writeln('      <LegacyLcsCode>${_escapeXml(section['legacyLcsCode'])}</LegacyLcsCode>');
        if (section.containsKey('operatingLine')) buffer.writeln('      <OperatingLine>${_escapeXml(section['operatingLine'])}</OperatingLine>');
        if (section.containsKey('newShortDescription')) buffer.writeln('      <Description>${_escapeXml(section['newShortDescription'])}</Description>');
        if (section.containsKey('trackSection')) buffer.writeln('      <TrackSectionNumber>${section['trackSection']}</TrackSectionNumber>');
        buffer.writeln('    </TrackSection>');
      }
      buffer.writeln('  </TrackSections>');
    }

    // Export user LCS to track sections mappings
    if (data.containsKey('user_lcs_to_track_sections')) {
      buffer.writeln('  <UserLcsToTrackSections>');
      final mappings = data['user_lcs_to_track_sections'] as Map<String, dynamic>;
      for (final entry in mappings.entries) {
        buffer.writeln('    <LcsMapping>');
        buffer.writeln('      <LcsCode>${_escapeXml(entry.key)}</LcsCode>');
        buffer.writeln('      <TrackSections>');
        for (final tsId in entry.value as List) {
          buffer.writeln('        <TSID>$tsId</TSID>');
        }
        buffer.writeln('      </TrackSections>');
        buffer.writeln('    </LcsMapping>');
      }
      buffer.writeln('  </UserLcsToTrackSections>');
    }

    buffer.writeln('</TSManagerData>');
    return buffer.toString();
  }

  /// Import data from XML format
  Map<String, dynamic> importFromXml(String xmlString) {
    // Basic XML parsing - for production, use xml package
    final data = <String, dynamic>{
      'metadata': {
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.0',
      },
      'station_mappings': <Map<String, dynamic>>[],
      'track_sections': <Map<String, dynamic>>[],
      'user_lcs_to_track_sections': <String, List<int>>{},
    };

    // This is a simplified parser - in production, use xml package properly
    // For now, return empty structure to avoid errors
    print('Warning: XML import is simplified - use JSON for full import');
    return data;
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

