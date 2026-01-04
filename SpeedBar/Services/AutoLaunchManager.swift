import Foundation
import ServiceManagement
import Combine

@MainActor
final class AutoLaunchManager: ObservableObject {
    
    static let shared = AutoLaunchManager()
    
    private let firstLaunchKey = "SpeedBar.HasLaunchedBefore"
    private let autoLaunchPreferenceKey = "SpeedBar.AutoLaunchEnabled"
    
    @Published private(set) var isAutoLaunchEnabled: Bool = false
    @Published private(set) var isFirstLaunch: Bool = false
    
    private init() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: firstLaunchKey)
        loadCurrentState()
    }
    
    // MARK: - Public Methods
    
    func requestAutoLaunchOnFirstLaunch() {
        UserDefaults.standard.set(true, forKey: firstLaunchKey)
        isFirstLaunch = false
        setAutoLaunchEnabled(true)
    }
    
    func setAutoLaunchEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            
            UserDefaults.standard.set(enabled, forKey: autoLaunchPreferenceKey)
            isAutoLaunchEnabled = enabled
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") auto-launch: \(error.localizedDescription)")
            loadCurrentState()
        }
    }
    
    func loadCurrentState() {
        let status = SMAppService.mainApp.status
        
        switch status {
        case .enabled:
            isAutoLaunchEnabled = true
        case .notRegistered, .notFound:
            isAutoLaunchEnabled = false
        case .requiresApproval:
            isAutoLaunchEnabled = false
        @unknown default:
            isAutoLaunchEnabled = false
        }
        
        UserDefaults.standard.set(isAutoLaunchEnabled, forKey: autoLaunchPreferenceKey)
    }
}
