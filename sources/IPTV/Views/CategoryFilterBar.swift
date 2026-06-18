//
//  CategoryFilterBar.swift
//  IPTV
//

import IPTVModels
import RealmSwift
import SwiftUI

struct CategoryFilterBar: View {
  let categories: Results<CategoryEntity>
  @Binding var selectedCategoryId: String?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        filterButton(title: "All", count: categories.count, categoryId: nil)

        ForEach(categories, id: \.id) { category in
          filterButton(title: category.name.formatted(), count: nil, categoryId: category.id)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 2)
    }
    .scrollIndicators(.hidden)
  }

  private func filterButton(title: String, count: Int?, categoryId: String?) -> some View {
    let isSelected = selectedCategoryId == categoryId

    return Button {
      withAnimation(.snappy) {
        selectedCategoryId = categoryId
      }
    } label: {
      HStack(spacing: 5) {
        Text(title)
          .lineLimit(1)

        if let count {
          Text("\(count)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.white.opacity(isSelected ? 0.22 : 0.12), in: Capsule())
        }
      }
      .font(.subheadline.weight(isSelected ? .semibold : .medium))
      .foregroundStyle(isSelected ? .white : .white.opacity(0.82))
      .padding(.horizontal, 13)
      .padding(.vertical, 8)
      .background {
        Capsule()
          .fill(isSelected ? .red.opacity(0.9) : .black.opacity(0.28))
          .overlay {
            Capsule()
              .stroke(.white.opacity(isSelected ? 0.18 : 0.12), lineWidth: 1)
          }
      }
    }
    .buttonStyle(.plain)
  }
}
