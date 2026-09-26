import Foundation

enum Money {
    /// Formats integer CNY cents as a yuan string with two decimals.
    static func formatYuan(cents: Int64) -> String {
        let negative = cents < 0
        let absCents = abs(cents)
        let yuan = absCents / 100
        let fen = absCents % 100
        let body = String(format: "%lld.%02lld", yuan, fen)
        return negative ? "−¥\(body)" : "¥\(body)"
    }

    /// Parses a yuan decimal string into cents. Returns nil if invalid or not positive.
    static func parseYuanToCents(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "CNY", with: "", options: .caseInsensitive)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        guard let whole = Int64(parts[0]) else { return nil }

        let fractional: Int64
        if parts.count == 2 {
            let fracRaw = String(parts[1])
            guard fracRaw.count <= 2, let frac = Int64(fracRaw.padding(toLength: 2, withPad: "0", startingAt: 0)) else {
                return nil
            }
            fractional = frac
        } else {
            fractional = 0
        }

        let cents = whole * 100 + fractional
        return cents > 0 ? cents : nil
    }
}
