import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum MockData {
    static let currentUserName = "Rosen"

    /// 深圳湾 / 南山一带 mock 锚点（不接真实定位）
    static let mapCenter = CLLocationCoordinate2D(latitude: 22.523, longitude: 113.935)
    static let userCoordinate = CLLocationCoordinate2D(latitude: 22.521, longitude: 113.933)
    static let fuzzyRadiusMeters: CLLocationDistance = 3_000

    /// 默认附近全览相机（约 6.5km 视野，支持继续拉远至球体）
    static var nearbyCamera: MapCamera {
        MapCamera(
            centerCoordinate: mapCenter,
            distance: 9_500,
            heading: 0,
            pitch: 0
        )
    }

    static var nearbyCameraPosition: MapCameraPosition {
        .camera(nearbyCamera)
    }

    static let sportZones: [SportZone] = [
        SportZone(
            id: "zone-strength",
            sport: .traditionalStrength,
            nearbyCount: 18,
            openCardCount: 5,
            latitude: 22.528,
            longitude: 113.928
        ),
        SportZone(
            id: "zone-running",
            sport: .running,
            nearbyCount: 12,
            openCardCount: 4,
            latitude: 22.518,
            longitude: 113.942
        ),
        SportZone(
            id: "zone-walking",
            sport: .walking,
            nearbyCount: 31,
            openCardCount: 8,
            latitude: 22.515,
            longitude: 113.930
        ),
        SportZone(
            id: "zone-skiing",
            sport: .skiing,
            nearbyCount: 4,
            openCardCount: 2,
            latitude: 22.526,
            longitude: 113.948
        )
    ]

    static let todayWorkout = WorkoutSummary(
        sport: .traditionalStrength,
        durationMinutes: 62,
        energyKcal: 486,
        nearbySameSportCount: 18
    )

    static let strengthZone: SportZone = sportZones[0]

    static let sameSportUsers: [NearbyUser] = [
        NearbyUser(
            id: "user-alex",
            name: "Alex",
            sportLabel: "传统力量训练",
            durationMinutes: 58,
            streakLabel: "本周第 4 练",
            focusLabel: "增肌/肩背",
            sport: .traditionalStrength
        ),
        NearbyUser(
            id: "user-mia",
            name: "Mia",
            sportLabel: "传统力量训练",
            durationMinutes: 72,
            streakLabel: "本周第 5 练",
            focusLabel: "减脂塑形",
            sport: .traditionalStrength
        ),
        NearbyUser(
            id: "user-ken",
            name: "Ken",
            sportLabel: "功能性力量",
            durationMinutes: 45,
            streakLabel: "连续 3 天没白戴",
            focusLabel: "核心训练",
            sport: .traditionalStrength
        )
    ]

    static let sportTopics: [SportTopic] = [
        SportTopic(id: "t1", title: "今天练什么部位？"),
        SportTopic(id: "t2", title: "你一周练几次？"),
        SportTopic(id: "t3", title: "Apple Watch 记录力量准吗？"),
        SportTopic(id: "t4", title: "这个健身房人多吗？")
    ]

    static func topicConversation(for topic: SportTopic, partner: NearbyUser) -> [TopicMessage] {
        switch topic.id {
        case "t1":
            return [
                TopicMessage(id: "m1", isMine: true, senderName: "我", text: topic.title),
                TopicMessage(
                    id: "m2",
                    isMine: false,
                    senderName: partner.name,
                    text: "我今天练背，刚开始恢复训练。你一般怎么安排胸背？"
                )
            ]
        default:
            return [
                TopicMessage(id: "m1", isMine: true, senderName: "我", text: topic.title),
                TopicMessage(
                    id: "m2",
                    isMine: false,
                    senderName: partner.name,
                    text: "这个话题不错，我们围绕今天的训练聊聊。"
                )
            ]
        }
    }

    static let profileTags = [
        "传统力量",
        "跑步",
        "步行/补环",
        "增肌",
        "体脂管理",
        "南山/深圳湾"
    ]

    static let pendingBumps: [PendingBump] = [
        PendingBump(
            id: "b1",
            fromUser: sameSportUsers[0],
            message: "Alex 今天也练了传统力量，向你碰碰",
            status: .pending,
            receivedAt: Date().addingTimeInterval(-3600)
        ),
        PendingBump(
            id: "b3",
            fromUser: sameSportUsers[2],
            message: "Ken 想问你 Apple Watch 力量训练准不准",
            status: .pending,
            receivedAt: Date().addingTimeInterval(-1800)
        )
    ]

    static let conversations: [SportConversation] = {
        let mia = sameSportUsers[1]
        let topic = sportTopics[2]
        let startedAt = Date().addingTimeInterval(-6 * 3600)
        return [
            SportConversation(
                id: "conv-\(mia.id)",
                partner: mia,
                topic: topic,
                messages: topicConversation(for: topic, partner: mia),
                startedAt: startedAt,
                expiresAt: startedAt.addingTimeInterval(24 * 3600),
                phase: .active
            ),
            SportConversation(
                id: "conv-expired-demo",
                partner: sameSportUsers[0],
                topic: sportTopics[0],
                messages: topicConversation(for: sportTopics[0], partner: sameSportUsers[0]),
                startedAt: Date().addingTimeInterval(-48 * 3600),
                expiresAt: Date().addingTimeInterval(-24 * 3600),
                phase: .expired
            )
        ]
    }()
}
