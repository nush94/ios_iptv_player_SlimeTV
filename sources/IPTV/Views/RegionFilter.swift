//
//  RegionFilter.swift
//  IPTV
//
//  Parses the country/language code that providers prefix onto category names
//  (e.g. "|EN| FRENCH MOVIES", "CA| ENGLISH") and a global region picker that
//  lets the user show only one region across Movies / Shows / TV.
//

import IPTVModels
import RealmSwift
import SwiftUI

enum RegionTag {
  /// Extracts a 2–3 letter region code from the start of a category name.
  /// "|EN| FRENCH MOVIES" -> "EN", "CA| ENGLISH" -> "CA", "ENGLISH" -> nil.
  static func code(from name: String) -> String? {
    var slice = Substring(name)
    while let first = slice.first, first == "|" || first == " " {
      slice = slice.dropFirst()
    }
    let letters = slice.prefix { $0.isLetter }
    guard (2 ... 3).contains(letters.count) else { return nil }

    // Must be followed by a separator so we don't match a real word like "ENGLISH".
    let after = slice.dropFirst(letters.count).first
    guard let after, after == "|" || after == "-" || after == " " else { return nil }
    return letters.uppercased()
  }
}

/// Globe menu for the top bar. Reads available regions from the cached
/// categories and writes the chosen one to a shared AppStorage key.
struct RegionMenu: View {
  @ObservedResults(CategoryEntity.self) private var categories
  @AppStorage("contentRegion") private var region: String = ""

  private var regions: [String] {
    var set = Set<String>()
    for category in categories {
      if let code = RegionTag.code(from: category.name) { set.insert(code) }
    }
    return set.sorted()
  }

  var body: some View {
    Menu {
      Button { region = "" } label: {
        Label("All regions", systemImage: region.isEmpty ? "checkmark" : "globe")
      }
      ForEach(regions, id: \.self) { code in
        Button { region = code } label: {
          if region == code {
            Label(code, systemImage: "checkmark")
          } else {
            Text(code)
          }
        }
      }
    } label: {
      // Mirror the search/settings icon buttons (icon + 3pt underline spacer
      // inside a 44pt-tall stack) so all three align on the same baseline.
      VStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "globe")
            .font(.system(size: 20, weight: .semibold))
          if !region.isEmpty {
            Text(region)
              .font(.system(size: 13, weight: .bold))
          }
        }
        Capsule()
          .fill(.clear)
          .frame(width: 0, height: 3)
      }
      .foregroundStyle(.white)
      .frame(height: 44)
      .contentShape(Rectangle())
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
  }
}
