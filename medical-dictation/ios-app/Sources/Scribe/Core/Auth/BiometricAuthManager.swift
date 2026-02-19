import Foundation
import LocalAuthentication

/// Handles biometric authentication (Face ID / Touch ID)
actor BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    private let context = LAContext()
    
    enum BiometricType {
        case none
        case touchID
        case faceID
    }
    
    /// Check if biometric authentication is available
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return available
    }
    
    /// Get the type of biometric available
    func biometricType() -> BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID  // Treat optic ID like faceID for UI purposes
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    /// Authenticate with biometrics
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Biometric not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            print("Biometric auth failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Authenticate with biometrics or device passcode as fallback
    func authenticateWithFallback(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("Device authentication not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            print("Device auth failed: \(error.localizedDescription)")
            return false
        }
    }
}
