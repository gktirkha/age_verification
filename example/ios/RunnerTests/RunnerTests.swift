import Flutter
import UIKit
import XCTest

@testable import age_verification

class AgeVerificationApiImplTests: XCTestCase {

  // MARK: - initialize

  func test_initialize_alwaysSucceeds() {
    let impl = AgeVerificationApiImpl()
    let expectation = expectation(description: "initialize completes")

    impl.initialize { result in
      switch result {
      case .success:
        expectation.fulfill()
      case .failure(let error):
        XCTFail("Expected success but got error: \(error)")
      }
    }

    waitForExpectations(timeout: 1)
  }

  // MARK: - verifyAge (platform guard)

  func test_verifyAge_onUnsupportedPlatform_returnsApiNotAvailableError() {
    // DeclaredAgeRange requires iOS 26.0+. On older OS versions the impl
    // must return an apiNotAvailable error without touching the API.
    guard #unavailable(iOS 26.0) else { return }

    let impl = AgeVerificationApiImpl()
    let expectation = expectation(description: "verifyAge returns error")

    impl.verifyAge(ageGates: nil) { result in
      switch result {
      case .success:
        XCTFail("Expected failure on iOS < 26")
      case .failure(let error):
        let pigeonError = error as? PigeonError
        XCTAssertNotNil(pigeonError, "Error should be a PigeonError")
        XCTAssertEqual(
          pigeonError?.code,
          String(describing: AgeVerificationErrorCode.apiNotAvailable),
          "Error code should be apiNotAvailable"
        )
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 1)
  }

  func test_verifyAge_withoutDeclaredAgeRangeFramework_returnsApiNotAvailableError() {
    // When DeclaredAgeRange is not linked (compile-time canImport is false),
    // verifyAge must return apiNotAvailable regardless of iOS version.
    #if canImport(DeclaredAgeRange)
      // Framework is linked — this path cannot be tested here.
    #else
      let impl = AgeVerificationApiImpl()
      let expectation = expectation(description: "verifyAge returns error")

      impl.verifyAge(ageGates: nil) { result in
        switch result {
        case .success:
          XCTFail("Expected failure when DeclaredAgeRange is not linked")
        case .failure(let error):
          let pigeonError = error as? PigeonError
          XCTAssertEqual(
            pigeonError?.code,
            String(describing: AgeVerificationErrorCode.apiNotAvailable)
          )
          expectation.fulfill()
        }
      }

      waitForExpectations(timeout: 1)
    #endif
  }

  // MARK: - verifyAge (age gate validation)

  @available(iOS 26.0, *)
  func test_verifyAge_withEmptyAgeGates_returnsApiError() {
    #if canImport(DeclaredAgeRange)
      let impl = AgeVerificationApiImpl()
      let expectation = expectation(description: "empty gates returns error")

      // An empty list must be rejected before the API call is made.
      impl.verifyAge(ageGates: []) { result in
        switch result {
        case .success:
          XCTFail("Expected failure for empty age gates")
        case .failure(let error):
          let pigeonError = error as? PigeonError
          XCTAssertNotNil(pigeonError)
          XCTAssertEqual(
            pigeonError?.code,
            String(describing: AgeVerificationErrorCode.apiError)
          )
          expectation.fulfill()
        }
      }

      waitForExpectations(timeout: 1)
    #endif
  }
}
