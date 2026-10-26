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

    var body: some View {
        NavigationStack {
            Group {
                if let message = model.errorMessage, model.shelves.isEmpty, !model.isLoading {
                    VStack(spacing: 0) {
                        header
                        EmptyStateView(systemImage: "wifi.exclamationmark", title: "Couldn’t load titles",
                                       message: message, actionTitle: "Try again") { model.reload() }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    feed
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .statusBarScrim()
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Aura")
                .font(.display(40, weight: .black))
                .foregroundStyle(Theme.brandGradient)
                .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 4)

            Spacer()

            HeaderIconButton(systemImage: "magnifyingglass", label: "Search") {
                TabRouter.shared.openSearch()
            }
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Platform.isMac ? 38 : 32) {
                    header

                    if !featured.isEmpty {
                        FeaturedMarquee(items: featured)
                    }
                    if !progress.continueItems.isEmpty {
                        ContinueWatchingShelf(items: progress.continueItems)
                    }
                    if !unwatchedWatchlist.isEmpty {
                        PosterShelf(title: "Your Watchlist", items: unwatchedWatchlist, accent: .pink)
                    }
                    if let because = model.becauseYouWatched {
                        PosterShelf(title: because.title, items: because.items,
                                    seeAll: because.destination, accent: .cyan)
                    }

                    if model.shelves.isEmpty {
                        // Placeholders keep the layout still while the catalog loads.
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
            .refreshable {
                progress.refresh()
                async let catalog: () = model.refresh()
                async let saved: () = watchlist.refresh()
                _ = await (catalog, saved)
            }
            .onChange(of: model.shelves.isEmpty) { _, empty in
                // -SBHomeRow series-top opens Home at that row (screenshots, debugging).
                if !empty, let row = UserDefaults.standard.string(forKey: "SBHomeRow") {
                    proxy.scrollTo(row, anchor: .top)
                }
            }
        }
    }

    /// Популярные фильмы и сериалы, чередуются для маркиза.
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

// MARK: - Theme helpers

private extension Theme {
    /// Яркий градиент для логотипа и акцентов.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [.pink, .purple, Theme.accent], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Marquee

/// Верхняя лента: широкие бэкдропы с логотипом, листается по одной карточке.
private struct FeaturedMarquee: View {
    let items: [MediaResult]
    @State private var current: String?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        PosterLink(item: item) {
                            FeaturedCard(item: item)
                        }
                        .overlay(alignment: .topTrailing) { FeaturedWatchlistButton(item: item) }
                        .containerRelativeFrame(.horizontal) { width, _ in
                            sizeClass == .regular ? min(width * 0.62, 760) : width - 40
                        }
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.92)
                                .rotation3DEffect(.degrees(phase.isIdentity || reduceMotion ? 0 : phase.value * 8),
                                                  axis: (x: 0, y: 1, z: 0))
                                .opacity(phase.isIdentity ? 1 : 0.5)
                        }
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 12)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: current)

            if items.count > 1 {
                PageDots(count: items.count,
                         index: items.firstIndex { $0.id == (current ?? items.first?.id) } ?? 0)
            }
        }
    }
}

private struct FeaturedCard: View {
    let item: MediaResult
[26.10.2026 18:19] Николай Племянник: var body: some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .background {
                KFImage(item.backdropURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 1200, height: 900)))
                    .cacheOriginalImage()
                    .cancelOnDisappear(true)
                    .fade(duration: 0.3)
                    .placeholder { Theme.surface }
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                // Цветной градиент поверх картинки вместо серого затемнения.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.2),
                    .init(color: .purple.opacity(0.35), location: 0.6),
                    .init(color: .black.opacity(0.9), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .purple.opacity(0.35), radius: 18, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.name)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let logo = item.logoURL {
                KFImage(logo)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 600, height: 240)))
                    .cancelOnDisappear(true)
                    .placeholder { titleText }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 80, alignment: .bottomLeading)
                    .shadow(color: .black.opacity(0.5), radius: 8)
            } else {
                titleText
            }

            HStack(spacing: 8) {
                if let year = item.year {
                    chip(year, tint: .white.opacity(0.2))
                }
                if let rating = item.imdbRating, !rating.isEmpty {
                    Label(rating, systemImage: "star.fill")
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.yellow, in: Capsule())
                        .foregroundStyle(.black)
                }
                if !item.genres.isEmpty {
                    chip(item.genres.prefix(2).joined(separator: " • "), tint: .pink.opacity(0.6))
                }
            }
        }
        .padding(20)
    }

    private var titleText: some View {
        Text(item.name)
            .font(.display(36, weight: .black))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }
}

/// Лежит поверх карточки (не внутри ссылки), чтобы тап доходил до кнопки.
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
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(saved ? .black : .white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 42, height: 42)
                .background {
                    if saved {
                        Circle().fill(LinearGradient(colors: [.yellow, .orange],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: saved ? .orange.opacity(0.5) : .black.opacity(0.15), radius: 8, y: 3)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: saved)
        .padding(14)
        .accessibilityLabel(saved ? "Remove from Watchlist" : "Add to Watchlist")
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index
                          ? AnyShapeStyle(LinearGradient(colors: [.pink, Theme.accent],
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.white.opacity(0.22)))
                    .frame(width: i == index ? 22 : 6, height: 6)
            }
        }
        .animation(Theme.snappy, value: index)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Shelves

private struct PosterShelf: View {
    let title: String
    let items: [MediaResult]
    var seeAll: CatalogDestination?
    var ranked = false
    var accent: Color = Theme.accent
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                // Яркая полоска слева от заголовка.
                Capsule()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.3)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: 22)

                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if let seeAll {
                    NavigationLink(value: seeAll) {
                        Text("See all")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(accent.opacity(0.9), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 16)

            HorizontalShelfScroller {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PosterLink(item: item) {
                            if ranked {
                                RankedCard(rank: index + 1, item: item, width: PosterMetrics.shelfWidth(sizeClass))
                            } else {
                                PosterCard(item: item)
                                    .frame(width: PosterMetrics.shelfWidth(sizeClass))
                                    .shadow(color: accent.opacity(0.25), radius: 12, y: 6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}
[26.10.2026 18:19] Николай Племянник: /// "Top 10": градиентная цифра, наполовину заходящая на постер.
private struct RankedCard: View {
    let rank: Int
    let item: MediaResult
    let width: CGFloat

    var body: some View {
        let size = width * 1.7
        let metrics = UIFont.systemFont(ofSize: size, weight: .black)
        HStack(alignment: .bottom, spacing: -width * 0.18) {
            Text(String(rank))   // Арабские цифры во всех локалях, как на постерах.
                .font(.display(size, weight: .black))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .purple, Theme.accent.opacity(0.6)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .purple.opacity(0.5), radius: 10, y: 4)
                .fixedSize()
                .padding(.top, metrics.capHeight - metrics.ascender)
                .padding(.bottom, metrics.descender)
            PosterCard(item: item)
                .frame(width: width)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: -3, y: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(rank), \(item.name)")
    }
}

private struct PlaceholderShelf: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.surface)
                .frame(width: 180, height: 24)
                .padding(.horizontal, 16)
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0.5)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: PosterMetrics.shelfWidth(sizeClass))
                        .aspectRatio(Theme.posterAspect, contentMode: .fit)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

#endif
