import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/session_state.dart';
import '../theme/app_colors.dart';

/// Second step of the new-user welcome flow. The name typed here becomes the
/// profile's display name and is shown on the Home screen after sign-in.
class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key});

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  bool _busy = false;

  String get _enteredName => _nameController.text.trim();
  bool get _canContinue => _enteredName.isNotEmpty && !_busy;

  @override
  void initState() {
    super.initState();
    // Bring the keyboard up as soon as the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged(String _) => setState(() {});

  Future<void> _continue() async {
    if (!_canContinue) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    final created = await SessionState.signIn(
      SessionKind.newUser,
      name: _enteredName,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!created) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Delete the saved session before starting another.'),
        ),
      );
      return;
    }
    // `signedIn` swaps the app root to MainShell, but this pushed route would
    // otherwise stay on top of the Navigator and hide the Home screen.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('name-back'),
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: AppColors.textSlate),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.orangeBorder),
                    ),
                    child: Icon(
                      Icons.person_add_alt,
                      color: AppColors.primaryOrange,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NEW USER',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Updates live with every keystroke.
                  Text(
                    key: const Key('welcome-name'),
                    _enteredName.isEmpty ? 'Welcome' : 'Welcome, $_enteredName',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tell us what to call you. This name is stored only on '
                    'this device and appears on your Home screen.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSlate,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('name-field'),
                    controller: _nameController,
                    focusNode: _nameFocus,
                    onChanged: _onNameChanged,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _continue(),
                    decoration: InputDecoration(
                      labelText: 'Your name',
                      hintText: 'e.g. Alex',
                      filled: true,
                      fillColor: AppColors.cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.orangeBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.orangeBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.primaryOrange,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    key: const Key('name-next'),
                    onPressed: _canContinue ? _continue : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: AppColors.textWhite,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Next',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
