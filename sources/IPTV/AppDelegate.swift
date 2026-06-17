//
//  AppDelegate.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 19/11/2024.
//
#if os(iOS)
import Foundation
import UIKit

#if canImport(GoogleCast)
import GoogleCast
#endif

class AppDelegate: UIResponder, UIApplicationDelegate {
#if canImport(GoogleCast)
    let kReceiverAppID = kGCKDefaultMediaReceiverApplicationID
    let kDebugLoggingEnabled = true

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let criteria = GCKDiscoveryCriteria(applicationID: kReceiverAppID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        // Enable logger.
        GCKLogger.sharedInstance().delegate = self
        return true
    }
#else
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        true
    }
#endif
}

#if canImport(GoogleCast)
extension AppDelegate: GCKLoggerDelegate {
    // MARK: - GCKLoggerDelegate

    func logMessage(
        _ message: String,
        at _: GCKLoggerLevel,
        fromFunction function: String,
        location _: String
    ) {
        if kDebugLoggingEnabled {
            print(function + " - " + message)
        }
    }
}
#endif
#endif
