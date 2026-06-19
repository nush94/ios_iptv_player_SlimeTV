//
//  TrailerLink.swift
//  IPTV
//

import Foundation

enum TrailerLink {
  static func url(from rawValue: String?) -> URL? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawValue.isEmpty else { return nil }

    if let url = URL(string: rawValue), url.scheme != nil {
      return url
    }

    let trimmed = rawValue
      .replacingOccurrences(of: "watch?v=", with: "")
      .replacingOccurrences(of: "youtu.be/", with: "")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    guard !trimmed.isEmpty else { return nil }
    return URL(string: "https://www.youtube.com/watch?v=\(trimmed)")
  }
}
