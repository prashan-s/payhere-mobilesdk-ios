//
//  PayHereSDKDelegate.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

/// Receives the outcome of a PayHere payment presentation.
public protocol PayHereSDKDelegate: AnyObject {
    /// Called when PayHere receives a payment response.
    func payHereSDK(didReceive response: PHResponse<Any>)
    
    /// Called when a payment fails.
    ///
    /// Delivered on the main queue after dismissal, or before presentation
    /// when a preflight error occurs.
    func payHereSDK(didFailWith error: PHPaymentError)
    
    /// Legacy compatibility callback. Move error handling to `payHereSDK(didFailWith:)`.
    @available(*, deprecated, renamed: "payHereSDK(didFailWith:)",
               message: "Use payHereSDK(didFailWith:) with PHPaymentError. This legacy callback will be removed in a future release.")
    func onErrorReceived(error: Error)
    
}

public extension PayHereSDKDelegate {
    /// Keeps legacy error handlers working while response handling migrates to the new delegate.
    @available(*, deprecated, message: "onErrorReceived(error:) is deprecated. Implement payHereSDK(didFailWith:) with PHPaymentError instead.")
    func payHereSDK(didFailWith error: PHPaymentError) {
        onErrorReceived(error: error.legacyError ?? error)
    }
    
}
