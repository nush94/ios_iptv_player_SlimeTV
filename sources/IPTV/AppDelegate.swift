//
//  AppDelegate.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 19/11/2024.
//
#if os(iOS)
import Foundation
import RealmSwift
import UIKit

#if canImport(GoogleCast)
import GoogleCast
#endif

func configureRealmSchema() {
  var config = Realm.Configuration.defaultConfiguration
  // Bump when the Realm object schema changes. Additive changes (new optional
  // properties like CachedStream.genre, CachedSeries.episodeCount, searchName)
  // need no migration body — just the bump. Existing rows get an empty
  // searchName until the playlist is reloaded; search falls back to `name`.
  config.schemaVersion = 7
  Realm.Configuration.defaultConfiguration = config
}

class AppDelegate: UIResponder, UIApplicationDelegate {
#if canImport(GoogleCast)
    let kReceiverAppID = kGCKDefaultMediaReceiverApplicationID
    let kDebugLoggingEnabled = true

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureRealmSchema()
        let criteria = GCKDiscoveryCriteria(applicationID: kReceiverAppID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        // Enable logger.
        GCKLogger.sharedInstance().delegate = self
        return true
    }
#else
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureRealmSchema()
        return true
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
