import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.dismiss) private var dismiss

    @State private var sessionToken = ""
    @State private var statusMessage = ""
    @State private var isError = false

    var body: some View {
        Form {
            Section("Authentication") {
                SecureField("WorkosCursorSessionToken", text: $sessionToken)
                    .textFieldStyle(.roundedBorder)

                Text("Copy the cookie value from cursor.com → DevTools → Application → Cookies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Save Token") { saveToken() }
                    Button("Clear Token", role: .destructive) { clearToken() }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .green)
                }
            }

            Section("Polling") {
                Picker("Refresh Interval", selection: Binding(
                    get: { store.refreshInterval },
                    set: { store.updateRefreshInterval($0) }
                )) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }

                Toggle("Show spending in menu bar", isOn: $store.displaySpending)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Endpoint", value: "cursor.com/api/usage-summary")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 340)
        .padding()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func saveToken() {
        do {
            try store.saveSessionToken(sessionToken)
            sessionToken = ""
            statusMessage = "Token saved securely to Keychain."
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func clearToken() {
        do {
            try store.clearSessionToken()
            sessionToken = ""
            statusMessage = "Token removed from Keychain."
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }
}
