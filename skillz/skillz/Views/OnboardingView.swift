import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: CatalogStore
    var onComplete: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.xl) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppBrand.name)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.skillzEmphasis)
                Spacer()
                Text("Agent Library")
                    .skillzCaptionStyle()
            }

            HStack(alignment: .top, spacing: SkillzSpacing.xl) {
                VStack(alignment: .leading, spacing: SkillzSpacing.md) {
                    HStack {
                        Text("Detected Tools")
                            .skillzHeadlineStyle()
                        Spacer()
                        SkillzTag(text: "\(store.detectedPlatforms.count) found", style: .muted)
                    }

                    if store.detectedPlatforms.isEmpty {
                        Text("No agents detected yet — you can still create and manage skills, and Skills will pick them up as you install tools.")
                            .skillzBodySecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                            ForEach(store.sourceStatuses) { status in
                                OnboardingSourceStatusRow(status: status)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(width: 410)

                VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
                    VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.skillzEmphasis)
                            .frame(width: 44, height: 44)
                            .background(Color.skillzSelection, in: RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))

                        Text("Agent Setup")
                            .skillzHeadlineStyle()

                        Text("Skills reads local agent folders immediately. Waiting-state hooks are installed only for tools that support them.")
                            .skillzBodySecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: SkillzSpacing.md) {
                        Toggle("Show waiting count in menu bar", isOn: $settings.showAgentCountInMenuBar)
                        Toggle("Show inspector by default", isOn: $settings.showInspector)
                        Toggle("Install or repair hooks automatically", isOn: $settings.autoInstallAgentHooks)
                            .disabled(!hasHookCapableTool)
                    }
                    .font(SkillzTypography.body)

                    HStack(alignment: .top, spacing: SkillzSpacing.md) {
                        Image(systemName: "eye")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.skillzEmphasis)
                            .frame(width: 28, height: 28)
                            .background(Color.skillzSelection, in: RoundedRectangle(cornerRadius: SkillzSpacing.sm))

                        VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                            Text("Quick Look previews")
                                .font(SkillzTypography.captionMedium)
                                .foregroundStyle(Color.skillzEmphasis)
                            Text("Finder spacebar previews get \(AppBrand.name) themes for markdown, JSON, logs, diffs, and more. Pick themes and fonts per file type from Quick Look Themes at the bottom of the sidebar — every type is optional, and one switch turns it all off.")
                                .skillzCaptionStyle()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(SkillzSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.skillzCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius)
                            .strokeBorder(Color.skillzHairline, lineWidth: 1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("Sources, appearance, hooks, and editor settings stay available after setup.")
                    .skillzCaptionStyle()
                Spacer()
                Button("Settings") {
                    finish()
                    onComplete()
                    onOpenSettings()
                }
                .font(SkillzTypography.body)

                Button("Get Started") {
                    finish()
                    onComplete()
                }
                .font(SkillzTypography.body)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(SkillzSpacing.xl)
        .frame(width: 720, height: 560)
        .background(Color.skillzCanvas)
        .onAppear {
            if store.snapshot.allItems.isEmpty {
                store.refresh()
            }
        }
    }

    private var hasHookCapableTool: Bool {
        store.sourceStatuses.contains { $0.isDetected && $0.hookSupport == .preciseWaitingState }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
    }
}

private struct OnboardingSourceStatusRow: View {
    let status: PlatformSourceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SkillzSpacing.sm) {
                PlatformBadge(platform: status.platform)
                Spacer(minLength: SkillzSpacing.sm)
                SkillzTag(text: status.statusLabel, style: status.isDetected ? .muted : .subtle)
                SkillzTag(text: "\(status.itemCount) items", style: .subtle)
            }

            HStack(alignment: .firstTextBaseline, spacing: SkillzSpacing.sm) {
                Text(status.detectionLabel)
                    .skillzCaptionStyle()
                    .lineLimit(1)
                Spacer(minLength: SkillzSpacing.sm)
                Text(status.hookSupportLabel)
                    .font(SkillzTypography.caption)
                    .foregroundStyle(Color.skillzSectionLabel)
            }

            if !status.isDetected {
                Text(status.notDetectedHint)
                    .font(SkillzTypography.caption)
                    .foregroundStyle(Color.skillzSectionLabel)
                    .lineLimit(2)
            }
        }
        .padding(SkillzSpacing.md)
        .background(Color.skillzCanvas, in: RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius)
                .strokeBorder(Color.skillzHairline, lineWidth: 1)
        }
    }
}
