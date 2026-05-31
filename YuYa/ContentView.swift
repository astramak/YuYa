//
//  ContentView.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import SwiftUI

enum TopChromeMetrics {
    static let toolbarHeight: CGFloat = 38
    static let toolbarPillHeight: CGFloat = 32
    static let toolbarVerticalOffset: CGFloat = 1
    static let toolbarTopPadding: CGFloat = 2
    static let trafficLightInset: CGFloat = 86
    static let webContentTopInset: CGFloat = 0
    static let webContentTopHitTestExclusion: CGFloat = 0
    static let scrimHeight: CGFloat = 0
}

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        WebViewStack(appModel: appModel)
        .frame(minWidth: 900, minHeight: 620)
        .background(Color.black)
        .background(WindowAccessor { window in
            appModel.windowLifecycle.bind(
                window,
                appModel: appModel,
                openSettings: { openSettings() }
            )
        })
    }
}

struct TopChromeNavigationToolbarItem: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        NavigationControls(
            navigationState: appModel.selectedNavigationState,
            goBack: appModel.goBack,
            goForward: appModel.goForward,
            openHome: { appModel.openHome(for: appModel.selectedServiceID) },
            reload: appModel.reload,
            strings: appModel.interfaceText
        )
        .frame(height: TopChromeMetrics.toolbarHeight)
    }
}

struct TopChromeMainToolbarItem: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            NavigationControls(
                navigationState: appModel.selectedNavigationState,
                goBack: appModel.goBack,
                goForward: appModel.goForward,
                openHome: { appModel.openHome(for: appModel.selectedServiceID) },
                reload: appModel.reload,
                strings: appModel.interfaceText
            )

            TrackIndicator(
                snapshot: appModel.nowPlayingSnapshot,
                service: nowPlayingService,
                favicon: nowPlayingFavicon,
                strings: appModel.interfaceText
            )
                .frame(width: 190, height: TopChromeMetrics.toolbarPillHeight)

            ServiceSwitcher(
                services: appModel.services,
                selectedServiceID: selectedServiceIDBinding,
                playingServiceID: appModel.playingServiceID,
                faviconsByServiceID: appModel.faviconsByServiceID
            )
            .frame(maxWidth: .infinity, minHeight: TopChromeMetrics.toolbarPillHeight, maxHeight: TopChromeMetrics.toolbarPillHeight)
        }
        .offset(y: TopChromeMetrics.toolbarVerticalOffset)
        .frame(maxWidth: .infinity, minHeight: TopChromeMetrics.toolbarHeight, maxHeight: TopChromeMetrics.toolbarHeight)
    }

    private var selectedServiceIDBinding: Binding<String> {
        Binding(
            get: { appModel.selectedServiceID },
            set: { appModel.selectedServiceID = $0 }
        )
    }

    private var nowPlayingServiceID: String {
        appModel.nowPlayingSnapshot?.serviceID ?? appModel.playingServiceID ?? appModel.selectedServiceID
    }

    private var nowPlayingService: MusicService? {
        appModel.service(withID: nowPlayingServiceID)
    }

    private var nowPlayingFavicon: NSImage? {
        appModel.faviconsByServiceID[nowPlayingServiceID]
    }
}

struct TopChromeTrackToolbarItem: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        TrackIndicator(
            snapshot: appModel.nowPlayingSnapshot,
            service: nowPlayingService,
            favicon: nowPlayingFavicon,
            strings: appModel.interfaceText
        )
            .frame(width: 190, height: TopChromeMetrics.toolbarHeight)
    }

    private var nowPlayingServiceID: String {
        appModel.nowPlayingSnapshot?.serviceID ?? appModel.playingServiceID ?? appModel.selectedServiceID
    }

    private var nowPlayingService: MusicService? {
        appModel.service(withID: nowPlayingServiceID)
    }

    private var nowPlayingFavicon: NSImage? {
        appModel.faviconsByServiceID[nowPlayingServiceID]
    }
}

