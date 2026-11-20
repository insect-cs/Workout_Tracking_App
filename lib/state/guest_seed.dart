import 'workout_state.dart';

/// Preloaded data for the guest profile.
///
/// The guest session is the device's original test/demo profile. Its saved
/// workouts, active workout and exercise logs already exist as defaults in
/// [WorkoutState]; this helper writes them into the guest namespace the first
/// time that profile is selected so a new user never inherits them.
abstract final class GuestSeed {
  static Future<void> ensureSeeded() => WorkoutState.instance.ensureSeeded();
}
