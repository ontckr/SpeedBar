import Foundation
import Combine

struct LiveMeasurementData: Equatable {
    var currentDownloadSpeed: Double?
    var currentUploadSpeed: Double?
    var phase: MeasurementPhase
    
    enum MeasurementPhase: Equatable {
        case starting
        case downloadTest
        case uploadTest
        case finishing
    }
    
    var formattedDownloadSpeed: String {
        guard let speed = currentDownloadSpeed else { return "—" }
        return formatSpeed(speed)
    }
    
    var formattedUploadSpeed: String {
        guard let speed = currentUploadSpeed else { return "—" }
        return formatSpeed(speed)
    }
    
    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1000 {
            return String(format: "%.1f Gbps", mbps / 1000)
        } else if mbps >= 100 {
            return String(format: "%.0f Mbps", mbps)
        } else if mbps >= 10 {
            return String(format: "%.1f Mbps", mbps)
        } else {
            return String(format: "%.2f Mbps", mbps)
        }
    }
}

struct NetworkQualityResult: Equatable {
    let uploadSpeed: Double?
    let downloadSpeed: Double?
    let uploadResponsiveness: Int?
    let downloadResponsiveness: Int?
    let idleLatency: Double?
    let uploadLatency: Double?
    let downloadLatency: Double?
    let rawOutput: String
    let timestamp: Date
    
    var formattedUploadSpeed: String {
        guard let speed = uploadSpeed else { return "N/A" }
        return formatSpeed(speed)
    }
    
    var formattedDownloadSpeed: String {
        guard let speed = downloadSpeed else { return "N/A" }
        return formatSpeed(speed)
    }
    
    var formattedUploadResponsiveness: String {
        guard let rpm = uploadResponsiveness else { return "N/A" }
        return "\(rpm) RPM"
    }
    
    var formattedDownloadResponsiveness: String {
        guard let rpm = downloadResponsiveness else { return "N/A" }
        return "\(rpm) RPM"
    }
    
    var formattedIdleLatency: String {
        guard let latency = idleLatency else { return "N/A" }
        return String(format: "%.1f ms", latency)
    }
    
    var formattedUploadLatency: String {
        guard let latency = uploadLatency else { return "N/A" }
        return String(format: "%.1f ms", latency)
    }
    
    var formattedDownloadLatency: String {
        guard let latency = downloadLatency else { return "N/A" }
        return String(format: "%.1f ms", latency)
    }
    
    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1000 {
            return String(format: "%.2f Gbps", mbps / 1000)
        } else if mbps >= 100 {
            return String(format: "%.0f Mbps", mbps)
        } else if mbps >= 10 {
            return String(format: "%.1f Mbps", mbps)
        } else {
            return String(format: "%.2f Mbps", mbps)
        }
    }
}

enum MeasurementError: Error {
    case binaryNotFound
    case executionFailed
    case timeout
    case noNetworkConnection
    case parseError
    case cancelled
}

@MainActor
final class NetworkQualityService: ObservableObject {
    
    private let networkQualityPath = "/usr/bin/networkQuality"
    private var currentProcess: Process?
    
    @Published private(set) var liveData = LiveMeasurementData(phase: .starting)
    
    func startMeasurement() async throws -> NetworkQualityResult {
        cancelMeasurement()
        liveData = LiveMeasurementData(phase: .starting)
        
        guard FileManager.default.fileExists(atPath: networkQualityPath) else {
            throw MeasurementError.binaryNotFound
        }
        
        if !checkNetworkConnectivity() {
            throw MeasurementError.noNetworkConnection
        }
        
        return try await runNetworkQualityWithScript()
    }
    
