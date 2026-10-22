//
//  TorrentStream.swift
//  SceneBox
//

import Foundation

nonisolated public struct TorrentStream: Identifiable, Sendable {
    public let id: String          // infoHash hex
    public let title: String       // full description line from Torrentio
    public let displayName: String // short label (source + resolution)
    public let infoHash: Data
    public let fileIndex: Int?     // which file in the torrent is the video
    public let trackers: [URL]
    public let seeders: Int?
    public let sizeText: String?
    public let resolution: String?
    public let url: URL?

    // Добавляем ручной инициализатор для подмены отображаемого имени
    public init(
        id: String,
        title: String,
        displayName: String,
        infoHash: Data,
        fileIndex: Int? = nil,
        trackers: [URL],
        seeders: Int? = nil,
        sizeText: String? = nil,
        resolution: String? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.title = title
        
        // ВАЖНО: Подменяем короткое имя на полное название релиза из Torrentio,
        // которое содержит информацию о трекере, языке и качестве
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = cleanTitle.isEmpty ? displayName : cleanTitle
        
        self.infoHash = infoHash
        self.fileIndex = fileIndex
        self.trackers = trackers
        self.seeders = seeders
        self.sizeText = sizeText
        self.resolution = resolution
        self.url = url
    }

    public var magnet: MagnetLink {
        MagnetLink(infoHash: infoHash, displayName: displayName, trackers: trackers)
    }

    public var isDebrid: Bool { url != nil }
}