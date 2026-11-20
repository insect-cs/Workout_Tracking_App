import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_key_service.dart';
import '../theme/app_colors.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/app_dialog.dart';

/// App-wide key manager. Keys added or validated here are used by every AI
/// feature, and the active endpoint (model) is shown prominently because it
/// changes the results the app produces.
class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen> {
  final ApiKeyStore _store = ApiKeyStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  Future<void> _addKey() async {
    await showApiKeyDialog(context);
    if (mounted) setState(() {});
  }

  Future<void> _confirmRemove(ApiKeyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          'Remove this key?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: Text(
          '${entry.endpoint.label} (${entry.maskedKey}) will be deleted. '
          'You will need to authenticate again the next time an AI feature '
          'is used.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _store.removeKey(entry.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _store,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        _buildActiveCard(),
                        const SizedBox(height: 18),
                        _buildAddCard(),
                        const SizedBox(height: 18),
                        _sectionLabel('SAVED KEYS'),
                        const SizedBox(height: 8),
                        if (_store.entries.isEmpty)
                          _buildEmptyState()
                        else
                          ..._store.entries.map(_buildKeyCard),
                        const SizedBox(height: 16),
                        Text(
                          'Keys are stored with flutter_secure_storage and are '
                          'fully masked on this screen - no characters, no '
                          'reveal button, and no length hint. Different '
                          'endpoints/models can produce different results '
                          'across all AI features.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSlate,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: AppColors.textLight,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KEYS',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'Manage AI keys and active endpoint',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.orangeBorder),
            ),
            child: Text(
              'SECURE',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.textWhite,
      ),
    );
  }

  Widget _buildActiveCard() {
    final active = _store.active;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 15, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Text(
                'ACTIVE ENDPOINT',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active == null ? 'No active key' : active.endpoint.label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            active == null
                ? 'Add a key below to enable AI features.'
                : '${active.endpoint.provider} • model: '
                      '${active.endpoint.model}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          ),
          if (active != null) ...[
            const SizedBox(height: 8),
            Text(
              active.maskedKey,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppColors.emerald,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _addKey,
        icon: const Icon(Icons.add, size: 18),
        label: Text(
          'Add / bring your own API key',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No keys saved yet. Add one to unlock Plan, Calories, Diet, '
        'Generate and Pose AI features.',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textSlate,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildKeyCard(ApiKeyEntry entry) {
    final isActive = _store.active?.id == entry.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.orangeBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.endpoint.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangeSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.endpoint.provider} • ${entry.endpoint.model}',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSlate),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.maskedKey,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove key',
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.rose,
                ),
                onPressed: () => _confirmRemove(entry),
              ),
            ],
          ),
          if (!isActive) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () async {
                  await _store.setActive(entry.id);
                  if (mounted) setState(() {});
                },
                child: Text(
                  'Use this endpoint',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