    func cancelMeasurement() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
        currentProcess = nil
    }
    
    private func runNetworkQualityWithScript() async throws -> NetworkQualityResult {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: MeasurementError.executionFailed)
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
            process.arguments = ["-q", "/dev/null", self.networkQualityPath, "-v"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            self.currentProcess = process
            
            var allOutput = ""
            var hasResumed = false
            let resumeLock = NSLock()
            
            func safeResume(with result: Result<NetworkQualityResult, Error>) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                
                if let output = String(data: data, encoding: .utf8) {
                    allOutput += output
                    
                    let outputCopy = output
                    Task { @MainActor in
                        self?.parseLiveOutput(outputCopy)
                    }
                }
            }
            
            process.terminationHandler = { [weak self] proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                
                let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
                if let remainingOutput = String(data: remainingData, encoding: .utf8), !remainingOutput.isEmpty {
                    allOutput += remainingOutput
                }
                
                if Task.isCancelled {
                    safeResume(with: .failure(MeasurementError.cancelled))
                    return
                }
                
                if proc.terminationStatus != 0 {
                    let lowerOutput = allOutput.lowercased()
                    if lowerOutput.contains("network") && (lowerOutput.contains("error") || lowerOutput.contains("unavailable") || lowerOutput.contains("no interface")) {
                        safeResume(with: .failure(MeasurementError.noNetworkConnection))
                    } else {
                        safeResume(with: .failure(MeasurementError.executionFailed))
                    }
                    return
                }
                
                if allOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    safeResume(with: .failure(MeasurementError.executionFailed))
                    return
                }
                
                let finalOutput = allOutput
                Task { @MainActor in
                    guard let self = self else {
                        safeResume(with: .failure(MeasurementError.executionFailed))
                        return
                    }
                    
                    let result = self.parseOutput(finalOutput)
                    safeResume(with: .success(result))
                }
            }
            
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                safeResume(with: .failure(MeasurementError.executionFailed))
            }
        }
    }
    
    private func parseLiveOutput(_ newOutput: String) {
        let cleanOutput = newOutput.replacingOccurrences(
            of: #"\x1B\[[0-9;]*[a-zA-Z]|\r"#,
            with: "",
            options: .regularExpression
        )
        
        let lines = cleanOutput.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            
            let lowercaseLine = trimmedLine.lowercased()
            
            if trimmedLine.contains(" - ") && lowercaseLine.contains("downlink") && lowercaseLine.contains("uplink") {
                let parts = trimmedLine.components(separatedBy: " - ")
                
                if parts.count > 0 {
                    let downloadPart = parts[0]
                    if let downloadSpeed = extractSpeedFromPart(downloadPart, isDownload: true) {
                        liveData.currentDownloadSpeed = downloadSpeed
                        liveData.phase = .downloadTest
                        print("🔵 Download: \(downloadSpeed) Mbps")
                    }
                }
                
                if parts.count > 1 {
                    let uploadPart = parts[1]
                    if let uploadSpeed = extractSpeedFromPart(uploadPart, isDownload: false) {
                        liveData.currentUploadSpeed = uploadSpeed
                        liveData.phase = .uploadTest
                        print("🟢 Upload: \(uploadSpeed) Mbps")
                    }
                }
            }
            else {
                if lowercaseLine.contains("downlink") {
                    if let downloadSpeed = extractSpeedFromPart(trimmedLine, isDownload: true) {
                        liveData.currentDownloadSpeed = downloadSpeed
                        liveData.phase = .downloadTest
                        print("🔵 Download (single): \(downloadSpeed) Mbps")
                    }
                }
                
                if lowercaseLine.contains("uplink") {
                    if let uploadSpeed = extractSpeedFromPart(trimmedLine, isDownload: false) {
                        liveData.currentUploadSpeed = uploadSpeed
                        liveData.phase = .uploadTest
                        print("🟢 Upload (single): \(uploadSpeed) Mbps")
                    }
                }
            }
        }
    }
    
    private func extractSpeedFromPart(_ part: String, isDownload: Bool) -> Double? {
        let lowercasePart = part.lowercased()
        
        let capacityPatterns = [
            #"capacity[:\s]+([\d.]+)\s*mbps"#,
            #"capacity\s+([\d.]+)\s*mbps"#
        ]
        
        for pattern in capacityPatterns {
            if let match = lowercasePart.range(of: pattern, options: .regularExpression) {
                let matchString = String(lowercasePart[match])
                if let speed = extractSpeed(from: matchString) {
                    return speed
                }
            }
        }
        
        return extractSpeed(from: part)
    }
    
    private func parseOutput(_ output: String) -> NetworkQualityResult {
        var uploadSpeed: Double?
        var downloadSpeed: Double?
        var uploadResponsiveness: Int?
        var downloadResponsiveness: Int?
        var idleLatency: Double?
        let uploadLatency: Double? = nil
        let downloadLatency: Double? = nil
        
        let cleanOutput = output.replacingOccurrences(
            of: #"\x1B\[[0-9;]*[a-zA-Z]|\r"#,
            with: "",
            options: .regularExpression
        )
        
        let lines = cleanOutput.components(separatedBy: .newlines)
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            if (lowercaseLine.contains("uplink") || lowercaseLine.contains("upload")) && 
               lowercaseLine.contains("capacity") &&
               !lowercaseLine.contains("downlink") && !lowercaseLine.contains("download") {
                if let speed = extractSpeed(from: line) {
                    uploadSpeed = speed
                    print("📊 Final Upload: \(speed) Mbps")
                }
            }
            
            if (lowercaseLine.contains("downlink") || lowercaseLine.contains("download")) && 
               lowercaseLine.contains("capacity") &&
               !lowercaseLine.contains("uplink") && !lowercaseLine.contains("upload") {
                if let speed = extractSpeed(from: line) {
                    downloadSpeed = speed
                    print("📊 Final Download: \(speed) Mbps")
                }
            }
            
            if (lowercaseLine.contains("upload") || lowercaseLine.contains("uplink")) && 
               lowercaseLine.contains("responsiveness") &&
               !lowercaseLine.contains("download") && !lowercaseLine.contains("downlink") {
                uploadResponsiveness = extractResponsiveness(from: line)
            }
            
            if (lowercaseLine.contains("download") || lowercaseLine.contains("downlink")) && 
               lowercaseLine.contains("responsiveness") &&
               !lowercaseLine.contains("upload") && !lowercaseLine.contains("uplink") {
                downloadResponsiveness = extractResponsiveness(from: line)
            }
            
            if lowercaseLine.contains("idle") && lowercaseLine.contains("latency") {
                idleLatency = extractLatency(from: line)
            }
            
            if lowercaseLine.contains("responsiveness") && 
               !lowercaseLine.contains("upload") && 
               !lowercaseLine.contains("download") &&
               !lowercaseLine.contains("uplink") &&
               !lowercaseLine.contains("downlink") {
                if downloadResponsiveness == nil {
                    downloadResponsiveness = extractResponsiveness(from: line)
                }
            }
        }
        
        liveData.phase = .finishing
        if let dl = downloadSpeed {
            liveData.currentDownloadSpeed = dl
        }
        if let ul = uploadSpeed {
            liveData.currentUploadSpeed = ul
        }
        
        return NetworkQualityResult(
            uploadSpeed: uploadSpeed,
            downloadSpeed: downloadSpeed,
            uploadResponsiveness: uploadResponsiveness,
            downloadResponsiveness: downloadResponsiveness,
            idleLatency: idleLatency,
            uploadLatency: uploadLatency,
            downloadLatency: downloadLatency,
            rawOutput: cleanOutput,
            timestamp: Date()
        )
    }
    
    private func extractSpeed(from line: String) -> Double? {
        let patterns = [
            #"([\d.]+)\s*[Gg]bps"#,
            #"([\d.]+)\s*[Mm]bps"#,
            #"([\d.]+)\s*[Kk]bps"#
        ]
        
        for (index, pattern) in patterns.enumerated() {
            if let match = line.range(of: pattern, options: .regularExpression) {
                let matchString = String(line[match])
                if let number = extractNumber(from: matchString) {
                    switch index {
                    case 0: return number * 1000
                    case 1: return number
                    case 2: return number / 1000
                    default: return number
                    }
                }
            }
        }
        return nil
    }
    
    private func extractResponsiveness(from line: String) -> Int? {
        let pattern = #"(\d+)\s*RPM"#
        if let match = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let matchString = String(line[match])
            if let number = extractNumber(from: matchString) {
                return Int(number)
            }
        }
        
        let parts = line.lowercased().components(separatedBy: "responsiveness")
        if parts.count > 1 {
            if let number = extractNumber(from: parts[1]) {
                return Int(number)
            }
        }
        
        return nil
    }
    
    private func extractLatency(from line: String) -> Double? {
        let patterns = [
            #"([\d.]+)\s*(?:ms|milliseconds?)"#,
            #"latency[:\s]*([\d.]+)"#
        ]
        
        for pattern in patterns {
            if let match = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchString = String(line[match])
                if let number = extractNumber(from: matchString) {
                    return number
                }
            }
        }
        return nil
    }
    
    private func extractNumber(from string: String) -> Double? {
        let pattern = #"[\d.]+"#
        if let match = string.range(of: pattern, options: .regularExpression) {
            return Double(string[match])
        }
        return nil
    }
    
    private func checkNetworkConnectivity() -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo("apple.com", "443", &hints, &result)
        
        if status == 0 {
            freeaddrinfo(result)
            return true
        }
        return false
    }
}
