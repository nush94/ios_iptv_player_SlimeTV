import Foundation
import IPTVInterfaces
import IPTVModels

class APIManager: APIManagerProtocol {
  static let shared = APIManager()

  private let operationQueue: OperationQueue
  private let userStandard = UserDefaults.standard

  private var apiHost: String {
    userStandard.string(forKey: "apiHost") ?? ""
  }

  private var normalizedApiHost: String {
    apiHost.trimmingCharacters(in: .whitespacesAndNewlines).trimmingTrailingSlashes()
  }

  private var apiPassword: String {
    userStandard.string(forKey: "apiPassword") ?? ""
  }

  private var apiLogin: String {
    userStandard.string(forKey: "apiLogin") ?? ""
  }

  public var baseURL: String {
    "\(normalizedApiHost)/player_api.php?username=\(apiLogin)&password=\(apiPassword)"
  }

  public var liveURL: String {
    "\(normalizedApiHost)/\(apiLogin)/\(apiPassword)"
  }

  public var vodURL: String {
    "\(normalizedApiHost)/movie/\(apiLogin)/\(apiPassword)"
  }

  public var serieURL: String {
    "\(normalizedApiHost)/series/\(apiLogin)/\(apiPassword)"
  }

  private let session: URLSession

  private init() {
    self.operationQueue = OperationQueue()
    operationQueue.maxConcurrentOperationCount = 4
    operationQueue.qualityOfService = .userInitiated

    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    self.session = URLSession(configuration: configuration)
  }

  func fetchCategories(from url: URL, completion: @escaping (Result<[IPTVModels.Category], Error>) -> Void) {
    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<[IPTVModels.Category], Error>) in
        switch result {
        case let .success(categories):
          completion(.success(categories))
        case let .failure(error):
          completion(.failure(error))
        }
      }
    }
    operationQueue.addOperation(operation)
  }

  func fetchStreams(for categoryAPI: String, completion: @escaping (Result<[IPTVModels.Stream], Error>) -> Void) {
    guard let url = URL(string: categoryAPI) else {
      completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
      return
    }

    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<[IPTVModels.Stream], Error>) in
        switch result {
        case let .success(streams):
          let filteredStreams = streams.filter { stream in
            !stream.name.contains("#####")
          }
          completion(.success(filteredStreams))
        case let .failure(error):
          completion(.failure(error))
        }
      }
    }
    operationQueue.addOperation(operation)
  }

  func fetchSeries(for categoryAPI: String, completion: @escaping (Result<[Series], Error>) -> Void) {
    guard let url = URL(string: categoryAPI) else {
      completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
      return
    }

    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<[Series], Error>) in
        switch result {
        case let .success(series):
          let filteredSeries = series.filter { serie in
            !serie.name.contains("#####")
          }
          completion(.success(filteredSeries))
        case let .failure(error):
          completion(.failure(error))
        }
      }
    }
    operationQueue.addOperation(operation)
  }

  func fetchSeriesDetails(from urlString: String, completion: @escaping (Result<SeriesDetail, Error>) -> Void) {
    guard let url = URL(string: urlString) else {
      completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
      return
    }

    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<SeriesDetail, Error>) in
        switch result {
        case let .success(serieDetail):
          completion(.success(serieDetail))
        case let .failure(error):
          completion(.failure(error))
        }
      }
    }
    operationQueue.addOperation(operation)
  }

  func fetchInfoUser(from urlString: String, completion: @escaping (Result<InfoUserResponse, Error>) -> Void) {
    guard let url = URL(string: urlString) else {
      completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
      return
    }

    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<InfoUserResponse, Error>) in
        switch result {
        case let .success(infoUser):
          completion(.success(infoUser))
        case let .failure(error):
          completion(.failure(error))
        }
      }
    }
    operationQueue.addOperation(operation)
  }

  func fetchShortEPG(streamId: Int, completion: @escaping (Result<ShortEPGResponse, Error>) -> Void) {
    guard let url = URL(string: "\(baseURL)&action=get_short_epg&stream_id=\(streamId)") else {
      completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
      return
    }

    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<ShortEPGResponse, Error>) in
        switch result {
        case let .success(epg):
          completion(.success(epg))
        case let .failure(error):
          completion(.failure(error))
        }
      }
    }
    operationQueue.addOperation(operation)
  }

  /// Full EPG schedule (past + upcoming) for a channel, used for catch-up.
  func fetchSimpleDataTable(streamId: Int, completion: @escaping (Result<ShortEPGResponse, Error>) -> Void) {
    guard let url = URL(string: "\(baseURL)&action=get_simple_data_table&stream_id=\(streamId)") else {
      completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
      return
    }

    let operation = BlockOperation {
      self.performRequest(url: url) { (result: Result<ShortEPGResponse, Error>) in
        completion(result)
      }
    }
    operationQueue.addOperation(operation)
  }

  /// Builds the catch-up / timeshift stream URL for a past program.
  func timeshiftURL(streamId: Int, start: Date, durationMinutes: Int) -> URL? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd:HH-mm"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let stamp = formatter.string(from: start)
    let minutes = max(1, durationMinutes)
    return URL(string: "\(normalizedApiHost)/timeshift/\(apiLogin)/\(apiPassword)/\(minutes)/\(stamp)/\(streamId).ts")
  }

  func fetchVodInfo(streamId: Int) async throws -> VodInfo? {
    guard let url = URL(string: "\(baseURL)&action=get_vod_info&vod_id=\(streamId)") else {
      throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
    }

    let (data, _) = try await session.data(from: url)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          var infoDict = json["info"] as? [String: Any]
    else {
      return nil
    }

    for key in ["youtube_trailer", "youtubeTrailer", "trailer"] where infoDict[key] == nil {
      infoDict[key] = json[key]
    }

    return VodInfo(from: infoDict)
  }

  func fetchData(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
    let operation = BlockOperation {
      let task = self.session.dataTask(with: url) { data, response, error in
        if let error {
          completion(.failure(error))
          return
        }

        guard let response = response as? HTTPURLResponse,
              (200 ... 299).contains(response.statusCode)
        else {
          completion(.failure(NSError(domain: "Invalid Response", code: -1, userInfo: nil)))
          return
        }

        guard let data else {
          completion(.failure(NSError(domain: "No Data", code: -1, userInfo: nil)))
          return
        }

        completion(.success(data))
      }
      task.resume()
    }
    operationQueue.addOperation(operation)
  }

  private func performRequest<T: Decodable>(url: URL, completion: @escaping (Result<T, Error>) -> Void) {
    let task = session.dataTask(with: url) { data, _, error in
      if let error {
        completion(.failure(error))
        return
      }

      guard let data else {
        completion(.failure(NSError(domain: "No Data", code: -1, userInfo: nil)))
        return
      }

      do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let result = try decoder.decode(T.self, from: data)
        completion(.success(result))
      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
  }
}

private extension String {
  func trimmingTrailingSlashes() -> String {
    var value = self
    while value.hasSuffix("/") {
      value.removeLast()
    }
    return value
  }
}
