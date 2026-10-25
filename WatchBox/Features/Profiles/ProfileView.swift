//
//  ProfileView.swift
//  MovieStream
//

import SwiftUI

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "Profile": "Профиль",
        "Switch profile": "Сменить профиль",
        "Add profile": "Добавить профиль",
        "Edit Profile": "Редактировать профиль",
        "Progress is saved on this device": "Прогресс сохраняется на этом устройстве",
        "Language / Язык": "Язык (Language)",
        "Theme": "Оформление",
        "System": "Авто",
        "Light": "Светлое",
        "Dark": "Темное",
        "Support the developer": "Поддержать разработчика (Сбербанк)",
        "Card number copied!": "Номер карты скопирован!",
        "Stream quality": "Качество видео",
        "Sort releases by": "Сортировка",
        "Prefer resolution": "Предпочтительное разрешение",
        "Hide qualities": "Скрыть качество",
        "Auto-pick best source": "Автовыбор лучшего источника",
        "Sources": "Источники",
        "Skip the release list and start the best match automatically.": "Пропускать список раздач и автоматически запускать лучший вариант.",
        "Stream sources": "Источники потоков",
        "Turn on at least one source.": "Включите хотя бы один источник.",
        "Peer-to-peer streams connect you directly to other peers, who can see your IP address. Use a VPN, or a debrid service (which fetches on your behalf), if that matters to you.": "P2P-потоки подключают вас напрямую к другим пирам (они видят ваш IP). Используйте VPN или Debrid-сервис, если это важно для вас.",
        "Extra public providers": "Дополнительные открытые трекеры",
        "Needs a Real-Debrid key": "Нужен ключ Real-Debrid",
        "Source privacy": "Приватность источников",
        "Send debrid key to community sources": "Отправлять ключ Debrid сторонним серверам",
        "StremThru server": "Сервер StremThru",
        "Comet and StremThru are community-run servers. The Stremio protocol puts your debrid key in every request to them, so whoever runs the server can read it. Off: they're used peer-to-peer only (Comet is skipped). Torrentio's official server always receives the key.": "Протокол Stremio передает ваш Debrid-ключ при каждом запросе к сторонним серверам. Отключите, если хотите использовать только P2P.",
        "Debrid": "Debrid-сервисы",
        "Service": "Сервис",
        "API key": "Ключ API",
        "Stream cached torrents at full speed instead of peer-to-peer.": "Смотрите кэшированные торренты на максимальной скорости без P2P.",
        "TMDB API key": "TMDB API ключ",
        "Cast": "Актёры",
        "A free TMDB key adds cast photos and filmographies.": "Бесплатный ключ TMDB добавляет фото актёров и фильмографии.",
        "Playback": "Воспроизведение",
        "Default audio": "Аудио по умолчанию",
        "Default subtitles": "Субтитры по умолчанию",
        "Subtitle size": "Размер субтитров",
        "Fill screen (crop)": "На весь экран (обрезка)",
        "Player buffer": "Буфер плеера",
        "Default audio is used when a title was made in that language (or its language is unknown); a foreign title keeps its original audio instead of a dub. Subtitles in your default language are fetched from OpenSubtitles as soon as you press play.\n\nPlayer buffer is how many seconds the player holds ahead. Larger smooths slow downloads but starts slower; 3 seconds suits most connections.": "Аудио по умолчанию используется, если это оригинальный язык фильма. Субтитры скачиваются с OpenSubtitles автоматически при запуске.\n\nБуфер плеера — запас видео в секундах. Большой буфер сглаживает медленную загрузку, но дольше запускается.",
        "Storage": "Память",
        "Downloads": "Загрузки",
        "Download limit": "Лимит загрузок",
        "Unlimited": "Без лимита",
        "Delete all downloads": "Удалить все загрузки",
        "Delete everything": "Удалить всё",
        "Every downloaded file and its resume data will be removed.": "Все загруженные файлы и данные будут удалены.",
        "Cache": "Кэш",
        "Stream cache limit": "Лимит кэша видео",
        "Off": "Выкл",
        "Clear cache": "Очистить кэш",
        "Clear": "Очистить",
        "Recently streamed video will buffer again, and subtitles (including translations) will be downloaded or translated again when needed.": "Ранее просмотренные видео будут буферизоваться заново, а субтитры скачаются повторно.",
        "Keep fully streamed videos": "Сохранять полностью загруженные видео",
        "New downloads won't start past the download limit. The cache keeps recently streamed video (so re-opening starts instantly; the oldest goes past the stream cache limit) plus downloaded and translated subtitles. Clearing it keeps your downloads and your saved subtitle choices. With \"Keep fully streamed videos\" on, a video that finished downloading while you watched moves from the cache to Downloads, to play offline.": "Кэш сохраняет недавно просмотренные видео для мгновенного запуска. При включенной опции сохранения, скачанное во время просмотра видео останется для офлайн-доступа.",
        "Simultaneous downloads": "Одновременные загрузки",
        "Keep downloading in background": "Фоновая загрузка",
        "Show progress in Live Activity": "Показывать прогресс (Live Activity)",
        "Extra downloads wait in a queue and start automatically. iOS normally freezes an app a few seconds after you leave it, which drops every peer; background mode keeps Aura running while downloads are active by playing silent audio that mixes with your music. Smart uses short pulses to save battery; switch to Always-on audio if downloads still stop. Closing Aura from the app switcher always stops downloads. The Live Activity shows progress on the Lock Screen, but iOS may mark it failed while a torrent is still looking for peers; downloads carry on regardless.": "Фоновый режим не дает iOS заморозить приложение при сворачивании (используется тихое аудио). Закрытие приложения из меню многозадачности всегда останавливает загрузки.",
        "Extra downloads wait in a queue and start automatically.": "Дополнительные загрузки ожидают в очереди и запускаются автоматически.",
        "Network": "Сеть",
        "Max peers": "Макс. пиров",
        "Streaming port": "Порт для стриминга",
        "Download over Wi-Fi only": "Загружать только по Wi-Fi",
        "Custom trackers": "Дополнительные трекеры",
        "Ports 1024–65535; if it's busy the app picks a free one automatically. Wi-Fi only pauses downloads on cellular and resumes them on Wi-Fi. Custom trackers are announced in addition to each torrent's own.": "Загрузка только по Wi-Fi ставит мобильную сеть на паузу.",
        "About": "О приложении",
        "Support": "Поддержка",
        "Credits": "Разработчики",
        "Delete all downloads?": "Удалить все загрузки?",
        "Clear cache?": "Очистить кэш?",
        "None": "Нет",
        " hidden": " скрыто",
        "Smart (recommended)": "Умная (рекомендуется)",
        "Always-on audio": "Постоянное аудио"
    ]
    return dict[key] ?? key
}

