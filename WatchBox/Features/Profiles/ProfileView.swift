//
//  ProfileView.swift
//  SceneBox
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
        "Support the developer": "Поддержать разработчика",
        "Donate Info": "Перевод по номеру карты Сбербанк:",
        "OK": "Понятно",
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
        "Default audio is used when a title was made in that language (or its language is unknown); a foreign title keeps its original audio instead of a dub. Subtitles in your default language are fetched from OpenSubtitles as soon as you press play.\n\nPlayer buffer is how many seconds the player holds ahead. Larger smooths slow downloads but starts slower; 3 seconds suits most connections.": "Аудио по умолчанию используется, если это оригинальный язык фильма. Субтитры скачиваются с OpenSubtitles автоматически при запуске.\n\nБуфер плеера — запас видео в секундах. Большой буфер сглаживает медленную загрузку,