import Flutter
import UIKit

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
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeVisualEffectViewPlugin") {
      let factory = NativeVisualEffectViewFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "flash_ink/native_glass_view")
    }
  }
}
