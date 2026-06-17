import Foundation

enum SupabaseDB {

    // MARK: - Playlists

    static func fetchPlaylists(token: String) async throws -> [Playlist] {
        let data = try await get("/playlists?order=created_at.desc", token: token)
        return try decode([Playlist].self, from: data)
    }

    static func createPlaylist(_ payload: CreatePlaylistPayload, token: String) async throws -> Playlist {
        let body = try JSONEncoder().encode(payload)
        let data = try await mutate("/playlists", method: "POST", body: body, token: token)
        let list = try decode([Playlist].self, from: data)
        guard let first = list.first else { throw DBError.emptyResponse }
        return first
    }

    static func deletePlaylist(id: String, token: String) async throws {
        _ = try await mutate("/playlists?id=eq.\(id)", method: "DELETE", body: nil, token: token)
    }

    // MARK: - Channels

    static func fetchChannels(playlistId: String, token: String) async throws -> [PlaylistChannel] {
        let data = try await get("/channels?playlist_id=eq.\(playlistId)&order=position.asc,created_at.asc", token: token)
        return try decode([PlaylistChannel].self, from: data)
    }

    static func addChannel(_ payload: CreateChannelPayload, token: String) async throws -> PlaylistChannel {
        let body = try JSONEncoder().encode(payload)
        let data = try await mutate("/channels", method: "POST", body: body, token: token)
        let list = try decode([PlaylistChannel].self, from: data)
        guard let first = list.first else { throw DBError.emptyResponse }
        return first
    }

    static func deleteChannel(id: String, token: String) async throws {
        _ = try await mutate("/channels?id=eq.\(id)", method: "DELETE", body: nil, token: token)
    }

    // MARK: - Private

    private static func get(_ path: String, token: String) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(SupabaseConfig.url)/rest/v1\(path)")!)
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return data
    }

    private static func mutate(_ path: String, method: String, body: Data?, token: String) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(SupabaseConfig.url)/rest/v1\(path)")!)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return data
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DBError.requestFailed
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

enum DBError: LocalizedError {
    case requestFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Request failed"
        case .emptyResponse: return "No data returned"
        }
    }
}
