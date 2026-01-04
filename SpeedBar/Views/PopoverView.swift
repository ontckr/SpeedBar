import SwiftUI

// MARK: - Popover View

struct PopoverView: View {
    
    @StateObject private var viewModel = MeasurementViewModel()
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            contentView
                .frame(minHeight: 200)
            
            Divider()
            
            footerView
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            viewModel.restoreFromCacheIfAvailable()
        }
        .id(localization.currentLanguage)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "network")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(localization.localizedString("app.name"))
                .font(.headline)
            
            Spacer()
            
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(localization.localizedString("settings.title"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            idleView
        case .measuring(let liveData):
            measuringView(liveData)
        case .completed(let result):
            resultsView(result)
        case .noConnection:
            noConnectionView
        }
    }
    
    // MARK: - Idle State
    
    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "speedometer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Button {
                viewModel.startMeasurement()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text(localization.localizedString("measurement.start"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Measuring State (Real-time)
    
    private func measuringView(_ liveData: LiveMeasurementData) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                LiveSpeedCard(
                    title: localization.localizedString("result.downloadSpeed"),
                    value: liveData.formattedDownloadSpeed,
                    icon: "arrow.down.circle.fill",
                    color: .blue,
                    isActive: true
                )
                
                LiveSpeedCard(
                    title: localization.localizedString("result.uploadSpeed"),
                    value: liveData.formattedUploadSpeed,
                    icon: "arrow.up.circle.fill",
                    color: .green,
                    isActive: true
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text(localization.localizedString("measurement.measuring"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(localization.localizedString("measurement.description"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
        }
        .padding()
    }
    
    // MARK: - Results View
    
    private func resultsView(_ result: NetworkQualityResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                speedCard(
                    title: localization.localizedString("result.downloadSpeed"),
                    value: result.formattedDownloadSpeed,
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                
                speedCard(
                    title: localization.localizedString("result.uploadSpeed"),
                    value: result.formattedUploadSpeed,
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Button {
                viewModel.startMeasurement()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(localization.localizedString("measurement.startAgain"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func speedCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
    
    // MARK: - No Connection View
    
    private var noConnectionView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text(localization.localizedString("error.noInternet"))
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.startMeasurement()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(localization.localizedString("measurement.startAgain"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text(localization.localizedString("settings.quit"))
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Live Speed Card with Gradient Animation

struct LiveSpeedCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isActive: Bool
    
    @State private var gradientOffset: CGFloat = -1
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                
                if isActive {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                color.opacity(0),
                                color.opacity(0.15),
                                color.opacity(0.25),
                                color.opacity(0.15),
                                color.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 1.5)
                        .offset(x: gradientOffset * geometry.size.width)
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                startAnimation()
            } else {
                gradientOffset = -1
            }
        }
    }
    
    private func startAnimation() {
        gradientOffset = -1
        withAnimation(
            Animation.linear(duration: 1.2)
                .repeatForever(autoreverses: false)
        ) {
            gradientOffset = 1.5
        }
    }
}

#Preview {
    PopoverView()
}
