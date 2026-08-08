import Foundation

enum SyncConfiguration {
    static let productionAPIBaseURL = URL(string: "https://dont-unplug-that-api.gregroyclark.workers.dev")!

    static var apiBaseURL: URL? {
        if let value = ProcessInfo.processInfo.environment["DUT_API_BASE_URL"],
           let url = URL(string: value),
           url.scheme == "https" {
            return url
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "DUTAPIBaseURL") as? String,
           let url = URL(string: value),
           url.scheme == "https" {
            return url
        }
        return productionAPIBaseURL
    }

    static let callbackScheme = "dontunplugthat"
}
