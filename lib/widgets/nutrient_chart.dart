import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/nutrient_analysis.dart';
import '../theme/app_colors.dart';

/// Horizontal bar chart used for food-specific and weekly nutrient totals.
///
/// A plain widget-based chart is used instead of a canvas so it stays readable
/// on narrow phones, follows the active palette and needs no chart package.
class NutrientBarChart extends StatelessWidget {
  const NutrientBarChart({
    super.key,
    required this.breakdown,
    this.emptyLabel = 'No nutrient data yet.',
    this.barColor,
  });

  final NutrientBreakdown breakdown;
  final String emptyLabel;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final totals = breakdown.chartTotals;
    if (totals.isEmpty) {
      return Text(
        emptyLabel,
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
      );
    }

    final max = breakdown.maxChartValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < totals.length; i++)
          _NutrientBar(
            total: totals[i],
            fraction: (totals[i].value / max).clamp(0.02, 1.0).toDouble(),
            color: _colorFor(i, barColor),
          ),
      ],
    );
  }

  Color _colorFor(int index, Color? override) {
    if (override != null) return override;
    final palette = [
      AppColors.primaryOrange,
      AppColors.emerald,
      AppColors.amber,
      AppColors.rose,
    ];
    return palette[index % palette.length];
  }
}

class _NutrientBar extends StatelessWidget {
  const _NutrientBar({
    required this.total,
    required this.fraction,
    required this.color,
  });

  final NutrientTotal total;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSlate,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                total.display,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ranked list of the foods that contributed the most nutrients.
class NutrientContributorList extends StatelessWidget {
  const NutrientContributorList({
    super.key,
    required this.breakdown,
    this.emptyLabel = 'Save analysed foods to see the biggest contributors.',
  });

  final NutrientBreakdown breakdown;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final foods = breakdown.contributors.take(5).toList();
    if (foods.isEmpty) {
      return Text(
        emptyLabel,
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
      );
    }
    final maxMass = foods
        .map((food) => food.nutrientMass)
        .fold<double>(0, (max, value) => value > max ? value : max);
    return Column(
      children: [
        for (final food in foods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        food.topNutrient == null
                            ? '${food.calories} kcal'
                            : '${food.topNutrient!.name} '
                                  '${food.topNutrient!.display} · '
                                  '${food.calories} kcal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxMass <= 0
                          ? 0
                          : (food.nutrientMass / maxMass).clamp(0.05, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceHigh,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
