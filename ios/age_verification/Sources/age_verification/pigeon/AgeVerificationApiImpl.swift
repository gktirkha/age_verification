import Flutter
import UIKit

#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

class AgeVerificationApiImpl: AgeVerificationApi {
    
    private var mockConfig: AgeVerificationMockConfig? = nil
    
    func initialize(
        mockConfig: AgeVerificationMockConfig?, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.mockConfig = mockConfig
        completion(.success(()))
    }
    
    func verifyAge(
        ageGates: [Int64]?, skipEligibilityCheck: Bool, completion: @escaping (Result<AgeVerificationResult, Error>) -> Void
    ) {
        if let mock = mockConfig {
            completion(
                .success(
                    AgeVerificationResult(
                        status: mock.status,
                        ageLower: mock.ageLower,
                        ageUpper: mock.ageUpper,
                        source: mock.source,
                        installId: mock.installId
                    )))
            return
        }
        
        if #available(iOS 26.0, *) {
#if canImport(DeclaredAgeRange)
            checkDeclaredAgeRange(ageGates: ageGates, skipEligibilityCheck: skipEligibilityCheck, completion: completion)
#else
            completion(
                .failure(
                    PigeonError(
                        code: String(describing: AgeVerificationErrorCode.apiNotAvailable),
                        message: "DeclaredAgeRange framework is not linked. Requires iOS 26.0+.",
                        details: nil
                    )))
#endif
        } else {
            completion(
                .failure(
                    PigeonError(
                        code: String(describing: AgeVerificationErrorCode.apiNotAvailable),
                        message: "Age verification requires iOS 26.0 or later.",
                        details: nil
                    )))
        }
    }
    
    @available(iOS 26.0, *)
    private func checkDeclaredAgeRange(
        ageGates: [Int64]?, skipEligibilityCheck: Bool, completion: @escaping (Result<AgeVerificationResult, Error>) -> Void
    ) {
#if canImport(DeclaredAgeRange)
        let sortedGates = (ageGates ?? []).map { Int($0) }.sorted()
        
        guard !sortedGates.isEmpty else {
            completion(
                .failure(
                    PigeonError(
                        code: String(describing: AgeVerificationErrorCode.apiError),
                        message: "At least one age gate is required for iOS age verification.",
                        details: nil
                    )))
            return
        }
        
        guard let presenter = presentationViewController() else {
            completion(
                .failure(
                    PigeonError(
                        code: String(describing: AgeVerificationErrorCode.apiError),
                        message:
                            "Unable to find a view controller to present the age verification prompt.",
                        details: nil
                    )))
            return
        }
        
        Task { @MainActor in
            // Check regional eligibility on iOS 26.2+; return unknown if ineligible.
            // Skip this check when skipEligibilityCheck is true to avoid potential hangs.
            if #available(iOS 26.2, *), !skipEligibilityCheck {
                if let isEligible = try? await AgeRangeService.shared.isEligibleForAgeFeatures,
                   !isEligible
                {
                    completion(.success(AgeVerificationResult(status: .unknown)))
                    return
                }
            }
            
            do {
                let response: AgeRangeService.Response
                switch sortedGates.count {
                case 1:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: sortedGates[0], in: presenter)
                case 2:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: sortedGates[0], sortedGates[1], in: presenter)
                case 3:
                    response = try await AgeRangeService.shared.requestAgeRange(
                        ageGates: sortedGates[0], sortedGates[1], sortedGates[2], in: presenter)
                default:
                    throw PigeonError(
                        code: String(describing: AgeVerificationErrorCode.apiError),
                        message: "DeclaredAgeRange supports 1 to 3 age gates.",
                        details: nil
                    )
                }
                
                switch response {
                case .declinedSharing:
                    completion(.success(AgeVerificationResult(status: .declined)))
                    
                case .sharing(let range):
                    let source: AgeDeclarationSource? = {
                        switch range.ageRangeDeclaration {
                        case .selfDeclared: return .selfDeclared
                        case .guardianDeclared: return .guardianDeclared
                        default: return nil
                        }
                    }()
                    
                    let highestGate = sortedGates.max() ?? 0
                    let lowerBound = range.lowerBound ?? 0
                    let status: AgeVerificationStatus = lowerBound >= highestGate ? .verified : .supervised
                    
                    completion(
                        .success(
                            AgeVerificationResult(
                                status: status,
                                ageLower: range.lowerBound.map { Int64($0) },
                                ageUpper: range.upperBound.map { Int64($0) },
                                source: source
                            )))
                    
                @unknown default:
                    completion(
                        .failure(
                            PigeonError(
                                code: String(describing: AgeVerificationErrorCode.apiError),
                                message: "Unexpected DeclaredAgeRange response.",
                                details: nil
                            )))
                }
            } catch let error as PigeonError {
                completion(.failure(error))
            } catch AgeRangeService.Error.notAvailable {
                completion(
                    .failure(
                        PigeonError(
                            code: String(describing: AgeVerificationErrorCode.apiNotAvailable),
                            message: "Age range service is not available on this device (no Apple account or unsupported configuration).",
                            details: nil
                        )))
            } catch AgeRangeService.Error.invalidRequest {
                completion(
                    .failure(
                        PigeonError(
                            code: String(describing: AgeVerificationErrorCode.apiError),
                            message: "Invalid age gate values passed to requestAgeRange.",
                            details: nil
                        )))
            } catch {
                let nsError = error as NSError
                let message = error.localizedDescription
                let domain = nsError.domain
                let code = nsError.code
                let details = "Domain: \(domain) | Code: \(code)"
                
                if (domain == NSCocoaErrorDomain && code == 3072)
                    || message.lowercased().contains("cancel")
                    || message.lowercased().contains("user abort")
                {
                    completion(
                        .failure(
                            PigeonError(
                                code: String(describing: AgeVerificationErrorCode.apiError),
                                message: "User cancelled the age verification prompt.",
                                details: details
                            )))
                    return
                }
                
                let isDeclaredAgeRangeError =
                domain.contains("DeclaredAgeRange") || domain.contains("AgeRangeService")
                let likelyEntitlementError =
                (code == 0 && isDeclaredAgeRangeError)
                || message.lowercased().contains("entitlement")
                || message.lowercased().contains("not entitled")
                
                if likelyEntitlementError {
                    completion(
                        .failure(
                            PigeonError(
                                code: String(describing: AgeVerificationErrorCode.apiNotAvailable),
                                message: "Missing 'com.apple.developer.declared-age-range' entitlement.",
                                details: details
                            )))
                    return
                }
                
                if domain == URLError.errorDomain
                    || message.lowercased().contains("network")
                    || message.lowercased().contains("connection")
                {
                    completion(
                        .failure(
                            PigeonError(
                                code: String(describing: AgeVerificationErrorCode.networkError),
                                message: "Network error: \(message)",
                                details: details
                            )))
                    return
                }
                
                completion(
                    .failure(
                        PigeonError(
                            code: String(describing: AgeVerificationErrorCode.apiError),
                            message: "DeclaredAgeRange API error: \(message)",
                            details: details
                        )))
            }
        }
#endif
    }
    @available(iOS 26.0, *)
    private func presentationViewController() -> UIViewController? {
        // Primary: foreground active scene's key window.
        let foregroundScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        if let root = foregroundScene?.keyWindow?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            return top
        }
        // Fallback: any connected scene that has a key window.
        if let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .compactMap({ $0.keyWindow })
            .first?
            .rootViewController
        {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            return top
        }
        return nil
    }
}
