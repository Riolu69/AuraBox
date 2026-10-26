//
//  MediaDetailView.swift
//  Aura
//
//  Created by Riolu.
//

import SwiftUI
import Kingfisher

struct MediaDetailView: View {
    let mediaID: String
    let type: MediaType
    let fallbackTitle: String

    @State private var model: MediaDetailModel
    @State private var streamer = StreamCoordinator()
    @State private var pendingPlay: (() -> Void)?
    @State private var isAutoResolving = false
    @State private var batchStatus: String?
    @State private var batchMessage: String?
    @State private var toast: ToastMessage?
    @State private var resumeAt: Duration = .zero
    @Environment(DownloadStore.self) private var downloads
    @Environment(AppSettings.self) private var settings
    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(WatchlistStore.self) private var watchlist
    @Environment(PlanToWatchStore.self) private var planStore
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    init(mediaID: String, type: MediaType, fallbackTitle: String) {
        self.mediaID = mediaID
        self.type = type
        self.fallbackTitle = fallbackTitle
        _model = State(initialValue: MediaDetailModel(mediaID: mediaID, type: type))
    }

    var body: some View {
        content
            .animation(.smooth(duration: 0.35), value: model.isReady)
            .toast(\$toast)
            .overlay { if isAutoResolving || batchStatus != nil { resolvingOverlay } }
            .alert("Some episodes weren't added",
                   isPresented: Binding(get: { batchMessage != nil }, set: { if !\$0 { batchMessage = nil } })) {
                Button("OK", role: .cancel) { batchMessage = nil }
            } message: {
                Text(batchMessage ?? "")
            }
            .background(Theme.background)
            #if os(iOS)
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(Platform.isMac ? .hidden : .automatic, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                if Platform.isMac {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(Theme.surface.opacity(0.8), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(16)
                    .accessibilityLabel("Back")
                }
            }
            #else
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationTitle(Platform.isMac ? displayTitle : "")
            .inlineNavigationBar()
            #if os(iOS)
            .onChange(of: displayTitle, initial: true) { _, title in MacWindow.setTitle(title) }
            .onDisappear { MacWindow.setTitle("") }
            #endif
            .task { model.load() }
            .onDisappear {
                if !streamer.isPresenting { streamer.stop() }
            }
            #if os(tvOS)
            .fullScreenCover(item: releaseRequestBinding, onDismiss: runPendingPlay) { request in
                ReleasePickerView(model: model, request: request) { stream in
                    handle(request: request, stream: stream)
                }
                .environment(settings)
                .environment(downloads)
                .environment(progressStore)
                .environment(watchlist)
            }
            #else
            .sheet(item: releaseRequestBinding, onDismiss: runPendingPlay) { request in
                ReleasePickerView(model: model, request: request) { stream in
                    handle(request: request, stream: stream)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
                .environment(settings)
                .environment(downloads)
                .environment(progressStore)
                .environment(watchlist)
            }
            #endif
            .fullScreenCover(isPresented: Binding(get: { streamer.isPresenting },
                                                  set: { if !\$0 { streamer.stop() } })) {
                StreamPlayerContainer(streamer: streamer)
                    .environment(settings)
                    .environment(downloads)
                    .environment(progressStore)
                    .environment(watchlist)
            }
    }

    private var displayTitle: String {
        if let name = model.detail?.name, !name.isEmpty { return name }
        return fallbackTitle
    }

    private var releaseRequestBinding: Binding<MediaDetailModel.ReleaseRequest?> {
        Binding(get: { model.releaseRequest },
                set: { if \$0 == nil { model.dismissReleases() } })
    }

    private func runPendingPlay() {
        let action = pendingPlay
        pendingPlay = nil
        action?()
    }

    private var resolvingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text(batchStatus ?? "Finding best source…")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isReady, let detail = model.detail {
            #if os(tvOS)
            TVDetailView(
                detail: detail,
                fallbackTitle: fallbackTitle,
                isBusy: streamer.isPreparing,
                cast: model.castMembers,
                selectedSeason: Binding(get: { model.selectedSeason },
                                        set: { model.selectedSeason = \$0 }),
                resumeEpisode: resumeEpisode(for: detail),
                watchLabel: resumeLabel(for: detail),
                watchProgress: watchProgressFraction(for: detail),
                watchedEpisodes: progressStore.watchedEpisodes(for: mediaID),
                similar: model.similar,
                onWatch: { watch(episode: \$0) },
                onDownload: { requestDownload(episode: \$0) },
                onSetWatched: { setWatched(\$1, episode: \$0, detail: detail) }
            )
            #else
            detailScroll(detail)
                .transition(.opacity)
            #endif
        } else if model.detail == nil, let message = model.errorMessage {
            EmptyStateView(systemImage: "wifi.exclamationmark",
                           title: "Couldn’t load this title", message: message,
                           actionTitle: "Try again") { model.load() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .tint(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
        }
    }

    private func detailScroll(_ detail: MediaDetail) -> some View {
        ZStack {
            if Platform.isMac {
                GeometryReader { proxy in
                    KFImage(detail.backdropURL)
                        .resizable()
                        .fade(duration: 0.3)
                        .placeholder { Theme.surface }
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay {
                            ZStack {
                                Color.black.opacity(0.45)
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .clear, location: 0.35),
                                        .init(color: Theme.background.opacity(0.85), location: 0.75),
                                        .init(color: Theme.background, location: 1.0),
                                    ],
                                    startPoint: .top, endPoint: .bottom)
                            }
                        }
                }
                .ignoresSafeArea()
            }
            detailScrollContent(detail)
        }
    }

