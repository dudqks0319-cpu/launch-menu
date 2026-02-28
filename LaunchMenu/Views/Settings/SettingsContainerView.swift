import SwiftUI

struct SettingsContainerView: View {
    @Binding var settings: LaunchSettings
    var onReset: () -> Void = {}
    var onRefreshApps: () -> Void = {}
    var onImportLaunchpad: () async throws -> Int = { 0 }
    var onExportBackup: () throws -> URL = { URL(fileURLWithPath: NSHomeDirectory()) }
    var onRestoreBackup: () throws -> Int = { 0 }

    @State private var showLaunchpadImportConfirmation = false
    @State private var showRestoreBackupConfirmation = false
    @State private var resultMessage: String?
    @State private var isImporting = false
    @State private var isProcessingBackup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingsSectionView(title: L10n.t("settings.section.general")) {
                    Toggle(L10n.t("settings.show.hidden.apps"), isOn: $settings.showHiddenApps)
                    Stepper(value: $settings.gridColumnCount, in: 4...10) {
                        Text(L10n.f("settings.grid.columns", settings.gridColumnCount))
                    }
                    Stepper(value: $settings.searchDebounceMilliseconds, in: 50...1000, step: 50) {
                        Text(L10n.f("settings.search.debounce", settings.searchDebounceMilliseconds))
                    }
                }

                SettingsSectionView(title: L10n.t("settings.section.hot.corner")) {
                    Toggle(L10n.t("settings.hot.corner.enable"), isOn: $settings.hotCornerEnabled)
                    Picker(L10n.t("settings.hot.corner.location"), selection: $settings.hotCornerLocation) {
                        ForEach(HotCornerLocation.allCases, id: \.self) { location in
                            Text(location.title).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(settings.hotCornerEnabled == false)
                }

                SettingsSectionView(title: L10n.t("settings.section.appearance")) {
                    Picker(L10n.t("settings.background.style"), selection: $settings.backgroundStyle) {
                        ForEach(BackgroundStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    if settings.backgroundStyle == .customColor {
                        TextField(L10n.t("settings.custom.color.placeholder"), text: $settings.customBackgroundHex)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.f("settings.background.opacity", Int(settings.backgroundOpacity * 100)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.backgroundOpacity, in: 0...1, step: 0.01)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.f("settings.icon.size", Int(settings.iconSize)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.iconSize, in: 48...96, step: 1)
                    }

                    Toggle(L10n.t("settings.show.app.names"), isOn: $settings.showsAppNames)

                    Picker(L10n.t("settings.theme"), selection: $settings.appearanceMode) {
                        ForEach(ThemeAppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SettingsSectionView(title: L10n.t("settings.section.smart.tabs")) {
                    Stepper(value: $settings.maxRecentItems, in: 4...40) {
                        Text(L10n.f("settings.recent.app.count", settings.maxRecentItems))
                    }
                    Stepper(value: $settings.maxFrequentItems, in: 4...40) {
                        Text(L10n.f("settings.frequent.app.count", settings.maxFrequentItems))
                    }
                    Stepper(value: $settings.newInstallWindowDays, in: 1...30) {
                        Text(L10n.f("settings.new.install.window.days", settings.newInstallWindowDays))
                    }
                }

                SettingsSectionView(title: L10n.t("settings.section.icon.cache")) {
                    Stepper(value: $settings.iconCacheItemLimit, in: 64...1000, step: 16) {
                        Text(L10n.f("settings.icon.cache.item.limit", settings.iconCacheItemLimit))
                    }
                    Stepper(value: $settings.iconCacheMemoryLimitBytes, in: 8 * 1024 * 1024...256 * 1024 * 1024, step: 8 * 1024 * 1024) {
                        Text(L10n.f("settings.icon.cache.memory.limit", settings.iconCacheMemoryLimitBytes / (1024 * 1024)))
                    }
                }

                SettingsSectionView(title: L10n.t("settings.section.import")) {
                    HStack {
                        Text(L10n.t("settings.import.launchpad.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Button(L10n.t("settings.import.launchpad.action")) {
                        showLaunchpadImportConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting || isProcessingBackup)
                }

                SettingsSectionView(title: L10n.t("settings.section.backup.restore")) {
                    HStack {
                        Text(L10n.t("settings.backup.restore.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Button(L10n.t("settings.backup.save")) {
                            performBackupExport()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting || isProcessingBackup)

                        Button(L10n.t("settings.backup.restore")) {
                            showRestoreBackupConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(isImporting || isProcessingBackup)
                    }
                }

                HStack(spacing: 8) {
                    Button(L10n.t("settings.rescan.apps")) {
                        onRefreshApps()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(L10n.t("settings.reset")) {
                        onReset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
        }
        .confirmationDialog(
            L10n.t("settings.import.launchpad.confirm"),
            isPresented: $showLaunchpadImportConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("common.import"), role: .destructive) {
                performLaunchpadImport()
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            L10n.t("settings.backup.restore.confirm"),
            isPresented: $showRestoreBackupConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("common.restore"), role: .destructive) {
                performBackupRestore()
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .alert(
            L10n.t("settings.backup.restore.title"),
            isPresented: Binding(
                get: { resultMessage != nil },
                set: { newValue in
                    if newValue == false {
                        resultMessage = nil
                    }
                }
            )
        ) {
            Button(L10n.t("common.confirm"), role: .cancel) {
                resultMessage = nil
            }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private func performLaunchpadImport() {
        isImporting = true
        Task {
            do {
                let importedCount = try await onImportLaunchpad()
                await MainActor.run {
                    resultMessage = L10n.f("settings.import.launchpad.result", importedCount)
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    resultMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func performBackupExport() {
        isProcessingBackup = true
        defer { isProcessingBackup = false }

        do {
            let savedURL = try onExportBackup()
            resultMessage = L10n.f("settings.backup.save.result", savedURL.lastPathComponent)
        } catch BackupManagerError.cancelled {
            // 사용자가 패널을 닫은 경우는 메시지를 표시하지 않습니다.
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    private func performBackupRestore() {
        isProcessingBackup = true
        defer { isProcessingBackup = false }

        do {
            let restoredEntryCount = try onRestoreBackup()
            resultMessage = L10n.f("settings.backup.restore.result", restoredEntryCount)
        } catch BackupManagerError.cancelled {
            // 사용자가 패널을 닫은 경우는 메시지를 표시하지 않습니다.
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}
