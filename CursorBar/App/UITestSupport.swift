import Foundation

enum UITestLaunchArgument {
    static let reset = "--uitesting-reset"
}

enum UITestSupport {
    static func applyLaunchArgumentsIfNeeded(userDefaults: UserDefaults = .standard) {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        guard args.contains(UITestLaunchArgument.reset) || env["CURSORBAR_UITEST_RESET"] == "1" else {
            return
        }

        try? KeychainService.shared.deleteSessionToken()
        userDefaults.removeObject(forKey: "cursorbar.refreshInterval")
        userDefaults.removeObject(forKey: "cursorbar.displaySpending")
    }
}
