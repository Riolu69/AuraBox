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
        "Watchlist": "Избранное", // или "Буду смотреть"
        "Section": "Раздел",
        "No saved titles": "Нет сохраненных видео",
        "Add movies and shows to your Watchlist from their detail pages.": "Добавляйте фильмы и сериалы в Избранное со страниц описания.",
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
                        .padding(.bottom, 6)
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
        #if os(tvOS)
        Picker(tr("Section", appLanguage), selection: $section) {
            ForEach(Section.allCases) { Text(tr($0.rawValue, appLanguage)).tag($0) }
        }
        .pickerStyle(.segmented)
        #else
        // A sliding pill instead of the stock segmented control.
        HStack(spacing: 4) {
            ForEach(Section.allCases) { option in
                let selected = section == option
                Button {
                    withAnimation(Theme.snappy) { section = option }
                } label: {
                    Text(tr(option.rawValue, appLanguage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Theme.onAccent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Theme.accent)
                                    .matchedGeometryEffect(id: "pill", in: switcher)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .sensoryFeedback(.selection, trigger: section)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .downloads: DownloadsView()
        case .watchlist: WatchlistSection()
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
                message: tr("Add movies and shows to your Watchlist from their detail pages.", appLanguage))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if os(tvOS)
                .frame(minHeight: 500)   // hosted in a ScrollView: give it room
                #endif
        } else {
            #if os(tvOS)
            LazyVStack(spacing: 8) {
                ForEach(watchlist.items) { item in
                    NavigationLink(value: item.mediaResult) {
                        WatchlistRow(item: item)
                    }
                    .buttonStyle(TVListRowButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            watchlist.remove(id: item.id)
                        } label: {
                            Label(tr("Remove from Watchlist", appLanguage), systemImage: "bookmark.slash")
                        }
                    }
                }
            }
            .focusSection()
            #else
            List {
                ForEach(watchlist.items) { item in
                    NavigationLink(value: item.mediaResult) {
                        WatchlistRow(item: item)
                    }
                    .listRowBackground(Theme.background)
                    .swipeActions {
                        Button(role: .destructive) {
                            watchlist.remove(id: item.id)
                        } label: {
                            Label(tr("Remove", appLanguage), systemImage: "bookmark.slash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            watchlist.remove(id: item.id)
                        } label: {
                            Label(tr("Remove from Watchlist", appLanguage), systemImage: "bookmark.slash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .hideScrollBackground()
            .refreshable { await watchlist.refresh() }
            #endif
        }
    }
}

private struct WatchlistRow: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let item: WatchlistItem
    @Environment(WatchProgressStore.self) private var progress
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #else
    private let isFocused = false
    #endif

    var body: some View {
        HStack(spacing: rowSpacing) {
            PosterImage(url: item.posterURL, cornerRadius: 8)
                .frame(width: posterWidth)
                .overlay(alignment: .topTrailing) {
                    if isWatchedMovie { WatchedBadge(size: 18).padding(4) }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(titleFont)
                    .lineLimit(2)
                Text(statusLine)
                    .font(subtitleFont)
                    .foregroundStyle(isFocused ? Color.black.opacity(0.6) : Color.secondary)
                if let fraction = inProgressFraction {
                    ProgressView(value: fraction)
                        .tint(Theme.accent)
                        .frame(maxWidth: 160)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, rowSpacing / 2)
        .foregroundStyle(isFocused ? Color.black : Color.white)
    }

    private var saved: WatchProgress? { progress.progress(for: item.id) }

    private var isWatchedMovie: Bool { item.mediaType == .movie && saved?.isFinished == true }

    private var inProgressFraction: Double? {
        guard let saved, !saved.isFinished, saved.fraction > 0.01 else { return nil }
        return saved.fraction
    }

    /// Type plus where the viewer is: "Movie, watched", "TV Show, 3 episodes watched".
    private var statusLine: String {
        if isWatchedMovie { return "\(typeLabel), \(tr("watched", appLanguage))" }
        let watched = progress.watchedEpisodes(for: item.id).count
        if item.mediaType != .movie, watched > 0 {
            let epStr = watched == 1 ? tr("episode watched", appLanguage) : tr("episodes watched", appLanguage)
            return "\(typeLabel), \(watched) \(epStr)"
        }
        if let label = saved?.episodeLabel, inProgressFraction != nil { return "\(typeLabel), \(label)" }
        return typeLabel
    }

    private var typeLabel: String {
        switch item.mediaType {
        case .movie: return tr("Movie", appLanguage)
        case .series: return tr("TV Show", appLanguage)
        case .anime: return tr("Anime", appLanguage)
        }
    }

    #if os(tvOS)
    private var posterWidth: CGFloat { 130 }
    private var rowSpacing: CGFloat { 28 }
    private var titleFont: Font { .title3.weight(.semibold) }
    private var subtitleFont: Font { .callout }
    #else
    private var posterWidth: CGFloat { 58 }
    private var rowSpacing: CGFloat { 14 }
    private var titleFont: Font { .subheadline.weight(.semibold) }
    private var subtitleFont: Font { .caption }
    #endif
}