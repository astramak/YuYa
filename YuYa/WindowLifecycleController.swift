//
//  WindowLifecycleController.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
final class WindowLifecycleController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private weak var window: NSWindow?
    private weak var appModel: AppModel?
    private var openSettings: (() -> Void)?
    private var toolbar: NSToolbar?

    func bind(_ window: NSWindow, appModel: AppModel, openSettings: @escaping () -> Void) {
        self.appModel = appModel
        self.openSettings = openSettings

        guard self.window !== window else {
            return
        }

        self.window = window
        window.delegate = self
        window.title = "YuYa"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.backgroundColor = .black
        configureToolbar(for: window)
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenPrimary)

        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
    }

    func showMainWindow() {
        guard let window else {
            NSApplication.shared.activate()
            return
        }

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            TopChromeToolbarIdentifier.mainChrome,
            TopChromeToolbarIdentifier.spacerBeforeSettings,
            TopChromeToolbarIdentifier.settings
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            TopChromeToolbarIdentifier.mainChrome,
            TopChromeToolbarIdentifier.spacerBeforeSettings,
            TopChromeToolbarIdentifier.settings
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let appModel else {
            return nil
        }

        switch itemIdentifier {
        case TopChromeToolbarIdentifier.spacerBeforeSettings:
            return makeSpacerToolbarItem(identifier: itemIdentifier, width: 4)

        case TopChromeToolbarIdentifier.mainChrome:
            return makeHostedToolbarItem(
                identifier: itemIdentifier,
                label: "Controls",
                width: 760,
                minWidth: 520,
                maxWidth: 10_000,
                rootView: TopChromeMainToolbarItem(appModel: appModel)
            )

        case TopChromeToolbarIdentifier.navigation:
            return makeHostedToolbarItem(
                identifier: itemIdentifier,
                label: "Navigation",
                width: 136,
                rootView: TopChromeNavigationToolbarItem(appModel: appModel)
            )

        case TopChromeToolbarIdentifier.track:
            return makeHostedToolbarItem(
                identifier: itemIdentifier,
                label: "Now Playing",
                width: 190,
                rootView: TopChromeTrackToolbarItem(appModel: appModel)
            )

        case TopChromeToolbarIdentifier.playback:
            return makeHostedToolbarItem(
                identifier: itemIdentifier,
                label: "Playback",
                width: 620,
                minWidth: 380,
                maxWidth: 10_000,
                rootView: TopChromePlaybackToolbarItem(appModel: appModel)
            )

        case TopChromeToolbarIdentifier.services:
            return makeHostedToolbarItem(
                identifier: itemIdentifier,
                label: "Services",
                width: 420,
                minWidth: 180,
                maxWidth: 10_000,
                rootView: TopChromeServicesToolbarItem(appModel: appModel)
            )

        case TopChromeToolbarIdentifier.settings:
            return makeHostedToolbarItem(
                identifier: itemIdentifier,
                label: "Settings",
                width: 34,
                rootView: TopChromeSettingsToolbarItem(
                    appModel: appModel,
                    openSettings: { [weak self] in
                        self?.openSettings?()
                    }
                )
            )

        default:
            return nil
        }
    }

    private func configureToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: TopChromeToolbarIdentifier.toolbar)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.showsBaselineSeparator = false
        toolbar.sizeMode = .regular

        self.toolbar = toolbar
        window.toolbar = toolbar

        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
    }

    private func makeHostedToolbarItem<Content: View>(
        identifier: NSToolbarItem.Identifier,
        label: String,
        width: CGFloat,
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        rootView: Content
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: TopChromeMetrics.toolbarHeight
        )
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        item.view = hostingView
        item.minSize = NSSize(width: minWidth ?? width, height: TopChromeMetrics.toolbarHeight)
        item.maxSize = NSSize(width: maxWidth ?? width, height: TopChromeMetrics.toolbarHeight)
        return item
    }

    private func makeSpacerToolbarItem(
        identifier: NSToolbarItem.Identifier,
        width: CGFloat
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: width,
                height: TopChromeMetrics.toolbarHeight
            )
        )
        item.minSize = NSSize(width: width, height: TopChromeMetrics.toolbarHeight)
        item.maxSize = NSSize(width: width, height: TopChromeMetrics.toolbarHeight)
        return item
    }
}

private enum TopChromeToolbarIdentifier {
    static let toolbar = NSToolbar.Identifier("YuYa.TopChromeToolbar")
    static let mainChrome = NSToolbarItem.Identifier("YuYa.MainChrome")
    static let navigation = NSToolbarItem.Identifier("YuYa.Navigation")
    static let playback = NSToolbarItem.Identifier("YuYa.Playback")
    static let track = NSToolbarItem.Identifier("YuYa.NowPlaying")
    static let services = NSToolbarItem.Identifier("YuYa.Services")
    static let settings = NSToolbarItem.Identifier("YuYa.Settings")
    static let spacerAfterNavigation = NSToolbarItem.Identifier("YuYa.SpacerAfterNavigation")
    static let spacerBeforeSettings = NSToolbarItem.Identifier("YuYa.SpacerBeforeSettings")
}
