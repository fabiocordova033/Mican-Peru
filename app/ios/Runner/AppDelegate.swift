import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // La key se define como MAPS_API_KEY en ios/Flutter/Mapas.xcconfig (ver app/README.md).
    if let clave = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !clave.isEmpty, !clave.hasPrefix("$(") {
      GMSServices.provideAPIKey(clave)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
