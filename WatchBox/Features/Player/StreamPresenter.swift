//
//  StreamPresenter.swift
//  MovieStream
//

import SwiftUI
import Kingfisher
import AVKit

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "Play now": "Начать просмотр",
        "Try another source": "Другой источник",
        "Close": "Закрыть"
    ]
    return dict[key] ?? key
}

struct StreamPlayerContainer: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let streamer: StreamCoordinator
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let target = streamer.target {
                // MARK: Гибридный плеер
                // Если формат поддерживается Apple (mp4, m3u8) — запускаем нативный плеер с PiP и AirPlay
                if target.isAppleSupported {
                    NativePlaybackScreen(target: target, onClose: streamer.stop)
                        .id(target.url)
                        .environment(settings)
                } else {
                    // Иначе падаем на всеядный VLC для MKV и тяжелых контейнеров
                    PlaybackScreen(
                        url: target.url,
                        title: target.title,
                        stats: target.showsTorrentStats ? streamer.stats : nil,
                        subtitleContext: target.subtitleContext,
                        episodes: streamer.episodePlaylist,
                        startAt: target.startPosition,
                        progress: target.progress,
                        artworkURL: streamer.backdropURL,
                        originalAudioLanguage: target.originalAudioLanguage,
                        onRecover: { await streamer.recoveryURL() },
                        onClose: streamer.stop
                    )
                    .id(target.url)
                    .environment(settings)
                }
            } else {
                PreparingPlayerView(
                    backdropURL: streamer.backdropURL,
                    logoURL: streamer.logoURL,
                    title: streamer.title,
                    progress: streamer.bufferProgress,
                    status: streamer.preparingStatus,
                    error: streamer.errorMessage,
                    canStartNow: streamer.canStartNow,
                    onStartNow: streamer.startNow,
                    canTryAnother: streamer.canTryAnotherSource,
                    onTryAnother: streamer.tryAnotherSource,
                    onClose: streamer.stop
                )
            }
        }
        .animation(nil, value: streamer.target?.url)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { streamer.revive() }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) { DiagnosticsOverlay() }
        #endif
    }
}

// MARK: - Apple AVPlayer (Native) 
/// Дает автоматическую поддержку Picture-in-Picture и полноценный AirPlay.
private struct NativePlaybackScreen: View {
    let target: StreamCoordinator.Target
    let onClose: () -> Void
    
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let player = player {
                NativeAVPlayerView(player: player)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // Пользовательская кнопка "Закрыть", накладываемая поверх плеера
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.45), in: Circle())
            }
            #if os(tvOS)
            .padding(.leading, 50)
            .padding(.top, 40)
            #else
            .padding(.horizontal, 24)
            .padding(.top, 56)
            #endif
        }
        .onAppear {
            let avPlayer = AVPlayer(url: target.url)
            
            // Восстановление позиции
            let startSec = target.startPosition.asSeconds
            if startSec > 0 {
                avPlayer.seek(to: CMTime(seconds: startSec, preferredTimescale: 1))
            }
            
            avPlayer.play()
            self.player = avPlayer
            
            // Периодическое сохранение прогресса в историю
            let interval = CMTime(seconds: 5, preferredTimescale: 1)
            timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                guard let progress = target.progress else { return }
                let position = time.seconds
                let dur = avPlayer.currentItem?.duration.seconds ?? 0
                if position > 0 {
                    WatchProgressStore.shared.record(
                        id: progress.mediaID, mediaType: progress.mediaType, title: progress.title,
                        posterURL: progress.posterURL, season: progress.season,
                        episode: progress.episode, episodeID: progress.episodeID,
                        position: Duration.seconds(position),
                        duration: Duration.seconds(dur.isNaN ? 0 : dur),
                        publish: false
                    )
                }
            }
        }
        .onDisappear {
            if let obs = timeObserver { player?.removeTimeObserver(obs) }
            player?.pause()
            
            // Финальное сохранение прогресса при закрытии
            guard let player = player, let progress = target.progress else { return }
            let position = player.currentTime().seconds
            let dur = player.currentItem?.duration.seconds ?? 0
            if position > 0 {
                WatchProgressStore.shared.record(
                    id: progress.mediaID, mediaType: progress.mediaType, title: progress.title,
                    posterURL: progress.posterURL, season: progress.season,
                    episode: progress.episode, episodeID: progress.episodeID,
                    position: Duration.seconds(position),
                    duration: Duration.seconds(dur.isNaN ? 0 : dur),
                    publish: true
                )
            }
        }
    }
}

