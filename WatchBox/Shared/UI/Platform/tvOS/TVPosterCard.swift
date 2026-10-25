//
//  TVPosterCard.swift
//  SceneBox
//

#if os(tvOS)
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
        "Remove from History": "Удалить из истории"
    ]
    return dict[key] ?? key
}

struct TVPosterCard: View {
    let item: MediaResult
    var width: CGFloat = 260
    
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(WatchlistStore.self) private var watchlist: WatchlistStore?
    @Environment(WatchProgressStore.self) private var progress: WatchProgressStore?
    @Environment(PlanToWatchStore.self) private var planStore: PlanToWatchStore?

    var body: some View {
        let saved = progress?.progress(for: item.id)
        let watchedMovie = item.type == .movie && saved?.isFinished == true
        
        PosterImage(url: item.posterURL)
            .frame(width: width)
            .overlay(alignment: .topTrailing) {
                if watchedMovie {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(9)
                        .background(.regularMaterial, in: Circle())
                        .environment(\.colorScheme, .dark)
                        .padding(10)
                } else if watchlist?.contains(item.id) == true {
                    Image(systemName: "bookmark.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(9)
                        // Меняем глухой черный на фирменное полупрозрачное стекло Apple
                        .background(.regularMaterial, in: Circle())
                        .environment(\.colorScheme, .dark)
                        .padding(10)
                }
            }
            .overlay(alignment: .bottom) {
                if let saved, !saved.isFinished, saved.fraction > 0.02 {
                    ArtworkProgress(fraction: saved.fraction)
                        .padding(10)
                }
            }
            // Добавляем плавные скругления (continuous) для идеального контура
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(item.name)
            // Добавляем контекстное меню (вызывается долгим нажатием на пульте)
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
            
            // Кнопка "Просмотрено" (в основном для фильмов)
            if item.type == .movie {
                let watchedMovie = savedProgress?.isFinished == true
                Button {
                    progress.setMovieWatched(!watchedMovie, id: item.id, title: item.name, posterURL: item.posterURL)
                } label: {
                    Label(watchedMovie ? tr("Mark as unwatched", appLanguage) : tr("Mark as watched", appLanguage),
                          systemImage: watchedMovie ? "eye.slash" : "checkmark.circle")
                }
            }
            
            // Если фильм/сериал есть в истории, даем возможность удалить его
            if savedProgress != nil {
                Button(role: .destructive) {
                    progress.remove(id: item.id)
                } label: {
                    Label(tr("Remove from History", appLanguage), systemImage: "trash")
                }
            }
        }
    }
}
#endif
