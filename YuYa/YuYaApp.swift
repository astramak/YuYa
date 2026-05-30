//
//  YuYaApp.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import SwiftUI

@main
struct YuYaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings
    @StateObject private var appModel: AppModel

    init() {
        let model = AppModel()
        _appModel = StateObject(wrappedValue: model)
        appDelegate.appModel = model
    }

    var body: some Scene {
        Window("YuYa", id: "main") {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(appModel.interfaceText.about) {
                    appModel.selectedSettingsTab = .about
                    openSettings()
                }
            }

            CommandMenu(appModel.interfaceText.playerMenu) {
                Button(appModel.interfaceText.reload) {
                    appModel.reload()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            ServiceSettingsView()
                .environmentObject(appModel)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appModel: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            appModel?.windowLifecycle.showMainWindow()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel?.prepareForTermination()
    }
}
