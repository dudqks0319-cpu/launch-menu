import SwiftUI

struct RootContentView: View {
    @ObservedObject var store: LaunchMenuStore
    let onCloseRequest: () -> Void

    @State private var displayMode: GridDisplayMode = .paged
    @State private var currentPage = 0
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VisualEffectBlurView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
            .overlay(Color.black.opacity(0.22))
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                SmartTabsContainerView(
                    tabs: store.tabs,
                    selectedPredicate: Binding(
                        get: { store.selectedTabID },
                        set: { store.selectTab(with: $0) }
                    )
                )

                SearchContainerView(
                    query: $store.searchQuery,
                    results: store.visibleItems,
                    showsResultList: isSearching,
                    onLaunch: { item in
                        store.launch(item)
                    },
                    iconProvider: { item in
                        store.icon(for: item)
                    }
                )

                controlsRow

                GridContainerView(
                    items: store.visibleItems,
                    displayMode: displayMode,
                    currentPage: $currentPage,
                    pageSize: 24,
                    columnCount: store.settings.gridColumnCount,
                    onLaunch: { item in
                        store.launch(item)
                    },
                    iconProvider: { item in
                        store.icon(for: item)
                    }
                )
            }
            .padding(22)
        }
        .frame(minWidth: 960, minHeight: 700)
        .onExitCommand(perform: onCloseRequest)
        .onChange(of: store.searchQuery) { _, _ in
            currentPage = 0
        }
        .onChange(of: store.selectedTabID) { _, _ in
            currentPage = 0
        }
        .sheet(isPresented: $showSettings) {
            SettingsContainerView(
                settings: Binding(
                    get: { store.settings },
                    set: { store.applySettings($0) }
                ),
                onReset: {
                    store.resetSettings()
                },
                onRefreshApps: {
                    Task {
                        await store.refreshApps()
                    }
                }
            )
            .frame(minWidth: 480, minHeight: 420)
        }
        .alert("실행 오류", isPresented: Binding(
            get: { store.lastErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    store.clearError()
                }
            }
        )) {
            Button("확인", role: .cancel) {
                store.clearError()
            }
        } message: {
            Text(store.lastErrorMessage ?? "알 수 없는 오류")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Launch Menu")
                    .font(.system(size: 30, weight: .semibold))

                Text("Option+Space 또는 F4로 열고, ESC로 닫으실 수 있습니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task {
                    await store.refreshApps()
                }
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button {
                showSettings = true
            } label: {
                Label("설정", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button("닫기", action: onCloseRequest)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
        }
    }

    private var controlsRow: some View {
        HStack {
            Picker("표시 모드", selection: $displayMode) {
                ForEach(GridDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Stepper(value: Binding(
                get: { store.settings.gridColumnCount },
                set: { newValue in
                    var updated = store.settings
                    updated.gridColumnCount = min(max(newValue, 4), 10)
                    store.applySettings(updated)
                }
            ), in: 4...10) {
                Text("열 수: \(store.settings.gridColumnCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.visibleItems.count)개 앱")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var isSearching: Bool {
        store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
