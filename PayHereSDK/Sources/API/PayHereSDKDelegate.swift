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
    
    /// Called for an SDK error or closure before a final payment result.
    ///
    /// Delivered on the main queue after dismissal, or before presentation
    /// when a preflight error occurs.
    func payHereSDK(didFailWith error: PHPaymentError)
}