struct TopChromePlaybackToolbarItem: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 4) {
            TrackIndicator(
                snapshot: appModel.nowPlayingSnapshot,
                service: nowPlayingService,
                favicon: nowPlayingFavicon,
                strings: appModel.interfaceText
            )
                .frame(width: 190, height: TopChromeMetrics.toolbarPillHeight)

            ServiceSwitcher(
                services: appModel.services,
                selectedServiceID: selectedServiceIDBinding,
                playingServiceID: appModel.playingServiceID,
                faviconsByServiceID: appModel.faviconsByServiceID
            )
            .frame(maxWidth: .infinity, minHeight: TopChromeMetrics.toolbarPillHeight, maxHeight: TopChromeMetrics.toolbarPillHeight)
        }
        .frame(maxWidth: .infinity, minHeight: TopChromeMetrics.toolbarHeight, maxHeight: TopChromeMetrics.toolbarHeight)
    }

    private var selectedServiceIDBinding: Binding<String> {
        Binding(
            get: { appModel.selectedServiceID },
            set: { appModel.selectedServiceID = $0 }
        )
    }

    private var nowPlayingServiceID: String {
        appModel.nowPlayingSnapshot?.serviceID ?? appModel.playingServiceID ?? appModel.selectedServiceID
    }

    private var nowPlayingService: MusicService? {
        appModel.service(withID: nowPlayingServiceID)
    }

    private var nowPlayingFavicon: NSImage? {
        appModel.faviconsByServiceID[nowPlayingServiceID]
    }
}

struct TopChromeServicesToolbarItem: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ServiceSwitcher(
            services: appModel.services,
            selectedServiceID: selectedServiceIDBinding,
            playingServiceID: appModel.playingServiceID,
            faviconsByServiceID: appModel.faviconsByServiceID
        )
        .frame(maxWidth: .infinity, minHeight: TopChromeMetrics.toolbarHeight, maxHeight: TopChromeMetrics.toolbarHeight)
    }

    private var selectedServiceIDBinding: Binding<String> {
        Binding(
            get: { appModel.selectedServiceID },
            set: { appModel.selectedServiceID = $0 }
        )
    }
}

struct TopChromeSettingsToolbarItem: View {
    @ObservedObject var appModel: AppModel
    let openSettings: () -> Void

    var body: some View {
        SettingsButton(
            openSettings: {
                appModel.selectedSettingsTab = .services
                openSettings()
            },
            strings: appModel.interfaceText
        )
            .frame(width: 34, height: TopChromeMetrics.toolbarHeight)
    }
}

private struct TopChromeScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: .black.opacity(0.24), location: 0),
                Gradient.Stop(color: .black.opacity(0.08), location: 0.42),
                Gradient.Stop(color: .black.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct TopChromePalette {
    let primaryText: Color
    let secondaryText: Color
    let disabledText: Color
    let capsuleFill: Color
    let capsuleStroke: Color
    let hoverFill: Color
    let selectedFill: Color
    let selectedStroke: Color
    let trackFill: Color
    let trackStroke: Color
    let iconBackground: Color

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .light:
            primaryText = Color.black.opacity(0.78)
            secondaryText = Color.black.opacity(0.54)
            disabledText = Color.black.opacity(0.22)
            capsuleFill = Color.black.opacity(0.06)
            capsuleStroke = Color.black.opacity(0.10)
            hoverFill = Color.black.opacity(0.10)
            selectedFill = Color.black.opacity(0.12)
            selectedStroke = Color.black.opacity(0.16)
            trackFill = Color.black.opacity(0.08)
            trackStroke = Color.black.opacity(0.14)
            iconBackground = Color.black.opacity(0.10)
        case .dark:
            primaryText = Color.white.opacity(0.88)
            secondaryText = Color.white.opacity(0.58)
            disabledText = Color.white.opacity(0.34)
            capsuleFill = Color.white.opacity(0.075)
            capsuleStroke = Color.white.opacity(0.08)
            hoverFill = Color.white.opacity(0.12)
            selectedFill = Color.white.opacity(0.16)
            selectedStroke = Color.white.opacity(0.16)
            trackFill = Color.white.opacity(0.09)
            trackStroke = Color.white.opacity(0.12)
            iconBackground = Color.white.opacity(0.12)
        @unknown default:
            primaryText = Color.white.opacity(0.88)
            secondaryText = Color.white.opacity(0.58)
            disabledText = Color.white.opacity(0.34)
            capsuleFill = Color.white.opacity(0.075)
            capsuleStroke = Color.white.opacity(0.08)
            hoverFill = Color.white.opacity(0.12)
            selectedFill = Color.white.opacity(0.16)
            selectedStroke = Color.white.opacity(0.16)
            trackFill = Color.white.opacity(0.09)
            trackStroke = Color.white.opacity(0.12)
            iconBackground = Color.white.opacity(0.12)
        }
    }
}

