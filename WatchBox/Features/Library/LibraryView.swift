//
//  LibraryView.swift
//  SceneBox
//

import SwiftUI

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "Library": "Медиатека",
        "Downloads": "Загрузки",
        "Watchlist": "Избранное",
        "History": "История",
        "Plan to Watch": "Буду смотреть",
        "Section": "Раздел",
        "No saved titles": "Нет сохраненных видео",
        "Add movies and shows to your Watchlist from their detail pages.": "Добавляйте фильмы и сериалы в Избранное со страниц описания.",
        "No history yet": "История пуста",
        "Titles you watch will appear here.": "Здесь появятся просмотренные фильмы и сериалы.",
        "Nothing planned": "Нет планов",
        "Add titles you want to watch later.": "Добавляйте фильмы и сериалы, которые хотите посмотреть позже.",
        "Remove": "Удалить",
        "Remove from Watchlist": "Удалить из Избранного",
        "Movie": "Фильм",
        "TV Show": "Сериал",
        "Anime": "Аниме",
        "watched": "просмотрено",
        "episode watched": "эпизод просмотрен",
        "episodes watched": "эпизодов просмотрено"
    ]
    return dict[key] ?? key
}

struct LibraryView: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"

    private enum Section: String, CaseIterable, Identifiable {
        case downloads = "Downloads"
        case watchlist = "Watchlist"
        case history = "History"
        case planToWatch = "Plan to Watch"
        var id: String { rawValue }
    }

    @State private var section: Section = .downloads
    @Namespace private var switcher

    var body: some View {
        NavigationStack {
            Group {
                #if os(tvOS)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        PageTitleRow(tr("Library", appLanguage))
                        sectionPicker
                        content
                    }
                    .padding(.horizontal, controlInset)
                    .padding(.top, 40)
                    .padding(.bottom, 60)
                }
                #else
                VStack(spacing: 0) {
                    RootHeader(tr("Library", appLanguage))
                    sectionPicker
                        .padding(.horizontal, controlInset)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                    content
                }
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            #if os(tvOS)
            .pageTitle(tr("Library", appLanguage))
            #else
            .toolbar(.hidden, for: .navigationBar)
            .statusBarScrim()
            #endif
            .mediaNavigationDestinations()
        }
    }

    @ViewBuilder
    private var sectionPicker: some View {
        // Нативный Apple Segmented Control для всех платформ
        Picker(tr("Section", appLanguage), selection: $section) {
            ForEach(Section.allCases) { option in 
                Text(tr(option.rawValue, appLanguage)).tag(option) 
            }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: section)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .downloads: DownloadsView()
        case .watchlist: WatchlistSection()
        case .history: HistorySection()
        case .planToWatch: PlanToWatchSection()
        }
    }

    #if os(tvOS)
    private var controlInset: CGFloat { TVHomeView.edge }
    #else
    private var controlInset: CGFloat { 16 }
    #endif
}

private struct WatchlistSection: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(WatchlistStore.self) private var watchlist

    var body: some View {
        if watchlist.items.isEmpty {
            EmptyStateView(
                systemImage: "bookmark",
                title: tr("No saved titles", appLanguage),
                message: tr("Add movies and shows to your Watchlist from their detail pages.", appLanguage)
            )
        } else {
            // Здесь отображается список элементов Избранного
            List {
                ForEach(watchlist.items) { item in
                    Text(item.title)
                }
            }
        }
    }
}

// Заглушка для раздела "История"
private struct HistorySection: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"

    var body: some View {
        EmptyStateView(
            systemImage: "clock.arrow.circlepath",
            title: tr("No history yet", appLanguage),
            message: tr("Titles you watch will appear here.", appLanguage)
        )
    }
}

// Заглушка для раздела "Буду смотреть"
private struct PlanToWatchSection: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"

    var body: some View {
        EmptyStateView(
            systemImage: "calendar.badge.clock",
            title: tr("Nothing planned", appLanguage),
            message: tr("Add titles you want to watch later.", appLanguage)
        )
    }
}
