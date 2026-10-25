//
//  TVPosterCard.swift
//  SceneBox
//

#if os(tvOS)
import SwiftUI

struct TVPosterCard: View {
    let item: MediaResult
    var width: CGFloat = 260
    @Environment(WatchlistStore.self) private var watchlist: WatchlistStore?

    var body: some View {
        PosterImage(url: item.posterURL)
            .frame(width: width)
            .overlay(alignment: .topTrailing) {
                if watchlist?.contains(item.id) == true {
                    Image(systemName: "bookmark.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(9)
                        // Меняем глухой черный на фирменное полупрозрачное стекло Apple
                        .background(.regularMaterial, in: Circle())
                        .environment(\.colorScheme, .dark)
                        .padding(10)
                }
            }
            // Добавляем плавные скругления (continuous) для идеального контура
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(item.name)
    }
}
#endif