private struct ServiceSwitcher: View {
    let services: [MusicService]
    @Binding var selectedServiceID: String
    let playingServiceID: String?
    let faviconsByServiceID: [String: NSImage]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(services) { service in
                    ServiceTabButton(
                        service: service,
                        image: faviconsByServiceID[service.id],
                        isSelected: service.id == selectedServiceID,
                        isPlaying: service.id == playingServiceID
                    ) {
                        selectedServiceID = service.id
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
        .frame(height: TopChromeMetrics.toolbarPillHeight)
        .scrollContentBackground(.hidden)
        .background {
            Capsule()
                .fill(palette.capsuleFill)
        }
        .overlay {
            Capsule()
                .strokeBorder(palette.capsuleStroke, lineWidth: 1)
        }
    }

    private var palette: TopChromePalette {
        TopChromePalette(colorScheme: colorScheme)
    }
}

private struct ServiceTabButton: View {
    let service: MusicService
    let image: NSImage?
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isPlaying {
                    EqualizerGlyph()
                        .frame(width: 18, height: 18)
                } else {
                    ServiceIcon(
                        image: image,
                        fallbackText: service.displayName,
                        size: 18
                    )
                }

                Text(service.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
            .padding(.leading, 7)
            .padding(.trailing, 9)
            .frame(height: 28)
            .background {
                if isPlaying {
                    PlayingTabBackground(isSelected: isSelected)
                } else if isSelected {
                    Capsule()
                        .fill(palette.selectedFill)
                } else if isHovered {
                    Capsule()
                        .fill(palette.hoverFill)
                }
            }
            .overlay {
                if isSelected || isPlaying {
                    Capsule()
                        .strokeBorder(isPlaying ? Color.white.opacity(0.24) : palette.selectedStroke, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(service.homeURL.absoluteString)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.16), value: isHovered)
        .animation(.easeInOut(duration: 0.16), value: isSelected)
        .animation(.easeInOut(duration: 0.16), value: isPlaying)
    }

    private var palette: TopChromePalette {
        TopChromePalette(colorScheme: colorScheme)
    }

    private var textColor: Color {
        if isPlaying {
            return Color.white.opacity(0.94)
        }

        return isSelected ? palette.primaryText : palette.secondaryText
    }
}

private struct EqualizerGlyph: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.green)
                        .frame(width: 3, height: barHeight(index: index, time: time))
                }
            }
            .frame(width: 18, height: 18)
            .background(Color.green.opacity(0.18), in: Circle())
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = time * 5.4 + Double(index) * 1.7
        return 5 + CGFloat((sin(phase) + 1) * 0.5) * 8
    }
}

