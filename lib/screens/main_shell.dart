import 'dart:async';

import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../state/session_state.dart';
import '../state/workout_state.dart';
import '../theme/nav_animations.dart';
import 'calories_screen.dart';
import 'diet_screen.dart';
import 'exercise_logger_screen.dart';
import 'home_screen.dart';
import 'keys_screen.dart';
import 'plan_screen.dart';
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
  final WorkoutState _state = WorkoutState.instance;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static const String homeRoute = '/home';
  static const String planRoute = '/plan';
  static const String caloriesRoute = '/calories';
  static const String dietRoute = '/diet';
  static const String keysRoute = '/keys';
  static const String inputRoute = '/generate';
  static const String resultRoute = '/result';
  static const String savedRoute = '/saved';
  static const String loggerRoute = '/logger';
  static const String poseRoute = '/pose';

  late final _RouteChangeObserver _observer;

  // Only the NavigationBar listens to this, so route changes no longer rebuild
  // the Navigator and its currently mounted screens.
  final ValueNotifier<int> _selectedTab = ValueNotifier<int>(0);
  final ValueNotifier<NavPressEvent> _pressEvent = ValueNotifier<NavPressEvent>(
    const NavPressEvent(-1, 0),
  );
  int _pressSequence = 0;
  String _currentRoute = homeRoute;
  String? _preselectedExercise;

  static const List<String> _tabs = [
    homeRoute,
    planRoute,
    caloriesRoute,
    inputRoute,
    savedRoute,
    loggerRoute,
    poseRoute,
  ];

  int _tabForRoute(String? route) {
    switch (route) {
      case planRoute:
        return 1;
      case caloriesRoute:
        return 2;
      // Diet and Keys are opened from Home, so Home stays highlighted.
      case dietRoute:
      case keysRoute:
        return 0;
      case inputRoute:
      case resultRoute:
        return 3;
      case savedRoute:
        return 4;
      case loggerRoute:
        return 5;
      case poseRoute:
        return 6;
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
    unawaited(_state.ensureLoaded());
  }

  @override
  void dispose() {
    _state.removeListener(_handleStateChanged);
    _selectedTab.dispose();
    _pressEvent.dispose();
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

  /// Tells the navigation icons which tab was tapped. The incrementing
  /// sequence makes repeat taps on the same tab replay its animation.
  void _animateTabPress(String route) {
    final index = _tabs.indexOf(route);
    if (index < 0) return;
    _pressEvent.value = NavPressEvent(index, ++_pressSequence);
  }

  /// Drawn glyph with the motion that matches its destination's name.
  Widget _navIcon(
    int index,
    NavIconAnimation animation, {
    bool selected = false,
  }) {
    return AnimatedNavIcon(
      index: index,
      animation: animation,
      pressEvent: _pressEvent,
      selected: selected,
    );
  }

  /// Bottom navigation: reset to that tab's root route.
  void _switchTab(String route) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    _animateTabPress(route);

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
                      destinations: [
                        NavigationDestination(
                          icon: _navIcon(0, NavIconAnimation.homeHop),
                          selectedIcon: _navIcon(
                            0,
                            NavIconAnimation.homeHop,
                            selected: true,
                          ),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: _navIcon(1, NavIconAnimation.planFlip),
                          selectedIcon: _navIcon(
                            1,
                            NavIconAnimation.planFlip,
                            selected: true,
                          ),
                          label: 'Plan',
                        ),
                        NavigationDestination(
                          icon: _navIcon(2, NavIconAnimation.calorieFlicker),
                          selectedIcon: _navIcon(
                            2,
                            NavIconAnimation.calorieFlicker,
                            selected: true,
                          ),
                          label: 'Calories',
                        ),
                        NavigationDestination(
                          icon: _navIcon(3, NavIconAnimation.generateSparkle),
                          selectedIcon: _navIcon(
                            3,
                            NavIconAnimation.generateSparkle,
                            selected: true,
                          ),
                          label: 'Generate',
                        ),
                        NavigationDestination(
                          icon: _navIcon(4, NavIconAnimation.savedDrop),
                          selectedIcon: _navIcon(
                            4,
                            NavIconAnimation.savedDrop,
                            selected: true,
                          ),
                          label: 'Saved',
                        ),
                        NavigationDestination(
                          icon: _navIcon(5, NavIconAnimation.loggerTick),
                          selectedIcon: _navIcon(
                            5,
                            NavIconAnimation.loggerTick,
                            selected: true,
                          ),
                          label: 'Logger',
                        ),
                        NavigationDestination(
                          icon: _navIcon(6, NavIconAnimation.poseWiggle),
                          selectedIcon: _navIcon(
                            6,
                            NavIconAnimation.poseWiggle,
                            selected: true,
                          ),
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
      case planRoute:
        return PlanScreen(onBack: _back);
      case caloriesRoute:
        return CaloriesScreen(onBack: _back);
      case dietRoute:
        return DietScreen(onBack: _back);
      case keysRoute:
        return KeysScreen(onBack: _back);
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
          onOpenDiet: () => _open(dietRoute),
          onOpenKeys: () => _open(keysRoute),
          onSignOut: () => unawaited(SessionState.signOut()),
        );
    }
  }
}
