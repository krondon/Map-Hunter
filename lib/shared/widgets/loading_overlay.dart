import 'package:flutter/material.dart';
import 'loading_indicator.dart';

class LoadingOverlay {
  static void show(BuildContext context, {String message = 'Cargando...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: LoadingIndicator(message: message),
        );
      },
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
