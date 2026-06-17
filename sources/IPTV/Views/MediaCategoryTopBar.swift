//
//  MediaCategoryTopBar.swift
//  IPTV
//

import IPTVModels
import RealmSwift
import SwiftUI

struct MediaCategoryTopBar: View {
  let title: String
  let categories: Results<CategoryEntity>
  let isLoading: Bool
  @Binding var selectedCategoryId: String?
  let refreshAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text(title)
          .font(.title2.weight(.bold))
          .foregroundStyle(.white)

        Spacer()

        Button(action: refreshAction) {
          Group {
            if isLoading {
              ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            } else {
              Image(systemName: "arrow.clockwise")
                .font(.headline)
            }
          }
          .foregroundStyle(.white)
          .frame(width: 38, height: 38)
          .background(.black.opacity(0.34), in: Circle())
          .overlay {
            Circle()
              .stroke(.white.opacity(0.16), lineWidth: 1)
          }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
      }

      CategoryFilterBar(categories: categories, selectedCategoryId: $selectedCategoryId)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .background {
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay {
          LinearGradient(
            colors: [.black.opacity(0.34), .black.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          )
        }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.08))
        .frame(height: 1)
    }
  }
}
