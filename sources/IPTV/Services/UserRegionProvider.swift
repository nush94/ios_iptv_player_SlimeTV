//
//  UserRegionProvider.swift
//  IPTV
//
//  Resolves the user's general country/region for personalization (req 4-6):
//  asks for When-In-Use location only, reverse-geocodes to a country + state,
//  and keeps ONLY the resolved codes (never the raw coordinates). Falls back to
//  the device locale when permission is denied or unavailable.
//

import CoreLocation
import Foundation

final class UserRegionProvider: NSObject, ObservableObject {
  static let shared = UserRegionProvider()

  @Published private(set) var context: RankingContext

  private let manager = CLLocationManager()
  private let geocoder = CLGeocoder()
  private let defaults = UserDefaults.standard

  private enum Keys {
    static let country = "smartUserCountry"
    static let region = "smartUserRegion"
  }

  override init() {
    // Start from the last resolved codes (or locale), so personalization works
    // immediately on launch without waiting on a location fix.
    context = RankingContext(
      country: defaults.string(forKey: Keys.country) ?? Self.localeCountry(),
      language: Self.localeLanguage(),
      region: defaults.string(forKey: Keys.region)
    )
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyReduced // city-level is plenty
  }

  /// Ask for When-In-Use authorization and resolve a coarse country/region.
  /// Safe to call repeatedly; only prompts when status is not yet determined.
  func resolve() {
    switch manager.authorizationStatus {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    default:
      applyLocaleFallback()
    }
  }

  private func applyLocaleFallback() {
    update(country: context.country ?? Self.localeCountry(), region: context.region)
  }

  private func update(country: String?, region: String?) {
    let resolved = RankingContext(
      country: country?.uppercased(),
      language: Self.localeLanguage(),
      region: region?.uppercased()
    )
    if let country = resolved.country { defaults.set(country, forKey: Keys.country) }
    if let region = resolved.region { defaults.set(region, forKey: Keys.region) }

    DispatchQueue.main.async { [weak self] in
      guard let self, resolved != self.context else { return }
      self.context = resolved
    }
  }

  static func localeCountry() -> String {
    (Locale.current.region?.identifier ?? "US").uppercased()
  }

  static func localeLanguage() -> String {
    (Locale.current.language.languageCode?.identifier ?? "en").uppercased()
  }
}

extension UserRegionProvider: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied, .restricted:
      applyLocaleFallback()
    default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    manager.stopUpdatingLocation() // one-shot; we don't track the user
    guard let location = locations.last else { return }

    // Reverse-geocode to a general country/state, then discard the coordinates.
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
      guard let self else { return }
      let placemark = placemarks?.first
      self.update(
        country: placemark?.isoCountryCode ?? self.context.country,
        region: placemark?.administrativeArea ?? self.context.region
      )
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    applyLocaleFallback()
  }
}
