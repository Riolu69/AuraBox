//
//  DownloadsView.swift
//  SceneBox
//
//  Created by SpontaneousArray on 08.08.26.
//

import SwiftUI

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "No downloads yet": "Пока нет загрузок",
        "Tap Download on a movie or episode to keep it on this device for offline viewing.": "Нажмите «Скачать» на фильме или серии, чтобы сохранить их для просмотра без интернета.",
        "Delete": "Удалить",
        "Cancel": "Отмена",
        "Play": "Смотреть",
        "Pause": "Пауза",
        "Resume": "Продолжить",
        "Retry": "Повторить",
        "Pause all": "Пауза для всех",
        "Resume all": "Возобновить все",
        "Resume All": "Возобновить все",
        "Pause All": "Пауза для всех",
        "Delete All Episodes": "Удалить все эпизоды",
        "Watched": "Просмотрено",
        "Paused": "На паузе",
        "in progress": "в процессе",
        "Resume to keep downloading.": "Возобновите, чтобы продолжить загрузку.",
        "Connecting to peers…": "Подключение к пирам…",
        " active": " активно",
        " of ": " из ",
        "Using ": "Используется ",
        " on this device": " на этом устройстве",
        " episodes": " эпизодов",
        " downloading": " загружается",
        " ready": " готово",
        " watched": " просмотрено",
        "Delete download?": "Удалить загрузку?",
        "episodes?": "эпизодов?",
        " will be removed from this device.": " будет удален с этого устройства.",
        "Every downloaded episode of ": "Все скачанные эпизоды ",
        "Collapses the episode list": "Свернуть список",
        "Shows every downloaded episode": "Показать все эпизоды"
    ]
    return dict[key] ?? key
}

/// All downloads for one title. A show's episodes fold into a single row that
/// expands; a movie is a group of one.
struct DownloadGroup: Identifiable {
    let id: String              // media id
    let title: String
    let posterURL: URL?
    let isSeries: Bool
    let items: [Download]

    var completedCount: Int { items.filter { $0.phase == .completed }.count }
    var pendingCount: Int { items.filter { $0.phase.isPending }.count }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.record.totalBytes } }
    var doneBytes: Int64 {
        items.reduce(0) { sum, item in
            sum + (item.phase == .completed
                   ? item.record.totalBytes
                   : Int64(min(max(item.progress, 0), 1) * Double(item.record.totalBytes)))
        }
    }

    static func make(from downloads: [Download]) -> [DownloadGroup] {
        var order: [String] = []
        var buckets: [String: [Download]] = [:]
        for download in downloads {           // store keeps newest first
            let key = download.record.mediaID
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(download)
        }
        return order.compactMap { key in
            guard let items = buckets[key], let first = items.first else { return nil }
            let sorted = items.sorted { $0.record.episodeOrder < $1.record.episodeOrder }
            return DownloadGroup(id: key, title: first.record.title, posterURL: first.record.posterURL,
                                 isSeries: first.record.episodeLabel != nil, items: sorted)
        }
    }
}

extension DownloadRecord {
    /// Sort key: season then episode ("S2E10" after "S2E9").
    var episodeOrder: Int {
        guard let label = episodeLabel else { return 0 }
        let numbers = label.dropFirst().split(separator: "E").compactMap { Int($0) }
        guard numbers.count == 2 else { return 0 }
        return numbers[0] * 10_000 + numbers[1]
    }
}

