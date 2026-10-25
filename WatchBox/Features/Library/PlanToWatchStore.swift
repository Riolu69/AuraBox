//
//  PlanToWatchStore.swift
//  SceneBox
//

import Foundation
import Observation

@MainActor
@Observable
final class PlanToWatchStore {
    static let shared = PlanToWatchStore()

    private(set) var items: [WatchlistItem] = []

    @ObservationIgnored private var backend: WatchlistBackend

    init(backend: WatchlistBackend = LocalPlanToWatchBackend()) {
        self.backend = backend
        Task { await reload() }
    }

    func use(_ backend: WatchlistBackend) {
        self.backend = backend
        items = []
        Task { await reload() }
    }

    private func reload() async {
        let loaded = await backend.load()
        items = loaded.sorted { $0.addedAt > $1.addedAt }
    }

    func refresh() async { await reload() }

    func contains(_ mediaID: String) -> Bool {
        items.contains { $0.id == mediaID }
    }

    func toggle(id: String, mediaType: MediaType, title: String, posterURL: URL?) {
        if contains(id) {
            remove(id: id)
        } else {
            let item = WatchlistItem(id: id, mediaType: mediaType, title: title,
                                     posterURLString: posterURL?.absoluteString,
                                     addedAt: Date())
            items.insert(item, at: 0)
            Task { [backend] in await backend.upsert(item) }
        }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        Task { [backend] in await backend.remove(id: id) }
    }
}

actor LocalPlanToWatchBackend: WatchlistBackend {
    private let url: URL

    init(profileID: String? = nil) {
        // Сохраняем в отдельный файл для каждого профиля
        url = ProfileFiles.dataURL("plantowatch", profileID: profileID)
    }

    func load() async -> [WatchlistItem] {
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([WatchlistItem].self, from: data)
        else { return [] }
        return items
    }

    func upsert(_ item: WatchlistItem) async {
        var all = await load()
        all.removeAll { $0.id == item.id }
        all.append(item)
        write(all)
    }

    func remove(id: String) async {
        var all = await load()
        all.removeAll { $0.id == id }
        write(all)
    }

    private func write(_ items: [WatchlistItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
