import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../state/workout_state.dart';
import 'exercise_logger_screen.dart';
import 'home_screen.dart';
import 'pose_tracking_screen.dart';
import 'saved_workouts_screen.dart';
import 'workout_input_screen.dart';
import 'workout_result_screen.dart';

/// Application shell: a Material 3 [NavigationBar] plus a real [Navigator].
///
/// The navigator is important: Flutter [Hero] animations can only fly between
/// *routes*, so every screen now lives on its own route instead of being
/// swapped inside a widget tree.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _RouteChangeObserver extends NavigatorObserver {
  _RouteChangeObserver(this.onChanged);

  final ValueChanged<String?> onChanged;

  @override
  void didPush(Route route, Route? previousRoute) =>
      onChanged(route.settings.name);

  @override
  void didPop(Route route, Route? previousRoute) =>
      onChanged(previousRoute?.settings.name);

  // Deliberately no didRemove/didReplace: pushNamedAndRemoveUntil reports the
  // routes it removed underneath the new tab, which used to reset the
  // selection back to Home after the new route had already been pushed.
}

class _MainShellState extends State<MainShell> {
  final WorkoutState _state = WorkoutState();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static const String homeRoute = '/home';
  static const String inputRoute = '/generate';
  static const String resultRoute = '/result';
  static const String savedRoute = '/saved';
  static const String loggerRoute = '/logger';
  static const String poseRoute = '/pose';

  late final _RouteChangeObserver _observer;

  // Only the NavigationBar listens to this, so route changes no longer rebuild
  // the Navigator and its currently mounted screens.
  final ValueNotifier<int> _selectedTab = ValueNotifier<int>(0);
  String _currentRoute = homeRoute;
  String? _preselectedExercise;

  static const List<String> _tabs = [
    homeRoute,
    inputRoute,
    savedRoute,
    loggerRoute,
    poseRoute,
  ];

  int _tabForRoute(String? route) {
    switch (route) {
      case inputRoute:
      case resultRoute:
        return 1;
      case savedRoute:
        return 2;
      case loggerRoute:
        return 3;
      case poseRoute:
        return 4;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    // The navigator pushes its first route *while* this widget is still being
    // built, so route-change callbacks must never call setState synchronously.
    // Always defer them to the end of the current frame.
    _observer = _RouteChangeObserver((route) {
      final routeName = route ?? homeRoute;
      _currentRoute = routeName;
      final tab = _tabForRoute(routeName);
      _updateAfterBuild(() {
        if (_selectedTab.value != tab) _selectedTab.value = tab;
      });
    });
    _state.addListener(_handleStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_handleStateChanged);
    _selectedTab.dispose();
    super.dispose();
  }

  void _handleStateChanged() {
    _updateAfterBuild(() {
      if (mounted) setState(() {});
    });
  }

  void _updateAfterBuild(VoidCallback update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) update();
    });
  }

  /// Push a new screen on top of the current one (keeps Hero transitions).
  void _open(String route, {String? exercise}) {
    _preselectedExercise = exercise;
    _currentRoute = route;
    _navigatorKey.currentState?.pushNamed(route);
  }

  /// Bottom navigation: reset to that tab's root route.
  void _switchTab(String route) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final previousRoute = _currentRoute;
    _currentRoute = route;
    _selectedTab.value = _tabForRoute(route);

    // Already on this tab's root route - avoid a redundant route transition.
    if (previousRoute == route) return;

    if (route == homeRoute) {
      navigator.popUntil((r) => r.isFirst);
      return;
    }

    // Keeps home underneath and replaces any pushed routes in one transaction,
    // instead of popping them one by one and then pushing the new tab.
    navigator.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
  }

  /// Reverse navigation (also reverses the Hero flight).
  void _back() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      _switchTab(homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: Navigator(
                    key: _navigatorKey,
                    initialRoute: homeRoute,
                    observers: [_observer],
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: (_) => _buildScreen(settings.name ?? homeRoute),
                    ),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _selectedTab,
                  builder: (context, selectedIndex, _) {
                    return NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) =>
                          _switchTab(_tabs[index]),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.auto_awesome_outlined),
                          selectedIcon: Icon(Icons.auto_awesome),
                          label: 'Generate',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.bookmark_border),
                          selectedIcon: Icon(Icons.bookmark),
                          label: 'Saved',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.timer_outlined),
                          selectedIcon: Icon(Icons.timer),
                          label: 'Logger',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.accessibility_new_outlined),
                          selectedIcon: Icon(Icons.accessibility_new),
                          label: 'Pose',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(String route) {
    switch (route) {
      case inputRoute:
        return WorkoutInputScreen(
          state: _state,
          initialExercise: _preselectedExercise,
          onBackToHome: _back,
          onGenerated: () => _open(resultRoute),
        );
      case resultRoute:
        return WorkoutResultScreen(
          state: _state,
          onBackToInput: _back,
          onSaved: () => _switchTab(savedRoute),
          onGoHome: () => _switchTab(homeRoute),
          onLogExercise: (exercise) => _open(loggerRoute, exercise: exercise),
        );
      case savedRoute:
        return SavedWorkoutsScreen(
          state: _state,
          onBackToHome: _back,
          onNavigateToInput: () => _open(inputRoute),
          onViewWorkout: (WorkoutModel workout) {
            _state.setCurrentWorkout(workout);
            _open(resultRoute);
          },
        );
      case loggerRoute:
        return ExerciseLoggerScreen(
          state: _state,
          initialExerciseName: _preselectedExercise,
          onBackToHome: _back,
        );
      case poseRoute:
        return PoseTrackingScreen(onBackToHome: _back);
      case homeRoute:
      default:
        return HomeScreen(
          state: _state,
          onTabChange: (tabIndex) {
            if (tabIndex >= 0 && tabIndex < _tabs.length) {
              _switchTab(_tabs[tabIndex]);
            }
          },
          onNavigateToInput: (exercise) =>
              _open(inputRoute, exercise: exercise),
        );
    }
  }
}
