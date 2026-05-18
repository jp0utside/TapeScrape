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

    func searchArtists(query: String) async throws -> ArtistSearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "type", value: "artist"),
            URLQueryItem(name: "q", value: query),
        ]
        return try await fetch(ArtistSearchResponse.self, url: components.url!)
    }

    func searchTracks(query: String) async throws -> TrackSearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "q", value: query),
        ]
        return try await fetch(TrackSearchResponse.self, url: components.url!)
    }

    func getConcerts(artist: String, page: Int = 1) async throws -> ConcertListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("concerts"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "page", value: String(page)),
        ]
        return try await fetch(ConcertListResponse.self, url: components.url!)
    }

    func getConcertDetail(id: String) async throws -> ConcertDetailResponse {
        let url = baseURL.appendingPathComponent("concerts/\(id)")
        return try await fetch(ConcertDetailResponse.self, url: url)
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CatalogError.badResponse
        }
        return try decoder.decode(type, from: data)
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
