import Foundation

/// Reads when the sideloaded build stops opening (free Apple ID profiles last 7 days).
public enum SigningExpiry {
    public enum Status: Equatable, Sendable {
        case ok(daysLeft: Int)
        case warning(daysLeft: Int)
        case expired
        case unknown
    }

    /// Below this many days left the app warns the user to re-sign before a show.
    public static let warningDays = 2

    public static func expirationDate(fromProvision data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }

    /// Reads embedded.mobileprovision from the app bundle (absent in simulator/App Store builds).
    public static func expirationDate(bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return expirationDate(fromProvision: data)
    }

    public static func status(expiration: Date?, now: Date = Date()) -> Status {
        guard let expiration else { return .unknown }
        let remaining = expiration.timeIntervalSince(now)
        guard remaining > 0 else { return .expired }
        let days = Int(remaining / 86_400)
        return days < warningDays ? .warning(daysLeft: days) : .ok(daysLeft: days)
    }
}
