// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // EN: Initializes the iOS app and registers plugins.
  // AR: تهيّئ تطبيق iOS وتسجّل الإضافات.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
