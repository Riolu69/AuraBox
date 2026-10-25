//
//  PosterMetrics.swift
//  SceneBox
//

#if os(iOS)
import SwiftUI

enum PosterMetrics {
    static func shelfWidth(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        if Platform.isMac { return 180 }          // big window, big posters
        // Чуть-чуть увеличим ширину постера для более "дорогого" вида на iPhone
        return sizeClass == .regular ? 168 : 120 
    }

    static func gridColumns(_ sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let regular = sizeClass == .regular
        if Platform.isMac {
            return [GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 24)]
        }
        return [GridItem(.adaptive(minimum: regular ? 150 : 112,
                                   maximum: regular ? 200 : 136),
                         // Увеличили отступы (spacing: 16 вместо 12), чтобы поместились красивые тени карточек
                         spacing: regular ? 24 : 16)]
    }
}
#endif