import SwiftUI

struct AgentNotchOpenView: View {
    @ObservedObject var agentStore: AgentSessionStore
    var hookStatuses: [AgentHookStatus]
    var hasPhysicalNotch: Bool
    var onClose: () -> Void
    var onReveal: (AgentSession) -> Void
    var onOpenSkillz: () -> Void
    var onRefresh: () -> Void
    var onInstallHooks: () -> Void

    private var displayRows: [AgentSession] {
        agentStore.summary.notchDisplaySessions
    }

    private var needsHooks: Bool {
        hookStatuses.contains { $0.status != .installed && $0.status != .unsupported }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            NotchHairline()
            content
            if needsHooks {
                hooksPrompt
            }
            NotchHairline()
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, hasPhysicalNotch ? 6 : 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Agents")
                .font(NotchMonochromeStyle.headerFont)
                .foregroundStyle(NotchMonochromeStyle.muted)
                .textCase(.uppercase)
                .tracking(0.6)

            Spacer(minLength: 4)

            Text(headerCountLabel)
                .font(NotchMonochromeStyle.captionFont)
                .foregroundStyle(NotchMonochromeStyle.faint)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchMonochromeStyle.muted)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close agent panel")
        }
        .padding(.bottom, 8)
    }

    private var headerCountLabel: String {
        let count = displayRows.count
        if count == 0 { return "None active" }
        if agentStore.summary.needsInputCount > 0 {
            return "\(agentStore.summary.needsInputCount) waiting"
        }
        if agentStore.summary.hasNotchAttention {
            return count == 1 ? "1 stopped" : "\(count) stopped"
        }
        return "\(count) active"
    }

    @ViewBuilder
    private var content: some View {
        if displayRows.isEmpty {
            Text("No active sessions")
                .font(NotchMonochromeStyle.bodyFont)
                .foregroundStyle(NotchMonochromeStyle.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(displayRows.enumerated()), id: \.element.id) { index, session in
                    sessionRow(session)
                    if index < displayRows.count - 1 {
                        NotchHairline()
                            .padding(.leading, 36)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var hooksPrompt: some View {
        Button(action: onInstallHooks) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .medium))
                Text("Install hooks")
                    .font(NotchMonochromeStyle.bodyFont)
            }
            .foregroundStyle(NotchMonochromeStyle.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .help("Install activity hooks for permission alerts")
        .accessibilityLabel("Install activity hooks for permission alerts")
    }

    private var footer: some View {
        HStack(spacing: 0) {
            footerButton("Open \(AppBrand.name)", action: onOpenSkillz)
            NotchFooterDivider()
            footerButton("Refresh", action: onRefresh)
        }
        .padding(.top, 6)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(NotchMonochromeStyle.bodyFont)
            .foregroundStyle(NotchMonochromeStyle.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .buttonStyle(.plain)
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        Button {
            onReveal(session)
        } label: {
            HStack(spacing: 10) {
                platformIcon(session)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.platform.displayName)
                        .font(NotchMonochromeStyle.titleFont)
                        .foregroundStyle(NotchMonochromeStyle.ink)
                        .lineLimit(1)

                    Text(subtitle(for: session))
                        .font(NotchMonochromeStyle.bodyFont)
                        .foregroundStyle(NotchMonochromeStyle.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

                NotchStatusPill(state: session.state)
                    .fixedSize()
                    .layoutPriority(1)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchRowButtonStyle())
        .help("Open session")
        .accessibilityLabel("\(session.platform.displayName), \(subtitle(for: session)), \(session.state.displayName)")
    }

    private func platformIcon(_ session: AgentSession) -> some View {
        ZStack {
            Circle()
                .strokeBorder(NotchMonochromeStyle.hairline, lineWidth: 1)
                .background(Circle().fill(NotchMonochromeStyle.rowFill))
            PlatformBrandIcon(
                platform: session.platform,
                size: 14,
                opacity: NotchMonochromeStyle.iconOpacity(for: session.state)
            )
        }
        .frame(width: 26, height: 26)
    }

    private func subtitle(for session: AgentSession) -> String {
        if let cwd = session.cwd, !cwd.isEmpty {
            let folder = (cwd as NSString).lastPathComponent
            if !folder.isEmpty { return folder }
        }

        let title = session.listTitle
        if let project = projectName(from: title) {
            return project
        }

        let platform = session.platform.displayName
        if title.caseInsensitiveCompare(platform) != .orderedSame,
           title.caseInsensitiveCompare(platform.lowercased()) != .orderedSame {
            return title
        }

        return "Session active"
    }

    private func projectName(from title: String) -> String? {
        if let range = title.range(of: "-Code-") {
            let name = String(title[range.upperBound...])
            return name.isEmpty ? nil : name
        }
        if title.hasPrefix("Users-"), title.contains("-") {
            return title.split(separator: "-").last.map(String.init)
        }
        return nil
    }
}

private struct NotchHairline: View {
    var body: some View {
        Rectangle()
            .fill(NotchMonochromeStyle.hairline)
            .frame(height: 1)
    }
}

private struct NotchFooterDivider: View {
    var body: some View {
        Rectangle()
            .fill(NotchMonochromeStyle.hairline)
            .frame(width: 1, height: 14)
    }
}

private struct NotchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? NotchMonochromeStyle.rowFillHover
                    : Color.clear
            )
    }
}
