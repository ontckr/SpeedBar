import SwiftUI

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var autoLaunchManager = AutoLaunchManager.shared
    @ObservedObject private var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    aboutSection
                    Divider()
                    preferencesSection
                    Divider()
                    legalSection
                }
                .padding(20)
            }
        }
        .frame(width: 360, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .id(localization.currentLanguage)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text(localization.localizedString("settings.title"))
                .font(.headline)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localization.localizedString("settings.about"), systemImage: "info.circle")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.localizedString("app.name"))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("\(localization.localizedString("settings.version")) \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(macOSCompatibilityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(localization.localizedString("settings.preferences"), systemImage: "slider.horizontal.3")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(localization.localizedString("settings.language"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            localization.setLanguage(language)
                        } label: {
                            Text(language.flag)
                                .font(.system(size: 24))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(localization.currentLanguage == language ? 
                                              Color.accentColor.opacity(0.2) : 
                                              Color(nsColor: .controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(localization.currentLanguage == language ? 
                                               Color.accentColor : 
                                               Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(language.displayName)
                    }
                }
            }
            .padding(.leading, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { autoLaunchManager.isAutoLaunchEnabled },
                    set: { autoLaunchManager.setAutoLaunchEnabled($0) }
                )) {
                    Text(localization.localizedString("settings.autoLaunch"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(localization.localizedString("settings.autoLaunchDescription"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localization.localizedString("settings.terms"), systemImage: "doc.text")
                .font(.headline)
            
            Text(localization.localizedString("settings.termsContent"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var macOSCompatibilityText: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(localization.localizedString("settings.compatibility")): macOS \(osVersion.majorVersion).\(osVersion.minorVersion)+"
    }
}

#Preview {
    SettingsView()
}
