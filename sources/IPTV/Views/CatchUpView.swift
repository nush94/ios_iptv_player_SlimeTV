//
//  CatchUpView.swift
//  IPTV
//
//  Catch-up / timeshift: lists a channel's recently-aired programs (within the
//  provider's archive window) and plays them from the start via the timeshift URL.
//

import IPTVModels
import SwiftUI

private struct CatchUpProgram: Identifiable {
  let id = UUID()
  let title: String
  let start: Date
  let end: Date
  var minutes: Int { max(Int(end.timeIntervalSince(start) / 60), 1) }
}

struct CatchUpView: View {
  let channel: CachedStream

  @Environment(\.dismiss) private var dismiss
  @State private var programs: [CatchUpProgram] = []
  @State private var isLoading = true
  @State private var showPlayer = false
  @State private var selectedURL: URL?

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          ProgressView().tint(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if programs.isEmpty {
          ContentUnavailableView(
            "No catch-up available",
            systemImage: "clock.arrow.circlepath",
            description: Text("This channel has no recently-aired programs in its \(max(channel.archiveDays, 1))-day archive.")
          )
        } else {
          ScrollView {
            LazyVStack(spacing: 10) {
              ForEach(programs) { program in
                Button { play(program) } label: { row(program) }
                  .buttonStyle(.plain)
              }
            }
            .padding(16)
          }
        }
      }
      .background(Color.black.ignoresSafeArea())
      .navigationTitle("Catch-up")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }.foregroundStyle(.white)
        }
      }
      .preferredColorScheme(.dark)
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedURL != nil
      }, set: { showPlayer = $0 })) {
        if let selectedURL {
          ViewPlayerContent(mediaURL: selectedURL, id: channel.id, kind: .live)
            .ignoresSafeArea()
        }
      }
      .task { await load() }
    }
  }

  private func row(_ program: CatchUpProgram) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(program.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        Text("\(timeText(program.start)) – \(timeText(program.end)) · \(dayText(program.start))")
          .font(.caption.weight(.medium))
          .foregroundStyle(.white.opacity(0.55))
      }

      Spacer(minLength: 8)

      Image(systemName: "play.fill")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.black)
        .frame(width: 32, height: 32)
        .background(.white, in: Circle())
    }
    .padding(12)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func play(_ program: CatchUpProgram) {
    guard let url = APIManager.shared.timeshiftURL(
      streamId: channel.id,
      start: program.start,
      durationMinutes: program.minutes
    ) else { return }
    selectedURL = url
    showPlayer = true
  }

  private func load() async {
    defer { isLoading = false }
    let listings = (try? await fetchSchedule()) ?? []
    let now = Date()
    let windowStart = Calendar.current.date(byAdding: .day, value: -max(channel.archiveDays, 1), to: now) ?? now

    programs = listings.compactMap { listing -> CatchUpProgram? in
      guard let start = listing.startDate, let end = listing.endDate else { return nil }
      guard end <= now, start >= windowStart else { return nil } // already aired & still in archive
      return CatchUpProgram(title: listing.decodedTitle, start: start, end: end)
    }
    .sorted { $0.start > $1.start } // most recent first
  }

  private func fetchSchedule() async throws -> [EPGListing] {
    try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchSimpleDataTable(streamId: channel.id) { result in
        continuation.resume(with: result.map(\.epgListings))
      }
    }
  }

  private func timeText(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f.string(from: date)
  }

  private func dayText(_ date: Date) -> String {
    Calendar.current.isDateInToday(date) ? "Today" : {
      let f = DateFormatter()
      f.dateFormat = "EEE"
      return f.string(from: date)
    }()
  }
}
