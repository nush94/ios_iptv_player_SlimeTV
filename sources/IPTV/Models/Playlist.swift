import Foundation

struct Playlist: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var description: String
    var isPublic: Bool
    var shareToken: String
    let userId: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isPublic = "is_public"
        case shareToken = "share_token"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PlaylistChannel: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var streamUrl: String
    var logoUrl: String
    var category: String
    var kind: String
    var position: Int
    let playlistId: String
    let userId: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, kind, position
        case streamUrl = "stream_url"
        case logoUrl = "logo_url"
        case playlistId = "playlist_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct CreatePlaylistPayload: Encodable, Sendable {
    let name: String
    let description: String
    let isPublic: Bool
    let userId: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPublic = "is_public"
        case userId = "user_id"
    }
}

struct CreateChannelPayload: Encodable, Sendable {
    let playlistId: String
    let userId: String
    let name: String
    let streamUrl: String
    let logoUrl: String
    let category: String
    let kind: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case name, category, kind, position
        case playlistId = "playlist_id"
        case userId = "user_id"
        case streamUrl = "stream_url"
        case logoUrl = "logo_url"
    }
}