    private func detailScrollContent(_ detail: MediaDetail) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                BannerHeader(detail: detail, fallbackTitle: fallbackTitle)

                actions(for: detail)
                metadata(for: detail)
                if let synopsis = detail.description, !synopsis.isEmpty {
                    Section("Synopsis") { Text(synopsis).font(.callout) }
                }
                if !model.castMembers.isEmpty || !detail.cast.isEmpty {
                    CastRow(members: model.castMembers, names: detail.cast)
                }
                crew(for: detail)
                if detail.type == .series, !detail.seasons.isEmpty {
                    EpisodeSection(
                        detail: detail,
                        selectedSeason: Binding(
                            get: { model.selectedSeason },
                            set: { model.selectedSeason = \$0 }),
                        watchedEpisodes: progressStore.watchedEpisodes(for: mediaID),
                        episodeFraction: { progressStore.episodeFraction(mediaID: mediaID, episodeID: \$0.id) },
                        onWatch: { watch(episode: \$0) },
                        onDownload: { requestDownload(episode: \$0) },
                        onDownloadEpisodes: { downloadEpisodes(\$0) },
                        onSetWatched: { setWatched(\$1, episode: \$0, detail: detail) }
                    )
                }
                moreLikeThis
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - ИСПРАВЛЕННЫЙ БЛОК КНОПОК
    private func actions(for detail: MediaDetail) -> some View {
        let watchFraction = watchProgressFraction(for: detail)
        
        return VStack(spacing: 16) {
            // ШИРОКАЯ КНОПКА PLAY
            Button {
                watch(episode: resumeEpisode(for: detail))
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(resumeLabel(for: detail) ?? "Watch")
                            .lineLimit(1)
                        if isWatchTargetDownloaded(for: detail) {
                            Image(systemName: "arrow.down.circle.fill").font(.caption)
                        }
                    }
                    if let watchFraction {
                        WatchProgressBar(fraction: watchFraction)
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                            .padding(.horizontal, 4)
                    }
                }
                .font(.headline)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .clipShape(Capsule())

            // ОСТАЛЬНЫЕ КНОПКИ (Отцентрованные)
            HStack(spacing: 16) {
                if detail.type == .series {
                    Menu {
                        if let episode = firstEpisode(of: detail) {
                            Button {
                                requestDownload(episode: episode)
                            } label: {
                                Label("Download \(episode.label)", systemImage: "arrow.down.circle")
                            }
                        }
                        let season = detail.episodes(inSeason: model.selectedSeason)
                        Button {
                            downloadEpisodes(season)
                        } label: {
                            Label(model.selectedSeason == 0 ? "Download All Specials" : "Download Season \(model.selectedSeason)",
                                  systemImage: "square.and.arrow.down.on.square")
                        }
                        .disabled(season.isEmpty)
                    } label: {
                        secondaryButtonLabel(icon: "arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .clipShape(Circle())
                } else {
                    let isDownloaded = downloads.isDownloaded(mediaID: mediaID)
                    Button {
                        requestDownload(episode: firstEpisode(of: detail))
                    } label: {
                        secondaryButtonLabel(icon: isDownloaded ? "arrow.down.circle.fill" : "arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .tint(isDownloaded ? Theme.success : .primary)
                    .clipShape(Circle())
                }

                // Избранное
                Button {
                    watchlist.toggle(id: mediaID, mediaType: type,
                                     title: detail.name.isEmpty ? fallbackTitle : detail.name,
                                     posterURL: detail.posterURL)
                } label: {
                    secondaryButtonLabel(icon: isInWatchlist ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)
                .tint(isInWatchlist ? Theme.accent : .primary)
                .clipShape(Circle())
                .sensoryFeedback(.selection, trigger: isInWatchlist)
                
                // Буду смотреть
                let isPlanned = planStore.contains(mediaID)
                Button {
                    planStore.toggle(id: mediaID, mediaType: type,
                                     title: detail.name.isEmpty ? fallbackTitle : detail.name,
                                     posterURL: detail.posterURL)
                    toast = ToastMessage(text: isPlanned ? "Удалено из планов" : "Добавлено в Буду смотреть",
                                         systemImage: isPlanned ? "calendar.badge.minus" : "calendar.badge.plus")
                } label: {
                    secondaryButtonLabel(icon: isPlanned ? "calendar.badge.clock" : "calendar")
                }
                .buttonStyle(.bordered)
                .tint(isPlanned ? Theme.accent : .primary)
                .clipShape(Circle())
                .sensoryFeedback(.selection, trigger: isPlanned)

                // Просмотрено
                if detail.type == .movie {
                    let watched = progressStore.isMovieWatched(mediaID)
                    Button {
                        progressStore.setMovieWatched(!watched, id: mediaID,
                                                      title: detail.name.isEmpty ? fallbackTitle : detail.name,
                                                      posterURL: detail.posterURL)
                        toast = ToastMessage(text: watched ? "Marked as unwatched" : "Marked as watched",
                                             systemImage: watched ? "eye.slash" : "checkmark.circle.fill")
                    } label: {
                        secondaryButtonLabel(icon: watched ? "checkmark.circle.fill" : "checkmark")
                    }
                    .buttonStyle(.bordered)
                    .tint(watched ? Theme.accent : .primary)
                    .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .center) // <- ВОТ ОНО! Центрирует круглые кнопки
        }
        .frame(maxWidth: Platform.isMac ? 480 : .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .disabled(streamer.isPreparing || isAutoResolving || batchStatus != nil)
    }

    // Хелпер для ровных круглых кнопок
    private func secondaryButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.title2)
            .frame(width: 24, height: 24)
            .padding(10)
    }

    private var isInWatchlist: Bool { watchlist.contains(mediaID) }

    private func firstEpisode(of detail: MediaDetail) -> Episode? {
        guard detail.type == .series else { return nil }
        return detail.episodes(inSeason: model.selectedSeason).first
    }

    // MARK: - Watch / Download

    private func watch(episode: Episode?) {
        resumeAt = startPosition(for: episode)
        if let download = downloads.completedDownload(mediaID: mediaID, episodeLabel: episode?.label) {
            playOffline(download, episode: episode)
        } else {
            watchByStreaming(episode: episode)
        }
    }

    private func watchByStreaming(episode: Episode?) {
        guard settings.autoSelectSource else {
            model.requestReleases(intent: .watch, episode: episode)
            return
        }
        Task {
            isAutoResolving = true
            let ranked = await model.rankedStreams(for: episode)
            isAutoResolving = false
            if let stream = ranked.first {
                startWatch(stream: stream, episode: episode,
                           fallbacks: Array(ranked.dropFirst().filter { !\$0.isDebrid }))
            } else { model.requestReleases(intent: .watch, episode: episode) }
        }
    }

    private func playOffline(_ download: Download, episode: Episode?) {
        Task {
            guard let url = await downloads.localFileURL(for: download) else {
                watchByStreaming(episode: episode)
                return
            }
            let detail = model.detail
            let name = detail?.name ?? fallbackTitle
            let label = [name, episode?.label].compactMap { \$0 }.joined(separator: " · ")
            let startAt = resumeAt
            resumeAt = .zero
            let subtitleContext = SubtitleContext(
                imdbID: mediaID, type: type,
                season: episode?.season, episode: episode?.episode)
                .withRelease(download.record.localRelativePath ?? download.record.releaseName)
                .withSource(SourceKey.make(streamID: download.record.torrentKey,
                                           fileIndex: download.record.fileIndex))
            let progressContext = WatchProgressContext(
                mediaID: mediaID, mediaType: type, title: name, posterURL: detail?.posterURL,
                season: episode?.season, episode: episode?.episode, episodeID: episode?.id)
            streamer.playLocalFile(at: url, title: label, subtitleContext: subtitleContext,
                                   episodes: makeEpisodePlaylist(current: episode, detail: detail),
                                   startAt: startAt, progress: progressContext,
                                   originalAudioLanguage: model.originalLanguage)
        }
    }

    private func isWatchTargetDownloaded(for detail: MediaDetail) -> Bool {
        downloads.isDownloaded(mediaID: mediaID,
                               episodeLabel: resumeEpisode(for: detail)?.label)
    }

    private func requestDownload(episode: Episode?) {
        guard settings.autoSelectSource else {
            model.requestReleases(intent: .download, episode: episode)
            return
        }
        Task {
            isAutoResolving = true
            let stream = await model.bestStream(for: episode)
            isAutoResolving = false
            if let stream { download(stream: stream, episode: episode) }
            else { model.requestReleases(intent: .download, episode: episode) }
        }
    }

    private func downloadEpisodes(_ episodes: [Episode]) {
        let now
