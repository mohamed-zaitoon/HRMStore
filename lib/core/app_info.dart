// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

class AppInfo {
  AppInfo._();

  static const String userAppName = 'HRM Store';
  static const String adminAppName = 'HRM Store (ادمن)';
  static const String merchantAppName = 'HRM Store (تاجر)';

  static bool isAdminApp = false;
  static bool isMerchantApp = false;

  static String get appName {
    if (isMerchantApp) return merchantAppName;
    if (isAdminApp) return adminAppName;
    return userAppName;
  }
}
