//
//  PHPaymentError.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation

/// A checkout error with a display message.
/// Recognized server error messages are preserved verbatim; SDK-generated errors use nontechnical text.
public struct PHPaymentError: Error {
    internal enum Reason: String {
        // User action
        case userCancelled = "user_cancelled"

        // Integration
        case invalidMerchantID = "invalid_merchant_id"
        case invalidAmount = "invalid_amount"
        case invalidCurrency = "invalid_currency"
        case paymentViewUnavailable = "payment_view_unavailable"

        // Connectivity
        case noInternet = "no_internet"
        case connectionLost = "connection_lost"
        case requestTimedOut = "request_timed_out"
        case networkFailure = "network_failure"

        // Service
        case requestRejected = "request_rejected"
        case serviceUnavailable = "service_unavailable"
        case invalidResponse = "invalid_response"
        case invalidPaymentURL = "invalid_payment_url"
        case paymentStatusUnavailable = "payment_status_unavailable"
        case paymentCannotContinue = "payment_cannot_continue"
    }

    internal let reason: Reason
    internal let code: Int?
    /// A recognized server error's original message, including empty strings. Nil means none was available.
    internal let serverMessage: String?

    internal init(reason: Reason, code: Int?, serverMessage: String?) {
        self.reason = reason
        self.code = code
        self.serverMessage = serverMessage
    }

    /// Use this text for display. Do not infer payment settlement or retry safety from an error.
    public var message: String {
        if let serverMessage = serverMessage { return serverMessage }
        switch reason {
        case .userCancelled:
            return "You cancelled checkout. Please check your payment status before trying again."
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
            return "We couldn’t complete this payment request. Please contact the merchant to check your payment status."
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
}
