import SwiftUI

struct SmartCategoryChipsView: View {
    var categories: [SmartCategory]
    @Binding private var selectedCategory: SmartCategory

    init(
        categories: [SmartCategory] = SmartCategory.allCases,
        selectedCategory: Binding<SmartCategory>
    ) {
        self.categories = categories
        _selectedCategory = selectedCategory
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(
                                selectedCategory == category
                                    ? Color.white
                                    : Color.primary
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        selectedCategory == category
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.12)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
