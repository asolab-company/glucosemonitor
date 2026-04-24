import Foundation
import AppTrackingTransparency
import UIKit

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

enum AppsFlyerConfig {
    static let devKey = "cSRFayvDVGvzuDdmHNu9BZ"

    static var appID: String {
        let raw = AppConstants.Links.appStoreURL
        guard let range = raw.range(of: #"id(\d+)"#, options: .regularExpression) else {
            return "6759051452"
        }

        return String(raw[range]).replacingOccurrences(of: "id", with: "")
    }
}

final class AppsFlyerService {
    static let shared = AppsFlyerService()

    private enum Event {
        static let subscription = "af_app_subscription"
        static let remoteSubscriptionSuccess = "af_web_subscription"
        static let source = "sugarpink_ios_app"
        static let context = "subscription_purchase_success"
        static let remoteSource = "sugarpink_ios_remote"
        static let remoteContext = "remote_checkout_success"
    }

    private var isConfigured = false
    private var didStartAppsFlyer = false
    private var attRequestAttempts = 0
    private let maxATTRequestAttempts = 3

    private init() {}

    func configure() {
        #if canImport(AppsFlyerLib)
        guard !isConfigured else { return }
        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = AppsFlyerConfig.devKey
        appsFlyer.appleAppID = AppsFlyerConfig.appID
        appsFlyer.waitForATTUserAuthorization(timeoutInterval: 60)
        appsFlyer.isDebug = false
        isConfigured = true
        #endif
    }

    func startRespectingTrackingAuthorization() {
        guard !didStartAppsFlyer else { return }

        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                requestATTAuthorizationAndStart()
                return
            }
        }

        startAppsFlyer()
    }

    func handleOpen(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: options)
        #endif
    }

    func trackSubscription(productID: String) {
        #if canImport(AppsFlyerLib)
        let values: [AnyHashable: Any] = [
            "product_id": productID,
            "event_source": Event.source,
            "event_context": Event.context,
        ]
        AppsFlyerLib.shared().logEvent(Event.subscription, withValues: values)
        #endif
    }

    func trackRemoteSubscriptionSuccess() {
        #if canImport(AppsFlyerLib)
        let values: [AnyHashable: Any] = [
            "event_source": Event.remoteSource,
            "event_context": Event.remoteContext,
            "purchase_channel": "remote_paywall",
        ]
        AppsFlyerLib.shared().logEvent(Event.remoteSubscriptionSuccess, withValues: values)
        #endif
    }

    @available(iOS 14, *)
    private func requestATTAuthorizationAndStart() {
        guard attRequestAttempts < maxATTRequestAttempts else {
            startAppsFlyer()
            return
        }

        attRequestAttempts += 1
        let currentAttempt = attRequestAttempts

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard UIApplication.shared.applicationState == .active else { return }

            ATTrackingManager.requestTrackingAuthorization { result in
                DispatchQueue.main.async {
                    if result == .notDetermined && currentAttempt < self.maxATTRequestAttempts {
                        self.requestATTAuthorizationAndStart()
                    } else {
                        self.startAppsFlyer()
                    }
                }
            }
        }
    }

    private func startAppsFlyer() {
        #if canImport(AppsFlyerLib)
        guard !didStartAppsFlyer else { return }
        if !isConfigured {
            configure()
        }
        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.isDebug = false
        appsFlyer.start()
        didStartAppsFlyer = true
        #endif
    }
}

final class AppsFlyerAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppsFlyerService.shared.configure()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppsFlyerService.shared.startRespectingTrackingAuthorization()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppsFlyerService.shared.handleOpen(url: url, options: options)
        return true
    }
}
