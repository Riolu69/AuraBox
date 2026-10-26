//
//  HomeView.swift
//  Aura
//

#if os(iOS)
import SwiftUI
import Kingfisher

struct HomeView: View {
    @State private var model = HomeModel()
    @Environment(AppSettings.self) private var settings
    @Environment(WatchProgressStore.self) private var progress
    @Environment(WatchlistStore.self) private var watchlist
    
    // Состояние для отслеживания скролла (чтобы плавно показывать размытие под хедером)
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.background.ignoresSafeArea()
                
                if let message = model.errorMessage, model.shelves.isEmpty, !model.isLoading {
                    VStack(spacing: 0) {
                        header.padding(.top, 50)
                        EmptyStateView(systemImage: "wifi.exclamationmark", title: "Couldn’t load titles",
                                       message: message, actionTitle: "Try again") { model.reload() }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    feed
                }
                
                // Фиксированный парящий хедер сверху с эффектом матового стекла
                floatingHeader
            }
            .toolbar(.hidden, for: .navigationBar)
            .mediaNavigationDestinations()
            .navigationDestination(for: CatalogDestination.self) { dest in
                CatalogListView(type: dest.type, feed: dest.feed, genre: dest.genre)
            }
        }
        .task { model.loadIfNeeded() }
        .onAppear { progress.refresh() }
        .onChange(of: progress.items.first?.id, initial: true) { _, _ in
            model.loadBecauseYouWatched(progress.items.first)
        }
        .onChange(of: settings.streamSourceBases) { _, _ in
            model.applySettings(settings)
        }
    }

    // Стандартный хедер для плейсхолдера ошибки
    private var header: some View {
        RootHeader(title: "Aura") {
            HeaderIconButton(systemImage: "magnifyingglass", label: "Search") {
                TabRouter.shared.openSearch()
            }
        }
    }
    
    // Парящий хедер с динамическим размытием
    private var floatingHeader: some View {
        VStack(spacing: 0) {
            RootHeader(title: "Aura") {
                HeaderIconButton(systemImage: "magnifyingglass", label: "Search") {
                    TabRouter.shared.openSearch()
                }
            }
            .padding(.horizontal, 4)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(scrollOffset > 30 ? 1 : 0)
                .ignoresSafeArea(edges: .top)
                .shadow(color: .black.opacity(scrollOffset > 30 ? 0.15 : 0), radius: 4, y: 2)
        }
        .animation(.easeInOut(duration: 0.2), value: scrollOffset > 30)
    }

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Невидимый трекер скролла для определения смещения
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetKey.self, value: -geo.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)
                
                LazyVStack(alignment: .leading, spacing: Platform.isMac ? 34 : 28) {
                    if !featured.isEmpty {
                        // Карусель новинок с учетом верхнего отступа под хедер
                        FeaturedMarquee(items: featured)
                            .padding(.top, 60) // Запас под шапку приложения
                            .padding(.bottom, 12)
                    } else {
                        Color.clear.frame(height: 100)
                    }
                    
                    if !progress.continueItems.isEmpty {
                        ContinueWatchingShelf(items: progress.continueItems)
                    }
                    if !unwatchedWatchlist.isEmpty {
                        PosterShelf(title: "Your Watchlist", items: unwatchedWatchlist)
                    }
                    if let because = model.becauseYouWatched {
                        PosterShelf(title: because.title, items: because.items, seeAll: because.destination)
                    }
                    if model.shelves.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in PlaceholderShelf() }
                    } else {
                        ForEach(model.shelves) { shelf in
                            PosterShelf(title: shelf.title, items: shelf.shown,
                                        seeAll: shelf.destination, ranked: shelf.isRanked)
                                .id(shelf.id)
                        }
                        ForEach(model.genreShelves) { shelf in
                            if shelf.items.isEmpty {
                                PlaceholderShelf().task { model.loadGenreShelf(shelf.id) }
                            } else {
                                PosterShelf(title: shelf.title, items: shelf.items, seeAll: shelf.destination)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            .refreshable {
                progress.refresh()
                async let catalog: () = model.refresh()
                async let saved: () = watchlist.refresh()
                _ = await (catalog, saved)
            }
            .onChange(of: model.shelves.isEmpty) { _, empty in
                if !empty, let row = UserDefaults.standard.string(forKey: "SBHomeRow") {
                    proxy.scrollTo(row, anchor: .top)
                }
            }
        }
    }

    private var featured: [MediaResult] {
        let pools = model.shelves.filter(\.isRanked).map { shelf in
            Array(shelf.items.filter { $0.backdropURL != nil }.prefix(3))
        }
        var picks: [MediaResult] = []
        for index in 0..<3 {
            for pool in pools where index < pool.count {
                picks.append(pool[index])
            }
        }
        return picks
    }

    private var unwatchedWatchlist: [MediaResult] {
        watchlist.items
            .filter { progress.progress(for: $0.id) == nil }
            .map(\.mediaResult)
    }
}

