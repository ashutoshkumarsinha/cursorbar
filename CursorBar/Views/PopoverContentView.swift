import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var store: UsageStore
    var onPreferences: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Label(headerTitle, systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(headerColor)

            Spacer()

            Button {
                Task { await store.syncNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Sync Now")
            .disabled(store.state == .loading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .sessionExpired:
            sessionExpiredView
        case .networkError(let message):
            errorView(message: message)
        case .loading, .idle:
            loadingView
        case .success(let usage):
            usageDashboard(usage)
        }
    }

    private var footer: some View {
        HStack {
            Button("Preferences…", action: onPreferences)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Quit App", action: onQuit)
                .buttonStyle(.plain)
                .foregroundStyle(.red)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func usageDashboard(_ usage: UsageResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(usage.subscriptionPlan) Plan")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(usage.daysLeftInPeriod) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Fast Requests")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(usage.fastRequestsUsed), total: Double(max(usage.fastRequestsTotal, 1)))
                    .tint(progressTint(for: usage))

                Text("\(usage.fastRequestsUsed) / \(usage.fastRequestsTotal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Optional Pay-As-You-Go Spending")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ProgressView(
                    value: usage.optionalSpendingCurrent,
                    total: max(usage.optionalSpendingLimit, 0.01)
                )
                .tint(usage.optionalSpendingPercentUsed >= 80 ? .orange : .blue)

                Text(
                    String(
                        format: "$%.2f / $%.2f Max",
                        usage.optionalSpendingCurrent,
                        usage.optionalSpendingLimit
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if !usage.modelBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model Breakdown (Current Cycle)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    ForEach(usage.modelBreakdown) { model in
                        HStack {
                            Text("• \(model.displayName):")
                            Spacer()
                            Text("\(model.formattedTokenCount) tokens")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(14)
    }

    private var sessionExpiredView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Expired — Re-authenticate", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text("Copy your WorkosCursorSessionToken from cursor.com cookies and paste it in Preferences.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Preferences…", action: onPreferences)
                .controlSize(.small)
        }
        .padding(14)
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to Sync", systemImage: "wifi.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Retry") {
                Task { await store.syncNow() }
            }
            .controlSize(.small)
        }
        .padding(14)
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Syncing usage…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private var headerTitle: String {
        switch store.state {
        case .success(let usage):
            let remaining = usage.fastRequestsRemaining
            return "⚡ \(remaining) Left (\(usage.subscriptionPlan))"
        case .sessionExpired:
            return "⚠️ Session Expired"
        case .networkError:
            return "⚠️ Sync Failed"
        case .loading, .idle:
            return "CursorBar"
        }
    }

    private var headerColor: Color {
        switch store.gaugeStatus {
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .warning, .loading: return .secondary
        }
    }

    private func progressTint(for usage: UsageResponse) -> Color {
        switch GaugeStatus.from(usage: usage, thresholds: store.gaugeThresholds) {
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        default: return .accentColor
        }
    }
}
