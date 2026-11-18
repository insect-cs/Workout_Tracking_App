/// Shared element (Hero) tags used for route-to-route transitions.
///
/// Keeping them centralized guarantees the source and destination widgets
/// always use the exact same tag, which is what makes Flutter's Hero
/// animation light up.
abstract final class AppHeroTags {
  static const String aiGenerator = 'hero-ai-generator';

  static String exercise(String name) => 'hero-exercise-$name';

  static String workout(String id) => 'hero-workout-$id';

  static String logExercise(String name) => 'hero-log-exercise-$name';

  static const String posePreview = 'hero-pose-preview';

  static const String poseAnalysis = 'hero-pose-analysis';

  static const String profile = 'hero-profile';
}
