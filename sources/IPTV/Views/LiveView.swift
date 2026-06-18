//
//  LiveView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

public struct LiveView: View {
  @ObservedObject var useCase: LiveUseCase
  @State private var belowFold = false
  private var showcaseHeight: CGFloat = 800

  @State private var selectedCategoryId: String?
  @State private var expandedGroups: Set<String> = []
  @State private var showPlayer: Bool = false
  @State private var selectedStreamURL: URL? = nil

  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  public var kindMedia: KindMedia

  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.live.rawValue })) var categories
  @ObservedResults(CachedStream.self, where: ({ $0.section == KindMedia.live.rawValue })) var channels

  private var selectedChannels: [CachedStream] {
    guard let selectedCategoryId else {
      return Array(channels).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    return channels
      .filter { $0.categoryId == selectedCategoryId }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private var channelGroups: [ChannelGroup] {
    var order: [String] = []
    var map: [String: [CachedStream]] = [:]

    for channel in selectedChannels {
      let key = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
      if map[key] == nil {
        order.append(key)
        map[key] = []
      }
      map[key]?.append(channel)
    }

    return order.compactMap { key in
      guard let streams = map[key], !streams.isEmpty else { return nil }
      return ChannelGroup(name: key, streams: streams)
    }
  }

  private var selectedCategoryTitle: String {
    guard let selectedCategoryId,
          let category = categories.first(where: { $0.id == selectedCategoryId })
    else {
      return "All Channels"
    }

    return category.name.formatted()
  }

  public init(kindMedia: KindMedia) {
    self.kindMedia = kindMedia
    self.useCase = LiveUseCase(
      kindMedia: kindMedia,
      apiManager: APIManager.shared,
      cacheManager: CacheManager.shared
    )
  }

  public var body: some View {
    NavigationStack {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 24) {
          if categories.count == 0 || channels.count == 0 {
            LibraryEmptyStateView(
              systemImage: "sparkles.tv",
              title: categories.count == 0 ? "No live categories yet" : "No channels loaded yet",
              message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
            )
            .padding(.top, 48)
          } else {
            LiveCategoryHeader(
              categories: categories,
              selectedCategoryId: $selectedCategoryId
            )

            makeSectionFavori()

            VStack(alignment: .leading, spacing: 14) {
              HStack(alignment: .lastTextBaseline) {
                Text(selectedCategoryTitle)
                  .font(.system(size: 24, weight: .bold))
                  .foregroundStyle(.white)
                  .lineLimit(1)

                Spacer()

                Text("\(channelGroups.count)")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.56))
              }
              .padding(.horizontal, 2)

              LazyVStack(spacing: 10) {
                ForEach(channelGroups) { group in
                  LiveChannelGroupRow(
                    group: group,
                    categoryName: categoryName(for: group.representative.categoryId),
                    isExpanded: expandedGroups.contains(group.id),
                    onTapPrimary: { handleGroupTap(group) },
                    onPlayStream: { open($0) }
                  )
                }
              }
            }
          }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
      }
      .background(alignment: .top) {
        HeroHeaderView(belowFold: true)
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .alert("Error", isPresented: $useCase.showErrorAlert) {
        Button("OK", role: .cancel) {
        }
      } message: {
        Text(errorMessage)
      }
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedStreamURL != nil
      }, set: { showPlayer = $0 })) {
        GeometryReader { _ in
          ViewPlayerContent(mediaURL: selectedStreamURL!, id: currentID, kind: .live)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
      }
    }
  }

  @State private var currentID: Int = 9999

  private func open(_ stream: CachedStream) {
    currentID = stream.id
    selectedStreamURL = URL(string: stream.streamURL())
    showPlayer = true
  }

  private func handleGroupTap(_ group: ChannelGroup) {
    if group.streams.count > 1 {
      withAnimation(.snappy) {
        if expandedGroups.contains(group.id) {
          expandedGroups.remove(group.id)
        } else {
          expandedGroups.insert(group.id)
        }
      }
    } else {
      open(group.representative)
    }
  }

  private func categoryName(for categoryId: String) -> String {
    categories.first(where: { $0.id == categoryId })?.name.formatted() ?? "Live TV"
  }

  @ViewBuilder
  private func makeSectionFavori() -> some View {
    Section {
      FavoriLiveShelf(kindMedia: kindMedia) { stream in
        currentID = stream.id
        selectedStreamURL = URL(string: stream.streamURL())
        showPlayer = true
      }
    }
  }

  @ViewBuilder
  func makeSection(for category: CategoryEntity) -> some View {
    Section {
      LiveShelf(category: category, kindMedia: kindMedia) { stream in
        currentID = stream.id
        selectedStreamURL = URL(string: stream.streamURL())
        showPlayer = true
      }
    }
    .id(category.id)
  }
}

