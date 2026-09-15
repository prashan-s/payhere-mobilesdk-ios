//
//  PHPaymentError.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation

/// A checkout event with a stable SDK code and a display message.
/// Recognized server error messages are preserved verbatim; SDK-generated errors use nontechnical text.
public struct PHPaymentError: LocalizedError {
    public enum Code: String {
        case checkoutClosed = "checkout_closed"
        case invalidMerchantID = "invalid_merchant_id"
        case invalidAmount = "invalid_amount"
        case invalidCurrency = "invalid_currency"
        case paymentViewUnavailable = "payment_view_unavailable"
        case noInternet = "no_internet"
        case connectionLost = "connection_lost"
        case requestTimedOut = "request_timed_out"
        case networkFailure = "network_failure"
        case requestRejected = "request_rejected"
        case serviceUnavailable = "service_unavailable"
        case invalidResponse = "invalid_response"
        case invalidPaymentURL = "invalid_payment_url"
        case paymentStatusUnavailable = "payment_status_unavailable"
        case paymentCannotContinue = "payment_cannot_continue"
    }

    public enum Category: String {
        case userAction = "user_action"
        case integration
        case connectivity
        case service
    }

    public enum Stage: String {
        case presentation
        case initialization
        case submission
        case paymentPage = "payment_page"
        case result
        case statusCheck = "status_check"
    }

    public let code: Code
    public let stage: Stage
    /// A recognized server error's original message, including empty strings. Nil means none was available.
    public let serverMessage: String?
    /// The server's application status, distinct from the SDK code and HTTP status.
    public let serverStatusCode: Int?
    public let httpStatusCode: Int?

    // Retain the original payload exclusively for the deprecated delegate bridge.
    internal let legacyError: Error?

    internal init(code: Code, stage: Stage, serverMessage: String?,
                  serverStatusCode: Int?, httpStatusCode: Int?, legacyError: Error?) {
        self.code = code
        self.stage = stage
        self.serverMessage = serverMessage
        self.serverStatusCode = serverStatusCode
        self.httpStatusCode = httpStatusCode
        self.legacyError = legacyError
    }

    public var category: Category {
        switch code {
        case .checkoutClosed:
            return .userAction
        case .invalidMerchantID, .invalidAmount, .invalidCurrency, .paymentViewUnavailable:
            return .integration
        case .noInternet, .connectionLost, .requestTimedOut, .networkFailure:
            return .connectivity
        case .requestRejected, .serviceUnavailable, .invalidResponse, .invalidPaymentURL,
             .paymentStatusUnavailable, .paymentCannotContinue:
            return .service
        }
    }

    /// Use this text for display. Do not infer payment settlement or retry safety from an error.
    public var message: String {
        if let serverMessage = serverMessage { return serverMessage }
        switch code {
        case .checkoutClosed:
            return "User closed the payment window."
        case .invalidMerchantID, .invalidAmount, .invalidCurrency:
            return "This payment couldn’t be started. Please contact the merchant."
        case .paymentViewUnavailable:
            return "The payment window couldn’t be opened."
        case .noInternet:
            return "You’re not connected to the internet. Please check your connection."
        case .connectionLost:
            return "The connection was interrupted. Please check your payment status before trying again."
        case .requestTimedOut:
            return "The payment service took too long to respond. Please check your payment status before trying again."
        case .networkFailure:
            return "We couldn’t connect to the payment service. Please check your payment status before trying again."
        case .requestRejected:
            if stage == .submission {
                return "We couldn’t complete this payment request. Please contact the merchant to check your payment status."
            }
            return "We couldn’t start this payment. Please contact the merchant."
        case .serviceUnavailable:
            return "The payment service is temporarily unavailable. Please check your payment status before trying again."
        case .invalidResponse:
            return "We couldn’t confirm the payment details. Please contact the merchant to check your payment status."
        case .invalidPaymentURL:
            return "The payment page couldn’t be opened."
        case .paymentStatusUnavailable:
            return "We couldn’t confirm your payment status. Please contact the merchant before trying again."
        case .paymentCannotContinue:
            return "We couldn’t continue this payment. Please contact the merchant to check your payment status."
        }
    }

    public var errorDescription: String? { message }
}
