import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var state: FetchState = .idle
    @Published var refreshInterval: RefreshInterval {
        didSet { userDefaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval) }
    }
    @Published var displaySpending: Bool {
        didSet { userDefaults.set(displaySpending, forKey: Keys.displaySpending) }
    }

    let config: AppConfig

    var gaugeThresholds: GaugeThresholds { config.gaugeThresholds }

    var gaugeStatus: GaugeStatus {
        switch state {
        case .loading, .idle:
            return .loading
        case .sessionExpired, .networkError:
            return .warning
        case .success(let usage):
            return GaugeStatus.from(usage: usage, thresholds: config.gaugeThresholds)
        }
    }

    private var pollTask: Task<Void, Never>?
    private let keychain: KeychainService
    private let api: CursorAPIService
    private let sleepMonitor: SleepMonitor
    private let userDefaults: UserDefaults

    private enum Keys {
        static let refreshInterval = "cursorbar.refreshInterval"
        static let displaySpending = "cursorbar.displaySpending"
    }

    init(
        config: AppConfig = ConfigLoader.load(),
        keychain: KeychainService = .shared,
        api: CursorAPIService? = nil,
        sleepMonitor: SleepMonitor = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.config = config
        self.keychain = keychain
        self.api = api ?? CursorAPIService(config: config)
        self.sleepMonitor = sleepMonitor
        self.userDefaults = userDefaults

        if userDefaults.object(forKey: Keys.refreshInterval) != nil {
            let stored = userDefaults.integer(forKey: Keys.refreshInterval)
            refreshInterval = RefreshInterval(rawValue: stored) ?? config.refreshInterval
        } else {
            refreshInterval = config.refreshInterval
        }

        if userDefaults.object(forKey: Keys.displaySpending) != nil {
            displaySpending = userDefaults.bool(forKey: Keys.displaySpending)
        } else {
            displaySpending = config.displaySpending
        }

        sleepMonitor.start()
        sleepMonitor.onSleep { [weak self] in
            Task { @MainActor in
                guard let self, self.config.pauseOnSleep else { return }
                self.pausePolling()
            }
        }
        sleepMonitor.onWake { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.config.syncOnWake {
                    await self.syncNow()
                }
                self.resumePolling()
            }
        }

        if keychain.hasToken {
            Task { await syncNow() }
            resumePolling()
        } else {
            state = .sessionExpired
        }
    }

    deinit {
        pollTask?.cancel()
        sleepMonitor.stop()
    }

    func saveSessionToken(_ token: String) throws {
        let normalized = SessionTokenNormalizer.cookieValue(from: token)
        guard !normalized.isEmpty else { return }
        try keychain.saveSessionToken(normalized)
        Task { await syncNow() }
        resumePolling()
    }

    func clearSessionToken() throws {
        try keychain.deleteSessionToken()
        pausePolling()
        state = .sessionExpired
    }

    func syncNow() async {
        guard !sleepMonitor.isAsleep else { return }

        guard let stored = try? keychain.readSessionToken(), !stored.isEmpty else {
            state = .sessionExpired
            return
        }
        let token = SessionTokenNormalizer.cookieValue(from: stored)

        if case .success = state {
            // Keep showing last good data while refreshing.
        } else {
            state = .loading
        }

        do {
            let usage = try await api.fetchUsage(sessionToken: token)
            state = .success(usage)
        } catch let error as CursorAPIError {
            switch error {
            case .unauthorized, .missingToken:
                state = .sessionExpired
            default:
                state = .networkError(error.localizedDescription)
            }
        } catch {
            state = .networkError(error.localizedDescription)
        }
    }

    func resumePolling() {
        pausePolling()
        guard keychain.hasToken else { return }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = self.refreshInterval.seconds
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.syncNow()
            }
        }
    }

    func pausePolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func updateRefreshInterval(_ interval: RefreshInterval) {
        refreshInterval = interval
        resumePolling()
    }
}
