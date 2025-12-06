// services/export_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw';
import 'package:excel/excel.dart' as excel_lib;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/track_data.dart';
import '../models/enhanced_track_data.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  // ============================================
  // CSV EXPORT
  // ============================================

  /// Export track sections to CSV format
  Future<File?> exportTrackSectionsToCSV(List<TrackSection> sections) async {
    try {
      List<List<dynamic>> rows = [];

      // Add header row
      rows.add([
        'LCS Code',
        'Legacy LCS Code',
        'Operating Line',
        'Description',
        'Meterage Start',
        'Meterage End',
        'Track',
        'Section',
        'Physical Assets',
        'Notes',
      ]);

      // Add data rows
      for (var section in sections) {
        rows.add([
          section.lcsCode,
          section.legacyLcsCode,
          section.operatingLine,
          section.newShortDescription,
          section.lcsMeterageStart.toStringAsFixed(2),
          section.lcsMeterageEnd.toStringAsFixed(2),
          section.track,
          section.trackSection,
          section.physicalAssets,
          section.notes,
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await _getDownloadsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/track_sections_$timestamp.csv');
      await file.writeAsString(csv);

      debugPrint('CSV exported successfully: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      return null;
    }
  }

  /// Export stations to CSV format
  Future<File?> exportStationsToCSV(List<LCSStationMapping> stations) async {
    try {
      List<List<dynamic>> rows = [];

      // Add header row
      rows.add([
        'LCS Code',
        'Station',
        'Line',
        'Branch',
        'Latitude',
        'Longitude',
        'Zone',
        'Interchanges',
      ]);

      // Add data rows
      for (var station in stations) {
        rows.add([
          station.lcsCode,
          station.station,
          station.line,
          station.branch ?? '',
          station.latitude?.toStringAsFixed(6) ?? '',
          station.longitude?.toStringAsFixed(6) ?? '',
          station.zone ?? '',
          station.interchanges.join(', '),
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await _getDownloadsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/stations_$timestamp.csv');
      await file.writeAsString(csv);

      debugPrint('Stations CSV exported successfully: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting stations to CSV: $e');
      return null;
    }
  }

  // ============================================
  // EXCEL EXPORT
  // ============================================

  /// Export track sections to Excel format
  Future<File?> exportTrackSectionsToExcel(List<TrackSection> sections) async {
    try {
      var excel = excel_lib.Excel.createExcel();
      var sheet = excel['Track Sections'];

      // Define header style
      var headerStyle = excel_lib.CellStyle(
        backgroundColorHex: '#1976D2',
        fontColorHex: '#FFFFFF',
        bold: true,
      );

      // Add headers
      final headers = [
        'LCS Code',
        'Legacy LCS Code',
        'Operating Line',
        'Description',
        'Meterage Start',
        'Meterage End',
        'Length (m)',
        'Track',
        'Section',
        'VCC',
        'Segment ID',
        'Physical Assets',
        'Notes',
      ];

      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = headers[i];
        cell.cellStyle = headerStyle;
      }

      // Add data rows
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        final rowData = [
          section.lcsCode,
          section.legacyLcsCode,
          section.operatingLine,
          section.newShortDescription,
          section.lcsMeterageStart,
          section.lcsMeterageEnd,
          section.length,
          section.track,
          section.trackSection,
          section.vcc,
          section.segmentId,
          section.physicalAssets,
          section.notes,
        ];

        for (var j = 0; j < rowData.length; j++) {
          sheet
              .cell(excel_lib.CellIndex.indexByColumnRow(
                columnIndex: j,
                rowIndex: i + 1,
              ))
              .value = rowData[j];
        }
      }

      // Auto-fit columns (approximate)
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // Save to file
      final directory = await _getDownloadsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/track_sections_$timestamp.xlsx');

      final excelBytes = excel.encode();
      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes);
        debugPrint('Excel exported successfully: ${file.path}');
        return file;
      }

      return null;
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      return null;
    }
  }

  // ============================================
  // PDF EXPORT
  // ============================================

  /// Export track sections to PDF format
  Future<File?> exportTrackSectionsToPDF(List<TrackSection> sections) async {
    try {
      final pdf = pw.Document();

      // Split sections into pages (10 per page)
      const itemsPerPage = 10;
      final totalPages = (sections.length / itemsPerPage).ceil();

      for (var pageNum = 0; pageNum < totalPages; pageNum++) {
        final startIndex = pageNum * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage < sections.length)
            ? startIndex + itemsPerPage
            : sections.length;
        final pageSections = sections.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    color: PdfColors.blue700,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Track Sections Manager',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Page ${pageNum + 1} of $totalPages',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        children: [
                          _buildTableCell('LCS Code', isHeader: true),
                          _buildTableCell('Line', isHeader: true),
                          _buildTableCell('Description', isHeader: true),
                          _buildTableCell('Meterage', isHeader: true),
                          _buildTableCell('Track', isHeader: true),
                        ],
                      ),

                      // Data rows
                      ...pageSections.map((section) {
                        return pw.TableRow(
                          children: [
                            _buildTableCell(section.lcsCode),
                            _buildTableCell(section.operatingLine),
                            _buildTableCell(section.newShortDescription),
                            _buildTableCell(
                              '${section.lcsMeterageStart.toStringAsFixed(1)} - '
                              '${section.lcsMeterageEnd.toStringAsFixed(1)}',
                            ),
                            _buildTableCell(section.track),
                          ],
                        );
                      }).toList(),
                    ],
                  ),

                  pw.Spacer(),

                  // Footer
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Text(
                      'Generated on ${DateTime.now().toString().split('.')[0]}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save to file
      final directory = await _getDownloadsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/track_sections_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint('PDF exported successfully: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      return null;
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Print PDF directly
  Future<void> printTrackSections(List<TrackSection> sections) async {
    try {
      final file = await exportTrackSectionsToPDF(sections);
      if (file != null) {
        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
        );
      }
    } catch (e) {
      debugPrint('Error printing: $e');
    }
  }

  // ============================================
  // SHARING
  // ============================================

  /// Share file
  Future<void> shareFile(File file, String title) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: title,
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }

  /// Share text
  Future<void> shareText(String text, String subject) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }

  // ============================================
  // UTILITIES
  // ============================================

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // For Android, use the Downloads directory
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // For iOS, use the documents directory
      return await getApplicationDocumentsDirectory();
    } else {
      // For other platforms, use downloads directory
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  }

  /// Export query result as JSON
  Future<File?> exportQueryResultToJSON(QueryResult result) async {
    try {
      final jsonString = result.toJson().toString();
      final directory = await _getDownloadsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/query_result_$timestamp.json');
      await file.writeAsString(jsonString);

      debugPrint('JSON exported successfully: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('Error exporting to JSON: $e');
      return null;
    }
  }

  /// Get export statistics
  Map<String, dynamic> getExportStats(List<TrackSection> sections) {
    final stats = <String, dynamic>{};

    stats['total_sections'] = sections.length;
    stats['total_length'] = sections.fold<double>(
      0,
      (sum, section) => sum + section.length,
    );

    final lineGroups = <String, int>{};
    for (var section in sections) {
      lineGroups[section.operatingLine] =
          (lineGroups[section.operatingLine] ?? 0) + 1;
    }
    stats['sections_by_line'] = lineGroups;

    return stats;
  }
}