private struct PlayingTabBackground: View {
    let isSelected: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + sin(time * 0.45) * 0.5
            let center = UnitPoint(
                x: 0.44 + cos(time * 0.22) * 0.10,
                y: 0.52 + sin(time * 0.18) * 0.12
            )

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(isSelected ? 0.34 : 0.24),
                            Color.cyan.opacity(isSelected ? 0.20 : 0.13),
                            Color.green.opacity(isSelected ? 0.26 : 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity((isSelected ? 0.14 : 0.08) + pulse * 0.05),
                                    Color.clear
                                ],
                                center: center,
                                startRadius: 1,
                                endRadius: 70
                            )
                        )
                        .blendMode(.screen)
                }
        }
    }
}

struct ServiceIcon: View {
    let image: NSImage?
    let fallbackText: String
    let size: CGFloat

    init(image: NSImage?, fallbackText: String, size: CGFloat = 16) {
        self.image = image
        self.fallbackText = fallbackText
        self.size = size
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Circle()
                        .fill(.secondary.opacity(0.16))
                    Text(initials)
                        .font(.system(size: max(size * 0.48, 8), weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(size * 0.2, 3), style: .continuous))
    }

    private var initials: String {
        let letters = fallbackText
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let value = letters.map(String.init).joined().uppercased()
        return value.isEmpty ? "?" : value
    }
}

private struct NavigationControls: View {
    let navigationState: WebNavigationState
    let goBack: () -> Void
    let goForward: () -> Void
    let openHome: () -> Void
    let reload: () -> Void
    let strings: InterfaceText

    var body: some View {
        HStack(spacing: 2) {
            ToolbarIconButton(systemName: "chevron.left", help: strings.back, action: goBack)
                .disabled(!navigationState.canGoBack)

            ToolbarIconButton(systemName: "chevron.right", help: strings.forward, action: goForward)
                .disabled(!navigationState.canGoForward)

            ToolbarIconButton(systemName: "house", help: strings.home, action: openHome)

            ToolbarIconButton(systemName: "arrow.clockwise", help: strings.reload, action: reload)
        }
        .frame(height: 34)
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isEnabled ? palette.primaryText : palette.disabledText)
                .frame(width: 30, height: 30)
                .background {
                    if isHovered && isEnabled {
                        Circle()
                            .fill(palette.hoverFill)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
    }

    private var palette: TopChromePalette {
        TopChromePalette(colorScheme: colorScheme)
    }
}

private struct SettingsButton: View {
    let openSettings: () -> Void
    let strings: InterfaceText

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: openSettings) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .frame(width: 30, height: 30)
                .background {
                    if isHovered {
                        Circle()
                            .fill(palette.hoverFill)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(strings.serviceSettingsHelp)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
    }

    private var palette: TopChromePalette {
        TopChromePalette(colorScheme: colorScheme)
    }
}

private struct TrackIndicator: View {
    let snapshot: PlaybackSnapshot?
    let service: MusicService?
    let favicon: NSImage?
    let strings: InterfaceText

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            indicatorIcon

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(height: TopChromeMetrics.toolbarPillHeight)
        .background(palette.trackFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(palette.trackStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        if snapshot?.isPlaying == true {
            ServiceIcon(
                image: favicon,
                fallbackText: service?.displayName ?? snapshot?.serviceName ?? "",
                size: 18
            )
        } else {
            ZStack {
                Circle()
                    .fill(palette.iconBackground)
                    .frame(width: 18, height: 18)
                Image(systemName: iconName)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private var palette: TopChromePalette {
        TopChromePalette(colorScheme: colorScheme)
    }

    private var iconName: String {
        "music.note.list"
    }

    private var title: String {
        let value = snapshot?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value! : strings.noTrack
    }

    private var subtitle: String {
        guard let snapshot else {
            return strings.ready
        }

        let artist = snapshot.artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        if artist?.isEmpty == false {
            return artist!
        }

        let album = snapshot.album?.trimmingCharacters(in: .whitespacesAndNewlines)
        return album?.isEmpty == false ? album! : ""
    }
}
