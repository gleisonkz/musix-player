import Foundation
import Testing
@testable import MusixCore

@Suite struct SigningExpiryTests {
    /// embedded.mobileprovision is a CMS blob with an XML plist inside; simulate the binary wrapper.
    func provision(expiring date: String) -> Data {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AppIDName</key><string>Musix</string>
            <key>ExpirationDate</key><date>\(date)</date>
        </dict>
        </plist>
        """
        var data = Data([0x30, 0x82, 0x1F, 0x00, 0xFF, 0x00])
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0xA0, 0x82, 0x0B]))
        return data
    }

    @Test func extractsExpirationDate() throws {
        let expiry = try #require(SigningExpiry.expirationDate(fromProvision: provision(expiring: "2026-11-11T10:00:00Z")))
        #expect(expiry == ISO8601DateFormatter().date(from: "2026-11-11T10:00:00Z"))
    }

    @Test func returnsNilForGarbage() {
        #expect(SigningExpiry.expirationDate(fromProvision: Data([1, 2, 3])) == nil)
    }

    @Test func statusLevels() {
        let now = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
        let day: TimeInterval = 86_400
        #expect(SigningExpiry.status(expiration: now + 5 * day, now: now) == .ok(daysLeft: 5))
        #expect(SigningExpiry.status(expiration: now + 1.5 * day, now: now) == .warning(daysLeft: 1))
        #expect(SigningExpiry.status(expiration: now + 3600, now: now) == .warning(daysLeft: 0))
        #expect(SigningExpiry.status(expiration: now - 1, now: now) == .expired)
        #expect(SigningExpiry.status(expiration: nil, now: now) == .unknown)
    }
}
