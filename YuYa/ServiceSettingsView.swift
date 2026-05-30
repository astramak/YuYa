//
//  ServiceSettingsView.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import SwiftUI

struct ServiceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedSettingsTab = SettingsTab.services
    @State private var selectedServiceID: String?
    @State private var draftName = ""
    @State private var draftURL = ""
    @State private var errorMessage: String?
    @State private var isShowingAddService = false

    var body: some View {
        TabView(selection: $selectedSettingsTab) {
            servicesTab
                .tabItem {
                    Label(strings.services, systemImage: "music.note.list")
                }
                .tag(SettingsTab.services)

            appSettingsTab
                .tabItem {
                    Label(strings.settings, systemImage: "gearshape")
                }
                .tag(SettingsTab.settings)

            aboutTab
                .tabItem {
                    Label(strings.about, systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 720, height: 430)
        .onAppear {
            selectedServiceID = selectedServiceID ?? appModel.selectedServiceID
            loadDraft()
        }
        .onChange(of: selectedServiceID) {
            loadDraft()
        }
        .sheet(isPresented: $isShowingAddService) {
            AddServiceSheet(strings: strings) { name, url in
                let added = appModel.addService(displayName: name, urlString: url)
                if added {
                    selectedServiceID = appModel.selectedServiceID
                    loadDraft()
                }
                return added
            }
        }
    }

    private var servicesTab: some View {
        HStack(spacing: 0) {
            serviceList
                .frame(width: 240)

            Divider()

            settingsForm
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.top, 8)
    }

    private var serviceList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedServiceID) {
                ForEach(appModel.services) { service in
                    HStack(spacing: 8) {
                        ServiceIcon(
                            image: appModel.faviconsByServiceID[service.id],
                            fallbackText: service.displayName
                        )
                        Text(service.displayName)
                            .lineLimit(1)
                    }
                    .tag(service.id as String?)
                }
                .onDelete(perform: deleteServices)
                .onMove(perform: moveServices)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    isShowingAddService = true
                } label: {
                    Image(systemName: "plus")
                }
                .help(strings.addService)

                Button(role: .destructive) {
                    appModel.resetServicesToDefaults()
                    selectedServiceID = appModel.selectedServiceID
                    loadDraft()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help(strings.resetDefaultServices)

                Spacer()

                Button {
                    moveSelectedService(by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveSelectedService(by: -1))
                .help(strings.moveUp)

                Button {
                    moveSelectedService(by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveSelectedService(by: 1))
                .help(strings.moveDown)

                Button(role: .destructive) {
                    removeSelectedService()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(appModel.services.count <= 1 || selectedService == nil)
                .help(strings.removeService)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(strings.services)
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            Form {
                TextField(strings.tabName, text: $draftName)
                TextField(strings.serviceURL, text: $draftURL)
                    .textContentType(.URL)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(strings.save) {
                    saveSelectedService()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedService == nil)

                Button(strings.openHome) {
                    if let selectedServiceID {
                        appModel.openHome(for: selectedServiceID)
                    }
                }
                .disabled(selectedService == nil)

                Spacer()
            }

            Spacer()
        }
        .padding(20)
    }

    private var appSettingsTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(strings.settings)
                .font(.title3.weight(.semibold))

            Form {
                Picker(strings.startupTab, selection: appSelectedServiceBinding) {
                    ForEach(appModel.services) { service in
                        Text(service.displayName)
                            .tag(service.id)
                    }
                }
                .pickerStyle(.menu)

                Picker(strings.interfaceLanguage, selection: $appModel.interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(strings.languageTitle(language))
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent(strings.popupWindows) {
                    Label(strings.openInsideYuYa, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                LabeledContent(strings.websiteData) {
                    Text(strings.persistentWebKitStorage)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: appIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(appName)
                        .font(.largeTitle.weight(.semibold))
                    Text("\(strings.version) \(appVersion) (\(buildNumber))")
                        .foregroundStyle(.secondary)
                }
            }

            Text(strings.appDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                LabeledContent(strings.bundleID, value: bundleIdentifier)
                LabeledContent(strings.engine, value: "SwiftUI + WebKit")
                LabeledContent(strings.mediaControls, value: "MPNowPlayingInfoCenter")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(strings.legalDisclaimerTitle)
                    .font(.headline)
                Text(strings.legalDisclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(24)
    }

    private var selectedService: MusicService? {
        guard let selectedServiceID else {
            return nil
        }
        return appModel.service(withID: selectedServiceID)
    }

    private var strings: InterfaceText {
        appModel.interfaceText
    }

    private var appSelectedServiceBinding: Binding<String> {
        Binding(
            get: { appModel.selectedServiceID },
            set: { appModel.selectedServiceID = $0 }
        )
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "YuYa"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "ru.astramak.YuYa"
    }

    private var appIconImage: NSImage {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.size = NSSize(width: 128, height: 128)
            return icon
        }

        let fallbackIcon = NSApp.applicationIconImage ?? NSImage(size: NSSize(width: 128, height: 128))
        fallbackIcon.size = NSSize(width: 128, height: 128)
        return fallbackIcon
    }

    private func loadDraft() {
        guard let service = selectedService else {
            selectedServiceID = appModel.services.first?.id
            return
        }

        draftName = service.displayName
        draftURL = service.homeURL.absoluteString
        errorMessage = nil
    }

    private func saveSelectedService() {
        guard let selectedServiceID else {
            return
        }

        if appModel.updateService(serviceID: selectedServiceID, displayName: draftName, urlString: draftURL) {
            errorMessage = nil
            appModel.selectedServiceID = selectedServiceID
        } else {
            errorMessage = strings.invalidServiceInput
        }
    }

    private func removeSelectedService() {
        guard let selectedServiceID else {
            return
        }

        appModel.removeService(serviceID: selectedServiceID)
        self.selectedServiceID = appModel.selectedServiceID
        loadDraft()
    }

    private func deleteServices(at offsets: IndexSet) {
        let ids = offsets
            .sorted()
            .compactMap { index in
                appModel.services.indices.contains(index) ? appModel.services[index].id : nil
            }

        for id in ids where appModel.services.count > 1 {
            appModel.removeService(serviceID: id)
        }

        if selectedServiceID == nil || selectedServiceID.flatMap({ appModel.service(withID: $0) }) == nil {
            selectedServiceID = appModel.selectedServiceID
            loadDraft()
        }
    }

    private func moveServices(from source: IndexSet, to destination: Int) {
        appModel.moveServices(from: source, to: destination)
    }

    private func canMoveSelectedService(by offset: Int) -> Bool {
        guard let selectedServiceID,
              let index = appModel.services.firstIndex(where: { $0.id == selectedServiceID })
        else {
            return false
        }

        return appModel.services.indices.contains(index + offset)
    }

    private func moveSelectedService(by offset: Int) {
        guard let selectedServiceID,
              appModel.moveService(serviceID: selectedServiceID, by: offset)
        else {
            return
        }

        self.selectedServiceID = selectedServiceID
    }
}

private enum SettingsTab: Hashable {
    case services
    case settings
    case about
}

private struct AddServiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let strings: InterfaceText
    let onAdd: (String, String) -> Bool

    @State private var name = ""
    @State private var url = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(strings.addService)
                .font(.title3.weight(.semibold))

            Form {
                TextField(strings.tabName, text: $name)
                TextField(strings.serviceURL, text: $url)
                    .textContentType(.URL)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(strings.cancel) {
                    dismiss()
                }
                Button(strings.add) {
                    if onAdd(name, url) {
                        dismiss()
                    } else {
                        errorMessage = strings.invalidServiceInput
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
