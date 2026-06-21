import Foundation

enum StreamYearExtractor {
  static func year(from text: String?) -> Int? {
    guard let text, !text.isEmpty else { return nil }

    let pattern = #"(?<!\d)(19\d{2}|20\d{2})(?!\d)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = regex.matches(in: text, range: range)

    let currentYear = Calendar.current.component(.year, from: Date())
    return matches
      .compactMap { match -> Int? in
        guard let matchRange = Range(match.range(at: 1), in: text),
              let year = Int(text[matchRange]),
              year >= 1900,
              year <= currentYear + 2
        else {
          return nil
        }
        return year
      }
      .max()
  }
}
