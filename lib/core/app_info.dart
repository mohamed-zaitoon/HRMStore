// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

class AppInfo {
  AppInfo._();

  static const String userAppName = 'HRM Store';
  static const String adminAppName = 'HRM Store (ادمن)';

  static bool isAdminApp = false;

  static String get appName => isAdminApp ? adminAppName : userAppName;
}