// Утилита для отслеживания скролла
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Marquee (Полноэкранный баннер)

private struct FeaturedMarquee: View {
    let items: [MediaResult]
    @State private var current: String?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(items) { item in
                        PosterLink(item: item) {
                            FeaturedCard(item: item)
                        }
                        .overlay(alignment: .topTrailing) {
                            FeaturedWatchlistButton(item: item)
                                .padding(.top, 16)
                                .padding(.trailing, 20)
                        }
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.4)
                                .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.98)
                        }
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)

            if items.count > 1 {
                PageDots(count: items.count,
                         index: items.firstIndex { $0.id == (current ?? items.first?.id) } ?? 0)
                    .padding(.horizontal, 20)
            }
        }
    }
}

private struct FeaturedCard: View {
    let item: MediaResult

    var body: some View {
        Color.clear
            .aspectRatio(1.35, contentMode: .fit) // Сбалансированный кинематографичный формат баннера
            .background {
                KFImage(item.backdropURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 1200, height: 900)))
                    .cacheOriginalImage()
                    .cancelOnDisappear(true)
                    .fade(duration: 0.4)
                    .placeholder { Theme.surface }
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(stops: [
                    .init(color: Theme.background.opacity(0), location: 0.3),
                    .init(color: Theme.background.opacity(0.7), location: 0.75),
                    .init(color: Theme.background, location: 1.0)
                ], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { caption }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.name)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let logo = item.logoURL {
                KFImage(logo)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 600, height: 240)))
                    .cancelOnDisappear(true)
                    .placeholder { titleText }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 75, alignment: .bottomLeading)
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 3)
            } else {
                titleText
            }
            
            HStack(spacing: 12) {
                if let year = item.year {
                    Text(year)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                if let rating = item.imdbRating, !rating.isEmpty {
                    Label(rating, systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if !item.genres.isEmpty {
                    Text(item.genres.prefix(2).joined(separator: " • "))
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var titleText: some View {
        Text(item.name)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
    }
}

private struct FeaturedWatchlistButton: View {
    let item: MediaResult
    @Environment(WatchlistStore.self) private var watchlist

    var body: some View {
        let saved = watchlist.contains(item.id)
        Button {
            withAnimation(Theme.snappy) {
                watchlist.toggle(id: item.id, mediaType: item.type, title: item.name, posterURL: item.posterURL)
            }
        } label: {
            Image(systemName: saved ? "checkmark" : "plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .background(saved ? Theme.accent : Color.black.opacity(0.4), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: saved)
        .accessibilityLabel(saved ? "Remove from Watchlist" : "Add to Watchlist")
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Theme.accent : Color.gray.opacity(0.4))
                    .frame(width: i == index ? 8 : 6, height: i == index ? 8 : 6)
            }
        }
        .animation(Theme.snappy, value: index)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shelves

private struct PosterShelf: View {
    let title: String
    let items: [MediaResult]
    var seeAll: CatalogDestination?
    var ranked = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: Platform.isMac ? 14 : 12) {
            SectionHeader(title: title) {
                if let seeAll {
                    NavigationLink(value: seeAll) {
                        Text("See all")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 20)

            HorizontalShelfScroller {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PosterLink(item: item) {
                            if ranked {
                                RankedCard(rank: index + 1, item: item, width: PosterMetrics.shelfWidth(sizeClass))
                            } else {
                                PosterCard(item: item).frame(width: PosterMetrics.shelfWidth(sizeClass))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct RankedCard: View {
    let rank: Int
    let item: MediaResult
    let width: CGFloat

    var body: some View {
        let size = width * 1.7
        let metrics = UIFont.systemFont(ofSize: size, weight: .black)
        HStack(alignment: .bottom, spacing: -width * 0.16) {
            Text(String(rank))
                .font(.display(size, weight: .black))
                .foregroundStyle(.linearGradient(colors: [.primary.opacity(0.9), .primary.opacity(0.2)],
                                               startPoint: .top, endPoint: .bottom))
                .fixedSize()
                .padding(.top, metrics.capHeight - metrics.ascender)
                .padding(.bottom, metrics.descender)
            PosterCard(item: item)
                .frame(width: width)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: -4, y: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(rank), \(item.name)")
    }
}

private struct PlaceholderShelf: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.surface)
                .frame(width: 170, height: 22)
                .padding(.horizontal, 20)
            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous)
                        .fill(Theme.surface)
                        .frame(width: PosterMetrics.shelfWidth(sizeClass))
                        .aspectRatio(Theme.posterAspect, contentMode: .fit)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

#endif
