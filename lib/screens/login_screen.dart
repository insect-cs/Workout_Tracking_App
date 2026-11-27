import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/update_service.dart';
import '../state/session_state.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import 'name_entry_screen.dart';
import '../widgets/app_dialog.dart';

String _label(SessionKind kind) =>
    kind == SessionKind.guest ? 'Guest session' : 'New user session';

/// Single-entry gate for the app. Only one local profile may exist, so a
/// signed-out profile must be deleted before another sign-in is allowed.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, UpdateChecker? updateChecker})
    : updateChecker = updateChecker ?? UpdateService.check;

  /// Injectable so widget tests can simulate a release response.
  final UpdateChecker updateChecker;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _checkingUpdates = false;

  static const _wheelCooldown = Duration(milliseconds: 180);
  static const _swipeStep = 28.0;

  /// Highlighted session card: 0 = guest, 1 = new user.
  int _selectedIndex = 0;
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);
  double _dragAccum = 0;
  double _paletteTurns = 0;

  void _choosePalette() {
    ThemeController.chooseNextPalette();
    setState(() => _paletteTurns += 1);
  }

  void _select(int index) {
    final next = index.clamp(0, 1);
    if (next == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = next);
  }

  /// Tapping an unhighlighted card selects it; tapping the highlighted card
  /// confirms it.
  void _onCardTap(int index) {
    if (_selectedIndex != index) {
      _select(index);
      return;
    }
    _confirm();
  }

  void _confirm() {
    if (_busy || !SessionState.canSignIn) return;
    HapticFeedback.mediumImpact();
    if (_selectedIndex == 1) {
      // New users pick a display name before the session is created.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const NameEntryScreen()));
      return;
    }
    _signIn(SessionKind.guest);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Claim the event so a parent scroll view does not also react to it.
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final now = DateTime.now();
      if (now.difference(_lastWheel) < _wheelCooldown) return;
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      if (dy == 0) return;
      _lastWheel = now;
      _select(dy > 0 ? _selectedIndex + 1 : _selectedIndex - 1);
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragAccum += details.delta.dy;
    if (_dragAccum.abs() >= _swipeStep) {
      _select(_dragAccum < 0 ? _selectedIndex + 1 : _selectedIndex - 1);
      _dragAccum = 0;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _select(_selectedIndex + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _select(_selectedIndex - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _confirm();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _signIn(SessionKind selected) async {
    setState(() => _busy = true);
    final created = await SessionState.signIn(selected);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete the saved session before starting another.'),
        ),
      );
    }
  }

  /// Reopens the saved session without deleting it or creating a new profile.
  Future<void> _resumeSession() async {
    if (_busy) return;
    setState(() => _busy = true);
    final resumed = await SessionState.resumeSession();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!resumed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not restore the saved session. Try again.'),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          'Delete saved session?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: Text(
          'This permanently removes the profile, its workouts, diet, plans, '
          'results, theme and saved API keys from this device. You can choose '
          'a fresh guest or new user afterwards.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    await SessionState.deleteSession();
    if (mounted) setState(() => _busy = false);
  }

  /// Queries GitHub Releases and reports whether a newer version is available.
  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);

    AppUpdate? update;
    try {
      update = await widget.updateChecker();
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Could not check for updates. Try again later.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }

    if (!mounted || update == null) return;
    await _showUpdateDialog(update);
  }

  Future<void> _showUpdateDialog(AppUpdate update) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          update.isNewer ? 'Update available' : 'You’re up to date',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                update.isNewer
                    ? 'Version ${update.latestVersion} is available. You have '
                          '${UpdateService.currentVersion}.'
                    : 'You are running the latest version '
                          '(${UpdateService.currentVersion}).',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textWhite,
                  height: 1.5,
                ),
              ),
              if (update.releaseName.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  update.releaseName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
              if (update.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  update.releaseNotes,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSlate,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('later'),
            child: const Text('Later'),
          ),
          if (update.isNewer)
            FilledButton(
              key: const Key('update-open'),
              onPressed: () => Navigator.of(dialogContext).pop('open'),
              child: const Text('Download'),
            ),
        ],
      ),
    );

    if (choice != 'open' || !mounted) return;
    final opened = await UpdateService.openRelease(update);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Could not open the release page.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionKind?>(
      valueListenable: SessionState.kind,
      builder: (context, sessionKind, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SessionState.signedIn,
          builder: (context, signedIn, _) {
            final hasStaleSession = SessionState.hasSession && !signedIn;
            final canSignIn = SessionState.canSignIn && !_busy;

            return Scaffold(
              backgroundColor: AppColors.background,
              body: Focus(
                autofocus: true,
                onKeyEvent: _onKey,
                child: Listener(
                  onPointerSignal: _onPointerSignal,
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryOrange,
                                          AppColors.amber,
                                        ],
                                        begin: Alignment.bottomLeft,
                                        end: Alignment.topRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.fitness_center,
                                      color: AppColors.onPrimary,
                                      size: 26,
                                    ),
                                  ),
                                  const Spacer(),
                                  AnimatedRotation(
                                    turns: _paletteTurns,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOutCubic,
                                    child: IconButton(
                                      key: const Key('login-palette'),
                                      onPressed: _busy ? null : _choosePalette,
                                      tooltip: 'Auto color scheme',
                                      icon: Icon(
                                        Icons.palette_outlined,
                                        color: AppColors.primaryOrange,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                  if (hasStaleSession && sessionKind != null)
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _label(sessionKind),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              textAlign: TextAlign.right,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.textSlate,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          IconButton(
                                            tooltip: 'Delete saved session',
                                            onPressed: _busy
                                                ? null
                                                : _confirmDelete,
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: AppColors.rose,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 34),
                              Text(
                                'WELCOME',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.4,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Choose your session',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textWhite,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Only one profile can exist on this device. Guest '
                                'starts with the preloaded test data; new user '
                                'starts completely clean.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSlate,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              GestureDetector(
                                key: const Key('session-selector'),
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (_) => _dragAccum = 0,
                                onVerticalDragUpdate: _onDragUpdate,
                                onVerticalDragEnd: (_) => _dragAccum = 0,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildOptionCard(
                                      index: 0,
                                      icon: Icons.person_outline,
                                      title: 'Continue as guest',
                                      subtitle:
                                          'Restore the preloaded workouts, logs and '
                                          'demo state used during testing.',
                                      onPressed: canSignIn
                                          ? () => _onCardTap(0)
                                          : null,
                                      isSelected: _selectedIndex == 0,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildOptionCard(
                                      index: 1,
                                      icon: Icons.person_add_alt_1_outlined,
                                      title: 'Continue as new user',
                                      subtitle:
                                          'Start with an empty profile and no saved '
                                          'API keys.',
                                      onPressed: canSignIn
                                          ? () => _onCardTap(1)
                                          : null,
                                      outlined: true,
                                      isSelected: _selectedIndex == 1,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Scroll, swipe or use arrow keys to highlight. '
                                      'Tap the highlighted card or press Enter to '
                                      'continue.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasStaleSession) ...[
                                const SizedBox(height: 22),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.orangeSoft,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.orangeBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: AppColors.primaryOrange,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'A ${_label(sessionKind ?? SessionKind.guest).toLowerCase()} is still saved. Resume it, or use the delete icon to remove it before choosing another profile.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textWhite,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  key: const Key('resume-session'),
                                  onPressed: _busy ? null : _resumeSession,
                                  icon: const Icon(
                                    Icons.play_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Resume saved session'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 30),
                              Text(
                                'Your data stays on this device. API keys are '
                                'stored in secure storage and fully masked in the '
                                'Keys page.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                key: const Key('check-for-updates'),
                                onPressed: _checkingUpdates
                                    ? null
                                    : _checkForUpdates,
                                icon: _checkingUpdates
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryOrange,
                                        ),
                                      )
                                    : Icon(
                                        Icons.system_update_alt,
                                        size: 16,
                                        color: AppColors.primaryOrange,
                                      ),
                                label: Text(
                                  _checkingUpdates
                                      ? 'Checking...'
                                      : 'Check for updates',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textSlate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onPressed,
    required bool isSelected,
    bool outlined = false,
  }) {
    final enabled = onPressed != null;
    // Both cards stay transparent and take their colour from the active
    // palette. Selection is shown by the primary border, icon and scale rather
    // than a hard-coded fill.
    final titleColor = enabled ? AppColors.textWhite : AppColors.textMuted;
    final subColor = enabled ? AppColors.textSlate : AppColors.textMuted;
    final accent = isSelected
        ? AppColors.primaryOrange
        : enabled
        ? AppColors.textSlate
        : AppColors.textMuted;
    const fill = Colors.transparent;
    final border = isSelected ? AppColors.primaryOrange : AppColors.border;
    final borderWidth = isSelected ? 2.0 : 1.0;

    final content = AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: borderWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.orangeSoft
                      : AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: subColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 15, color: accent),
            ],
          ),
        ),
      ),
    );

    final button = outlined
        ? OutlinedButton(
            key: Key('session-option-$index'),
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: fill,
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
            ),
            child: content,
          )
        : FilledButton(
            key: Key('session-option-$index'),
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: fill,
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
            ),
            child: content,
          );

    return Semantics(
      key: Key('session-option-semantics-$index'),
      button: true,
      selected: isSelected,
      label: '$title${isSelected ? ', highlighted' : ''}',
      child: button,
    );
  }
}
