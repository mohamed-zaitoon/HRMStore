import 'package:flutter/material.dart';

// EN: Global navigator access for dialogs that are triggered above the app Navigator.
// AR: وصول عام للـ Navigator لعرض الحوارات التي تُشغّل فوق الـ Navigator.
class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static BuildContext? get context => key.currentState?.overlay?.context;
}
