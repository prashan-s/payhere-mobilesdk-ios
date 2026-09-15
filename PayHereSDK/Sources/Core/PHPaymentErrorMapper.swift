//
//  PHPaymentErrorMapper.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation
import Alamofire

/// Maps checkout failures to their internal reason, code, and display message.
internal enum PHPaymentErrorMapper {
    static func invalidInitializationResponse() -> PHPaymentError {
        return PHPaymentError(reason: .invalidResponse, code: nil, serverMessage: nil)
    }

    static func paymentCannotContinue() -> PHPaymentError {
        return PHPaymentError(reason: .paymentCannotContinue, code: nil, serverMessage: nil)
    }

    static func paymentStatusUnavailable() -> PHPaymentError {
        return PHPaymentError(reason: .paymentStatusUnavailable, code: nil, serverMessage: nil)
    }

    static func sdk(reason: PHPaymentError.Reason, code: Int?) -> PHPaymentError {
        return PHPaymentError(reason: reason, code: code, serverMessage: nil)
    }

    static func serverRejected(message: String?) -> PHPaymentError {
        return PHPaymentError(reason: .requestRejected, code: 501, serverMessage: message)
    }

    static func missingPaymentURL(status: Int?, message: String?) -> PHPaymentError {
        let isRejection = status.map { $0 != 1 } ?? false
        return PHPaymentError(reason: isRejection ? .requestRejected : .invalidPaymentURL,
                              code: 401, serverMessage: isRejection ? message : nil)
    }

    static func network(_ error: AFError, responseCode: Int?, responseData: Data?) -> PHPaymentError {
        let reason: PHPaymentError.Reason
        // A response status can exist even when a transport failure leaves the body incomplete.
        if let status = error.responseCode {
            switch status {
            case 400..<500: reason = .requestRejected
            case 500..<600: reason = .serviceUnavailable
            default: reason = .invalidResponse
            }
        } else if let underlying = error.underlyingError as NSError?, underlying.domain == NSURLErrorDomain {
            switch underlying.code {
            case NSURLErrorNotConnectedToInternet: reason = .noInternet
            case NSURLErrorNetworkConnectionLost: reason = .connectionLost
            case NSURLErrorTimedOut: reason = .requestTimedOut
            default: reason = .networkFailure
            }
        } else if error.isResponseValidationError || error.isResponseSerializationError {
            reason = .invalidResponse
        } else {
            // A cancelled internal request is never evidence that the user closed checkout.
            reason = .networkFailure
        }
        // Only recognized PayHere error fields from an HTTP rejection are displayable server text.
        // A proxy's HTML or a partial response from a transport failure is not an error message.
        let serverError: ServerError?
        if let status = error.responseCode, (400..<600).contains(status), let data = responseData {
            serverError = try? JSONDecoder().decode(ServerError.self, from: data)
        } else {
            serverError = nil
        }
        return PHPaymentError(reason: reason, code: responseCode, serverMessage: serverError?.msg)
    }

    private struct ServerError: Decodable {
        let status: Int?
        let msg: String?
    }
}
