import SwiftUI

/// Full-window Quick Look preferences page, opened from the top-bar
/// "Quick Look" button. Left: file-type list. Right: per-type options and a
/// large live sample rendered by the same `PreviewContentView` the Finder
/// extension uses.
struct QuickLookSettingsPage: View {
    let onClose: () -> Void

    @StateObject private var status = QuickLookExtensionStatus()
    @State private var selectedType: PreviewFileType = .markdown
    @State private var current: PreviewTypeSettings = .defaults(for: .markdown)
    @State private var masterEnabled = true

    private let store = PreviewSettingsStore()

    var body: some View {
        VStack(spacing: 0) {
            header
            if let issue = QuickLookExtensionStatus.bundleLocationIssue() {
                locationWarning(issue)
            }
            SkillzHairline()
            HStack(spacing: 0) {
                typeList
                    .frame(width: 230)
                Rectangle()
                    .fill(Color.skillzHairline)
                    .frame(width: 1)
                VStack(spacing: 0) {
                    optionsStrip
                    SkillzHairline()
                    preview
                }
            }
        }
        .skillzCanvas()
        .onAppear {
            status.refresh()
            // Idempotent: guarantees the extension finds per-type blobs even if
            // startup seeding was skipped (e.g. first run after an update).
            store.seedMissingDefaults()
            current = store.load(selectedType)
            masterEnabled = store.masterEnabled
        }
        .onChange(of: selectedType) { _, newType in
            current = store.load(newType)
        }
        .onChange(of: current) { _, newValue in
            store.save(newValue, for: selectedType)
        }
        .onChange(of: masterEnabled) { _, newValue in
            store.masterEnabled = newValue
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: SkillzSpacing.md) {
            VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                Text("Quick Look Previews")
                    .skillzNavigationTitleStyle()
                Text("Theme Finder spacebar previews per file type. Changes apply the next time a preview opens.")
                    .skillzCaptionStyle()
            }

            Spacer(minLength: SkillzSpacing.xl)

            Toggle("Skills previews", isOn: $masterEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(SkillzTypography.caption)
                .help("Off: every file type shows a plain, unthemed preview. The macOS-level switch lives in System Settings.")

            SkillzTag(text: status.state.label, style: status.state == .enabled ? .muted : .subtle)
                .help("Quick Look extension registration state")

            Button("Refresh Status") { status.refresh() }
                .buttonStyle(SkillzTextButtonStyle())
                .help("Re-check extension registration with PlugInKit")

            Button("System Settings…") { status.openSystemSettings() }
                .buttonStyle(SkillzTextButtonStyle())
                .help("Manage Quick Look extensions in System Settings")

            Button("Reset Quick Look") { status.resetQuickLook() }
                .buttonStyle(SkillzTextButtonStyle())
                .help("Clear cached previews so theme changes show up immediately")

            Button("Test Preview") { status.openTestPreview(for: selectedType) }
                .buttonStyle(SkillzTextButtonStyle())
                .help("Open a sample \(selectedType.displayName) file in the real Quick Look panel")

            Button("Done") { onClose() }
                .buttonStyle(SkillzTextButtonStyle(prominent: true))
                .keyboardShortcut(.cancelAction)
                .help("Back to the catalog (Esc)")
        }
        .padding(.horizontal, SkillzSpacing.xl)
        .padding(.vertical, SkillzSpacing.lg)
    }

