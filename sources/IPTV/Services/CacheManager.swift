//
//  CacheManager.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import Foundation
import IPTVInterfaces
import IPTVModels
import RealmSwift
import SwiftUI

class CacheManager: CacheManagerProtocol {
  static let shared = CacheManager()

  /// Serial queue for bulk-import writes, so large Realm writes run off the main
  /// thread. The UI's main-thread Realm auto-refreshes and notifies observers as
  /// usual once each background write commits.
  private let writeQueue = DispatchQueue(label: "com.iptv.cache.write", qos: .userInitiated)

  public init() {
    print(Realm.Configuration.defaultConfiguration.fileURL!)
  }

  @MainActor
  func cacheCategories(_ categories: [IPTVModels.Category], for section: String) async {
    let realm = try! await Realm()
    do {
      try realm.write {
        for category in categories {
          let categoryCached = CategoryEntity(
            id: category.id,
            name: category.name,
            parentId: category.parentId,
            section: section
          )

          realm.add(categoryCached, update: .modified)
        }
      }
    } catch {
      print("Erreur lors de la sauvegarde dans Realm: \(error)")
    }
  }

  func cacheStreams(_ streams: [IPTVModels.Stream], for section: String) {
    let realm = try! Realm()
    do {
      try realm.write {
        for stream in streams {
          realm.add(Self.makeCachedStream(stream, section: section), update: .modified)
        }
      }
    } catch {
      print("Erreur lors de la sauvegarde dans Realm: \(error)")
    }
  }

  /// Background-thread variant of `cacheStreams` for bulk import: the value-type
  /// `streams` array is handed to a serial write queue so the large Realm write
  /// doesn't block the main thread. Awaitable so the import can pace itself.
  func cacheStreamsInBackground(_ streams: [IPTVModels.Stream], for section: String) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      writeQueue.async {
        autoreleasepool {
          do {
            let realm = try Realm()
            try realm.write {
              for stream in streams {
                realm.add(Self.makeCachedStream(stream, section: section), update: .modified)
              }
            }
          } catch {
            print("Erreur lors de la sauvegarde dans Realm: \(error)")
          }
        }
        continuation.resume()
      }
    }
  }

  private static func makeCachedStream(_ stream: IPTVModels.Stream, section: String) -> CachedStream {
    CachedStream(
      id: stream.id,
      name: stream.name,
      streamType: stream.streamType,
      streamIcon: stream.streamIcon,
      section: section,
      added: stream.added,
      categoryId: stream.categoryId,
      rating: stream.rating,
      desc: stream.description,
      tmdb: stream.tmdb?.value,
      year: stream.year,
      containerExtension: stream.containerExtension,
      tvArchive: stream.tvArchive,
      archiveDays: stream.archiveDays
    )
  }

  func resetDatabase() {
    let realm = try! Realm()
    do {
      try realm.write {
        realm.deleteAll()
      }
    } catch {
      print("Erreur lors de la sauvegarde dans Realm: \(error)")
    }
  }

  func cacheSeries(_ series: [Series], for section: String) {
    let realm = try! Realm()
    do {
      try realm.write {
        for serie in series {
          let cachedSerie = CachedSeries(serie: serie, section: section)
          realm.add(cachedSerie, update: .modified)
        }
      }
    } catch {
      print("Erreur lors de la sauvegarde dans Realm: \(error)")
    }
  }

  /// Background-thread variant of `cacheSeries` for bulk import (see
  /// `cacheStreamsInBackground`).
  func cacheSeriesInBackground(_ series: [Series], for section: String) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      writeQueue.async {
        autoreleasepool {
          do {
            let realm = try Realm()
            try realm.write {
              for serie in series {
                realm.add(CachedSeries(serie: serie, section: section), update: .modified)
              }
            }
          } catch {
            print("Erreur lors de la sauvegarde dans Realm: \(error)")
          }
        }
        continuation.resume()
      }
    }
  }

  // Récupère les catégories d'une section depuis la base de données
  func fetchCachedCategories(for section: String) -> [CategoryEntity] {
    // Utilisation de la requête SwiftData
    return fetchFilteredCategories(for: section)
  }

  // Récupère les catégories d'une section depuis la base de données
  func fetchCachedStream(for section: String, categoryId: String) -> [IPTVModels.Stream] {
    do {
      let realm = try Realm()
      let streams = realm.objects(CachedStream.self)
      let results = streams.where { $0.section == section && $0.categoryId == categoryId }

      return results.map {
        IPTVModels.Stream(
          id: $0.id,
          name: $0.name,
          streamType: $0.streamType,
          streamIcon: $0.streamIcon,
          categoryId: $0.categoryId,
          rating: $0.rating,
          description: $0.desc,
          tmdb: FlexibleString(from: $0.tmdb),
          added: $0.added,
          year: $0.year
        )
      }
    } catch {
      print("Erreur lors de la récupération des streams : \(error)")
      return []
    }
  }

  func fetchFilteredCategories(for section: String) -> [CategoryEntity] {
    do {
      let realm = try Realm()
      let categories = realm.objects(CategoryEntity.self)
      let results = categories.where { $0.section == section && ($0.name.contains("[FR]") || $0.name.contains("|FR|") || $0.name.contains("FRANCE")) }

      return results.map(\.self)
    } catch {
      print("Erreur lors de la récupération des catégories : \(error)")
      return []
    }
  }
}