struct DownloadsView: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @Environment(DownloadStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(WatchProgressStore.self) private var progress
    @State private var streamer = StreamCoordinator()
    @State private var pendingDelete: DeleteRequest?
    @State private var expanded: Set<String> = []

    private enum DeleteRequest: Identifiable {
        case one(Download)
        case group(DownloadGroup)

        var id: String {
            switch self {
            case .one(let download): return "one-\(download.id)"
            case .group(let group): return "group-\(group.id)"
            }
        }
    }

    var body: some View {
        let groups = DownloadGroup.make(from: store.downloads)
        Group {
            if store.downloads.isEmpty {
                EmptyStateView(
                    systemImage: "arrow.down.circle",
                    title: tr("No downloads yet", appLanguage),
                    message: tr("Tap Download on a movie or episode to keep it on this device for offline viewing.", appLanguage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if os(tvOS)
                    .frame(minHeight: 500)   // hosted in Library's ScrollView
                    #endif
            } else {
                #if os(tvOS)
                LazyVStack(spacing: 12) {
                    ForEach(store.downloads) { download in
                        DownloadRow(
                            download: download,
                            onPrimary: { primaryAction(for: download) },
                            onDelete: { pendingDelete = .one(download) })
                    }
                }
                .focusSection()
                #else
                list(groups)
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            if UserDefaults.standard.bool(forKey: "SBExpandAll") { expanded = Set(groups.map(\.id)) }
        }
        .fullScreenCover(isPresented: Binding(get: { streamer.isPresenting },
                                              set: { if !$0 { streamer.stop() } })) {
            StreamPlayerContainer(streamer: streamer)
                .environment(settings)
        }
        .alert(deleteTitle, isPresented: Binding(get: { pendingDelete != nil },
                                                 set: { if !$0 { pendingDelete = nil } })) {
            Button(tr("Delete", appLanguage), role: .destructive) {
                switch pendingDelete {
                case .one(let download): store.remove(download)
                case .group(let group): group.items.forEach { store.remove($0) }
                case nil: break
                }
                pendingDelete = nil
            }
            Button(tr("Cancel", appLanguage), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(deleteMessage)
        }
    }

    // MARK: List

    #if !os(tvOS)
    private func list(_ groups: [DownloadGroup]) -> some View {
        List {
            if store.hasPendingWork || groups.contains(where: { $0.items.contains { $0.phase == .paused || $0.phase == .failed } }) {
                TransferSummary(store: store)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }

            ForEach(groups) { group in
                if group.items.count == 1, let download = group.items.first {
                    DownloadItemRow(download: download, style: .standalone,
                                    watched: isWatched(download), watchFraction: watchFraction(download),
                                    onPrimary: { primaryAction(for: download) })
                        .listRowBackground(Theme.background)
                        .listRowSeparatorTint(Theme.hairline)
                        .swipeActions { deleteButton { pendingDelete = .one(download) } }
                        .contextMenu { itemMenu(download) }
                } else {
                    Button {
                        withAnimation(Theme.smooth) { toggle(group.id) }
                    } label: {
                        GroupHeaderRow(group: group, isExpanded: expanded.contains(group.id),
                                       watchedCount: group.items.filter { isWatched($0) }.count)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(expanded.contains(group.id) ? Theme.surface : Theme.background)
                    .listRowSeparator(expanded.contains(group.id) ? .hidden : .visible)
                    .listRowSeparatorTint(Theme.hairline)
                    .swipeActions { deleteButton { pendingDelete = .group(group) } }
                    .contextMenu { groupMenu(group) }

                    if expanded.contains(group.id) {
                        ForEach(group.items) { download in
                            DownloadItemRow(download: download, style: .episode,
                                            watched: isWatched(download), watchFraction: watchFraction(download),
                                            onPrimary: { primaryAction(for: download) })
                                .listRowBackground(Theme.surface)
                                .listRowSeparator(download.id == group.items.last?.id ? .visible : .hidden)
                                .listRowSeparatorTint(Theme.hairline)
                                .swipeActions { deleteButton { pendingDelete = .one(download) } }
                                .contextMenu { itemMenu(download) }
                        }
                    }
                }
            }

            Text(tr("Using ", appLanguage) + "\(ByteFormat.size(store.diskUsage))" + tr(" on this device", appLanguage))
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .listRowBackground(Theme.background)
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
        }
        .listStyle(.plain)
        .hideScrollBackground()
        .refreshable { store.refreshDiskUsage() }
        .sensoryFeedback(.success, trigger: store.downloads.filter { $0.phase == .completed }.count) { old, new in
            new > old
        }
    }

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(tr("Delete", appLanguage), systemImage: "trash")
        }
    }

    @ViewBuilder
    private func itemMenu(_ download: Download) -> some View {
        switch download.phase {
        case .completed:
            Button { primaryAction(for: download) } label: { Label(tr("Play", appLanguage), systemImage: "play.fill") }
        case .downloading, .resolving, .queued:
            Button { store.pause(download) } label: { Label(tr("Pause", appLanguage), systemImage: "pause.fill") }
        case .paused, .failed:
            Button { store.resume(download) } label: { Label(tr("Resume", appLanguage), systemImage: "arrow.down") }
        }
        Button(role: .destructive) { pendingDelete = .one(download) } label: {
            Label(tr("Delete", appLanguage), systemImage: "trash")
        }
    }

    @ViewBuilder
    private func groupMenu(_ group: DownloadGroup) -> some View {
        if group.items.contains(where: { $0.phase == .paused || $0.phase == .failed }) {
            Button {
                group.items.filter { $0.phase == .paused || $0.phase == .failed }.forEach { store.resume($0) }
            } label: { Label(tr("Resume All", appLanguage), systemImage: "arrow.down") }
        }
        if group.pendingCount > 0 {
            Button {
                group.items.filter(\.phase.isPending).forEach { store.pause($0) }
            } label: { Label(tr("Pause All", appLanguage), systemImage: "pause.fill") }
        }
        Button(role: .destructive) { pendingDelete = .group(group) } label: {
            Label(tr("Delete All Episodes", appLanguage), systemImage: "trash")
        }
    }
    #endif

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func isWatched(_ download: Download) -> Bool {
        if let label = download.record.episodeLabel {
            return progress.watchedEpisodes(for: download.record.mediaID).contains(label)
        }
        return progress.isMovieWatched(download.record.mediaID)
    }

    private func watchFraction(_ download: Download) -> Double? {
        guard let context = download.record.watchProgressContext else { return nil }
        if let episodeID = context.episodeID {
            return progress.episodeFraction(mediaID: context.mediaID, episodeID: episodeID)
        }
        guard let saved = progress.progress(for: context.mediaID), !saved.isFinished,
              saved.fraction > 0.01 else { return nil }
        return saved.fraction
    }

    private var deleteTitle: String {
        switch pendingDelete {
        case .group(let group): return tr("Delete", appLanguage) + " \(group.items.count) " + tr("episodes?", appLanguage)
        default: return tr("Delete download?", appLanguage)
        }
    }

    private var deleteMessage: String {
        switch pendingDelete {
        case .one(let download):
            let name = [download.record.title, download.record.episodeLabel].compactMap { $0 }.joined(separator: " ")
            return "\(name)" + tr(" will be removed from this device.", appLanguage)
        case .group(let group):
            return tr("Every downloaded episode of ", appLanguage) + "\(group.title)" + tr(" will be removed from this device.", appLanguage)
        case nil:
            return ""
        }
    }

    private func primaryAction(for download: Download) {
        switch download.phase {
        case .completed:
            play(download)
        case .downloading, .resolving, .queued:
            store.pause(download)
        case .paused, .failed:
            store.resume(download)
        }
    }

    private func play(_ download: Download) {
        Task {
            guard let url = await store.localFileURL(for: download) else { return }
            let title = [download.record.title, download.record.episodeLabel]
                .compactMap { $0 }.joined(separator: " · ")
            let context = download.record.watchProgressContext
            streamer.playLocalFile(at: url, title: title,
                                   subtitleContext: download.record.subtitleContext,
                                   episodes: playlist(for: download),
                                   startAt: resumePosition(for: context),
                                   progress: context)
        }
    }

    /// The show's other finished downloads, so the player offers the next one.
    private func playlist(for download: Download) -> EpisodePlaylist? {
        let finished = store.downloads.filter {
            $0.record.mediaID == download.record.mediaID && $0.record.episode != nil
                && ($0.phase == .completed || $0.record.isComplete)
        }
        guard let current = download.record.episode, finished.count > 1 else { return nil }
        return EpisodePlaylist(current: current, all: finished.compactMap(\.record.episode),
                               mediaID: download.record.mediaID) { episode in
            if let next = finished.first(where: { $0.record.episode == episode }) { play(next) }
        }
    }

    private func resumePosition(for context: WatchProgressContext?) -> Duration {
        guard let context,
              let saved = WatchProgressStore.shared.progress(for: context.mediaID),
              !saved.isFinished, saved.episodeID == context.episodeID
        else { return .zero }
        return .seconds(saved.positionSeconds)
    }
}

// MARK: - Rows (iOS)

#if !os(tvOS)
/// Total transfer state with the bulk controls.
private struct TransferSummary: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let store: DownloadStore

    var body: some View {
        let pending = store.downloads.filter(\.phase.isPending)
        let active = pending.filter(\.phase.isActive)
        let rate = active.reduce(0) { $0 + $1.downloadRate }
        let total = pending.reduce(Int64(0)) { $0 + $1.record.totalBytes }
        let done = pending.reduce(Int64(0)) {
            $0 + Int64(min(max($1.progress, 0), 1) * Double($1.record.totalBytes))
        }
        let canResume = store.downloads.contains { $0.phase == .paused || $0.phase == .failed }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.isEmpty ? tr("Paused", appLanguage) : "\(pending.count) " + tr("in progress", appLanguage))
                        .font(.display(22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(pending.isEmpty
                         ? tr("Resume to keep downloading.", appLanguage)
                         : (rate > 0 ? "\(ByteFormat.rate(rate)) · \(active.count)" + tr(" active", appLanguage) : tr("Connecting to peers…", appLanguage)))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                if !pending.isEmpty {
                    Button { store.pauseAll() } label: {
                        Label(tr("Pause all", appLanguage), systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                } else if canResume {
                    Button { store.resumeAll() } label: {
                        Label(tr("Resume all", appLanguage), systemImage: "arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
                }
            }
            if total > 0 {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Theme.accent)
                Text("\(ByteFormat.size(done))" + tr(" of ", appLanguage) + "\(ByteFormat.size(total))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).strokeBorder(Theme.hairline))
        .animation(Theme.smooth, value: pending.count)
    }
}

private struct GroupHeaderRow: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let group: DownloadGroup
    let isExpanded: Bool
    let watchedCount: Int

    var body: some View {
        HStack(spacing: 14) {
            PosterImage(url: group.posterURL, cornerRadius: 8)
                .frame(width: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                if group.pendingCount > 0, group.totalBytes > 0 {
                    ProgressView(value: Double(group.doneBytes), total: Double(group.totalBytes))
                        .tint(Theme.accent)
                        .padding(.top, 2)
                } else {
                    Text(ByteFormat.size(group.totalBytes))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 32, height: 32)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isExpanded ? tr("Collapses the episode list", appLanguage) : tr("Shows every downloaded episode", appLanguage))
    }

    private var summary: String {
        var parts = ["\(group.items.count)" + tr(" episodes", appLanguage)]
        if group.pendingCount > 0 {
            parts.append("\(group.pendingCount)" + tr(" downloading", appLanguage))
        } else if group.completedCount < group.items.count {
            parts.append("\(group.completedCount)" + tr(" ready", appLanguage))
        }
        if watchedCount > 0 { parts.append("\(watchedCount)" + tr(" watched", appLanguage)) }
        return parts.joined(separator: ", ")
    }
}

private struct DownloadItemRow: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    enum Style { case standalone, episode }

    let download: Download
    let style: Style
    let watched: Bool
    let watchFraction: Double?
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            leading

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(titleLine)
                        .font(style == .standalone ? .headline : .subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if watched, style == .standalone { WatchedBadge(size: 16) }
                }
                if style == .standalone, let episode = download.record.episodeLabel {
                    Text(episode)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                status
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onPrimary) {
                Image(systemName: primaryIcon)
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(download.phase == .completed ? Theme.accent : .white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(primaryLabel)
        }
        .padding(.vertical, style == .standalone ? 6 : 2)
        .padding(.leading, style == .episode ? 4 : 0)
    }

    @ViewBuilder
    private var leading: some View {
        switch style {
        case .standalone:
            PosterImage(url: download.record.posterURL, cornerRadius: 8)
                .frame(width: 58)
                .overlay(alignment: .bottom) {
                    if let watchFraction { ArtworkProgress(fraction: watchFraction).padding(4) }
                }
        case .episode:
            Text(episodeCode)
                .font(.display(17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(watched ? Theme.textTertiary : .white)
                .frame(width: 58, alignment: .leading)
        }
    }

    private var titleLine: String {
        switch style {
        case .standalone: return download.record.title
        case .episode: return download.phase == .completed
            ? ByteFormat.size(download.record.totalBytes)
            : download.statusText
        }
    }

    @ViewBuilder
    private var status: some View {
        switch download.phase {
        case .completed:
            if style == .standalone {
                Text(ByteFormat.size(download.record.totalBytes))
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            } else if let watchFraction {
                ProgressView(value: watchFraction)
                    .tint(.white.opacity(0.7))
                    .frame(maxWidth: 140)
            } else if watched {
                Label(tr("Watched", appLanguage), systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(download.record.releaseName)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: download.progress)
                    .tint(download.phase == .failed ? Theme.danger : Theme.accent)
                    .opacity(download.phase == .queued || download.phase == .paused ? 0.5 : 1)
                Text(detailLine)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(download.phase == .failed ? Theme.danger : Theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var detailLine: String {
        if style == .episode {
            return download.sizeProgressText ?? download.record.releaseName
        }
        return [download.statusText, download.sizeProgressText].compactMap { $0 }.joined(separator: "  ")
    }

    private var episodeCode: String {
        guard let label = download.record.episodeLabel else { return "" }
        return label.replacingOccurrences(of: "E", with: " E")
    }

    private var primaryIcon: String {
        switch download.phase {
        case .completed: return "play.circle.fill"
        case .downloading, .resolving, .queued: return "pause.circle.fill"
        case .paused, .failed: return "arrow.down.circle.fill"
        }
    }

    private var primaryLabel: String {
        switch download.phase {
        case .completed: return tr("Play", appLanguage)
        case .downloading, .resolving, .queued: return tr("Pause", appLanguage)
        case .paused: return tr("Resume", appLanguage)
        case .failed: return tr("Retry", appLanguage)
        }
    }
}
#endif

// MARK: - Row (tvOS)

private struct DownloadRow: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    let download: Download
    let onPrimary: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            PosterImage(url: download.record.posterURL, cornerRadius: 6)
                .frame(width: 130)

            VStack(alignment: .leading, spacing: 6) {
                Text(download.record.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(download.record.subtitleLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if download.phase != .completed {
                    ProgressView(value: download.progress)
                        .tint(download.phase == .failed ? .red : Theme.accent)
                }
                if let size = download.sizeProgressText {
                    Text(size).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(download.statusText)
                    .foregroundStyle(download.phase == .failed ? .red : .secondary)
                    .lineLimit(1)
            }
            .font(.callout.monospacedDigit())
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button(action: onPrimary) { Image(systemName: primaryIcon) }
                    .tint(Theme.accent)
                Button(action: onDelete) { Image(systemName: "trash") }
                    .tint(.red)
            }
            .buttonStyle(.bordered)
            .font(.title3)
        }
        .padding(.vertical, 14)
        .foregroundStyle(.white)
    }

    private var primaryIcon: String {
        switch download.phase {
        case .completed: return "play.circle.fill"
        case .downloading, .resolving, .queued: return "pause.circle.fill"
        case .paused, .failed: return "arrow.down.circle.fill"
        }
    }
}