    private func locationWarning(_ issue: String) -> some View {
        HStack(spacing: SkillzSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.small)
                .foregroundStyle(Color.skillzEmphasis)
            Text(issue)
                .skillzCaptionStyle()
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, SkillzSpacing.xl)
        .padding(.bottom, SkillzSpacing.md)
    }

    // MARK: File-type list

    private var typeList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                SkillzSectionHeader(title: "File Types")
                    .padding(.horizontal, SkillzSpacing.sm)
                    .padding(.top, SkillzSpacing.lg)
                    .padding(.bottom, SkillzSpacing.xs)

                ForEach(PreviewFileType.allCases) { type in
                    Button {
                        selectedType = type
                    } label: {
                        SkillzNavRow(
                            title: type.displayName,
                            trailing: ".\(type.allExtensions[0])",
                            isSelected: selectedType == type
                        )
                    }
                    .buttonStyle(SkillzNavRowButtonStyle(isSelected: selectedType == type))
                    .help("Applies to \(extensionList(for: type))")
                }
            }
            .padding(.horizontal, SkillzSpacing.sm)
            .padding(.bottom, SkillzSpacing.lg)
        }
        .background(Color.skillzCanvas)
    }

    private func extensionList(for type: PreviewFileType) -> String {
        type.allExtensions.map { ".\($0)" }.joined(separator: ", ")
    }

    // MARK: Options

    /// Installed fixed-pitch families, captured once per page appearance —
    /// enumerating fonts is not free and the set rarely changes mid-session.
    @State private var monospacedFamilies: [String] = PreviewFontResolver.installedMonospacedFamilies()

    /// Bridges optional `fontName` storage to the picker's non-optional tag.
    /// A stored family that is no longer installed selects System Mono, which
    /// mirrors how rendering falls back.
    private var fontSelection: Binding<String> {
        Binding {
            switch PreviewFontResolver.choice(for: current.fontName) {
            case .systemMono: return PreviewFontID.systemMono
            case .systemSans: return PreviewFontID.systemSans
            case .systemSerif: return PreviewFontID.systemSerif
            case .custom(let family): return family
            }
        } set: { newValue in
            current.fontName = newValue == PreviewFontID.systemMono ? nil : newValue
        }
    }

    private var showsTextOptions: Bool {
        if selectedType == .csv { return false }
        if selectedType == .markdown, current.markdownRenderedMode { return false }
        return true
    }

    /// Styling controls only apply when the master switch and the type's
    /// "Preview with Skills" toggle are both on.
    private var stylingEnabled: Bool {
        masterEnabled && current.enabled
    }

    /// What Finder will actually render right now — feeds the live preview.
    private var effectivePreviewSettings: PreviewTypeSettings {
        stylingEnabled ? current : .neutralFallback
    }

    private var footnote: String {
        var text = "Applies to \(extensionList(for: selectedType)). Types that share extensions (yml/yaml, csv/tsv, shell dialects) share one configuration."
        if !masterEnabled {
            text += " \(AppBrand.name) previews are off — every type shows a plain, unthemed preview."
        } else if !current.enabled {
            text += " This type shows a plain, unthemed preview."
        } else {
            text += " Recent macOS reserves some types — such as JSON and CSV — for the built-in preview; \(AppBrand.name) theming applies wherever third-party previews are allowed."
        }
        text += " To remove \(AppBrand.name) previews entirely, turn the extension off in System Settings — or just delete the app; the extension goes with it."
        return text
    }

    private var optionsStrip: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.md) {
            HStack(spacing: SkillzSpacing.xl) {
                Toggle("Preview with \(AppBrand.name)", isOn: $current.enabled)
                    .toggleStyle(.checkbox)
                    .disabled(!masterEnabled)
                    .help("Off: .\(selectedType.allExtensions[0]) files show a plain, system-style preview instead of \(AppBrand.name) theming")

                Toggle("Use custom theme", isOn: $current.useCustomTheme)
                    .toggleStyle(.checkbox)
                    .disabled(!stylingEnabled)

                HStack(spacing: SkillzSpacing.sm) {
                    Text("Theme")
                    Picker("Theme", selection: $current.preset) {
                        ForEach(PreviewThemePreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .disabled(!stylingEnabled || !current.useCustomTheme)
                }

                HStack(spacing: SkillzSpacing.sm) {
                    Text("Font")
                    Picker("Font", selection: fontSelection) {
                        Text("System Mono").tag(PreviewFontID.systemMono)
                        Text("System Sans").tag(PreviewFontID.systemSans)
                        Text("System Serif").tag(PreviewFontID.systemSerif)
                        Divider()
                        ForEach(monospacedFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                    .disabled(!stylingEnabled)
                    .help("Installed fixed-pitch fonts plus the system families. Missing fonts fall back to System Mono.")
                }

                HStack(spacing: SkillzSpacing.sm) {
                    Text("Font size")
                    Stepper(value: $current.fontSize, in: PreviewTypeSettings.fontSizeRange, step: 1) {
                        Text("\(Int(current.fontSize)) pt")
                            .skillzCaptionStyle()
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                .disabled(!stylingEnabled)

                Spacer()
            }

            HStack(spacing: SkillzSpacing.xl) {
                if selectedType == .markdown {
                    HStack(spacing: SkillzSpacing.sm) {
                        Text("Markdown shows")
                        Picker("Markdown shows", selection: $current.markdownRenderedMode) {
                            Text("Rendered").tag(true)
                            Text("Source").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    Toggle("Load remote images", isOn: $current.loadRemoteImages)
                        .toggleStyle(.checkbox)
                        .disabled(!stylingEnabled || !current.markdownRenderedMode)
                        .help("Off keeps previews network-free — remote images render as placeholders. Applies to Finder previews and the app's Rich Text view.")
                }

                if showsTextOptions {
                    Toggle("Wrap lines", isOn: $current.lineWrap)
                        .toggleStyle(.checkbox)
                    Toggle("Line numbers", isOn: $current.showLineNumbers)
                        .toggleStyle(.checkbox)
                }

                if selectedType.supportsPrettyPrint {
                    Toggle(
                        selectedType == .jsonl ? "Pretty-print each record" : "Pretty-print JSON",
                        isOn: $current.jsonPrettyPrint
                    )
                    .toggleStyle(.checkbox)
                }

                Spacer()
            }
            .disabled(!stylingEnabled)

            Text(footnote)
                .skillzCaptionStyle()
        }
        .font(SkillzTypography.body)
        .foregroundStyle(Color.skillzEmphasis)
        .padding(.horizontal, SkillzSpacing.xl)
        .padding(.vertical, SkillzSpacing.lg)
    }

    // MARK: Live preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
            HStack {
                SkillzSectionHeader(title: "Live Preview")
                Spacer()
                Text("Rendered by the same engine the Finder preview uses")
                    .skillzCaptionStyle()
            }

            PreviewContentView(
                text: selectedType.defaultSampleContent,
                type: selectedType,
                settings: effectivePreviewSettings
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius)
                    .strokeBorder(Color.skillzHairline, lineWidth: 1)
            }
        }
        .padding(SkillzSpacing.xl)
    }
}
