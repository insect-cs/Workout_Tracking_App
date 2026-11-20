import 'dart:math' as math;

import 'package:flutter/material.dart';

const double _maxDialogWidth = 400;
const double _minDialogWidth = 200;
const double _dialogMargin = 32;

/// Computes a finite dialog width even when the dialog theme injects
/// `BoxConstraints.expand()` before the web viewport has a real size.
double responsiveDialogWidth(BoxConstraints viewport) {
  final double available = viewport.maxWidth.isFinite
      ? viewport.maxWidth
      : _maxDialogWidth;
  return math.min(
    _maxDialogWidth,
    math.max(_minDialogWidth, available - _dialogMargin),
  );
}

/// An [AlertDialog] with a width that always fits the current viewport.
///
/// Use this instead of a raw [AlertDialog] so dialogs cannot be pushed off
/// screen by the full-window dialog route used on web.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.backgroundColor,
    this.shape,
    this.title,
    this.content,
    this.actions,
  });

  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: shape,
          constraints: BoxConstraints.tightFor(
            width: responsiveDialogWidth(viewport),
          ),
          title: title,
          content: content,
          actions: actions,
        );
      },
    );
  }
}
