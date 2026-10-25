//
//  PosterCard.swift
//  SceneBox
//

#if os(iOS)
import SwiftUI

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "Remove from Watchlist": "Удалить из Избранного",
        "Add to Watchlist": "В Избранное",
        "Remove from Plan to Watch": "Удалить из планов",
        "Plan to Watch": "Буду смотреть",
        "Mark as watched": "Отметить просмотренным",
        "Mark as unwatched": "Не просмотрено",
        "Remove from History": "Удалить из истории",
        "Share": "Поделиться"
    ]
    return dict[key] ?? key
}

struct PosterCard: View {
    let item: MediaResult
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(WatchlistStore.self) private var watchlist: WatchlistStore?
    @Environment(WatchProgressStore.self) private var progress: WatchProgressStore?
    @Environment(PlanToWatchStore.self) private var planStore: PlanToWatchStore? // Подключаем хранилище планов

    var body: some View {
        let saved = progress?.progress(for: item.id)
        let watchedMovie = item.type == .movie && saved?.isFinished == true
        
        PosterImage(url: item.posterURL)
            .overlay(alignment: .topTrailing) {
                if watchedMovie {
                    WatchedBadge()
                        .padding(6)
                } else if watchlist?.contains(item.id) == true {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        // Используем системный блюр для подложки иконки
                        .background(.regularMaterial, in: Circle())
                        .environment(\.colorScheme, .dark) // Всегда темный блюр на постерах
                        .padding(6)
                }
            }
            .overlay(alignment: .bottom) {
                if let saved, !saved.isFinished, saved.fraction > 0.02 {
                    ArtworkProgress(fraction: saved.fraction)
                        .padding(6)
                }
            }
            // --- APPLE-СТИЛЬ ДЛЯ КАРТОЧЕК ---
            .clipShape(RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous))
            // Добавляем фирменную мягкую тень
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            // Добавляем микро-рамку (hairline) для идеального контура
            .overlay(
                RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
            // --------------------------------
            .accessibilityLabel(item.name)
            .contentShape(.contextMenuPreview,
                          RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous))
            .contextMenu { menu }
    }

    @ViewBuilder private var menu: some View {
        // 1. Избранное
        if let watchlist {
            let saved = watchlist.contains(item.id)
            Button {
                watchlist.toggle(id: item.id, mediaType: item.type, title: item.name, posterURL: item.posterURL)
            } label: {
                Label(saved ? tr("Remove from Watchlist", appLanguage) : tr("Add to Watchlist", appLanguage),
                      systemImage: saved ? "bookmark.slash" : "bookmark")
            }
        }
        
        // 2. Буду смотреть
        if let planStore {
            let planned = planStore.contains(item.id)
            Button {
                planStore.toggle(id: item.id, mediaType: item.type, title: item.name, posterURL: item.posterURL)
            } label: {
                Label(planned ? tr("Remove from Plan to Watch", appLanguage) : tr("Plan to Watch", appLanguage),
                      systemImage: planned ? "calendar.badge.minus" : "calendar.badge.plus")
            }
        }
        
        // 3. История и Просмотрено
        if let progress {
            let savedProgress = progress.progress(for: item.id)
            
            // Кнопка "Просмотрено" (имеет смысл в основном для фильмов)
            if item.type == .movie {
                let watchedMovie = savedProgress?.isFinished == true
                Button {
                    progress.setMovieWatched(!watchedMovie, id: item.id, title: item.name, posterURL: item.posterURL)
                } label: {
                    Label(watchedMovie ? tr("Mark as unwatched", appLanguage) : tr("Mark as watched", appLanguage),
                          systemImage: watchedMovie ? "eye.slash" : "checkmark.circle")
                }
            }
            
            // Если фильм/сериал уже есть в истории прогресса, даем возможность удалить его оттуда
            if savedProgress != nil {
                Button(role: .destructive) {
                    progress.remove(id: item.id)
                } label: {
                    Label(tr("Remove from History", appLanguage), systemImage: "trash")
                }
            }
        }
        
        // 4. Поделиться
        if item.id.hasPrefix("tt"), let url = URL(string: "https://www.imdb.com/title/\(item.id)/") {
            ShareLink(item: url, subject: Text(item.name)) {
                Label(tr("Share", appLanguage), systemImage: "square.and.arrow.up")
            }
        }
    }
}
#endif
