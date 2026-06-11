import Foundation

struct GaugeThresholds: Equatable {
    var redRequestsRemaining: Int
    var orangeQuotaPercent: Double
    var orangeSpendPercent: Double

    static let `default` = GaugeThresholds(
        redRequestsRemaining: 50,
        orangeQuotaPercent: 20,
        orangeSpendPercent: 80
    )
}

struct AppConfig: Equatable {
    var refreshIntervalMinutes: Int
    var pauseOnSleep: Bool
    var syncOnWake: Bool
    var displaySpending: Bool
    var apiBaseURL: String
    var userAgent: String
    var gaugeThresholds: GaugeThresholds
    var loggingLevel: String

    static let `default` = AppConfig(
        refreshIntervalMinutes: 15,
        pauseOnSleep: true,
        syncOnWake: true,
        displaySpending: false,
        apiBaseURL: "https://cursor.com/api/usage-summary",
        userAgent: "CursorBar/1.0 (macOS; Native Utility)",
        gaugeThresholds: .default,
        loggingLevel: "info"
    )

    var refreshInterval: RefreshInterval {
        RefreshInterval(rawValue: refreshIntervalMinutes) ?? .fifteenMinutes
    }
}
