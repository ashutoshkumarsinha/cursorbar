import SwiftUI

/// First-run onboarding sheet for session token setup.
struct AuthenticationView: View {
    @ObservedObject var store: UsageStore
    @Binding var isPresented: Bool

    @State private var sessionToken = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect CursorBar")
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("onboarding.title")

            Text("CursorBar reads your usage from cursor.com using your browser session token. The token is stored only in the macOS Keychain.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("How to find your token:")
                    .font(.subheadline.weight(.medium))

                VStack(alignment: .leading, spacing: 4) {
                    step(1, "Open cursor.com and sign in")
                    step(2, "Open DevTools → Application → Cookies")
                    step(3, "Copy the value of WorkosCursorSessionToken")
                    step(4, "Or paste your JWT access token — CursorBar will format it automatically")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            SecureField("Paste session token", text: $sessionToken)
                .textFieldStyle(.roundedBorder)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Skip for Now") { isPresented = false }
                    .accessibilityIdentifier("onboarding.skip")
                Button("Save & Connect") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(sessionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        Text("\(number). \(text)")
    }

    private func save() {
        do {
            try store.saveSessionToken(sessionToken)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
