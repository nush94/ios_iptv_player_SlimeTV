//
//  DetailProgressBar.swift
//  IPTV
//

import SwiftUI

struct DetailProgressBar: View {
  let progress: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(.white.opacity(0.18))

        Capsule()
          .fill(.red)
          .frame(width: max(0, min(proxy.size.width, proxy.size.width * progress)))
      }
    }
    .frame(height: 4)
  }
}
