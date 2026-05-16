import Testing
import Foundation
@testable import TapeScrape

struct DeepLinkRouterTests {
    let router = DeepLinkRouter()

    @Test func concertRoute() {
        let url = URL(string: "tapescrape://concert/abc-123")!
        #expect(router.resolve(url) == .concert(id: "abc-123"))
    }

    @Test func recordingRoute() {
        let url = URL(string: "tapescrape://recording/gd1977-05-08.sbd.hicks.4982.sbeok.shnf")!
        #expect(router.resolve(url) == .recording(identifier: "gd1977-05-08.sbd.hicks.4982.sbeok.shnf"))
    }

    @Test func unknownHostReturnsNil() {
        let url = URL(string: "tapescrape://unknown/foo")!
        #expect(router.resolve(url) == nil)
    }

    @Test func wrongSchemeReturnsNil() {
        let url = URL(string: "https://concert/abc-123")!
        #expect(router.resolve(url) == nil)
    }

    @Test func missingPathReturnsNil() {
        let url = URL(string: "tapescrape://concert")!
        #expect(router.resolve(url) == nil)
    }
}
