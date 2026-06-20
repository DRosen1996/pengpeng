import Foundation

/// PocketBase 关系字段：未 expand 时为 id 字符串，expand 后为完整对象。
enum PBRelation<T: Decodable>: Decodable {
    case id(String)
    case expanded(T)

    var id: String? {
        switch self {
        case .id(let value):
            return value
        case .expanded(let value as PBUserRecord):
            return value.id
        default:
            return nil
        }
    }

    var expandedValue: T? {
        if case .expanded(let value) = self { return value }
        return nil
    }

    init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self = .id(string)
            return
        }
        self = .expanded(try T(from: decoder))
    }
}

struct PBListResponse<T: Decodable>: Decodable {
    let page: Int
    let perPage: Int
    let totalItems: Int
    let totalPages: Int
    let items: [T]
}

struct PBAuthResponse: Decodable {
    let token: String
    let record: PBUserRecord
}

struct PBUserRecord: Decodable {
    let id: String
    let email: String?
    let name: String?
    let avatar: String?
    let tags: [String]?
    let geohash: String?
    let geohashUpdatedAt: Date?
    let created: Date?
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar, tags, geohash, created, updated
        case geohashUpdatedAt = "geohash_updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        geohash = try container.decodeIfPresent(String.self, forKey: .geohash)
        geohashUpdatedAt = try PocketBaseDate.decodeIfPresent(container, forKey: .geohashUpdatedAt)
        created = try PocketBaseDate.decodeIfPresent(container, forKey: .created)
        updated = try PocketBaseDate.decodeIfPresent(container, forKey: .updated)
    }
}

struct PBPresenceRecord: Decodable {
    let id: String
    let user: PBRelation<PBUserRecord>
    let sport: String
    let durationMinutes: Int?
    let energyKcal: Int?
    let geohash: String?
    let date: Date?
    let streakLabel: String?
    let focusLabel: String?
    let created: Date?
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, user, sport, geohash, date, created, updated
        case durationMinutes = "duration_minutes"
        case energyKcal = "energy_kcal"
        case streakLabel = "streak_label"
        case focusLabel = "focus_label"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user = try container.decode(PBRelation<PBUserRecord>.self, forKey: .user)
        sport = try container.decode(String.self, forKey: .sport)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        energyKcal = try container.decodeIfPresent(Int.self, forKey: .energyKcal)
        geohash = try container.decodeIfPresent(String.self, forKey: .geohash)
        date = try PocketBaseDate.decodeIfPresent(container, forKey: .date)
        streakLabel = try container.decodeIfPresent(String.self, forKey: .streakLabel)
        focusLabel = try container.decodeIfPresent(String.self, forKey: .focusLabel)
        created = try PocketBaseDate.decodeIfPresent(container, forKey: .created)
        updated = try PocketBaseDate.decodeIfPresent(container, forKey: .updated)
    }
}

struct PBBumpRecord: Decodable {
    let id: String
    let fromUser: PBRelation<PBUserRecord>
    let toUser: PBRelation<PBUserRecord>
    let message: String?
    let status: String?
    let created: Date?
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, message, status, created, updated
        case fromUser = "from_user"
        case toUser = "to_user"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fromUser = try container.decode(PBRelation<PBUserRecord>.self, forKey: .fromUser)
        toUser = try container.decode(PBRelation<PBUserRecord>.self, forKey: .toUser)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        created = try PocketBaseDate.decodeIfPresent(container, forKey: .created)
        updated = try PocketBaseDate.decodeIfPresent(container, forKey: .updated)
    }
}

struct PBConversationRecord: Decodable {
    let id: String
    let userA: PBRelation<PBUserRecord>
    let userB: PBRelation<PBUserRecord>
    let topicID: String?
    let phase: String?
    let startedAt: Date?
    let expiresAt: Date?
    let created: Date?
    let updated: Date?

    enum CodingKeys: String, CodingKey {
        case id, phase, created, updated
        case userA = "user_a"
        case userB = "user_b"
        case topicID = "topic_id"
        case startedAt = "started_at"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userA = try container.decode(PBRelation<PBUserRecord>.self, forKey: .userA)
        userB = try container.decode(PBRelation<PBUserRecord>.self, forKey: .userB)
        topicID = try container.decodeIfPresent(String.self, forKey: .topicID)
        phase = try container.decodeIfPresent(String.self, forKey: .phase)
        startedAt = try PocketBaseDate.decodeIfPresent(container, forKey: .startedAt)
        expiresAt = try PocketBaseDate.decodeIfPresent(container, forKey: .expiresAt)
        created = try PocketBaseDate.decodeIfPresent(container, forKey: .created)
        updated = try PocketBaseDate.decodeIfPresent(container, forKey: .updated)
    }
}

struct PBMessageRecord: Decodable {
    let id: String
    let conversation: PBRelation<PBConversationRecord>
    let sender: PBRelation<PBUserRecord>
    let text: String?
    let created: Date?
    let updated: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversation = try container.decode(PBRelation<PBConversationRecord>.self, forKey: .conversation)
        sender = try container.decode(PBRelation<PBUserRecord>.self, forKey: .sender)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        created = try PocketBaseDate.decodeIfPresent(container, forKey: .created)
        updated = try PocketBaseDate.decodeIfPresent(container, forKey: .updated)
    }

    private enum CodingKeys: String, CodingKey {
        case id, conversation, sender, text, created, updated
    }
}

// MARK: - Request bodies

struct PBPresenceBody: Encodable {
    let user: String
    let sport: String
    let durationMinutes: Int
    let energyKcal: Int
    let geohash: String
    let date: String
    let streakLabel: String?
    let focusLabel: String?

    enum CodingKeys: String, CodingKey {
        case user, sport, geohash, date
        case durationMinutes = "duration_minutes"
        case energyKcal = "energy_kcal"
        case streakLabel = "streak_label"
        case focusLabel = "focus_label"
    }
}

struct PBBumpBody: Encodable {
    let fromUser: String
    let toUser: String
    let message: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case message, status
        case fromUser = "from_user"
        case toUser = "to_user"
    }
}

struct PBBumpPatch: Encodable {
    let status: String
}

struct PBConversationBody: Encodable {
    let userA: String
    let userB: String
    let topicID: String?
    let phase: String
    let startedAt: String
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case phase
        case userA = "user_a"
        case userB = "user_b"
        case topicID = "topic_id"
        case startedAt = "started_at"
        case expiresAt = "expires_at"
    }
}

struct PBConversationPatch: Encodable {
    let topicID: String?
    let phase: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case phase
        case topicID = "topic_id"
        case expiresAt = "expires_at"
    }
}

struct PBMessageBody: Encodable {
    let conversation: String
    let sender: String
    let text: String
}

struct PBUserPatch: Encodable {
    let name: String?
    let tags: [String]?
    let geohash: String?
    let geohashUpdatedAt: String?

    enum CodingKeys: String, CodingKey {
        case name, tags, geohash
        case geohashUpdatedAt = "geohash_updated_at"
    }
}
