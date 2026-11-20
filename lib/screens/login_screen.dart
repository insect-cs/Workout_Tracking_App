import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/session_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';

String _label(SessionKind kind) =>
    kind == SessionKind.guest ? 'Guest session' : 'New user session';

/// Single-entry gate for the app. Only one local profile may exist, so a
/// signed-out profile must be deleted before another sign-in is allowed.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

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
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              if (hasStaleSession && sessionKind != null)
                                Row(
                                  children: [
                                    Text(
                                      _label(sessionKind),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textSlate,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Delete saved session',
                                      onPressed: _busy ? null : _confirmDelete,
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: AppColors.rose,
                                      ),
                                    ),
                                  ],
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
                          const SizedBox(height: 28),
                          _buildOptionCard(
                            icon: Icons.person_outline,
                            title: 'Continue as guest',
                            subtitle:
                                'Restore the preloaded workouts, logs and demo '
                                'state used during testing.',
                            onPressed: canSignIn
                                ? () => _signIn(SessionKind.guest)
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _buildOptionCard(
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'Continue as new user',
                            subtitle:
                                'Start with an empty profile and no saved API '
                                'keys.',
                            onPressed: canSignIn
                                ? () => _signIn(SessionKind.newUser)
                                : null,
                            outlined: true,
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
                                      'A ${_label(sessionKind ?? SessionKind.guest).toLowerCase()} is still saved. Use the delete icon to remove it before choosing another profile.',
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
                        ],
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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: outlined ? AppColors.surfaceLow : AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.orangeBorder),
            ),
            child: Icon(icon, color: AppColors.primaryOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSlate,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 15),
        ],
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.orangeBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: content,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: content,
            ),
    );
  }
}
