//
//  PHPaymentErrorMapper.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation
import Alamofire

/// Classifies events before their legacy error payload loses the source context.
internal enum PHPaymentErrorMapper {
    static func invalidInitializationResponse() -> PHPaymentError {
        return PHPaymentError(code: .invalidResponse, stage: .initialization, serverMessage: nil,
                              serverStatusCode: nil, httpStatusCode: nil, legacyError: nil)
    }

    static func paymentCannotContinue(stage: PHPaymentError.Stage) -> PHPaymentError {
        return PHPaymentError(code: .paymentCannotContinue, stage: stage, serverMessage: nil,
                              serverStatusCode: nil, httpStatusCode: nil, legacyError: nil)
    }

    static func paymentStatusUnavailable() -> PHPaymentError {
        return PHPaymentError(code: .paymentStatusUnavailable, stage: .statusCheck, serverMessage: nil,
                              serverStatusCode: nil, httpStatusCode: nil, legacyError: nil)
    }

    static func sdk(code: PHPaymentError.Code, stage: PHPaymentError.Stage,
                    legacyError: Error) -> PHPaymentError {
        return PHPaymentError(code: code, stage: stage, serverMessage: nil,
                              serverStatusCode: nil, httpStatusCode: nil, legacyError: legacyError)
    }

    static func serverRejected(status: Int?, message: String?,
                               stage: PHPaymentError.Stage) -> PHPaymentError {
        let legacyError = NSError(domain: "", code: 501,
                                  userInfo: [NSLocalizedDescriptionKey: message ?? ""])
        return PHPaymentError(code: .requestRejected, stage: stage, serverMessage: message,
                              serverStatusCode: status, httpStatusCode: nil, legacyError: legacyError)
    }

    static func missingPaymentURL(status: Int?, message: String?,
                                  stage: PHPaymentError.Stage) -> PHPaymentError {
        let isRejection = status.map { $0 != 1 } ?? false
        let legacyError = NSError(domain: "", code: 401,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        return PHPaymentError(code: isRejection ? .requestRejected : .invalidPaymentURL,
                              stage: stage, serverMessage: isRejection ? message : nil,
                              serverStatusCode: status, httpStatusCode: nil, legacyError: legacyError)
    }

    static func network(_ error: AFError, stage: PHPaymentError.Stage, responseData: Data?) -> PHPaymentError {
        let code: PHPaymentError.Code
        if let status = error.responseCode {
            switch status {
            case 400..<500: code = .requestRejected
            case 500..<600: code = .serviceUnavailable
            default: code = .invalidResponse
            }
        } else if let underlying = error.underlyingError as NSError?, underlying.domain == NSURLErrorDomain {
            switch underlying.code {
            case NSURLErrorNotConnectedToInternet: code = .noInternet
            case NSURLErrorNetworkConnectionLost: code = .connectionLost
            case NSURLErrorTimedOut: code = .requestTimedOut
            default: code = .networkFailure
            }
        } else if error.isResponseValidationError || error.isResponseSerializationError {
            code = .invalidResponse
        } else {
            // A cancelled internal request is never evidence that the user closed checkout.
            code = .networkFailure
        }
        let legacyError = NSError(domain: "", code: error.responseCode ?? 0,
                                  userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? ""])
        // Only recognized PayHere error fields from an HTTP rejection are displayable server text.
        // A proxy's HTML or a partial response from a transport failure is not an error message.
        let serverError: ServerError?
        if let status = error.responseCode, (400..<600).contains(status), let data = responseData {
            serverError = try? JSONDecoder().decode(ServerError.self, from: data)
        } else {
            serverError = nil
        }
        return PHPaymentError(code: code, stage: stage, serverMessage: serverError?.msg,
                              serverStatusCode: serverError?.status, httpStatusCode: error.responseCode,
                              legacyError: legacyError)
    }

    private struct ServerError: Decodable {
        let status: Int?
        let msg: String?
    }
}
