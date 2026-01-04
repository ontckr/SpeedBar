import Foundation
import Combine

// MARK: - Measurement State

enum MeasurementState: Equatable {
    case idle
    case measuring(LiveMeasurementData)
    case completed(NetworkQualityResult)
    case noConnection
    
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    
    var isMeasuring: Bool {
        if case .measuring = self { return true }
        return false
    }
    
    var result: NetworkQualityResult? {
        if case .completed(let result) = self { return result }
        return nil
    }
    
    var liveData: LiveMeasurementData? {
        if case .measuring(let data) = self { return data }
        return nil
    }
}

// MARK: - Measurement View Model

@MainActor
final class MeasurementViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var state: MeasurementState = .idle
    @Published private(set) var cachedResult: NetworkQualityResult?
    
    private let service = NetworkQualityService()
    private var cacheTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let cacheExpirationInterval: TimeInterval = 600
    
    // MARK: - Initialization
    
    init() {
        loadCachedResult()
        setupLiveDataObserver()
    }
    
    // MARK: - Public Methods
    
    func startMeasurement() {
        guard !state.isMeasuring else { return }
        
        state = .measuring(LiveMeasurementData(phase: .starting))
        
        Task {
            do {
                let result = try await service.startMeasurement()
                handleMeasurementSuccess(result)
            } catch let error as MeasurementError {
                handleMeasurementError(error)
            } catch {
                state = .idle
            }
        }
    }
    
    func restoreFromCacheIfAvailable() {
        guard !state.isMeasuring else { return }
        
        if let cached = cachedResult, isCacheValid(cached) {
            state = .completed(cached)
        } else {
            cachedResult = nil
            state = .idle
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLiveDataObserver() {
        service.$liveData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveData in
                guard let self = self else { return }
                if case .measuring = self.state {
                    self.state = .measuring(liveData)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleMeasurementSuccess(_ result: NetworkQualityResult) {
        cachedResult = result
        state = .completed(result)
        saveToCache(result)
        startCacheExpirationTimer(from: result.timestamp)
    }
    
    private func handleMeasurementError(_ error: MeasurementError) {
        switch error {
        case .noNetworkConnection:
            state = .noConnection
        case .cancelled:
            if let cached = cachedResult, isCacheValid(cached) {
                state = .completed(cached)
            } else {
                state = .idle
            }
        default:
            state = .idle
        }
    }
    
    // MARK: - Cache Management
    
    private func saveToCache(_ result: NetworkQualityResult) {
        let cacheData = CachedMeasurement(
            uploadSpeed: result.uploadSpeed,
            downloadSpeed: result.downloadSpeed,
            uploadResponsiveness: result.uploadResponsiveness,
            downloadResponsiveness: result.downloadResponsiveness,
            idleLatency: result.idleLatency,
            uploadLatency: result.uploadLatency,
            downloadLatency: result.downloadLatency,
            rawOutput: result.rawOutput,
            timestamp: result.timestamp
        )
        
        if let encoded = try? JSONEncoder().encode(cacheData) {
            UserDefaults.standard.set(encoded, forKey: "SpeedBar.CachedMeasurement")
        }
    }
    
    private func loadCachedResult() {
        guard let data = UserDefaults.standard.data(forKey: "SpeedBar.CachedMeasurement"),
              let cached = try? JSONDecoder().decode(CachedMeasurement.self, from: data) else {
            return
        }
        
        let result = NetworkQualityResult(
            uploadSpeed: cached.uploadSpeed,
            downloadSpeed: cached.downloadSpeed,
            uploadResponsiveness: cached.uploadResponsiveness,
            downloadResponsiveness: cached.downloadResponsiveness,
            idleLatency: cached.idleLatency,
            uploadLatency: cached.uploadLatency,
            downloadLatency: cached.downloadLatency,
            rawOutput: cached.rawOutput,
            timestamp: cached.timestamp
        )
        
        if isCacheValid(result) {
            cachedResult = result
            state = .completed(result)
            startCacheExpirationTimer(from: result.timestamp)
        } else {
            clearCache()
        }
    }
    
    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: "SpeedBar.CachedMeasurement")
        cacheTimer?.invalidate()
        cacheTimer = nil
    }
    
    private func isCacheValid(_ result: NetworkQualityResult) -> Bool {
        let elapsed = Date().timeIntervalSince(result.timestamp)
        return elapsed < cacheExpirationInterval
    }
    
    private func startCacheExpirationTimer(from timestamp: Date) {
        cacheTimer?.invalidate()
        
        let elapsed = Date().timeIntervalSince(timestamp)
        let remaining = max(0, cacheExpirationInterval - elapsed)
        
        cacheTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.cachedResult = nil
                if case .completed = self?.state {
                    self?.state = .idle
                }
                self?.clearCache()
            }
        }
    }
}

// MARK: - Cached Measurement (Codable)

private struct CachedMeasurement: Codable {
    let uploadSpeed: Double?
    let downloadSpeed: Double?
    let uploadResponsiveness: Int?
    let downloadResponsiveness: Int?
    let idleLatency: Double?
    let uploadLatency: Double?
    let downloadLatency: Double?
    let rawOutput: String
    let timestamp: Date
}
