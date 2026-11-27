import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/workout_models.dart';
import 'package:workout_app/screens/saved_workouts_screen.dart';
import 'package:workout_app/screens/workout_result_screen.dart';
import 'package:workout_app/state/workout_state.dart';

void main() {
  const workout = WorkoutModel(
    id: 'saved-1',
    name: 'Full Body Strength and Core Stability Routine',
    focus: 'Full Body Strength and Core Stability',
    duration: '65 min',
    difficulty: 'Advanced',
    date: 'Monday, November 27, 2026',
    exercises: [
      ExerciseModel(
        name: 'Single-Leg Romanian Deadlift with Dumbbells',
        category: 'Legs',
        difficulty: 'Advanced',
        target: 'Hamstrings',
        equipment: 'Dumbbells',
        sets: '4 sets',
        reps: '10 reps',
        rest: '90 sec',
        pr: '',
        cues: ['Hinge at the hips', 'Keep the spine neutral'],
      ),
    ],
  );

  testWidgets('viewing a saved workout does not overflow at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WorkoutState();
    state.setCurrentWorkout(workout);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutResultScreen(
          state: state,
          onBackToInput: () {},
          onSaved: () {},
          onGoHome: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Workout Result'), findsOneWidget);
    expect(
      find.text('Single-Leg Romanian Deadlift with Dumbbells'),
      findsOneWidget,
    );
  });

  testWidgets('saved workout cards do not overflow at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = WorkoutState();
    state.saveWorkout(workout);

    await tester.pumpWidget(
      MaterialApp(
        home: SavedWorkoutsScreen(
          state: state,
          onBackToHome: () {},
          onNavigateToInput: () {},
          onViewWorkout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Saved Workouts'), findsOneWidget);
    expect(find.text(workout.name), findsOneWidget);
  });
}
