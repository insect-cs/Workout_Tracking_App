import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/screens/keys_screen.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/widgets/api_key_dialog.dart';

void main() {
  setUp(() async {
    await ApiKeyStore.instance.resetForTesting();
  });

  test('endpoints build Gemini-compatible generate URLs', () {
    final defaultEndpoint = AiEndpoint.presets.first;
    expect(
      defaultEndpoint.generateUrl,
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.1-flash-lite:generateContent',
    );
    expect(AiEndpoint.presets.length, 5);

    final custom = AiEndpoint.custom(
      'https://example.com/v1beta/models/',
      'my-model',
    );
    expect(
      custom.generateUrl,
      'https://example.com/v1beta/models/my-model:generateContent',
    );
    expect(custom.isCustom, isTrue);
    expect(AiEndpoint.byId('does-not-exist').id, defaultEndpoint.id);

    final pastedFullUrl = AiEndpoint.custom(
      'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-3.8-flash:generateContent',
      'gemini-3.8-flash',
    );
    expect(
      pastedFullUrl.generateUrl,
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.8-flash:generateContent',
    );
  });

  test('API key is sent as a header, not in the request URL', () {
    const secret = 'SECRET_KEY_VALUE';
    final config = ActiveAiConfig(
      key: secret,
      endpoint: AiEndpoint.presets.first,
    );

    expect(config.generateUrl, isNot(contains(secret)));
    expect(geminiHeaders(secret)['x-goog-api-key'], secret);
  });

  test('keys are masked but reveal their first and last four characters', () {
    final entry = ApiKeyEntry(
      id: 'k1',
      key: 'AIzaSyAbCdEfGh1234567890',
      endpoint: AiEndpoint.presets.first,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(entry.maskedKey, startsWith('AIza'));
    expect(entry.maskedKey, endsWith('7890'));
    expect(entry.maskedKey, contains('•'));
    expect(entry.maskedKey.length, entry.key.length);

    final short = ApiKeyEntry(
      id: 'k2',
      key: 'short',
      endpoint: AiEndpoint.presets.first,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(short.maskedKey, '•••••');
  });

  test('store keeps multiple keys and switches the active endpoint', () async {
    final store = ApiKeyStore.instance;
    final first = await store.addKey('key-one-1234', AiEndpoint.presets.first);
    final second = await store.addKey(
      'key-two-5678',
      AiEndpoint.presets[1],
      setActive: false,
    );

    expect(store.entries.length, 2);
    expect(store.active?.id, first.id);
    expect(store.activeConfig.endpoint.model, 'gemini-3.1-flash-lite');

    await store.setActive(second.id);
    expect(store.activeConfig.key, 'key-two-5678');
    expect(store.activeConfig.endpoint.model, 'gemini-2.5-flash');

    final json = first.toJson();
    expect(ApiKeyEntry.fromJson(json).key, first.key);
    expect(ApiKeyEntry.fromJson(json).endpoint.id, first.endpoint.id);
  });

  test('removing all keys makes AI access fail again', () async {
    final store = ApiKeyStore.instance;
    final entry = await store.addKey('key-abc', AiEndpoint.presets.first);
    expect(store.hasActiveKey, isTrue);

    await store.removeKey(entry.id);
    expect(store.entries, isEmpty);
    expect(store.hasActiveKey, isFalse);
    expect(
      () => store.activeConfig,
      throwsA(
        isA<ApiKeyException>().having(
          (error) => error.message,
          'message',
          contains('No AI API key is configured'),
        ),
      ),
    );
  });

  test(
    'validator rejects empty keys and incomplete custom endpoints',
    () async {
      final empty = await ApiKeyValidator.validate(
        ApiKeyEntry(
          id: 'candidate',
          key: '',
          endpoint: AiEndpoint.presets.first,
          createdAt: DateTime.now(),
        ),
      );
      expect(empty.isValid, isFalse);
      expect(empty.error, 'Enter an API key first.');

      final incomplete = await ApiKeyValidator.validate(
        ApiKeyEntry(
          id: 'candidate',
          key: 'some-key',
          endpoint: AiEndpoint.custom('', ''),
          createdAt: DateTime.now(),
        ),
      );
      expect(incomplete.error, contains('endpoint base URL and model'));
    },
  );

  testWidgets('key dialog shows endpoint choices and validates empty input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showApiKeyDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add Gemini API key'), findsOneWidget);
    expect(find.text('Validate'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an API key first.'), findsOneWidget);
  });

  testWidgets('Keys page shows the active endpoint and can hide/remove keys', (
    tester,
  ) async {
    await ApiKeyStore.instance.addKey(
      'AIzaSyAbCdEfGh1234567890',
      AiEndpoint.presets[1],
    );

    await tester.pumpWidget(MaterialApp(home: KeysScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('KEYS'), findsOneWidget);
    expect(find.text('ACTIVE ENDPOINT'), findsOneWidget);
    expect(find.textContaining('model: gemini-2.5-flash'), findsOneWidget);
    expect(find.text(ApiKeyStore.instance.active!.maskedKey), findsWidgets);

    await tester.tap(find.byTooltip('Show key'));
    await tester.pumpAndSettle();
    expect(find.text('AIzaSyAbCdEfGh1234567890'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove key'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this key?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(ApiKeyStore.instance.entries, isEmpty);
    expect(find.text('No keys saved yet.'), findsNothing);
    expect(find.textContaining('No keys saved yet'), findsOneWidget);
  });
}
