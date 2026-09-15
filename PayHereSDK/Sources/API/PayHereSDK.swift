//
//  PayHereSDK.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-14.
//  Copyright © 2026 PayHere. All rights reserved.
//

import UIKit

/// Presents the PayHere payment view from a merchant's view controller.
public final class PayHereSDK {

    private init() {}

    /// Presents a payment using preferences scoped to this presentation.
    /// The merchant must retain its delegate until completion.
    /// Presentation and delegate callbacks are delivered on the main queue.
    public static func present(from: UIViewController,
                               withInitRequest request: PHInitialRequest,
                               configuration: PHPaymentConfiguration = .default,
                               delegate: PayHereSDKDelegate) {
        PHPaymentPresenter.present(from: from,
                                   withInitRequest: request,
                                   configuration: configuration,
                                   delegate: delegate)
    }

    /// Retained only to provide migration diagnostics for the former delegate API.
    @available(*, unavailable, message: "Use present(from:withInitRequest:configuration:delegate:) with PayHereSDKDelegate.")
    public static func present(from: UIViewController,
                               withInitRequest request: PHInitialRequest,
                               configuration: PHPaymentConfiguration = .default,
                               delegate: PHViewControllerDelegate) {
        // Unavailable: callers must migrate their delegate before presenting a payment.
    }
}
