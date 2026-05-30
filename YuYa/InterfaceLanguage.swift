//
//  InterfaceLanguage.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import Foundation

enum InterfaceLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case english
    case russian

    var id: String {
        rawValue
    }

    var resolved: InterfaceLanguage {
        switch self {
        case .system:
            return Self.systemLanguage
        case .english, .russian:
            return self
        }
    }

    private static var systemLanguage: InterfaceLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("ru") ? .russian : .english
    }
}

struct InterfaceText {
    private let language: InterfaceLanguage

    init(_ preference: InterfaceLanguage) {
        language = preference.resolved
    }

    var playerMenu: String { value(en: "Player", ru: "Плеер") }
    var reload: String { value(en: "Reload", ru: "Обновить") }
    var back: String { value(en: "Back", ru: "Назад") }
    var forward: String { value(en: "Forward", ru: "Вперед") }
    var home: String { value(en: "Home", ru: "Домой") }
    var serviceSettingsHelp: String { value(en: "Service settings", ru: "Настройки сервисов") }
    var noTrack: String { value(en: "No track", ru: "Нет трека") }
    var ready: String { value(en: "Ready", ru: "Готово") }

    var services: String { value(en: "Services", ru: "Сервисы") }
    var settings: String { value(en: "Settings", ru: "Настройки") }
    var about: String { value(en: "About", ru: "О приложении") }
    var tabName: String { value(en: "Tab name", ru: "Название вкладки") }
    var serviceURL: String { value(en: "Service URL", ru: "URL сервиса") }
    var save: String { value(en: "Save", ru: "Сохранить") }
    var openHome: String { value(en: "Open Home", ru: "Открыть главную") }
    var addService: String { value(en: "Add Service", ru: "Добавить сервис") }
    var add: String { value(en: "Add", ru: "Добавить") }
    var cancel: String { value(en: "Cancel", ru: "Отмена") }
    var resetDefaultServices: String { value(en: "Reset default services", ru: "Сбросить сервисы") }
    var moveUp: String { value(en: "Move up", ru: "Выше") }
    var moveDown: String { value(en: "Move down", ru: "Ниже") }
    var removeService: String { value(en: "Remove service", ru: "Удалить сервис") }
    var startupTab: String { value(en: "Startup tab", ru: "Стартовая вкладка") }
    var interfaceLanguage: String { value(en: "Interface language", ru: "Язык интерфейса") }
    var popupWindows: String { value(en: "Popup windows", ru: "Всплывающие окна") }
    var openInsideYuYa: String { value(en: "Open inside YuYa", ru: "Открывать внутри YuYa") }
    var websiteData: String { value(en: "Website data", ru: "Данные сайтов") }
    var persistentWebKitStorage: String {
        value(en: "Uses persistent WebKit storage", ru: "Используется постоянное хранилище WebKit")
    }
    var version: String { value(en: "Version", ru: "Версия") }
    var bundleID: String { value(en: "Bundle ID", ru: "Bundle ID") }
    var engine: String { value(en: "Engine", ru: "Движок") }
    var mediaControls: String { value(en: "Media controls", ru: "Медиа-кнопки") }
    var appDescription: String {
        value(
            en: "YuYa is a small macOS player shell for web music services. It keeps each service in its own persistent tab and connects playback metadata to macOS media controls.",
            ru: "YuYa - небольшой macOS-плеер для веб-версий музыкальных сервисов. Он держит каждый сервис в отдельной постоянной вкладке и передает метаданные воспроизведения в медиа-кнопки macOS."
        )
    }
    var legalDisclaimerTitle: String { value(en: "Legal notice", ru: "Юридическое уведомление") }
    var legalDisclaimer: String {
        value(
            en: "YuYa is not affiliated with, endorsed by, or sponsored by Yandex, Google, YouTube, Spotify, or other supported services. All trademarks belong to their owners. The app does not download, extract, or bypass protected audio streams; it only displays official web players.",
            ru: "YuYa не связан, не одобрен и не спонсируется Яндексом, Google, YouTube, Spotify или другими поддерживаемыми сервисами. Все товарные знаки принадлежат их владельцам. Приложение не скачивает, не извлекает и не обходит защищенные аудиопотоки, а только отображает официальные веб-плееры."
        )
    }
    var invalidServiceInput: String {
        value(
            en: "Enter a tab name and a valid http or https URL.",
            ru: "Введите название вкладки и корректный http или https URL."
        )
    }

    func languageTitle(_ option: InterfaceLanguage) -> String {
        switch option {
        case .system:
            return value(en: "System", ru: "Системный")
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }

    private func value(en: String, ru: String) -> String {
        language == .russian ? ru : en
    }
}
