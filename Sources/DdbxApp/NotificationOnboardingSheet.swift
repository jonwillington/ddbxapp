import SwiftUI

struct NotificationOnboardingSheet: View {
    @Environment(\.ddbxColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pushManager: PushManager

    @State private var requesting = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(colors.accent)
                    .padding(.bottom, 4)

                Text("Get notifications sent straight to you")
                    .font(.instrument(.bold, size: 24))
                    .foregroundStyle(colors.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Be first to see standout director buys as they're disclosed, plus an optional morning and close digest summarising the day's deals. You can fine-tune any of this later in Settings.")
                    .font(.instrument(size: 15))
                    .foregroundStyle(colors.foreground.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 16)

                Button(action: enable) {
                    ZStack {
                        if requesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable")
                                .font(.instrument(.semiBold, size: 17))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(requesting)
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 24)

            closeButton
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .presentationDetents([.medium])
        .ddbxPresentationBackground(colors.background)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.foreground.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(colors.surfaceSecondary, in: Circle())
        }
        .accessibilityLabel("Close")
    }

    private func enable() {
        requesting = true
        Task {
            await pushManager.requestPermission()
            requesting = false
            dismiss()
        }
    }
}
