//
//  LibraryEmptyStateView.swift
//  IPTV
//

import SwiftUI

struct LibraryEmptyStateView: View {
  let systemImage: String
  let title: String
  let message: String

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 68, height: 68)
        .background {
          Circle()
            .fill(.white.opacity(0.12))
            .overlay {
              Circle()
                .stroke(.white.opacity(0.18), lineWidth: 1)
            }
        }

      VStack(spacing: 8) {
        Text(title)
          .font(.title3.weight(.bold))
          .foregroundStyle(.white)

        Text(message)
          .font(.callout)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.68))
          .lineSpacing(2)
      }
    }
    .frame(maxWidth: 370)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 22)
    .padding(.vertical, 28)
    .background {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.black.opacity(0.28))
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
  }
}
