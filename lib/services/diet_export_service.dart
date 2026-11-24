import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diet_models.dart';
import 'export_service.dart';

/// Builds and saves the Diet summary (everything tracked up to now) as CSV or
/// PDF. Reuses [ExportService.saveBytes] so web downloads work the same way as
/// the workout progress exports.
class DietExportService {
  static String buildCsv(DietSummary data) {
    final sb = StringBuffer();

    sb.writeln('Diet Summary Export');
    sb.writeln('Scope,${_csvCell(data.scope)}');
    sb.writeln('Generated,${data.generatedAt}');
    sb.writeln('Week Calorie Goal (kcal),${data.weekCalorieGoal}');
    sb.writeln('Week Water Goal (ml),${data.weekWaterGoalMl}');
    sb.writeln(
      'Week Rest Goal,${_csvCell(_fmtSleep(data.weekRestGoalMinutes))}',
    );
    sb.writeln();

    sb.writeln('SUMMARY');
    sb.writeln('Metric,Value');
    sb.writeln('Days with activities,${data.days.length}');
    sb.writeln('Days with 50%+ goal met,${data.daysGoalMet}');
    sb.writeln('Total calories consumed (kcal),${data.totalCalories}');
    sb.writeln('Total water consumed (ml),${data.totalWaterMl}');
    sb.writeln('Total sleep,${_csvCell(_fmtSleep(data.totalSleepMinutes))}');
    sb.writeln('Total activities,${data.totalActivities}');
    sb.writeln('Food activities,${data.foodCount}');
    sb.writeln('Water activities,${data.waterCount}');
    sb.writeln('Rest / sleep activities,${data.restCount}');
    sb.writeln();

    sb.writeln('DAILY BREAKDOWN');
    sb.writeln(
      'Date,Calorie Goal (kcal),Calories Eaten (kcal),Water Goal (ml),'
      'Water Drunk (ml),Rest Goal,Sleep,Activities,50%+ Goal',
    );
    for (final day in data.days) {
      sb.writeln(
        '${_date(day.date)},${day.calorieGoal},${day.caloriesConsumed},'
        '${day.waterGoalMl},${day.waterConsumedMl},'
        '${_csvCell(_fmtSleep(day.restGoalMinutes))},'
        '${_csvCell(_fmtSleep(day.sleepMinutes))},${day.activityCount},'
        '${day.isGoalHalfMet ? 'Yes' : 'No'}',
      );
    }
    sb.writeln();

    sb.writeln('ACTIVITY LOG');
    sb.writeln(
      'Date,Slot,Type,Label,Detail,Quantity Unit,Calories (kcal),'
      'Water (ml),Sleep (min)',
    );
    for (final item in data.entries) {
      final entry = item.entry;
      sb.writeln(
        '${_date(item.date)},${_csvCell(slotLabel(entry.slotHour))},'
        '${entry.type.name},${_csvCell(entry.label)},'
        '${_csvCell(entry.detail)},${entry.quantityUnit ?? ''},'
        '${entry.calories},${entry.waterMl},${entry.sleepMinutes}',
      );
    }

    return sb.toString();
  }

  static Future<List<int>> buildPdf(DietSummary data) async {
    final doc = pw.Document();

    final summaryRows = [
      ['Days with activities', '${data.days.length}'],
      ['Days with 50%+ goal met', '${data.daysGoalMet}'],
      ['Calories consumed', '${data.totalCalories} kcal'],
      ['Water consumed', '${data.totalWaterMl} ml'],
      ['Total sleep', _fmtSleep(data.totalSleepMinutes)],
      [
        'Food / Water / Rest',
        '${data.foodCount} / ${data.waterCount} / ${data.restCount}',
      ],
      ['Week calorie goal', '${data.weekCalorieGoal} kcal'],
      ['Week water goal', '${data.weekWaterGoalMl} ml'],
      ['Week rest goal', _fmtSleep(data.weekRestGoalMinutes)],
    ];

    final dailyRows = data.days
        .map(
          (day) => [
            _date(day.date),
            '${day.caloriesConsumed}/${day.calorieGoal}',
            '${day.waterConsumedMl}/${day.waterGoalMl}',
            '${_fmtSleep(day.sleepMinutes)}/${_fmtSleep(day.restGoalMinutes)}',
            day.isGoalHalfMet ? 'Yes' : 'No',
          ],
        )
        .toList();

    final activityRows = data.entries
        .map(
          (item) => [
            _date(item.date),
            slotLabel(item.entry.slotHour),
            item.entry.type.name,
            item.entry.label,
            item.entry.detail,
            item.entry.quantityUnit ?? '',
            item.entry.type == DietActivityType.food
                ? '${item.entry.calories} kcal'
                : item.entry.type == DietActivityType.water
                ? '${item.entry.waterMl} ml'
                : _fmtSleep(item.entry.sleepMinutes),
          ],
        )
        .toList();

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
                  'Diet Summary Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${data.scope}  •  Generated: ${data.generatedAt}',
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
          _table(['Metric', 'Value'], summaryRows),
          pw.SizedBox(height: 14),
          pw.Text(
            'Daily Breakdown',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _table([
            'Date',
            'Calories (eaten/goal)',
            'Water ml (drunk/goal)',
            'Sleep/rest goal',
            '50%+',
          ], dailyRows),
          pw.SizedBox(height: 14),
          pw.Text(
            'Activity Log',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _table(
            ['Date', 'Slot', 'Type', 'Label', 'Detail', 'Unit', 'Value'],
            activityRows,
            fontSize: 8,
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _table(
    List<String> headers,
    List<List<String>> rows, {
    double fontSize = 9,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: pw.TextStyle(fontSize: fontSize),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );
  }

  static Future<String> saveCsv(DietSummary data) {
    final name = 'diet_summary_${_stamp()}.csv';
    return ExportService.saveBytes(
      name,
      utf8.encode(buildCsv(data)),
      'text/csv',
    );
  }

  static Future<String> savePdf(DietSummary data) async {
    final name = 'diet_summary_${_stamp()}.pdf';
    final bytes = await buildPdf(data);
    return ExportService.saveBytes(name, bytes, 'application/pdf');
  }

  static String _stamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  static String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _fmtSleep(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  static String _csvCell(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
