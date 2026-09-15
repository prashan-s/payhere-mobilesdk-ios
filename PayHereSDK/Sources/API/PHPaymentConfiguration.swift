//
//  PHPaymentConfiguration.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-14.
//  Copyright © 2026 PayHere. All rights reserved.
//

/// Merchant preferences for a single payment presentation.
/// Configuration is optional. Omit it when presenting to keep the result screen and Retry enabled.
public struct PHPaymentConfiguration {
    /// Shows the SDK result screen for a completed payment when enabled.
    public var showResultScreen: Bool

    /// Shows Retry for failed payments. Ignored when the result screen is hidden.
    public var showRetryOnResultScreen: Bool

    public init(showResultScreen: Bool = true,
                showRetryOnResultScreen: Bool = true) {
        
        self.showResultScreen = showResultScreen
        self.showRetryOnResultScreen = showRetryOnResultScreen
        
    }
    
    public static let `default` : PHPaymentConfiguration = .init(showResultScreen: true, showRetryOnResultScreen: true)
}
