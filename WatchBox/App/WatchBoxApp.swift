//
//  WatchBoxApp.swift
//  SceneBox
//
//  Created by SpontaneousArray on 19.08.26.
//

import SwiftUI
import SwiftVLC
import Kingfisher

@main
struct WatchBoxApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    // Подтягиваем выбранную тему из настроек (сохраняется в ProfileView)
    @AppStorage("themeMode") private var themeMode = "Auto"
    
    // 1. Создаем переменную для нашего хранилища
    @State private var planStore = PlanToWatchStore.shared

    init() {
        Self.configureImageCache()

        _ = VLCInstance.prewarmShared()

        StreamCoordinator.pruneCacheAtLaunch()
        Task.detached(priority: .utility) { await DefaultTrackers.refreshIfStale() }

        // Resume downloads that were running when the app last closed, and keep
        // them going when the app leaves the screen.
        _ = DownloadStore.shared
        BackgroundDownloads.shared.start()
    }

    private static func configureImageCache() {
        let storage = ImageCache.default.memoryStorage
        storage.config.totalCostLimit = 80 * 1024 * 1024
        storage.config.countLimit = 200
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { DeepLinkRouter.shared.handle($0) }
                // Динамически применяем тему в зависимости от выбора в Профиле
                .preferredColorScheme(colorScheme)
                // 2. Передаем хранилище "Буду смотреть" всем экранам приложения
                .environment(planStore)
        }
    }

    // Мапим строковое значение темы в системный ColorScheme?
    private var colorScheme: ColorScheme? {
        switch themeMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil // "Auto" — системная тема (автоматически день/ночь)
        }
    }
}
