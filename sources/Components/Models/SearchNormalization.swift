//
//  SearchNormalization.swift
//  IPTVModels
//
//  Shared text normalization for search: lowercased, diacritic-folded, and
//  stripped of spaces/punctuation so a query like "powerbook" matches a title
//  like "Power Book II: Ghost". Used both when caching (to fill the stored
//  `searchName`) and when building the search query, so the two always match.
//

import Foundation

public extension String {
  var normalizedForSearch: String {
    folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
      .lowercased()
      .filter { $0.isLetter || $0.isNumber }
  }
}
