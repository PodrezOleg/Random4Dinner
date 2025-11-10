//
//  BackgroundView.swift
//  RandomForDinner
//
//  Created by Oleg Podrez on 18.10.25.
//

import SwiftUI

/// Represents coarse time-of-day buckets used for theming.
enum TimeOfDay: CaseIterable, Equatable {
    case morning     // until 11:00
    case day         // 11:00–16:00
    case evening     // 16:00–22:00
    case night       // 22:00–06:00

    /// Resolve a TimeOfDay for a given date in the current calendar/time zone.
    static func from(date: Date = .now, calendar: Calendar = .current) -> TimeOfDay {
        let comps = calendar.dateComponents(in: calendar.timeZone, from: date)
        let hour = comps.hour ?? 0

        switch hour {
        case 0..<6:
            return .night
        case 6..<11:
            return .morning
        case 11..<16:
            return .day
        case 16..<22:
            return .evening
        default:
            return .night
        }
    }

    /// Asset image name to use for each time of day.
    var assetImageName: String {
        switch self {
        case .morning: return "morning"
        case .day:     return "lunch"
        case .evening: return "dinner" // ensure this matches your asset name exactly
        case .night:   return "night"
        }
    }
}

struct BackgroundView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let timeOfDay = TimeOfDay.from(date: context.date)
            ZStack {
               
                if let uiImage = UIImage(named: timeOfDay.assetImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    // Fallback background so it’s obvious when an asset is missing.
                    Color.black.opacity(0.6)
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: timeOfDay)
        }
    }
}

#Preview("BackgroundView dynamic") {
    BackgroundView()
        .previewLayout(.sizeThatFits)
}
