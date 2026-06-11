import Foundation

// MARK: - GET /api/usage-summary (current dashboard API)

struct UsageSummaryResponse: Codable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let individualUsage: IndividualUsageSummary?
    let teamUsage: TeamUsageSummary?

    static let empty = UsageSummaryResponse(
        billingCycleStart: nil,
        billingCycleEnd: nil,
        membershipType: nil,
        individualUsage: nil,
        teamUsage: nil
    )
}

struct IndividualUsageSummary: Codable {
    let plan: PlanUsageSummary?
    let onDemand: OnDemandUsageSummary?
}

struct TeamUsageSummary: Codable {
    let onDemand: OnDemandUsageSummary?
}

struct PlanUsageSummary: Codable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

struct OnDemandUsageSummary: Codable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

// MARK: - POST api2.cursor.sh GetCurrentPeriodUsage (Pro / Team spend plans)

struct CurrentPeriodUsageResponse: Codable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let planUsage: PlanSpendUsage?
    let spendLimitUsage: SpendLimitUsage?
    let membershipType: String?
}

struct PlanSpendUsage: Codable {
    let totalSpend: Int?
    let includedSpend: Int?
    let remaining: Int?
    let limit: Int?
    let totalPercentUsed: Double?
}

struct SpendLimitUsage: Codable {
    let individualUsed: Int?
    let individualLimit: Int?
    let individualRemaining: Int?
}

// MARK: - GET /api/usage (legacy enterprise model buckets)

struct LegacyUsageResponse: Codable {
    let startOfMonth: String?
    private let models: [String: LegacyModelUsage]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        startOfMonth = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("startOfMonth"))
        var parsed: [String: LegacyModelUsage] = [:]
        for key in container.allKeys where key.stringValue != "startOfMonth" {
            if let usage = try? container.decode(LegacyModelUsage.self, forKey: key) {
                parsed[key.stringValue] = usage
            }
        }
        models = parsed
    }

    var modelBreakdown: [ModelUsage] {
        models.compactMap { name, usage in
            let tokens = usage.numTokens ?? 0
            guard tokens > 0 || (usage.numRequests ?? 0) > 0 else { return nil }
            return ModelUsage(
                modelName: name,
                inputTokens: tokens,
                outputTokens: 0
            )
        }
        .sorted { $0.totalTokens > $1.totalTokens }
    }

    var primaryRequestBucket: (used: Int, total: Int)? {
        guard let bucket = models.values.first(where: { ($0.maxRequestUsage ?? 0) > 0 }) else {
            return nil
        }
        return (bucket.numRequests ?? 0, bucket.maxRequestUsage ?? 0)
    }
}

struct LegacyModelUsage: Codable {
    let numRequests: Int?
    let numRequestsTotal: Int?
    let numTokens: Int?
    let maxRequestUsage: Int?
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

// MARK: - Mapping

enum UsageResponseMapper {
    static func from(
        summary: UsageSummaryResponse,
        period: CurrentPeriodUsageResponse? = nil,
        legacy: LegacyUsageResponse? = nil
    ) -> UsageResponse {
        let planName = capitalizePlan(
            summary.membershipType
                ?? period?.membershipType
                ?? "unknown"
        )
        let daysLeft = daysUntil(
            endISO: summary.billingCycleEnd
                ?? period?.billingCycleEnd
                ?? ""
        )

        var used = summary.individualUsage?.plan?.used ?? 0
        var total = summary.individualUsage?.plan?.limit ?? 0

        if total == 0, let bucket = legacy?.primaryRequestBucket {
            used = bucket.used
            total = bucket.total
        }

        if total == 0, let planUsage = period?.planUsage, let limit = planUsage.limit, limit > 0 {
            used = Int((planUsage.totalPercentUsed ?? 0).rounded())
            total = 100
        }

        let onDemand = summary.individualUsage?.onDemand
        let teamOnDemand = summary.teamUsage?.onDemand
        let spendLimit = period?.spendLimitUsage

        let optionalCurrent = centsToDollars(
            onDemand?.used
                ?? spendLimit?.individualUsed
                ?? period?.planUsage?.includedSpend
        )
        let optionalLimit = centsToDollars(
            onDemand?.limit
                ?? teamOnDemand?.limit
                ?? spendLimit?.individualLimit
                ?? period?.planUsage?.limit
        )

        return UsageResponse(
            subscriptionPlan: planName,
            daysLeftInPeriod: daysLeft,
            fastRequestsUsed: used,
            fastRequestsTotal: max(total, used),
            optionalSpendingLimit: optionalLimit,
            optionalSpendingCurrent: optionalCurrent,
            modelBreakdown: legacy?.modelBreakdown ?? []
        )
    }

    private static func capitalizePlan(_ raw: String) -> String {
        raw.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func daysUntil(endISO: String) -> Int {
        guard !endISO.isEmpty else { return 0 }

        if let millis = Int64(endISO) {
            let end = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
            return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var end = formatter.date(from: endISO)
        if end == nil {
            formatter.formatOptions = [.withInternetDateTime]
            end = formatter.date(from: endISO)
        }
        guard let end else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }

    private static func centsToDollars(_ cents: Int?) -> Double {
        guard let cents else { return 0 }
        return Double(cents) / 100.0
    }
}
