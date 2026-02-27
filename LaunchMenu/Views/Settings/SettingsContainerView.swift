import SwiftUI

struct SettingsContainerView: View {
    @Binding var settings: LaunchSettings
    var onReset: () -> Void = {}
    var onRefreshApps: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingsSectionView(title: "일반") {
                    Toggle("숨김 앱 표시", isOn: $settings.showHiddenApps)
                    Stepper(value: $settings.gridColumnCount, in: 4...10) {
                        Text("그리드 열 수: \(settings.gridColumnCount)")
                    }
                    Stepper(value: $settings.searchDebounceMilliseconds, in: 50...1000, step: 50) {
                        Text("검색 디바운스: \(settings.searchDebounceMilliseconds)ms")
                    }
                }

                SettingsSectionView(title: "스마트 탭") {
                    Stepper(value: $settings.maxRecentItems, in: 4...40) {
                        Text("최근 앱 개수: \(settings.maxRecentItems)")
                    }
                    Stepper(value: $settings.maxFrequentItems, in: 4...40) {
                        Text("자주 앱 개수: \(settings.maxFrequentItems)")
                    }
                    Stepper(value: $settings.newInstallWindowDays, in: 1...30) {
                        Text("신규 설치 기준: \(settings.newInstallWindowDays)일")
                    }
                }

                SettingsSectionView(title: "아이콘 캐시") {
                    Stepper(value: $settings.iconCacheItemLimit, in: 64...1000, step: 16) {
                        Text("캐시 아이템 수: \(settings.iconCacheItemLimit)")
                    }
                    Stepper(value: $settings.iconCacheMemoryLimitBytes, in: 8 * 1024 * 1024...256 * 1024 * 1024, step: 8 * 1024 * 1024) {
                        Text("메모리 한도: \(settings.iconCacheMemoryLimitBytes / (1024 * 1024))MB")
                    }
                }

                HStack(spacing: 8) {
                    Button("앱 목록 다시 스캔") {
                        onRefreshApps()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("설정 초기화") {
                        onReset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
        }
    }
}
