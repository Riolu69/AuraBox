//
//  LibraryView.swift
//  Aura
//

import SwiftUI
import Kingfisher

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
        "Remove from Watchlist": "Удалить из Избранного",
        "Remove from Plan to Watch": "Удалить из планов",
        "Remove from History": "Удалить из истории"
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
                    
                    // Контент занимает всё свободное место (для центрирования пустых экранов)
                    content
                        .frame(maxHeight: .infinity)
                }
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    // НОВОЕ МЕНЮ В 2 РЯДА
    @ViewBuilder
    private var sectionPicker: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Section.allCases) { option in
                let isSelected = section == option
                
                Button {
                    withAnimation(.snappy) {
                        section = option
                    }
                } label: {
                    Text(tr(option.rawValue, appLanguage))
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8) // Слегка сожмет текст, если не влезет
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        // Подсветка активной кнопки
                        .background(isSelected ? Theme.surface : Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
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
            EmptyStateView(systemImage: "bookmark", title: tr("No saved titles", appLanguage), message: tr("Add movies and shows to your Watchlist from their detail pages.", appLanguage))
                .frame(maxHeight: .infinity)
        } else {
            MediaGridView(items: watchlist.items.map { MediaGridItem(id: $0.id, title: $0.title, poster: $0.posterURLString, type: $0.mediaType) })
        }
    }
}

private struct HistorySection: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(WatchProgressStore.self) private var progressStore

    var body: some View {
        if progressStore.items.isEmpty {
            EmptyStateView(systemImage: "clock.arrow.circlepath", title: tr("No history yet", appLanguage), message: tr("Titles you watch will appear here.", appLanguage))
                .frame(maxHeight: .infinity)
        } else {
            MediaGridView(items: progressStore.items.map { MediaGridItem(id: $0.id, title: $0.title, poster: $0.posterURLString, type: $0.mediaType) })
        }
    }
}

private struct PlanToWatchSection: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(PlanToWatchStore.self) private var planStore

    var body: some View {
        if planStore.items.isEmpty {
            EmptyStateView(systemImage: "calendar.badge.clock", title: tr("Nothing planned", appLanguage), message: tr("Add titles you want to watch later.", appLanguage))
                .frame(maxHeight: .infinity)
        } else {
            MediaGridView(items: planStore.items.map { MediaGridItem(id: $0.id, title: $0.title, poster: $0.posterURLString, type: $0.mediaType) })
        }
    }
}

private struct MediaGridItem: Identifiable {
    let id: String
    let title: String
    let poster: String?
    let type: MediaType
    
    var result: MediaResult {
        MediaResult(id: id, type: type, name: title, year: nil, posterURL: poster.flatMap(URL.init(string:)), description: nil)
    }
}

private struct MediaGridView: View {
    let items: [MediaGridItem]
    
    // АДАПТИВНАЯ СЕТКА ПОСТЕРОВ (как в поиске)
    #if os(tvOS)
    let columns = [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)]
    #else
    let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 16)
    ]
    #endif

    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(WatchlistStore.self) private var watchlist
    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(PlanToWatchStore.self) private var planStore

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item.result) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let posterString = item.poster, let url = URL(string: posterString) {
                                KFImage(url)
                                    .resizable()
                                    .placeholder { Theme.surface }
                                    .aspectRatio(2/3, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface)
                                    .aspectRatio(2/3, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .overlay(Text(item.title).font(.caption).multilineTextAlignment(.center).padding())
                            }
                            Text(item.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if watchlist.contains(item.id) {
                            Button(role: .destructive) {
                                watchlist.remove(id: item.id)
                            } label: {
                                Label(tr("Remove from Watchlist", appLanguage), systemImage: "bookmark.slash")
                            }
                        }
                        if planStore.contains(item.id) {
                            Button(role: .destructive) {
                                planStore.remove(id: item.id)
                            } label: {
                                Label(tr("Remove from Plan to Watch", appLanguage), systemImage: "calendar.badge.minus")
                            }
                        }
                        if progressStore.progress(for: item.id) != nil {
                            Button(role: .destructive) {
                                progressStore.remove(id: item.id)
                            } label: {
                                Label(tr("Remove from History", appLanguage), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
