import SwiftUI

struct SmartTabsContainerView: View {
    var tabs: [SmartTabModel]
    @Binding private var selectedPredicate: String
    var onSelect: (SmartTabModel) -> Void

    init(
        tabs: [SmartTabModel] = [SmartTabModel.all],
        selectedPredicate: Binding<String> = .constant("all"),
        onSelect: @escaping (SmartTabModel) -> Void = { _ in }
    ) {
        self.tabs = tabs
        _selectedPredicate = selectedPredicate
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    SmartTabChipView(
                        tab: tab,
                        isSelected: selectedPredicate == tab.id,
                        onSelect: {
                            selectedPredicate = tab.id
                            onSelect(tab)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear(perform: ensureSelectedTab)
    }

    private func ensureSelectedTab() {
        guard selectedPredicate.isEmpty else { return }
        selectedPredicate = tabs.first?.id ?? ""
    }
}
