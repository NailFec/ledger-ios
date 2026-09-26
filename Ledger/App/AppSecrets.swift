import Foundation

struct AppSecrets: Equatable, Sendable {
    let url: URL
    let anonKey: String

    static func loadFromBundle() -> AppSecrets? {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: String],
            let urlString = dict["SUPABASE_URL"],
            let key = dict["SUPABASE_ANON_KEY"],
            let url = URL(string: urlString),
            !urlString.contains("YOUR_PROJECT"),
            key != "YOUR_ANON_KEY",
            !urlString.isEmpty,
            !key.isEmpty
        else {
            return nil
        }
        return AppSecrets(url: url, anonKey: key)
    }
}
