//
//  SearchView.swift
//  MovieStream
//

#if os(iOS)
import SwiftUI

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "Search": "Поиск",
        "Movies, shows and anime": "Фильмы, сериалы и аниме",
        "Clear search": "Очистить поиск",
        "Search movies, shows & anime": "Искать фильмы, сериалы и аниме",
        "Reset Filters": "Сбросить фильтры",
        "Type": "Тип",
        "Feed": "Подборка",
        "Genre": "Жанр",
        "All Genres": "Все жанры",
        "Filters": "Фильтры",
        "Loading": "Загрузка",
        "Nothing found": "Ничего не найдено",
        "Check the spelling, or try the original title.": "Проверьте написание или попробуйте оригинальное название.",
        "Search by name, or browse by type, feed and genre.": "Ищите по названию или фильтруйте по типу, подборке и жанру.",
        
        // Категории и фиды (если они приходят из других файлов)
        "Movie": "Фильмы",
        "Movies": "Фильмы",
        "Series": "Сериалы",
        "TV Show": "Сериалы",
        "TV Shows": "Сериалы",
        "Anime": "Аниме",
        "Popular": "Популярное",
        "Top": "Топ",
        "New": "Новинки"
    ]
    
    // Пытаемся перевести и некоторые популярные жанры, если они совпадают
    let genres: [String: String] = [
        "Action": "Боевик", "Adventure": "Приключения", "Animation": "Анимация",
        "Comedy": "Комедия", "Crime": "Криминал", "Documentary": "Документальный",
        "Drama": "Драма", "Family": "Семейный", "Fantasy": "Фэнтези",
        "History": "История", "Horror": "Ужасы", "Music": "Музыка",
        "Mystery": "Детектив", "Romance": "Мелодрама", "Science Fiction": "Фантастика",
        "Sci-Fi": "Фантастика", "Thriller": "Триллер", "War": "Военный", "Western": "Вестерн"
    ]
    
    return dict[key] ?? genres[key] ?? key
}

struct SearchView: View {
    var body: some View {
        NavigationStack {
            SearchScreen()
                .mediaNavigationDestinations()
                .navigationDestination(for: CatalogDestination.self) { dest in
                    CatalogListView(type: dest.type, feed: dest.feed)
                }
        }
    }
}

struct SearchScreen: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @State private var model = SearchModel()
    @State private var router = TabRouter.shared
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            if Platform.isMac {
                macSearchHeader
            } else {
                phoneHeader
            }
            SearchResults(model: model)
        }
            .toolbar(.hidden, for: .navigationBar)
            .background(Theme.background)
            .statusBarScrim()
            .onAppear { focusIfAsked() }
            .onChange(of: router.focusSearch) { _, _ in focusIfAsked() }
            .onChange(of: model.query) { _, _ in model.run() }
            .onSubmit(of: .search) { model.run(immediate: true) }
            .task { if model.results.isEmpty { model.run() } }
            .onChange(of: settings.streamSourceBases) { _, _ in
                model.applySettings(settings)
                model.run()
            }
    }

    // MARK: - Phone header

    private var phoneHeader: some View {
        VStack(spacing: 10) {
            RootHeader(title: tr("Search", appLanguage)) {
                if !model.isSearching {
                    filterMenu
                        .labelStyle(.iconOnly)
                        .font(.headline.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.hairline))
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField(tr("Movies, shows and anime", appLanguage), text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($macFieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { model.run(immediate: true) }
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Clear search", appLanguage))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(macFieldFocused ? Theme.accent.opacity(0.6) : Theme.hairline))
            .animation(Theme.snappy, value: macFieldFocused)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    /// Home's search button lands here with the keyboard up.
    private func focusIfAsked() {
        guard router.focusSearch else { return }
        router.focusSearch = false
        Task {
            try? await Task.sleep(for: .milliseconds(350))   // after the tab switch settles
            macFieldFocused = true
        }
    }

    // MARK: - Mac header

    @FocusState private var macFieldFocused: Bool

    private var macSearchHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(tr("Search movies, shows & anime", appLanguage), text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($macFieldFocused)
                    .onSubmit { model.run(immediate: true) }
                if !model.query.isEmpty {
                    Button { model.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: 520)

            if !model.isSearching { filterMenu }
            Spacer(minLength: 0)
            if model.isLoading { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .onAppear { macFieldFocused = true }
    }

    // MARK: - Filters

    private var filterMenu: some View {
        Menu {
            if filtersActive {
                Button { resetFilters() } label: {
                    Label(tr("Reset Filters", appLanguage), systemImage: "arrow.counterclockwise")
                }
            }

            Picker(tr("Type", appLanguage), selection: $model.scope) {
                ForEach(SearchModel.Scope.browseScopes) { scope in
                    Text(tr(scope.title, appLanguage)).tag(scope)
                }
            }
            Picker(tr("Feed", appLanguage), selection: $model.feed) {
                ForEach(CatalogFeed.allCases) { feed in
                    Text(tr(feed.title, appLanguage)).tag(feed)
                }
            }
            Picker(tr("Genre", appLanguage), selection: $model.genre) {
                Text(tr("All Genres", appLanguage)).tag(String?.none)
                ForEach(MediaGenre.shared, id: \.self) { genre in
                    Text(tr(genre, appLanguage)).tag(String?.some(genre))
                }
            }
        } label: {
            Label(tr("Filters", appLanguage), systemImage: filtersActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .tint(filtersActive ? Theme.accent : .white)
        .onChange(of: model.scope) { _, _ in model.run() }
        .onChange(of: model.feed) { _, _ in model.run() }
        .onChange(of: model.genre) { _, _ in model.run() }
    }

    private var filtersActive: Bool {
        model.feed != .popular || model.genre != nil
    }

    private func resetFilters() {
        model.feed = .popular
        model.genre = nil
        model.run()
    }
}

struct SearchResults: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let model: SearchModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    // Создаем собственные колонки вместо PosterMetrics, чтобы на iPhone их всегда было две
    private var columns: [GridItem] {
        if sizeClass == .compact {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        } else {
            return [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)]
        }
    }

    @ViewBuilder
    var body: some View {
        if model.isLoading && model.results.isEmpty {
            placeholderGrid
        } else if model.results.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass",
                           title: model.isSearching ? tr("Nothing found", appLanguage) : tr("Search", appLanguage),
                           message: model.errorMessage ?? (model.isSearching
                               ? tr("Check the spelling, or try the original title.", appLanguage)
                               : tr("Search by name, or browse by type, feed and genre.", appLanguage)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            grid
        }
    }

    /// Poster-shaped placeholders while the first page loads.
    private var placeholderGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous)
                        .fill(Theme.surface)
                        .aspectRatio(Theme.posterAspect, contentMode: .fit)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollDisabled(true)
        .accessibilityLabel(tr("Loading", appLanguage))
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(model.results) { item in
                    PosterLink(item: item) {
                        PosterCard(item: item)
                    }
                    .onAppear { model.loadMoreIfNeeded(after: item) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            if model.isLoadingMore {
                ProgressView()
                    .tint(Theme.accent)
                    .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if model.isLoading {
                ProgressView()
                    .tint(Theme.accent)
                    .controlSize(.large)
                    .padding(22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.isLoading)
    }
}
#endif