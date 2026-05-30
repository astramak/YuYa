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
    @StateObject private var appModel: AppModel

    init() {
        let model = AppModel()
        _appModel = StateObject(wrappedValue: model)
        appDelegate.appModel = model
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
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
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel?.prepareForTermination()
    }
}
