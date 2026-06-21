//
//  SearchQuery.swift
//  IPTV
//
//  Builds the Realm predicate used by the search screens. Splits the query into
//  whitespace tokens and requires every token to match (AND), where each token
//  matches either the normalized `searchName` (space/punctuation insensitive, so
//  "powerbook" finds "Power Book II: Ghost") or the raw `name` (so multi-word
//  search still works for rows cached before `searchName` was populated).
//

import Foundation
import IPTVModels

enum SearchQuery {
  static func predicate(for query: String) -> NSPredicate? {
    let tokens = query.split(whereSeparator: { $0 == " " }).map(String.init)
    guard !tokens.isEmpty else { return nil }

    let subpredicates = tokens.map { token -> NSPredicate in
      let normalized = token.normalizedForSearch
      guard !normalized.isEmpty else {
        return NSPredicate(format: "name CONTAINS[c] %@", token)
      }
      return NSPredicate(format: "searchName CONTAINS %@ OR name CONTAINS[c] %@", normalized, token)
    }

    return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
  }

  /// Same as `predicate(for:)` but additionally constrained to a media section
  /// (for the shared CachedStream table that holds both movies and live TV).
  static func predicate(for query: String, section: String) -> NSPredicate? {
    guard let base = predicate(for: query) else { return nil }
    return NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(format: "section == %@", section),
      base,
    ])
  }
}
