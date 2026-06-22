import Foundation

enum PBMapping {
    static func nearbyUser(
        from presence: PBPresenceRecord,
        excludingUserID: String?
    ) -> NearbyUser? {
        let userID = presence.user.id ?? presence.user.expandedValue?.id
        guard let userID, userID != excludingUserID else { return nil }
        guard let sport = SportType(rawValue: presence.sport) else { return nil }

        let userRecord = presence.user.expandedValue
        let name = userRecord?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false) ? name! : "运动者"

        return NearbyUser(
            id: userID,
            name: displayName,
            sportLabel: sport.title,
            durationMinutes: presence.durationMinutes ?? 0,
            streakLabel: presence.streakLabel ?? "",
            focusLabel: presence.focusLabel ?? "",
            sport: sport
        )
    }

    static func nearbyUser(from user: PBUserRecord, presence: PBPresenceRecord) -> NearbyUser? {
        guard let sport = SportType(rawValue: presence.sport) else { return nil }
        let name = user.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return NearbyUser(
            id: user.id,
            name: (name?.isEmpty == false) ? name! : "运动者",
            sportLabel: sport.title,
            durationMinutes: presence.durationMinutes ?? 0,
            streakLabel: presence.streakLabel ?? "",
            focusLabel: presence.focusLabel ?? "",
            sport: sport
        )
    }

    static func pendingBump(from record: PBBumpRecord) -> PendingBump? {
        guard let fromUserRecord = record.fromUser.expandedValue,
              let nearbyUser = nearbyUser(from: fromUserRecord, presence: placeholderPresence(for: fromUserRecord)),
              let statusRaw = record.status,
              let status = BumpStatus(rawValue: statusRaw)
        else { return nil }

        return PendingBump(
            id: record.id,
            fromUser: nearbyUser,
            message: record.message ?? "",
            status: status,
            receivedAt: record.created ?? Date()
        )
    }

    static func pendingBump(
        from record: PBBumpRecord,
        presenceByUserID: [String: PBPresenceRecord]
    ) -> PendingBump? {
        guard let fromID = record.fromUser.id ?? record.fromUser.expandedValue?.id,
              let statusRaw = record.status,
              let status = BumpStatus(rawValue: statusRaw)
        else { return nil }

        let userRecord = record.fromUser.expandedValue ?? minimalUser(id: fromID, name: "运动者")

        let presence = presenceByUserID[fromID] ?? placeholderPresence(for: userRecord)
        guard let nearbyUser = nearbyUser(from: userRecord, presence: presence) else { return nil }

        return PendingBump(
            id: record.id,
            fromUser: nearbyUser,
            message: record.message ?? "",
            status: status,
            receivedAt: record.created ?? Date()
        )
    }

    static func conversation(
        from record: PBConversationRecord,
        messages: [TopicMessage],
        currentUserID: String
    ) -> SportConversation? {
        let userA = record.userA.expandedValue
        let userB = record.userB.expandedValue
        let userAID = record.userA.id ?? userA?.id
        let userBID = record.userB.id ?? userB?.id

        guard let userAID, let userBID else { return nil }

        let partnerID = userAID == currentUserID ? userBID : userAID
        let partnerExpanded = userAID == currentUserID ? userB : userA
        let partnerRecord = partnerExpanded ?? minimalUser(id: partnerID, name: "运动者")

        let partnerPresence = placeholderPresence(for: partnerRecord)
        guard let partner = nearbyUser(from: partnerRecord, presence: partnerPresence) else { return nil }

        let topic = record.topicID.flatMap { id in
            MockData.sportTopics.first { $0.id == id }
        }

        let phase = record.phase.flatMap { ConversationPhase(rawValue: $0) } ?? .awaitingTopic

        return SportConversation(
            id: record.id,
            partner: partner,
            topic: topic,
            messages: messages,
            startedAt: record.startedAt ?? record.created ?? Date(),
            expiresAt: record.expiresAt,
            phase: phase
        )
    }

    static func topicMessage(
        from record: PBMessageRecord,
        currentUserID: String,
        currentUserName: String
    ) -> TopicMessage? {
        guard let text = record.text else { return nil }
        let senderID = record.sender.id ?? record.sender.expandedValue?.id
        let isMine = senderID == currentUserID
        let senderName = isMine ? "我" : (record.sender.expandedValue?.name ?? "对方")
        return TopicMessage(
            id: record.id,
            isMine: isMine,
            senderName: senderName,
            text: text
        )
    }

    static func workoutSummary(
        from presence: PBPresenceRecord,
        nearbyCount: Int
    ) -> WorkoutSummary? {
        guard let sport = SportType(rawValue: presence.sport) else { return nil }
        return WorkoutSummary(
            sport: sport,
            durationMinutes: presence.durationMinutes ?? 0,
            energyKcal: presence.energyKcal ?? 0,
            nearbySameSportCount: nearbyCount
        )
    }

    static func hasTestBypassTag(_ user: PBUserRecord) -> Bool {
        user.tags?.contains(APIConfig.testBypassTag) == true
    }

    static func shouldUsePresenceBypass(user: PBUserRecord, presence: PBPresenceRecord) -> Bool {
        guard hasTestBypassTag(user) else { return false }
        guard let minutes = presence.durationMinutes,
              minutes >= APIConfig.minimumWorkoutDurationMinutes else { return false }
        return SportType(rawValue: presence.sport) != nil
    }

    static func todayWorkoutCandidate(from presence: PBPresenceRecord) -> TodayWorkoutCandidate? {
        guard let sport = SportType(rawValue: presence.sport),
              let minutes = presence.durationMinutes,
              minutes >= APIConfig.minimumWorkoutDurationMinutes else { return nil }
        return TodayWorkoutCandidate(
            id: "presence-\(presence.id)",
            sport: sport,
            durationMinutes: minutes,
            energyKcal: presence.energyKcal ?? 0,
            startDate: presence.date ?? Date()
        )
    }

    static func sportZones(
        from presences: [PBPresenceRecord],
        templates: [SportZone] = MockData.sportZones
    ) -> [SportZone] {
        var counts: [SportType: Int] = [:]
        for presence in presences {
            if let sport = SportType(rawValue: presence.sport) {
                counts[sport, default: 0] += 1
            }
        }

        return templates.map { template in
            SportZone(
                id: template.id,
                sport: template.sport,
                nearbyCount: counts[template.sport] ?? 0,
                openCardCount: min(counts[template.sport] ?? 0, 12),
                latitude: template.latitude,
                longitude: template.longitude
            )
        }
    }

    private static func minimalUser(id: String, name: String) -> PBUserRecord {
        try! JSONDecoder().decode(
            PBUserRecord.self,
            from: Data("{\"id\":\"\(id)\",\"name\":\"\(name)\"}".utf8)
        )
    }

    private static func placeholderPresence(for user: PBUserRecord) -> PBPresenceRecord {
        // 仅用于展示昵称时的占位，运动数据以 presence 表为准
        try! JSONDecoder().decode(
            PBPresenceRecord.self,
            from: Data("""
            {
              "id": "placeholder",
              "user": "\(user.id)",
              "sport": "\(SportType.traditionalStrength.rawValue)",
              "duration_minutes": 0,
              "energy_kcal": 0
            }
            """.utf8)
        )
    }
}
