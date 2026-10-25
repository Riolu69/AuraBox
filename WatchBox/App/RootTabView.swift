//
//  RootTabView.swift
//  SceneBox
//

import SwiftUI

enum AppTab: String, Hashable {
    case home, search, library, profile

    static var initial: AppTab {
        UserDefaults.standard.string(forKey: "SBInitialTab").flatMap(AppTab.init(rawValue:)) ?? .home
    }
}

// MARK: - Мини-переводчик (Словарь)
enum L {
    static func text(_ key: String, lang: String) -> String {
        let ruDict: [String: String] = [
            "Home": "Главная",
            "Search": "Поиск",
            "Library": "Медиатека",
            "Profile": "Профиль",
            "Done": "Готово"
        ]
        // Если выбран русский — берем из словаря. Иначе — оставляем английский.
        return lang == "ru" ? (ruDict[key] ?? key) : key
    }
}

struct RootTabView: View {
    // Эта переменная хранит язык и заставляет экран обновиться при переключении
    @AppStorage("appLanguage") private var appLanguage = "ru" 
    
    @State private var router = TabRouter.shared
    @State private var settings = AppSettings.shared
    @State private var downloads = DownloadStore.shared
    @State private var watchProgress = WatchProgressStore.shared
    @State private var watchlist = WatchlistStore.shared
    
    // НОВОЕ: Переменная для "Буду смотреть"
    @State private var planStore = PlanToWatchStore.shared
    
    @Environment(ProfileStore.self) private var profiles
    @State private var profileIcon: UIImage?
    #if os(iOS)
    @State private var detailItem: MediaResult?
    @State private var links = DeepLinkRouter.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        TabView(selection: $router.tab) {
            #if os(tvOS)
            Tab(LocalizedStringKey(L.text("Home", lang: appLanguage)), systemImage: "house.fill", value: AppTab.home) {
                TVHomeView()
            }
            Tab(LocalizedStringKey(L.text("Search", lang: appLanguage)), systemImage: "magnifyingglass", value: AppTab.search) {
                TVSearchView()
            }
            #else
            Tab(LocalizedStringKey(L.text("Home", lang: appLanguage)), systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab(LocalizedStringKey(L.text("Search", lang: appLanguage)), systemImage: "magnifyingglass", value: AppTab.search) {
                SearchView()
            }
            #endif

            Tab(LocalizedStringKey(L.text("Library", lang: appLanguage)), systemImage: "books.vertical", value: AppTab.library) {
                LibraryView()
            }
            #if !os(tvOS)
            .badge(downloads.activeCount)
            #endif

            #if os(tvOS)
            Tab(LocalizedStringKey(L.text("Profile", lang: appLanguage)), systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView()
            }
            #else
            Tab(value: AppTab.profile) {
                ProfileView()
            } label: {
                Label {
                    Text(L.text("Profile", lang: appLanguage))
                } icon: {
                    if let profileIcon {
                        Image(uiImage: profileIcon).renderingMode(.original)
                    } else {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            #endif
        }
        .task(id: profiles.selected) {
            guard let profile = profiles.selected else { profileIcon = nil; return }
            profileIcon = await ProfileTabIcon.make(for: profile)
        }
        .tint(settings.accentColor)
        .environment(settings)
        .environment(downloads)
        .environment(watchProgress)
        .environment(watchlist)
        
        // НОВОЕ: Передаем хранилище вкладок вниз по иерархии
        .environment(planStore) 
        
        .sensoryFeedback(.selection, trigger: router.tab)
        #if os(iOS)
        .environment(\.openMediaDetail, sizeClass == .regular && !Platform.isMac ? { detailItem = $0 } : nil)
        .onChange(of: links.pendingDetail) { _, item in
            guard let item else { return }
            links.pendingDetail = nil
            detailItem = item
        }
        .sheet(item: $detailItem) { item in
            NavigationStack {
                MediaDetailView(mediaID: item.id, type: item.type, fallbackTitle: item.name)
                    .mediaNavigationDestinations()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L.text("Done", lang: appLanguage)) { detailItem = nil }
                        }
                    }
            }
            .environment(settings)
            .environment(downloads)
            .environment(watchProgress)
            .environment(watchlist)
            
            // НОВОЕ: Передаем хранилище для всплывающих карточек фильмов на iPad/Mac
            .environment(planStore)
            
            .environment(\.openMediaDetail, nil)
        }
        #endif
    }
}