/// Обёртка контроллера UIKit для работы PiP
private struct NativeAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        return controller
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

#if DEBUG
private struct DiagnosticsOverlay: View {
    private var diag = TorrentDiagnostics.shared

    var body: some View {
        if let s = diag.latest {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.appState)\(s.deviceLocked ? " LOCKED" : "") · \(s.network) · \(s.torrentState)")
                Text("peers \(s.peers) (\(s.seeds) seed) conns \(s.connections) cand \(s.candidates) known \(s.listPeers)")
                Text("rate \(Int(s.downloadRate) / 1024) KB/s · att \(s.attempts) fail \(s.connectFailures) · dht \(s.dhtNodes)")
                Text("t=\(Int(s.playerSeconds))s · head \(s.playheadMB)MB · win \(s.window)")
                if let top = s.disconnectReasons.max(by: { $0.value < $1.value }) {
                    Text("\(top.key) ×\(top.value)").lineLimit(1)
                }
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.green)
            .padding(6)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
            .padding(.top, 40)
            .padding(.trailing, 12)
            .allowsHitTesting(false)
        }
    }
}
#endif

private struct PreparingPlayerView: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let backdropURL: URL?
    let logoURL: URL?
    let title: String
    let progress: Double?
    let status: String?
    let error: String?
    var canStartNow = false
    var onStartNow: () -> Void = {}
    var canTryAnother = false
    var onTryAnother: () -> Void = {}
    let onClose: () -> Void

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()

            if error != nil {
                errorCard(width: 360)
            } else {
                VStack(spacing: 28) {
                    titleArt
                    VStack(spacing: 14) {
                        BufferBar(progress: progress)
                            .frame(maxWidth: 300)
                        if let status {
                            Text(status)
                                .font(.footnote.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.85))
                                .contentTransition(.numericText())
                                .animation(.default, value: status)
                        }
                        if canStartNow {
                            Button(action: onStartNow) {
                                Label(tr("Play now", appLanguage), systemImage: "play.fill")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .foregroundStyle(Theme.onAccent)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        if canTryAnother {
                            Button(action: onTryAnother) {
                                Label(tr("Try another source", appLanguage), systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .transition(.opacity)
                        }
                    }
                    .animation(Theme.smooth, value: canStartNow)
                    .animation(Theme.smooth, value: canTryAnother)
                }
                .padding(.horizontal, 40)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topLeading) { closeButton }
        .preferredColorScheme(.dark)
        .hideStatusBarCompat()
        #if os(tvOS)
        .onExitCommand(perform: onClose)
        #endif
    }

    private var backdrop: some View {
        Color.clear
            .overlay {
                KFImage(backdropURL)
                    .resizable()
                    .fade(duration: 0.25)
                    .placeholder { Color.black }
                    .scaledToFill()
            }
            .clipped()
            .overlay(Color.black.opacity(0.45))
            .overlay(
                RadialGradient(colors: [.black.opacity(0.55), .clear],
                               center: .center, startRadius: 0, endRadius: 380)
            )
    }

    @ViewBuilder
    private var titleArt: some View {
        if let logoURL {
            KFImage(logoURL)
                .resizable()
                .fade(duration: 0.2)
                .placeholder { titleText }
                .scaledToFit()
                .frame(maxWidth: 360, maxHeight: 160)
        } else {
            titleText
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.display(38))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: 340)
    }

    private func errorCard(width: CGFloat) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text(error ?? "")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Button(tr("Close", appLanguage), action: onClose)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: min(width, 360))
    }

    private var closeButton: some View {
        #if os(tvOS)
        Button(action: onClose) { Image(systemName: "xmark") }
            .buttonStyle(TVCircleButtonStyle(diameter: 46))
            .padding(.leading, 50)
            .padding(.top, 40)
        #else
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.45), in: Circle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        #endif
    }
}

private struct BufferBar: View {
    let progress: Double?
    private let height: CGFloat = 8

    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Capsule()
                .fill(.white.opacity(0.28))
                .overlay(alignment: .leading) {
                    if let progress {
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(height, w * CGFloat(max(0, min(1, progress)))))
                            .animation(.easeOut(duration: 0.4), value: progress)
                    } else {
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: w * 0.34)
                            .offset(x: sweep ? w : -w * 0.34)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false),
                                       value: sweep)
                    }
                }
                .clipShape(Capsule())
        }
        .frame(height: height)
        .shadow(color: Theme.accent.opacity(0.45), radius: 8)
        .onAppear { sweep = true }
    }
}