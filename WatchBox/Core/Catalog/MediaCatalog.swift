//
//  MediaCatalog.swift
//  SceneBox
//

import Foundation

// MARK: - Cinemeta browse + detail

extension TorrentSearch {
    public func catalog(
        type: MediaType,
        feed: CatalogFeed = .popular,
        genre: String? = nil,
        skip: Int = 0
    ) async throws -> [MediaResult] {
        let isAnime = type == .anime
        
        let base = isAnime ? kitsuBase : "https://v3-cinemeta.strem.io"
        
        var path = "catalog/\(isAnime ? "anime" : type.rawValue)/\(isAnime ? feed.kitsuCatalog : feed.rawValue)"
        var extras: [String] = []
        if let genre, !genre.isEmpty {
            let encoded = genre.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? genre
            extras.append("genre=\(encoded)")
        }
        if skip > 0 { extras.append("skip=\(skip)") }
        if !extras.isEmpty { path += "/" + extras.joined(separator: "&") }

        guard let url = URL(string: "\(base)/\(path).json") else { throw CatalogError.badURL }
        let (data, _) = try await URLSession.shared.data(for: Self.request(url))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let metas = json?["metas"] as? [[String: Any]] ?? []
        return metas.compactMap { Self.parseResult($0, type: isAnime ? .series : type) }
    }

    public func detail(id: String, type: MediaType) async throws -> MediaDetail {
        let isKitsu = id.hasPrefix("kitsu:")
        
        // УБРАЛИ /ru: базовая ссылка должна быть чистой, иначе сервер отдает ошибку 404 (HTML вместо JSON)
        let base = isKitsu ? kitsuBase : "https://v3-cinemeta.strem.io"
        
        let typePath = isKitsu ? "anime" : type.rawValue
        let safeID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(base)/meta/\(typePath)/\(safeID).json") else {
            throw CatalogError.badURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: Self.request(url))
        
        // Проверяем, не заблокировал ли нас сервер (Cloudflare / 404)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw CatalogError.formatError("Ошибка сервера \(httpResponse.statusCode). Проверьте VPN.")
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let meta = json?["meta"] as? [String: Any] else {
                throw CatalogError.notFound(id)
            }
            return Self.parseDetail(meta, fallbackType: type)
        } catch {
            throw CatalogError.formatError("Сервер вернул данные в неожиданном формате.")
        }
    }

    nonisolated private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(TorrentSearch.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    // MARK: Parsing

    static func parseResult(_ meta: [String: Any], type: MediaType) -> MediaResult? {
        guard let id = meta["id"] as? String, let name = meta["name"] as? String else { return nil }
        return MediaResult(
            id: id,
            type: (meta["type"] as? String).flatMap(MediaType.init(rawValue:)) ?? type,
            name: name,
            year: (meta["releaseInfo"] as? String) ?? stringValue(meta["year"]),
            posterURL: (meta["poster"] as? String).flatMap(URL.init(string:)),
            description: meta["description"] as? String,
            backdropURL: (meta["background"] as? String).flatMap(URL.init(string:)),
            logoURL: (meta["logo"] as? String).flatMap(URL.init(string:)),
            genres: stringList(meta["genres"] ?? meta["genre"]),
            imdbRating: stringValue(meta["imdbRating"])
        )
    }

    static func parseDetail(_ meta: [String: Any], fallbackType: MediaType) -> MediaDetail {
        let type = (meta["type"] as? String).flatMap(MediaType.init(rawValue:)) ?? fallbackType
        let videos = meta["videos"] as? [[String: Any]] ?? []

        return MediaDetail(
            id: (meta["id"] as? String) ?? (meta["imdb_id"] as? String) ?? "",
            type: type,
            name: (meta["name"] as? String) ?? "Untitled",
            year: (meta["releaseInfo"] as? String) ?? stringValue(meta["year"]),
            posterURL: (meta["poster"] as? String).flatMap(URL.init(string:)),
            backdropURL: (meta["background"] as? String).flatMap(URL.init(string:)),
            logoURL: (meta["logo"] as? String).flatMap(URL.init(string:)),
            description: meta["description"] as? String,
            cast: stringList(meta["cast"]),
            directors: stringList(meta["director"]),
            writers: stringList(meta["writer"]),
            genres: stringList(meta["genres"] ?? meta["genre"]),
            imdbRating: doubleValue(meta["imdbRating"]),
            runtime: meta["runtime"] as? String,
            released: (meta["released"] as? String).flatMap(parseDate),
            country: meta["country"] as? String,
            awards: meta["awards"] as? String,
            episodes: videos.compactMap(parseEpisode),
            moviedbID: intValue(meta["moviedb_id"]),
            trailerYouTubeIDs: parseTrailers(meta["trailers"])
        )
    }

    private static func parseTrailers(_ any: Any?) -> [String] {
        guard let list = any as? [[String: Any]] else { return [] }
        let items = list.compactMap { entry -> (id: String, isTrailer: Bool)? in
            guard let id = entry["source"] as? String, !id.isEmpty else { return nil }
            return (id, (entry["type"] as? String)?.lowercased() == "trailer")
        }
        return items.filter(\.isTrailer).map(\.id) + items.filter { !$0.isTrailer }.map(\.id)
    }

    private static func intValue(_ any: Any?) -> Int? {
        switch any {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let text as String: return Int(text)
        default: return nil
        }
    }

    private static func parseEpisode(_ video: [String: Any]) -> Episode? {
        guard let id = video["id"] as? String else { return nil }
        let season = video["season"] as? Int ?? 0
        guard let number = video["episode"] as? Int ?? video["number"] as? Int else { return nil }

        return Episode(
            id: id,
            season: season,
            episode: number,
            name: (video["name"] as? String) ?? "Episode \(number)",
            overview: (video["overview"] as? String) ?? (video["description"] as? String),
            thumbnailURL: (video["thumbnail"] as? String).flatMap(URL.init(string:)),
            released: (video["released"] as? String ?? video["firstAired"] as? String).flatMap(parseDate)
        )
    }

    private static func stringValue(_ any: Any?) -> String? {
        switch any {
        case let text as String: return text
        case let number as Int: return String(number)
        case let number as Double: return String(Int(number))
        default: return nil
        }
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        switch any {
        case let number as Double: return number
        case let number as Int: return Double(number)
        case let text as String: return Double(text)
        default: return nil
        }
    }

    private static func stringList(_ any: Any?) -> [String] {
        switch any {
        case let list as [String]: return list
        case let single as String: return [single]
        default: return []
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        if let isoDate = ISO8601DateFormatter().date(from: text) {
            return isoDate
        }
        if let isoFraction = ISO8601DateFormatter.withFractionalSeconds.date(from: text) {
            return isoFraction
        }
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        return simpleFormatter.date(from: text)
    }
}

nonisolated public enum CatalogError: Error, LocalizedError {
    case notFound(String)
    case badURL
    case formatError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id): return "No metadata for \(id)."
        case .badURL: return "Couldn’t build a valid catalog URL."
        case .formatError(let msg): return msg
        }
    }
}

nonisolated extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}