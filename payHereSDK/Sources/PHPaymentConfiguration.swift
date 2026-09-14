//
//  PHPaymentConfiguration.swift
//  payHereSDK
//

/// Merchant preferences for a single payment presentation.
public struct PHPaymentConfiguration {
    /// Shows the SDK result screen for a completed payment when enabled.
    public let showResultScreen: Bool

    /// Shows Retry for failed payments. Ignored when the result screen is hidden.
    public let showRetryOnResultScreen: Bool

    public init(showResultScreen: Bool = true, showRetryOnResultScreen: Bool = true) {
        self.showResultScreen = showResultScreen
        self.showRetryOnResultScreen = showRetryOnResultScreen
    }
}
