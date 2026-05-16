import Foundation

struct DeepLinkRouter {
    enum Destination: Equatable {
        case concert(id: String)
        case recording(identifier: String)
    }

    func resolve(_ url: URL) -> Destination? {
        guard url.scheme == "tapescrape", let host = url.host else { return nil }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let itemID = pathComponents.first else { return nil }
        switch host {
        case "concert":
            return .concert(id: itemID)
        case "recording":
            return .recording(identifier: itemID)
        default:
            return nil
        }
    }
}
