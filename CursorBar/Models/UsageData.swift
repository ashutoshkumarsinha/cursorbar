import Foundation

// MARK: - API Response

struct UsageResponse: Codable, Equatable {
    let subscriptionPlan: String
    let daysLeftInPeriod: Int
    let fastRequestsUsed: Int
    let fastRequestsTotal: Int
    let optionalSpendingLimit: Double
    let optionalSpendingCurrent: Double
    let modelBreakdown: [ModelUsage]

    var fastRequestsRemaining: Int {
        max(0, fastRequestsTotal - fastRequestsUsed)
    }

    var fastRequestsQuotaPercentRemaining: Double {
        guard fastRequestsTotal > 0 else { return 0 }
        return Double(fastRequestsRemaining) / Double(fastRequestsTotal) * 100
    }

    var optionalSpendingPercentUsed: Double {
        guard optionalSpendingLimit > 0 else { return 0 }
        return optionalSpendingCurrent / optionalSpendingLimit * 100
    }
}

struct ModelUsage: Codable, Equatable, Identifiable {
    var id: String { modelName }
    let modelName: String
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }

    var displayName: String {
        ModelUsage.displayNames[modelName] ?? modelName
    }

    var formattedTokenCount: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.2fM", Double(total) / 1_000_000)
        }
        if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }

    private static let displayNames: [String: String] = [
        "claude-4.6-opus": "Claude 4.6 Opus",
        "gpt-5-fast": "GPT-5 Fast",
        "gpt-5": "GPT-5",
        "gemini-3.1-pro": "Gemini 3.1 Pro"
    ]
}

// MARK: - Gauge Status

enum GaugeStatus: Equatable {
    case green
    case orange
    case red
    case warning
    case loading

    static func from(
        usage: UsageResponse,
        thresholds: GaugeThresholds = .default
    ) -> GaugeStatus {
        if usage.fastRequestsRemaining < thresholds.redRequestsRemaining { return .red }
        if usage.fastRequestsQuotaPercentRemaining < thresholds.orangeQuotaPercent { return .orange }
        if usage.optionalSpendingLimit > 0,
           usage.optionalSpendingPercentUsed >= thresholds.orangeSpendPercent {
            return .orange
        }
        return .green
    }
}

// MARK: - Refresh Interval

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30

    var id: Int { rawValue }

    var label: String {
        "Every \(rawValue) min"
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

// MARK: - Fetch State

enum FetchState: Equatable {
    case idle
    case loading
    case success(UsageResponse)
    case sessionExpired
    case networkError(String)

    var usage: UsageResponse? {
        if case .success(let usage) = self { return usage }
        return nil
    }

    var isSessionExpired: Bool {
        if case .sessionExpired = self { return true }
        return false
    }
}
