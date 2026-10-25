//
//  MediaDetailView.swift
//  SceneBox
//
//  Created by SpontaneousArray on 19.08.26.
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

    private func actions(for detail: MediaDetail) -> some View {
        let watchFraction = watchProgressFraction(for: detail)
        let labelHeight: CGFloat = 32
        return HStack(spacing: 12) {
            Button {
                watch(episode: resumeEpisode(for: detail))
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        ViewThatFits(in: .horizontal) {
                            Text(resumeLabel(for: detail) ?? "Watch")
                                .lineLimit(1)
                            Text(resumeLabel(for: detail, compact: true) ?? "Watch")
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
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
                .fontWeight(.semibold)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: labelHeight)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .layoutPriority(1)          // the main action keeps its label; the rest are icons

            if
