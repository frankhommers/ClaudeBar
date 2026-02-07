import SwiftUI
import Domain

/// A card view displaying a single quota metric.
/// Directly uses the rich domain model - no ViewModel needed.
struct QuotaCardView: View {
    let quota: UsageQuota

    @State private var settings = AppSettings.shared

    private var displayMode: UsageDisplayMode {
        settings.usageDisplayMode
    }

    /// Effective display mode: falls back to .used when pace is unknown
    private var effectiveDisplayMode: UsageDisplayMode {
        if displayMode == .pace && quota.pace == .unknown {
            return .used
        }
        return displayMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(quota.quotaType.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Percentage
            Text("\(Int(quota.displayPercent(mode: effectiveDisplayMode)))%")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(effectiveDisplayMode == .pace ? quota.pace.displayColor : quota.status.displayColor)

            // Progress bar
            GeometryReader { geometry in
                let progressPercent = quota.displayProgressPercent(mode: effectiveDisplayMode)
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)

                    // Fill (clamp width to 0-100%)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(quota.status.displayColor)
                        .frame(width: geometry.size.width * max(0, min(100, progressPercent)) / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}
