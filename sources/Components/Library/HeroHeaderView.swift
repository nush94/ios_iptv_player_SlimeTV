//
//  HeroHeaderView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 11/11/2024.
//

import SwiftUI

public struct HeroHeaderView: View {
  public var belowFold: Bool

  public init(belowFold: Bool) {
    self.belowFold = belowFold
  }

  public var body: some View {
    ZStack {
      Color.black

      Image("beach_landscape")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .opacity(0.32)

      LinearGradient(
        colors: [
          .black.opacity(0.18),
          .black.opacity(0.52),
          .black.opacity(0.94),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
      .ignoresSafeArea()
  }

  public var maskView: some View {
    // The gradient makes direct use of the `belowFold` property to
    // determine the opacity of its stops.  This way, when `belowFold`
    // changes, the gradient can animate the change to its opacity smoothly.
    // If you swap out the gradient with an opaque color, SwiftUI builds a
    // cross-fade between the solid color and the gradient, resulting in a
    // strange fade-out-and-back-in appearance.
    LinearGradient(
      stops: [
        .init(color: .black, location: 0.25),
        .init(color: .black.opacity(belowFold ? 1 : 0.3), location: 0.375),
        .init(color: .black.opacity(belowFold ? 1 : 0), location: 0.5),
      ],
      startPoint: .bottom, endPoint: .top
    )
  }
}
