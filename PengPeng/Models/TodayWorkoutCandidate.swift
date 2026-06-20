import Foundation

struct TodayWorkoutCandidate: Identifiable, Equatable {
    let id: String
    let sport: SportType
    let durationMinutes: Int
    let energyKcal: Int
    let startDate: Date

    var displayTitle: String {
        "\(sport.title) · \(durationMinutes) 分钟"
    }

    var displaySubtitle: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) · 活动能量 \(energyKcal) kcal"
    }

    func toWorkoutSummary(nearbyCount: Int) -> WorkoutSummary {
        WorkoutSummary(
            sport: sport,
            durationMinutes: durationMinutes,
            energyKcal: energyKcal,
            nearbySameSportCount: nearbyCount
        )
    }
}
