import SwiftUI

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var opacity: Double = 0.55

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton shapes

struct SkeletonRow: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Date placeholder
            RoundedRectangle(cornerRadius: 3)
                .fill(colors.surfaceSecondary)
                .frame(width: 32, height: 12)

            // Ticker placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(colors.surfaceSecondary)
                .frame(width: 56, height: 26)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 160, height: 14)

                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 110, height: 12)
            }

            Spacer()

            // Value + rating
            VStack(alignment: .trailing, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 50, height: 14)

                RoundedRectangle(cornerRadius: 8)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 64, height: 18)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .shimmer()
    }
}

struct SkeletonDashboard: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                // Title
                HStack {
                    Text("Deals")
                        .font(.instrument(.bold, size: 28))
                        .foregroundStyle(colors.foreground)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Filter pills placeholder
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors.surfaceSecondary)
                        .frame(width: 90, height: 30)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors.surfaceSecondary)
                        .frame(width: 40, height: 30)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .shimmer()

                // Section header placeholder
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colors.surfaceSecondary)
                        .frame(width: 100, height: 12)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .shimmer()

                // Rows
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonRow()
                    Divider()
                        .overlay(colors.separator)
                        .padding(.leading, 16)
                }
            }
            .padding(.bottom, 32)
        }
    }
}

struct SkeletonPositionCard: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                cell
            }
        }
        .shimmer()
    }

    private var cell: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(colors.surfaceSecondary)
                .frame(width: 48, height: 10)
            RoundedRectangle(cornerRadius: 4)
                .fill(colors.surfaceSecondary)
                .frame(width: 80, height: 22)
            RoundedRectangle(cornerRadius: 3)
                .fill(colors.surfaceSecondary)
                .frame(width: 64, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }
}

struct SkeletonMiniPriceChart: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 40, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 48, height: 12)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors.surfaceSecondary)
                        .frame(width: 64, height: 22)
                }
                Spacer()
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(colors.surfaceSecondary)
                .frame(height: 120)
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors.surfaceSecondary)
                            .frame(width: 30, height: 8)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors.surfaceSecondary)
                            .frame(width: 40, height: 11)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
        .shimmer()
    }
}

struct SkeletonNewsRow: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Favicon
            RoundedRectangle(cornerRadius: 4)
                .fill(colors.surfaceSecondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                // Source
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 60, height: 10)

                // Title line 1
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(height: 12)

                // Title line 2
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.surfaceSecondary)
                    .frame(width: 180, height: 12)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .shimmer()
    }
}

struct SkeletonNews: View {
    @Environment(\.ddbxColors) private var colors

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                HStack {
                    Text("News")
                        .font(.instrument(.bold, size: 28))
                        .foregroundStyle(colors.foreground)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ForEach(0..<8, id: \.self) { _ in
                    SkeletonNewsRow()
                    Divider()
                        .overlay(colors.separator)
                        .padding(.leading, 56)
                }
            }
            .padding(.bottom, 32)
        }
    }
}