struct ProfileView: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @AppStorage("themeMode") private var themeMode = "Auto"

    @Environment(AppSettings.self) private var settings
    @Environment(DownloadStore.self) private var downloads
    @Environment(ProfileStore.self) private var profiles
    @State private var editing: ProfileEditorView.Mode?
    @State private var confirmClearDownloads = false
    @State private var confirmClearStreamCache = false
    @State private var streamCacheBytes: Int64 = 0
    @State private var toast: ToastMessage?

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            VStack(spacing: 0) {
                #if !os(tvOS)
                RootHeader(title: tr("Profile", appLanguage)) { profileMenu }
                #endif
                Form {
                    PageTitleRow(tr("Profile", appLanguage))
                    if let profile = profiles.selected {
                        Section {
                            profileHeader(profile)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        #if os(tvOS)
                        Section {
                            Button(tr("Switch profile", appLanguage)) { profiles.deselect() }
                            if profiles.profiles.count < Profile.maxPerAccount {
                                Button(tr("Add profile", appLanguage)) { editing = .create(first: false) }
                            }
                        }
                        #endif
                    }

                    Section {
                        Picker(tr("Theme", appLanguage), selection: $themeMode) {
                            Text(tr("System", appLanguage)).tag("Auto")
                            Text(tr("Light", appLanguage)).tag("Light")
                            Text(tr("Dark", appLanguage)).tag("Dark")
                        }
                        .pickerStyle(.segmented)
                        
                        Picker(tr("Language / Язык", appLanguage), selection: $appLanguage) {
                            Text("🇷🇺 Русский").tag("ru")
                            Text("🇺🇸 English").tag("en")
                        }
                        .pickerStyle(.segmented)
                        
                        // Кнопка копирования карты Сбербанка
                        Button(action: {
                            let cardNumber = "4276 6700 3253 5758"
                            #if os(iOS)
                            UIPasteboard.general.string = cardNumber
                            #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cardNumber, forType: .string)
                            #endif
                            
                            toast = ToastMessage(text: tr("Card number copied!", appLanguage), systemImage: "doc.on.doc.fill")
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.fill")
                                    .foregroundStyle(.green)
                                Text(tr("Support the developer", appLanguage))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "doc.on.clipboard")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Section(tr("Stream quality", appLanguage)) {
                        Picker(tr("Sort releases by", appLanguage), selection: $settings.releaseSort) {
                            ForEach(ReleaseSort.allCases) { sort in
                                Text(sort.title).tag(sort)
                            }
                        }
                        Picker(tr("Prefer resolution", appLanguage), selection: $settings.preferredResolution) {
                            ForEach(["2160p", "1080p", "720p", "480p"], id: \.self) { res in
                                Text(res == "2160p" ? "4K" : res).tag(res)
                            }
                        }
                        NavigationLink {
                            QualityFilterList()
                        } label: {
                            LabeledContent(tr("Hide qualities", appLanguage), value: hiddenSummary)
                        }
                    }

                    Section {
                        Toggle(tr("Auto-pick best source", appLanguage), isOn: $settings.autoSelectSource)
                            .tint(toggleTint)
                    } header: {
                        Text(tr("Sources", appLanguage))
                    } footer: {
                        Text(tr("Skip the release list and start the best match automatically.", appLanguage))
                    }

                    Section {
                        ForEach(StreamProvider.queryOrder) { provider in
                            let locked = provider.requiresDebrid && !settings.hasRealDebridKey
                            Toggle(isOn: sourceBinding(provider)) {
                                if locked {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(provider.title)
                                        Text(tr("Needs a Real-Debrid key", appLanguage))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text(provider.title)
                                }
                            }
                            .disabled(locked)
                            .tint(toggleTint)
                        }
                        Toggle(tr("Extra public providers", appLanguage), isOn: $settings.extraSourceProviders)
                            .tint(toggleTint)
                    } header: {
                        Text(tr("Stream sources", appLanguage))
                    } footer: {
                        if settings.enabledSources.isEmpty {
                            Text(tr("Turn on at least one source.", appLanguage))
                        } else {
                            Text(tr("Peer-to-peer streams connect you directly to other peers, who can see your IP address. Use a VPN, or a debrid service (which fetches on your behalf), if that matters to you.", appLanguage))
                        }
                    }

                    Section {
                        Toggle(tr("Send debrid key to community sources", appLanguage), isOn: $settings.shareDebridKeyWithCommunitySources)
                            .tint(toggleTint)
                        LabeledContent(tr("StremThru server", appLanguage)) {
                            TextField("https://…", text: $settings.stremthruHost)
                                .autocorrectionDisabled()
                                .tint(.primary)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                        }
                    } header: {
                        Text(tr("Source privacy", appLanguage))
                    } footer: {
                        Text(tr("Comet and StremThru are community-run servers. The Stremio protocol puts your debrid key in every request to them, so whoever runs the server can read it. Off: they're used peer-to-peer only (Comet is skipped). Torrentio's official server always receives the key.", appLanguage))
                    }

                    Section {
                        Picker(tr("Service", appLanguage), selection: $settings.debridProvider) {
                            ForEach(DebridProvider.allCases) { provider in
                                Text(provider.title).tag(provider)
                            }
                        }
                        if settings.debridProvider.requiresKey {
                            SecureField(tr("API key", appLanguage), text: $settings.debridAPIKey)
                                .autocorrectionDisabled()
                                .tint(.primary)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                        }
                    } header: {
                        Text(tr("Debrid", appLanguage))
                    } footer: {
                        if let hint = settings.debridProvider.keyHint {
                            Text("\(tr("API key", appLanguage)): \(hint)")
                        } else {
                            Text(tr("Stream cached torrents at full speed instead of peer-to-peer.", appLanguage))
                        }
                    }

                    Section {
                        SecureField(tr("TMDB API key", appLanguage), text: $settings.tmdbAPIKey)
                            .autocorrectionDisabled()
                            .tint(.primary)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    } header: {
                        Text(tr("Cast", appLanguage))
                    } footer: {
                        Text(tr("A free TMDB key adds cast photos and filmographies.", appLanguage))
                    }

                    SubtitleKeysSection()

                    Section {
                        Picker(tr("Default audio", appLanguage), selection: $settings.preferredAudioLanguage) {
                            ForEach(AppSettings.audioLanguageOptions, id: \.code) { option in
                                Text(option.name).tag(option.code)
                            }
                        }
                        Picker(tr("Default subtitles", appLanguage), selection: $settings.preferredSubtitleLanguage) {
                            ForEach(SubtitleLanguage.offered) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                        }
                        Picker(tr("Subtitle size", appLanguage), selection: $settings.subtitleScale) {
                            ForEach(AppSettings.subtitleScaleOptions, id: \.self) { scale in
                                Text(String(format: "%.2g×", scale)).tag(scale)
                            }
                        }
                        SubtitleSizePreview(scale: settings.subtitleScale)
                        Toggle(tr("Fill screen (crop)", appLanguage), isOn: $settings.fillScreen)
                            .tint(toggleTint)
                        Picker(tr("Player buffer", appLanguage), selection: $settings.networkCacheMilliseconds) {
                            Text("2 s").tag(2000)
                            Text("3 s").tag(3000)
                            Text("5 s").tag(5000)
                            Text("10 s").tag(10000)
                            Text("20 s").tag(20000)
                        }
                    } header: {
                        Text(tr("Playback", appLanguage))
                    } footer: {
                        Text(tr("Default audio is used when a title was made in that language (or its language is unknown); a foreign title keeps its original audio instead of a dub. Subtitles in your default language are fetched from OpenSubtitles as soon as you press play.\n\nPlayer buffer is how many seconds the player holds ahead. Larger smooths slow downloads but starts slower; 3 seconds suits most connections.", appLanguage))
                    }

                    Section {
                        LabeledContent(tr("Downloads", appLanguage), value: ByteFormat.size(downloads.diskUsage))
                        Picker(tr("Download limit", appLanguage), selection: $settings.storageCapBytes) {
                            Text(tr("Unlimited", appLanguage)).tag(Int64(0))
                            Text("5 GB").tag(Int64(5) << 30)
                            Text("10 GB").tag(Int64(10) << 30)
                            Text("25 GB").tag(Int64(25) << 30)
                            Text("50 GB").tag(Int64(50) << 30)
                        }
                        Button(tr("Delete all downloads", appLanguage), role: .destructive) {
                            confirmClearDownloads = true
                        }
                        .disabled(downloads.downloads.isEmpty)

                        LabeledContent(tr("Cache", appLanguage), value: ByteFormat.size(streamCacheBytes))
                        Picker(tr("Stream cache limit", appLanguage), selection: $settings.streamCacheLimitGB) {
                            ForEach(AppSettings.streamCacheOptions, id: \.self) { gb in
                                Text(gb == 0 ? tr("Off", appLanguage) : "\(gb) GB").tag(gb)
                            }
                        }
                        Button(tr("Clear cache", appLanguage), role: .destructive) {
                            confirmClearStreamCache = true
                        }
                        .disabled(streamCacheBytes == 0)
                        Toggle(tr("Keep fully streamed videos", appLanguage), isOn: $settings.keepFinishedStreams)
                    } header: {
                        Text(tr("Storage", appLanguage))
                    } footer: {
                        Text(tr("New downloads won't start past the download limit. The cache keeps recently streamed video (so re-opening starts instantly; the oldest goes past the stream cache limit) plus downloaded and translated subtitles. Clearing it keeps your downloads and your saved subtitle choices. With \"Keep fully streamed videos\" on, a video that finished downloading while you watched moves from the cache to Downloads, to play offline.", appLanguage))
                    }

                    Section {
                        Picker(tr("Simultaneous downloads", appLanguage), selection: $settings.maxSimultaneousDownloads) {
                            ForEach(AppSettings.simultaneousDownloadOptions, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        #if os(iOS)
                        Picker(tr("Keep downloading in background", appLanguage), selection: $settings.backgroundDownloadMode) {
                            ForEach(BackgroundDownloadMode.allCases) { mode in
                                Text(tr(mode.title, appLanguage)).tag(mode)
                            }
                        }
                        if #available(iOS 26, *) {
                            Toggle(tr("Show progress in Live Activity", appLanguage), isOn: $settings.downloadLiveActivity)
                                .tint(toggleTint)
                        }
                        #endif
                    } header: {
                        Text(tr("Downloads", appLanguage))
                    } footer: {
                        #if os(iOS)
                        Text(tr("Extra downloads wait in a queue and start automatically. iOS normally freezes an app a few seconds after you leave it, which drops every peer; background mode keeps Aura running while downloads are active by playing silent audio that mixes with your music. Smart uses short pulses to save battery; switch to Always-on audio if downloads still stop. Closing Aura from the app switcher always stops downloads. The Live Activity shows progress on the Lock Screen, but iOS may mark it failed while a torrent is still looking for peers; downloads carry on regardless.", appLanguage))
                        #else
                        Text(tr("Extra downloads wait in a queue and start automatically.", appLanguage))
                        #endif
                    }

                    Section {
                        Picker(tr("Max peers", appLanguage), selection: $settings.maxPeers) {
                            ForEach([20, 40, 60, 80, 100, 150, 200], id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        LabeledContent(tr("Streaming port", appLanguage)) {
                            TextField("Port", value: portBinding, format: .number.grouping(.never))
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .tint(.primary)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }
                        Toggle(tr("Download over Wi-Fi only", appLanguage), isOn: $settings.wifiOnly)
                            .tint(toggleTint)
                        NavigationLink(tr("Custom trackers", appLanguage)) {
                            TrackerEditor()
                        }
                    } header: {
                        Text(tr("Network", appLanguage))
                    } footer: {
                        Text(tr("Ports 1024–65535; if it's busy the app picks a free one automatically. Wi-Fi only pauses downloads on cellular and resumes them on Wi-Fi. Custom trackers are announced in addition to each torrent's own.", appLanguage))
                    }

                    Section {
                        contactRow(tr("Support", appLanguage), email: "rbnfq1121@gmail.com")
                        NavigationLink(tr("Credits", appLanguage)) { CreditsView() }
                    } header: {
                        Text(tr("About", appLanguage))
                    } footer: {
                        Text("Aura \(appVersion) (\(buildNumber))")
                    }
                }
                .hideScrollBackground()
                #if !os(tvOS)
                .contentMargins(.top, 4, for: .scrollContent)
                #endif
            }
            .background(Theme.background)
            #if os(tvOS)
            .pageTitle(tr("Profile", appLanguage))
            #else
            .toolbar(.hidden, for: .navigationBar)
            .statusBarScrim()
            #endif
            .toast($toast)
            .task {
                downloads.refreshDiskUsage()
                await refreshStreamCacheSize()
            }
            .tint(.primary)
        }
        .confirmationDialog(tr("Delete all downloads?", appLanguage), isPresented: $confirmClearDownloads) {
            Button(tr("Delete everything", appLanguage), role: .destructive) { downloads.removeAll() }
        } message: {
            Text(tr("Every downloaded file and its resume data will be removed.", appLanguage))
        }
        .confirmationDialog(tr("Clear cache?", appLanguage), isPresented: $confirmClearStreamCache) {
            Button(tr("Clear", appLanguage), role: .destructive) {
                StreamCoordinator.purgeStreamCache()
                TranslationCenter.shared.cancelAll()
                TranslatedSubtitles.clearCaches()
                Task {
                    await SubtitlesProvider.shared.reset()
                    await refreshStreamCacheSize()
                }
            }
        } message: {
            Text(tr("Recently streamed video will buffer again, and subtitles (including translations) will be downloaded or translated again when needed.", appLanguage))
        }
        .sheet(item: $editing) { mode in
            ProfileEditorView(mode: mode)
                .environment(profiles)
        }
    }

    private var profileMenu: some View {
        Menu {
            Button { profiles.deselect() } label: {
                Label(tr("Switch profile", appLanguage), systemImage: "person.2")
            }
            if profiles.profiles.count < Profile.maxPerAccount {
                Button { editing = .create(first: false) } label: {
                    Label(tr("Add profile", appLanguage), systemImage: "plus.circle")
                }
            }
        } label: {
            Image(systemName: "person.2")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline))
        }
        .accessibilityLabel(tr("Profile", appLanguage))
    }

    private func profileHeader(_ profile: Profile) -> some View {
        VStack(spacing: 14) {
            #if os(tvOS)
            ProfileAvatar(profile: profile, size: 180)
            #else
            ProfileAvatar(profile: profile, size: 110)
            #endif
            VStack(spacing: 6) {
                Text(profile.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(tr("Progress is saved on this device", appLanguage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button {
                    editing = .edit(profile)
                } label: {
                    Label(tr("Edit Profile", appLanguage), systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var portBinding: Binding<Int> {
        Binding(
            get: { settings.streamingPort },
            set: { settings.streamingPort = AppSettings.streamingPortRange.contains($0) ? $0 : AppSettings.defaultStreamingPort })
    }

    private func refreshStreamCacheSize() async {
        streamCacheBytes = await Task.detached(priority: .utility) {
            StreamCache.totalBytes() + TranslatedSubtitles.totalCacheBytes()
        }.value
    }

    private var toggleTint: Color {
        #if os(tvOS)
        .white
        #else
        settings.accentColor
        #endif
    }

    private func sourceBinding(_ provider: StreamProvider) -> Binding<Bool> {
        Binding(
            get: { settings.enabledSources.contains(provider) },
            set: { on in
                if on { settings.enabledSources.insert(provider) }
                else { settings.enabledSources.remove(provider) }
            }
        )
    }

    private var hiddenSummary: String {
        let hidden = QualityFilter.offered.filter(settings.excludedQualities.contains)
        if hidden.isEmpty { return tr("None", appLanguage) }
        if hidden.count <= 2 { return hidden.map(\.title).joined(separator: ", ") }
        return "\(hidden.count)" + tr(" hidden", appLanguage)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    @ViewBuilder
    private func contactRow(_ title: String, email: String) -> some View {
        #if os(tvOS)
        LabeledContent(title, value: email)
        #else
        Link(destination: URL(string: "mailto:\(email)")!) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(email).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        #endif
    }
}
