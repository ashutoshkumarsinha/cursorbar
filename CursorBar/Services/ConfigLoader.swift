import Foundation

enum ConfigLoader {
    static let configEnvKey = "CURSORBAR_CONFIG"
    static let defaultDirectoryName = ".cursorbar"
    static let defaultFileName = "config.toml"

    static func resolveConfigURL(fileManager: FileManager = .default) -> URL? {
        if let envPath = ProcessInfo.processInfo.environment[configEnvKey],
           !envPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expanded = NSString(string: envPath).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }

        let defaultURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(defaultDirectoryName)
            .appendingPathComponent(defaultFileName)

        return fileManager.fileExists(atPath: defaultURL.path) ? defaultURL : nil
    }

    static func load(from url: URL? = resolveConfigURL()) -> AppConfig {
        guard let url, let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return .default
        }
        return parse(contents)
    }

    static func parse(_ contents: String) -> AppConfig {
        var config = AppConfig.default
        var section = ""

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("["), line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            apply(key: key, value: value, section: section, to: &config)
        }

        return config
    }

    private static func stripComment(_ line: String) -> String {
        var result = ""
        var inQuotes = false

        for character in line {
            if character == "\"" {
                inQuotes.toggle()
                result.append(character)
                continue
            }
            if character == "#", !inQuotes {
                break
            }
            result.append(character)
        }

        return result
    }

    private static func apply(key: String, value: String, section: String, to config: inout AppConfig) {
        switch section {
        case "polling":
            switch key {
            case "refresh_interval_minutes":
                if let minutes = Int(parseScalar(value)), RefreshInterval(rawValue: minutes) != nil {
                    config.refreshIntervalMinutes = minutes
                }
            case "pause_on_sleep":
                config.pauseOnSleep = parseBool(value)
            case "sync_on_wake":
                config.syncOnWake = parseBool(value)
            default:
                break
            }
        case "menu_bar":
            if key == "display_spending" {
                config.displaySpending = parseBool(value)
            }
        case "api":
            switch key {
            case "base_url":
                config.apiBaseURL = parseString(value)
            case "user_agent":
                config.userAgent = parseString(value)
            default:
                break
            }
        case "gauge":
            switch key {
            case "red_requests_remaining":
                if let value = Int(parseScalar(value)) {
                    config.gaugeThresholds.redRequestsRemaining = value
                }
            case "orange_quota_percent":
                if let value = Int(parseScalar(value)) {
                    config.gaugeThresholds.orangeQuotaPercent = Double(value)
                }
            case "orange_spend_percent":
                if let value = Int(parseScalar(value)) {
                    config.gaugeThresholds.orangeSpendPercent = Double(value)
                }
            default:
                break
            }
        case "logging":
            if key == "level" {
                config.loggingLevel = parseString(value)
            }
        default:
            break
        }
    }

    private static func parseScalar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private static func parseString(_ value: String) -> String {
        parseScalar(value)
    }

    private static func parseBool(_ value: String) -> Bool {
        switch parseScalar(value).lowercased() {
        case "true", "yes", "1": return true
        default: return false
        }
    }
}
