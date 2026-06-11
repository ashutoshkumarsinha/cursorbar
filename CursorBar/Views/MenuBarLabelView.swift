import SwiftUI

/// Compact label rendered inside the NSStatusItem button.
struct MenuBarLabelView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            if store.gaugeStatus == .warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.gray)
                    .font(.system(size: 11, weight: .semibold))
            } else {
                Image("MenuBarLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(iconColor)
            }

            if let text = primaryText {
                Text(text)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor)
            }
        }
        .padding(.horizontal, 2)
    }

    private var iconColor: Color {
        switch store.gaugeStatus {
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .warning: return .gray
        case .loading: return .secondary
        }
    }

    private var textColor: Color {
        store.gaugeStatus == .warning ? .secondary : .primary
    }

    private var primaryText: String? {
        switch store.state {
        case .sessionExpired:
            return "Auth"
        case .networkError:
            return "—"
        case .loading, .idle:
            return "…"
        case .success(let usage):
            if store.displaySpending {
                return String(format: "$%.2f", usage.optionalSpendingCurrent)
            }
            return "\(usage.fastRequestsRemaining)"
        }
    }
}
