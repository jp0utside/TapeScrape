import Foundation

actor CatalogClient {
    static let shared = CatalogClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.session = session
        self.baseURL = baseURL
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    func getConcert(id: String) async throws -> ConcertResponse {
        let url = baseURL.appendingPathComponent("concerts/\(id)")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CatalogError.badResponse
        }
        return try decoder.decode(ConcertResponse.self, from: data)
    }
}

enum CatalogError: Error, LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse: "Unexpected response from the catalog server."
        }
    }
}
