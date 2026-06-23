import Foundation
import os

/// Realtime 调试日志：DEBUG 下输出到 Xcode 控制台，并保留最近条目供开发者页查看。
enum RealtimeDebugLog {
    private static let logger = Logger(subsystem: "com.pengpeng.app", category: "Realtime")
    private static let maxLines = 40
    private static var lines: [String] = []

    static var recentSummary: String {
        if lines.isEmpty { return "—" }
        return lines.suffix(8).joined(separator: "\n")
    }

    static func log(_ message: String) {
        let stamp = Self.timeFormatter.string(from: Date())
        let line = "[\(stamp)] \(message)"
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        #if DEBUG
        logger.info("\(message, privacy: .public)")
        print("[Realtime] \(message)")
        #endif
    }

    static func clear() {
        lines.removeAll()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