private struct LiveCategoryHeader: View {
  let categories: Results<CategoryEntity>
  @Binding var selectedCategoryId: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .lastTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Live TV")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)

          Text("Choose a category, then tap a channel to watch.")
            .font(.callout.weight(.medium))
            .foregroundStyle(.white.opacity(0.62))
        }

        Spacer()
      }

      CategoryFilterBar(categories: categories, selectedCategoryId: $selectedCategoryId)
    }
    .padding(.top, 4)
    .padding(.bottom, 2)
  }
}

private struct ChannelGroup: Identifiable {
  let name: String
  let streams: [CachedStream]

  var id: String { name }
  var representative: CachedStream { streams[0] }
  var isPile: Bool { streams.count > 1 }
}

private struct LiveChannelGroupRow: View {
  let group: ChannelGroup
  let categoryName: String
  let isExpanded: Bool
  let onTapPrimary: () -> Void
  let onPlayStream: (CachedStream) -> Void

  var body: some View {
    VStack(spacing: 6) {
      Button(action: onTapPrimary) {
        HStack(spacing: 14) {
          channelImage

          VStack(alignment: .leading, spacing: 5) {
            Text(group.name)
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
              Text(categoryName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)

              if group.isPile {
                Text("\(group.streams.count) sources")
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(.red)
              }
            }
          }

          Spacer(minLength: 10)

          trailingControl
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isExpanded ? .red.opacity(0.4) : .white.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)

      if group.isPile, isExpanded {
        HStack(spacing: 12) {
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(.red.opacity(0.55))
            .frame(width: 3)

          VStack(spacing: 6) {
            ForEach(Array(group.streams.enumerated()), id: \.element.id) { index, stream in
              Button {
                onPlayStream(stream)
              } label: {
                HStack(spacing: 10) {
                  Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))

                  Text("Source \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                  Spacer()

                  Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(.white, in: Circle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.leading, 14)
        .padding(.top, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  @ViewBuilder
  private var trailingControl: some View {
    if group.isPile {
      HStack(spacing: 6) {
        Text("\(group.streams.count)")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)

        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white.opacity(0.7))
      }
      .frame(width: 52, height: 34)
      .background(.white.opacity(0.12), in: Capsule())
    } else {
      Image(systemName: "play.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.black)
        .frame(width: 34, height: 34)
        .background(.white, in: Circle())
    }
  }

  @ViewBuilder
  private var channelImage: some View {
    if let imagePath = group.representative.getImage(),
       let url = URL(string: imagePath),
       !imagePath.isEmpty {
      AsyncImage(url: url, placeholder: {
        placeholderImage
      }, content: { image in
        image
          .resizable()
          .scaledToFit()
          .padding(7)
      })
      .frame(width: 58, height: 58)
      .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    } else {
      placeholderImage
    }
  }

  private var placeholderImage: some View {
    Image(systemName: "tv")
      .font(.system(size: 23, weight: .semibold))
      .foregroundStyle(.white.opacity(0.74))
      .frame(width: 58, height: 58)
      .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
