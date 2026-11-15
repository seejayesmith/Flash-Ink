import Flutter
import GoogleMaps
import UIKit
import UserNotifications

class NativeVisualEffectViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeVisualEffectView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class NativeVisualEffectView: NSObject, FlutterPlatformView {
    private var _blurView: UIVisualEffectView

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        var blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark
        if let params = args as? [String: Any], let styleStr = params["style"] as? String {
            switch styleStr {
            case "ultraThinDark":
                blurStyle = .systemUltraThinMaterialDark
            case "thinDark":
                blurStyle = .systemThinMaterialDark
            case "materialDark":
                blurStyle = .systemMaterialDark
            case "chromeDark":
                blurStyle = .systemChromeMaterialDark
            default:
                blurStyle = .systemUltraThinMaterialDark
            }
        }
        
        let blurEffect = UIBlurEffect(style: blurStyle)
        _blurView = UIVisualEffectView(effect: blurEffect)
        _blurView.frame = frame
        _blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _blurView.clipsToBounds = true
        super.init()
    }

    func view() -> UIView {
        return _blurView
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyAMPnEDNfBY3i5RfEjcsMeJ6M6ScWt3OJ8")
    UNUserNotificationCenter.current().delegate = self
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeVisualEffectViewPlugin") {
      let factory = NativeVisualEffectViewFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "flash_ink/native_glass_view")
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeviceCornerRadiusPlugin") {
      let channel = FlutterMethodChannel(
        name: "flash_ink/device_corner_radius",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "getBottomCornerRadii" else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.main.async {
          let radii = self?.resolveBottomCornerRadii() ?? (bottomLeft: 0.0, bottomRight: 0.0)
          result([
            "bottomLeft": Double(radii.bottomLeft),
            "bottomRight": Double(radii.bottomRight),
          ])
        }
      }
    }
  }

  private func activeKeyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes where scene.activationState == .foregroundActive {
      if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
        return keyWindow
      }
    }
    for scene in scenes {
      if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
        return keyWindow
      }
    }
    return nil
  }

  private func resolveBottomCornerRadii() -> (bottomLeft: CGFloat, bottomRight: CGFloat) {
    let window = activeKeyWindow()
    let bottomSafe = window?.safeAreaInsets.bottom ?? 0

    if #available(iOS 26.0, *), let window = window, window.bounds.width > 0, window.bounds.height > 0 {
      let probe = UIView(frame: window.bounds)
      probe.isUserInteractionEnabled = false
      probe.backgroundColor = .clear
      probe.cornerConfiguration = .corners(radius: .containerConcentric())
      window.addSubview(probe)
      probe.setNeedsLayout()
      probe.layoutIfNeeded()
      let left = probe.effectiveRadius(corner: .bottomLeft)
      let right = probe.effectiveRadius(corner: .bottomRight)
      probe.removeFromSuperview()

      if left > 0 || right > 0 {
        return (bottomLeft: left, bottomRight: right)
      }
      if bottomSafe <= 0 {
        return (bottomLeft: 0.0, bottomRight: 0.0)
      }
    }

    guard bottomSafe > 0 else {
      return (bottomLeft: 0.0, bottomRight: 0.0)
    }

    let fallback = fallbackCornerRadius()
    return (bottomLeft: fallback, bottomRight: fallback)
  }

  private func hardwareIdentifier() -> String {
    #if targetEnvironment(simulator)
    if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
       !simModel.isEmpty {
      return simModel
    }
    #endif
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
  }

  private func fallbackCornerRadius() -> CGFloat {
    if UIDevice.current.userInterfaceIdiom == .pad {
      return 18.0
    }

    let model = hardwareIdentifier()
    let knownRadii: [String: CGFloat] = [
      // 62.0 pt — iPhone 16 Pro / Pro Max, iPhone 17 / Pro / Pro Max / Air
      "iPhone17,1": 62.0,
      "iPhone17,2": 62.0,
      "iPhone18,1": 62.0,
      "iPhone18,2": 62.0,
      "iPhone18,3": 62.0,
      "iPhone18,4": 62.0,
      // 55.0 pt — iPhone 14 Pro/Pro Max, 15/15 Plus/Pro/Pro Max, 16/16 Plus
      "iPhone15,2": 55.0,
      "iPhone15,3": 55.0,
      "iPhone15,4": 55.0,
      "iPhone15,5": 55.0,
      "iPhone16,1": 55.0,
      "iPhone16,2": 55.0,
      "iPhone17,3": 55.0,
      "iPhone17,4": 55.0,
      // 47.33 pt — iPhone 12/12 Pro/Pro Max, 13/13 Pro/Pro Max, 14/14 Plus, 16e
      "iPhone13,2": 47.33,
      "iPhone13,3": 47.33,
      "iPhone13,4": 47.33,
      "iPhone14,2": 47.33,
      "iPhone14,3": 47.33,
      "iPhone14,5": 47.33,
      "iPhone14,7": 47.33,
      "iPhone14,8": 47.33,
      "iPhone17,5": 47.33,
      // 44.0 pt — iPhone 12 mini, 13 mini
      "iPhone13,1": 44.0,
      "iPhone14,4": 44.0,
      // 41.5 pt — iPhone XR, 11
      "iPhone11,8": 41.5,
      "iPhone12,1": 41.5,
      // 39.0 pt — iPhone X, XS, XS Max, 11 Pro, 11 Pro Max
      "iPhone10,3": 39.0,
      "iPhone10,6": 39.0,
      "iPhone11,2": 39.0,
      "iPhone11,4": 39.0,
      "iPhone11,6": 39.0,
      "iPhone12,3": 39.0,
      "iPhone12,5": 39.0,
    ]

    if let matched = knownRadii[model] {
      return matched
    }

    let bounds = activeKeyWindow()?.windowScene?.screen.bounds ?? UIScreen.main.bounds
    let minSide = min(bounds.width, bounds.height)
    let maxSide = max(bounds.width, bounds.height)

    if (abs(minSide - 402) <= 1.5 && abs(maxSide - 874) <= 1.5) ||
       (abs(minSide - 440) <= 1.5 && abs(maxSide - 956) <= 1.5) ||
       (abs(minSide - 420) <= 1.5 && abs(maxSide - 912) <= 1.5) ||
       maxSide >= 940 {
      return 62.0
    }
    if (abs(minSide - 393) <= 1.5 && abs(maxSide - 852) <= 1.5) ||
       (abs(minSide - 430) <= 1.5 && abs(maxSide - 932) <= 1.5) ||
       maxSide >= 850 {
      return 55.0
    }
    if abs(minSide - 375) <= 1.5 && abs(maxSide - 812) <= 1.5 {
      return 44.0
    }
    if abs(minSide - 414) <= 1.5 && abs(maxSide - 896) <= 1.5 {
      return 41.5
    }
    return 47.33
  }
}
