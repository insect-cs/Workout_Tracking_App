import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/app_dialog.dart';

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
  testWidgets('AppDialog stays bounded when dialog theme expands', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogTheme(
            data: const DialogThemeData(constraints: BoxConstraints.expand()),
            child: const _UnboundedWidth(
              child: AppDialog(title: Text('Remove this key?')),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.constraints!.maxWidth, 368);
    expect(dialog.constraints!.maxWidth, lessThan(double.infinity));
  });
}
