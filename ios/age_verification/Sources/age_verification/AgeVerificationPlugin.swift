import Flutter
import UIKit

public class AgeVerificationPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let api = AgeVerificationApiImpl()
    AgeVerificationApiSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
  }
}
