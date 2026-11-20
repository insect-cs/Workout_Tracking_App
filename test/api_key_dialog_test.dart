import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/api_key_dialog.dart';

/// Lays its child out with unbounded width, like a web dialog route can before
/// the browser reports a viewport size.
class _UnboundedWidth extends SingleChildRenderObjectWidget {
  const _UnboundedWidth({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderUnboundedWidth();
}

class _RenderUnboundedWidth extends RenderProxyBox {
  @override
  void performLayout() {
    child!.layout(const BoxConstraints(maxHeight: 600), parentUsesSize: true);
    size = child!.size;
  }
}

void main() {
  testWidgets('API key dialog lays out under unbounded dialog width', (
    WidgetTester tester,
  ) async {
    // This Flutter build's dialog wrapper uses BoxConstraints.expand(), which
    // becomes an invalid tightly-infinite width when the host has no width yet.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogTheme(
            data: const DialogThemeData(constraints: BoxConstraints.expand()),
            child: const _UnboundedWidth(child: ApiKeyDialog()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Validate'), findsOneWidget);
  });
}
