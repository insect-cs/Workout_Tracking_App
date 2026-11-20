import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_key_service.dart';
import '../theme/app_colors.dart';
import 'app_dialog.dart';

/// Shows the key dialog. Returns true when a valid key was stored.
Future<bool?> showApiKeyDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ApiKeyDialog(),
  );
}

/// Gate used by every AI action: if a validated key is already active it does
/// nothing, otherwise it asks the user for one.
Future<bool> ensureAiAccess(BuildContext context) async {
  await ApiKeyStore.instance.ensureLoaded();
  if (ApiKeyStore.instance.hasActiveKey) return true;
  if (!context.mounted) return false;
  final added = await showApiKeyDialog(context);
  return added ?? false;
}

class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key});

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController(
    text: AiEndpoint.googleBaseUrl,
  );
  final TextEditingController _modelController = TextEditingController(
    text: AiEndpoint.presets.first.model,
  );

  String _selectedId = AiEndpoint.presets.first.id;
  bool _obscure = true;
  bool _validating = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  AiEndpoint get _endpoint {
    if (_selectedId == AiEndpoint.customId) {
      return AiEndpoint.custom(_baseUrlController.text, _modelController.text);
    }
    return AiEndpoint.byId(_selectedId);
  }

  Future<void> _validate() async {
    if (_validating) return;
    setState(() {
      _validating = true;
      _error = null;
    });

    final candidate = ApiKeyEntry(
      id: 'candidate',
      key: _keyController.text,
      endpoint: _endpoint,
      createdAt: DateTime.now(),
    );
    final result = await ApiKeyValidator.validate(candidate);
    if (!mounted) return;

    if (!result.isValid) {
      setState(() {
        _validating = false;
        _error = result.error;
      });
      return;
    }

    await ApiKeyStore.instance.addKey(candidate.key, candidate.endpoint);
    if (!mounted) return;
    setState(() => _validating = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        // Dialog themes can inject BoxConstraints.expand(), which becomes an
        // invalid tightly-infinite width if the host has not sized the window
        // yet (web). Pick a real finite width that also fits small screens.
        final double dialogWidth = responsiveDialogWidth(viewport);
        // AlertDialog reserves 24 dp on each side for title and content.
        final double contentWidth = dialogWidth - 48;
        const double validateButtonWidth = 96;
        const double gap = 8;
        final double keyFieldWidth = contentWidth - validateButtonWidth - gap;

        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          constraints: BoxConstraints.tightFor(width: dialogWidth),
          title: Text(
            'Add Gemini API key',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI features need a valid API key. Enter a key from your own '
                    'endpoint, then tap Validate to authenticate it. Valid keys '
                    'are stored securely and reused across the whole app.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSlate,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ENDPOINT / MODEL',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textSlate,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedId,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      for (final endpoint in AiEndpoint.presets)
                        DropdownMenuItem(
                          value: endpoint.id,
                          child: Text(
                            endpoint.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedId = value);
                    },
                  ),
                  if (_selectedId == AiEndpoint.customId) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Endpoint base URL',
                        hintText: 'https://.../v1beta/models',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model name',
                        hintText: 'gemini-2.5-flash',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'API KEY',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textSlate,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: keyFieldWidth,
                        child: TextField(
                          controller: _keyController,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Paste your API key',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              tooltip: _obscure ? 'Show key' : 'Hide key',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: gap),
                      SizedBox(
                        width: validateButtonWidth,
                        height: 46,
                        child: FilledButton(
                          onPressed: _validating ? null : _validate,
                          child: _validating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.onPrimary,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Validate',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.rose,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.rose,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _validating
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
