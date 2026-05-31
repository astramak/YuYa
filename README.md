# YuYa

<p align="center">
  <img src="Docs/assets/app-icon.png" width="128" height="128" alt="Иконка YuYa">
</p>

<p align="center">
  <strong>Нативная macOS-оболочка для веб-музыкальных сервисов.</strong><br>
  Яндекс Музыка, YouTube Music, Звук и любые другие веб-плееры в одном постоянном окне.
</p>

<p align="center">
  <img alt="Платформа" src="https://img.shields.io/badge/platform-macOS-lightgrey">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-orange">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20WebKit-blue">
  <img alt="Лицензия" src="https://img.shields.io/badge/license-GPL--3.0-green">
</p>

<p align="center">
  <a href="README.en.md">English version</a>
</p>

YuYa - небольшой музыкальный плеер для macOS, собранный на SwiftUI, AppKit и WebKit. Каждый сервис живет в своем постоянном `WKWebView`, поэтому при переключении между вкладками не сбрасываются экран, очередь, авторизация и текущая страница.

Приложение не скачивает, не извлекает, не проксирует и не обходит защищенные аудиопотоки. Оно открывает официальные веб-плееры и передает метаданные воспроизведения в системные медиа-кнопки macOS.

## Скриншоты

<p align="center">
  <img src="Docs/assets/screenshot-yandex.png" width="860" alt="Главное окно YuYa с Яндекс Музыкой">
</p>

<p align="center"><em>Главное окно: нативный тулбар, постоянные вкладки сервисов и веб-плеер внутри YuYa.</em></p>

<p align="center">
  <img src="Docs/assets/screenshot-youtube.png" width="860" alt="YouTube Music внутри YuYa">
</p>

<p align="center"><em>YouTube Music работает как отдельная вкладка и сохраняет свое состояние при переключении.</em></p>

<table>
  <tr>
    <td width="50%">
      <img src="Docs/assets/screenshot-add-service.png" alt="Добавление сервиса">
    </td>
    <td width="50%">
      <img src="Docs/assets/screenshot-settings.png" alt="Настройки YuYa">
    </td>
  </tr>
  <tr>
    <td align="center"><em>Добавление пользовательского сервиса</em></td>
    <td align="center"><em>Настройки приложения</em></td>
  </tr>
</table>

<table>
  <tr>
    <td width="75%">
      <img src="Docs/assets/screenshot-about.png" alt="О приложении YuYa">
    </td>
    <td width="25%" align="center">
      <img src="Docs/assets/screenshot-control-center.png" width="160" alt="Мини-плеер macOS">
    </td>
  </tr>
  <tr>
    <td align="center"><em>О приложении и юридическое уведомление</em></td>
    <td align="center"><em>Медиа-контролы macOS</em></td>
  </tr>
</table>

<p align="center">
  <img src="Docs/assets/screenshot-yandex-alt.png" width="860" alt="YuYa с Яндекс Музыкой в другом состоянии">
</p>

## Возможности

- Нативное окно macOS с компактным тулбаром.
- Постоянные вкладки сервисов: можно переключаться без пересоздания вебвью.
- Встроенные сервисы по умолчанию: YouTube Music и Яндекс Музыка.
- Пользовательские сервисы: можно добавить название и URL в настройках.
- Автозагрузка favicon для вкладок и индикатора воспроизведения.
- Интеграция с Пунктом управления macOS через `MPNowPlayingInfoCenter`.
- Управление с медиа-клавиш и системных кнопок через `MPRemoteCommandCenter`.
- Один активный источник звука: запуск воспроизведения в одном сервисе ставит остальные на паузу.
- Cookies, сессии и последние URL хранятся в постоянном WebKit-хранилище.
- Русский и английский язык интерфейса.

## Поддерживаемые сервисы

Встроенные:

- YouTube Music
- Яндекс Музыка

Проверяемые пользовательские сценарии:

- Звук
- Другие музыкальные веб-плееры с обычным браузерным воспроизведением

Пользовательские сервисы работают по принципу best effort. Если сервис запрещает встроенные WebKit-браузеры, использует нестандартную авторизацию или полагается на браузерно-специфичное DRM-поведение, может понадобиться отдельная адаптация.

## Архитектура

YuYa специально сделан небольшим и нативным:

- `SwiftUI` отвечает за оболочку приложения, настройки и элементы тулбара.
- `AppKit` используется для жизненного цикла окна и нативного `NSToolbar`.
- `WKWebView` изолирует и сохраняет состояние каждой вкладки-сервиса.
- JavaScript bridge собирает состояние плеера, возможности команд и метаданные.
- `MediaPlayer` API передает данные в Now Playing, Пункт управления и медиа-клавиши.

Основное состояние находится в `AppModel`, а каждый сервис представлен отдельным `ServiceWebViewModel`.

## Сборка и распространение

Требования:

- macOS
- Xcode с поддержкой Swift 5

Debug-сборка для разработки:

```sh
xcodebuild build \
  -scheme YuYa \
  -configuration Debug \
  -destination 'platform=macOS'
```

Запуск тестов:

```sh
xcodebuild test \
  -scheme YuYa \
  -destination 'platform=macOS'
```

Release-сборка без подписи для локальной проверки:

```sh
xcodebuild build \
  -scheme YuYa \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Готовое приложение будет здесь:

```sh
build/DerivedData/Build/Products/Release/YuYa.app
```

Такая сборка подходит для локальной проверки, но не для публичного распространения: macOS будет ругаться на неподписанное приложение.

### Developer ID release

Для распространения вне Mac App Store нужен Apple Developer аккаунт, сертификат `Developer ID Application` и настроенный `notarytool`.

Архив:

```sh
xcodebuild archive \
  -scheme YuYa \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/YuYa.xcarchive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

Экспорт подписанного `.app`:

```sh
xcodebuild -exportArchive \
  -archivePath build/YuYa.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist Packaging/ExportOptions.DeveloperID.plist
```

DMG:

```sh
hdiutil create \
  -volname "YuYa" \
  -srcfolder build/export/YuYa.app \
  -ov \
  -format UDZO \
  build/YuYa.dmg
```

Notarization:

```sh
xcrun notarytool submit build/YuYa.dmg \
  --keychain-profile "notarytool-profile" \
  --wait

xcrun stapler staple build/YuYa.dmg
```

Если профиль для notarization еще не создан:

```sh
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

## Важные замечания

- Пароли и сессии Safari не шарятся с приложениями на `WKWebView`. У YuYa свое WebKit-хранилище.
- Некоторые провайдеры авторизации могут блокировать встроенные браузеры.
- Закрытие главного окна скрывает его и оставляет воспроизведение активным; полный выход из приложения останавливает все.
- Метаданные в macOS зависят от того, что сам веб-плеер отдает через Media Session или стандартные HTML media elements.

## Юридический дисклеймер

YuYa не связан с Yandex, Google, YouTube, Spotify, Звук или другими поддерживаемыми сервисами, не одобрен ими и не спонсируется ими. Все товарные знаки, названия сервисов, логотипы и медиаконтент принадлежат их владельцам.

YuYa не скачивает, не извлекает, не расшифровывает, не проксирует и не обходит защищенные аудиопотоки. Приложение только отображает официальные веб-плееры в нативной оболочке macOS.
