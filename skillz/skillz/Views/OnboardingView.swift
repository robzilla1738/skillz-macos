import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    var onComplete: () -> Void
    var onOpenSettings: () -> Void

    @State private var selectedStep = 0

    private let steps = OnboardingStep.all

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
                VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        Button {
                            selectedStep = index
                        } label: {
                            HStack(spacing: SkillzSpacing.sm) {
                                Image(systemName: step.symbolName)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 22)
                                Text(step.title)
                                    .font(SkillzTypography.body)
                                Spacer()
                            }
                            .foregroundStyle(selectedStep == index ? Color.skillzCanvas : Color.skillzEmphasis)
                            .padding(.horizontal, SkillzSpacing.md)
                            .padding(.vertical, SkillzSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: SkillzSpacing.sm)
                                    .fill(selectedStep == index ? Color.skillzEmphasis : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 180)

                VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
                    Image(systemName: steps[selectedStep].symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.skillzEmphasis)
                        .frame(width: 48, height: 48)
                        .background(Color.skillzSelection, in: RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))

                    VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                        Text(steps[selectedStep].title)
                            .font(SkillzTypography.headline)
                            .foregroundStyle(Color.skillzEmphasis)

                        Text(steps[selectedStep].message)
                            .skillzBodySecondaryStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                        Toggle("Show waiting count in menu bar", isOn: $settings.showAgentCountInMenuBar)
                            .font(SkillzTypography.body)

                        Toggle("Show inspector by default", isOn: $settings.showInspector)
                            .font(SkillzTypography.body)
                    }
                    .padding(SkillzSpacing.lg)
                    .background(Color.skillzCanvas, in: RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius)
                            .strokeBorder(Color.skillzHairline, lineWidth: 1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("You can adjust sources, appearance, hooks, and editor settings any time.")
                    .skillzCaptionStyle()
                Spacer()
                Button("Settings") {
                    finish()
                    onOpenSettings()
                }
                .font(SkillzTypography.body)

                Button(selectedStep == steps.indices.last ? "Get Started" : "Next") {
                    if selectedStep == steps.indices.last {
                        finish()
                        onComplete()
                    } else {
                        selectedStep += 1
                    }
                }
                .font(SkillzTypography.body)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(SkillzSpacing.xl)
        .frame(width: 600, height: 430)
        .background(Color.skillzCanvas)
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
    }
}

private struct OnboardingStep {
    let title: String
    let message: String
    let symbolName: String

    static let all: [OnboardingStep] = [
        OnboardingStep(
            title: "Browse agent assets",
            message: "Skills collects skills, MCP servers, and plugins from the standard agent folders on this Mac so new users can see what is installed without hunting through dot-directories.",
            symbolName: "rectangle.stack"
        ),
        OnboardingStep(
            title: "Edit with context",
            message: "Select a skill to edit SKILL.md, update metadata, reveal its folder, rename it, or create a new skill in the right platform location.",
            symbolName: "pencil.and.outline"
        ),
        OnboardingStep(
            title: "Watch live agents",
            message: "The menu bar shows Codex, Claude Code, and Cursor activity. Waiting agents are counted so you can see when a session needs input.",
            symbolName: "dot.radiowaves.left.and.right"
        )
    ]
}
