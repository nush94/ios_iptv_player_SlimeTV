//
//  TitleCleaner.swift
//  IPTV
//
//  Cleans messy IPTV titles and pulls out structured metadata (year, language,
//  country). Pure and thread-safe so it can run on the import's background write
//  queue. Regexes are precompiled (static) because this runs on every one of the
//  200K+ items at import time. The detected language/country here are best-effort
//  from the tags providers prepend; TMDB enrichment refines them later.
//

import Foundation

struct CleanedTitle {
  let cleanTitle: String
  let year: Int?
  let language: String?  // uppercased ISO-639-1-ish, e.g. "EN"
  let country: String?   // uppercased ISO-3166-ish, e.g. "US"
}

enum TitleCleaner {
  // Quality / format / source tags stripped out entirely.
  private static let junkTags: Set<String> = [
    "HD", "FHD", "UHD", "SD", "HQ", "4K", "8K", "1080P", "720P", "480P", "2160P",
    "HEVC", "H264", "H265", "X264", "X265", "AAC", "AC3",
    "CAM", "TS", "TC", "HDCAM", "HDTS", "HDTC", "TELESYNC", "TELECINE",
    "WEB", "WEBRIP", "WEBDL", "BLURAY", "BRRIP", "DVDRIP", "HDRIP",
    "MULTI", "VOSTFR", "VOST", "DUB", "DUBBED", "SUB", "SUBBED",
  ]

  private static let languageCodes: Set<String> = [
    "EN", "FR", "AR", "ES", "DE", "IT", "PT", "NL", "RU", "TR", "HI", "UR",
    "FA", "PL", "SV", "NO", "DA", "FI", "EL", "HE", "ZH", "JA", "KO", "RO",
  ]

  private static let countryCodes: Set<String> = [
    "US", "UK", "GB", "CA", "AU", "NZ", "IE", "IN", "PK", "AE", "SA", "EG",
    "BR", "MX", "BE", "SE", "DK", "GR", "ZA", "QA", "KW", "MA", "DZ", "TN",
  ]

  /// Tags sit at the edges of the title, where providers put them — so a real
  /// word mid-title is never mistaken for a code.
  private static let edgeWindow = 2

  private static let separators = CharacterSet(charactersIn: "|[](){}_/\\•·")
  private static let trimChars = CharacterSet(charactersIn: " -–—:_.|")

  private static let yearRegex = try? NSRegularExpression(pattern: #"(?<!\d)(?:19|20)\d{2}(?!\d)"#)
  private static let parensYearRegex = try? NSRegularExpression(pattern: #"\((?:19|20)\d{2}\)"#)
  private static let multiSpaceRegex = try? NSRegularExpression(pattern: #"\s+"#)

  static func clean(_ raw: String) -> CleanedTitle {
    let year = firstYear(in: raw)
    let yearToken = year.map(String.init)

    let spaced = String(raw.unicodeScalars.map { separators.contains($0) ? " " : Character($0) })
    let tokens = spaced.split(separator: " ").map(String.init)

    var detectedLanguage: String?
    var detectedCountry: String?
    var kept: [String] = []
    kept.reserveCapacity(tokens.count)

    for (index, token) in tokens.enumerated() {
      let code = token.uppercased().filter { $0.isLetter || $0.isNumber }
      if code.isEmpty { continue }
      if code == yearToken { continue }
      if junkTags.contains(code) { continue }

      let isEdge = index < edgeWindow || index >= tokens.count - edgeWindow
      if isEdge, (2 ... 3).contains(code.count) {
        if detectedLanguage == nil, languageCodes.contains(code) {
          detectedLanguage = code
          continue
        }
        if detectedCountry == nil, countryCodes.contains(code) {
          detectedCountry = code
          continue
        }
      }

      kept.append(token)
    }

    var clean = kept.joined(separator: " ")
    clean = removingMatches(parensYearRegex, in: clean, with: "")
    clean = removingMatches(multiSpaceRegex, in: clean, with: " ")
    clean = clean.trimmingCharacters(in: trimChars)
    if clean.isEmpty { clean = raw.trimmingCharacters(in: .whitespaces) }

    return CleanedTitle(
      cleanTitle: clean,
      year: year,
      language: detectedLanguage,
      country: detectedCountry
    )
  }

  private static func firstYear(in text: String) -> Int? {
    guard let yearRegex else { return nil }
    let range = NSRange(text.startIndex ..< text.endIndex, in: text)
    let currentYear = Calendar.current.component(.year, from: Date())
    var best: Int?
    yearRegex.enumerateMatches(in: text, range: range) { match, _, _ in
      guard let match, let matchRange = Range(match.range, in: text),
            let value = Int(text[matchRange]), value >= 1900, value <= currentYear + 2
      else { return }
      best = max(best ?? 0, value)
    }
    return best
  }

  private static func removingMatches(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
    guard let regex else { return text }
    let range = NSRange(text.startIndex ..< text.endIndex, in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
  }
}
