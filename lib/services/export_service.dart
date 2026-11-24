import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/workout_models.dart';
import '../web/file_downloader.dart';
import 'download_saver.dart';

/// One aggregate data point of the progress graph (a time bin/column).
typedef GraphPoint = ({String label, double value});

/// One category distribution row.
typedef CategoryPoint = ({
  String category,
  double volume,
  double percentage,
  int sessionCount,
  int durationSeconds,
});

/// Exportable progress-graph data snapshot for the currently selected
/// timeframe (Daily / Weekly / Monthly). Only the bins of that timeframe
/// are exported - "that column data" of the selected view.
class ExportData {
  final String timeframe;
  final List<GraphPoint> overallPoints;
  final List<CategoryPoint> categoryPoints;
  final List<WorkoutSessionLog> sessions;

  const ExportData({
    required this.timeframe,
    required this.overallPoints,
    required this.categoryPoints,
    required this.sessions,
  });

  double get totalVolume => overallPoints.fold(0.0, (a, b) => a + b.value);
  int get totalDuration =>
      categoryPoints.fold(0, (a, b) => a + b.durationSeconds);
}

/// Builds and saves progress-graph exports as CSV or PDF.
///
/// CSV: proper rows/columns, one section per entity group (summary, overall
/// progress bins, category distribution, per-set detail) - all restricted
/// to the selected timeframe's data.
///
/// PDF: same sections laid out as tables with a title header.
class ExportService {
  // ── CSV ────────────────────────────────────────────────────────────────
  static String buildCsv(ExportData data) {
    final sb = StringBuffer();

    // Meta section
    sb.writeln('Workout Progress Export');
    sb.writeln('Timeframe,${data.timeframe}');
    sb.writeln('Generated,${DateTime.now()}');
    sb.writeln();

    // Summary section
    sb.writeln('SUMMARY');
    sb.writeln('Metric,Value');
    sb.writeln('Total Volume (kg),${data.totalVolume.toStringAsFixed(1)}');
    sb.writeln('Sessions,${data.sessions.length}');
    final hours = data.totalDuration ~/ 3600;
    final mins = (data.totalDuration % 3600) ~/ 60;
    sb.writeln('Total Time,"${hours}h ${mins}m"');
    sb.writeln();

    // Overall progress section: one row per timeframe bin/column
    sb.writeln('OVERALL EXERCISE PROGRESS (Volume Load, kg)');
    sb.writeln('Period,Volume (kg)');
    for (final p in data.overallPoints) {
      sb.writeln('${_csvCell(p.label)},${p.value.toStringAsFixed(1)}');
    }
    sb.writeln();

    // Category distribution section
    sb.writeln('CATEGORY-WISE DISTRIBUTION');
    sb.writeln(
      'Category,Sessions,Volume (kg),Share (%),Time Recorded (seconds),Time Recorded',
    );
    for (final c in data.categoryPoints) {
      final mins = c.durationSeconds ~/ 60;
      final secs = c.durationSeconds % 60;
      sb.writeln(
        '${_csvCell(c.category)},${c.sessionCount},'
        '${c.volume.toStringAsFixed(1)},${c.percentage.toStringAsFixed(1)},'
        '${c.durationSeconds},"${mins}m ${secs}s"',
      );
    }
    sb.writeln();

    // Per-set detail section: singular weight only (never weight x reps)
    sb.writeln('SESSION SET DETAIL (weight as logged, not multiplied by reps)');
    sb.writeln(
      'Date,Exercise,Category,Set,Weight (kg),Reps,Set Duration (s),Rest (s)',
    );
    for (final log in data.sessions) {
      final date =
          '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')}';
      for (final set in log.sets) {
        sb.writeln(
          '$date,${_csvCell(log.exerciseName)},${_csvCell(log.category)},'
          'S${set.setNumber},${set.weight.toStringAsFixed(1)},'
          '${set.reps},${set.durationSeconds},${set.restSeconds}',
        );
      }
    }

    return sb.toString();
  }

  static String _csvCell(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── PDF ────────────────────────────────────────────────────────────────
  static Future<List<int>> buildPdf(ExportData data) async {
    final doc = pw.Document();

    final summaryRows = [
      ['Total Volume', '${data.totalVolume.toStringAsFixed(1)} kg'],
      ['Sessions', '${data.sessions.length}'],
      ['Time Recorded', _fmtDur(data.totalDuration)],
    ];

    final overallRows = data.overallPoints
        .map((p) => [p.label, p.value.toStringAsFixed(1)])
        .toList();

    final categoryRows = data.categoryPoints
        .map(
          (c) => [
            c.category,
            '${c.sessionCount}',
            c.volume.toStringAsFixed(1),
            '${c.percentage.toStringAsFixed(1)}%',
            _fmtDur(c.durationSeconds),
          ],
        )
        .toList();

    final setRows = <List<String>>[];
    for (final log in data.sessions) {
      final date =
          '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}';
      for (final set in log.sets) {
        setRows.add([
          date,
          log.exerciseName,
          'S${set.setNumber}',
          _fmtKg(set.weight),
          '${set.reps}',
          '${set.durationSeconds}s',
        ]);
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Workout Progress Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Timeframe: ${data.timeframe}  •  Generated: ${DateTime.now()}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Metric', 'Value'],
            data: summaryRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Overall Exercise Progress (Volume Load, kg)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Period', 'Volume (kg)'],
            data: overallRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Category-Wise Distribution',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Sessions', 'Volume (kg)', 'Share', 'Time'],
            data: categoryRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Session Set Detail (weight as logged, not x reps)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Exercise', 'Set', 'Weight (kg)', 'Reps', 'Time'],
            data: setRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Save / Download ────────────────────────────────────────────────────
  static Future<String> saveCsv(ExportData data) async {
    final name = _fileName(data.timeframe, 'csv');
    final content = buildCsv(data);
    return saveBytes(name, utf8.encode(content), 'text/csv');
  }

  static Future<String> savePdf(ExportData data) async {
    final name = _fileName(data.timeframe, 'pdf');
    final bytes = await buildPdf(data);
    return saveBytes(name, bytes, 'application/pdf');
  }

  static String _fileName(String timeframe, String ext) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'progress_${timeframe.toLowerCase()}_$stamp.$ext';
  }

  /// Saves export bytes to Android Downloads (visible in a file manager), to
  /// the browser download folder on web, or to app documents elsewhere.
  /// Shared with the diet summary exporter.
  static Future<String> saveBytes(
    String name,
    List<int> bytes,
    String mime,
  ) async {
    if (kIsWeb) {
      // Trigger a browser download via a Blob + temporary <a> element.
      downloadBytes(name, bytes, mime);
      return name;
    }

    final downloadsPath = await saveToAndroidDownloads(name, bytes, mime);
    if (downloadsPath != null) return downloadsPath;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static String _fmtDur(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${seconds % 60}s';
    return '${seconds}s';
  }

  static String _fmtKg(double w) {
    if (w <= 0) return 'BW';
    return w == w.roundToDouble() ? w.round().toString() : w.toStringAsFixed(1);
  }
}
