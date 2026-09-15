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

    /// Presents a payment using optional merchant preferences scoped to this presentation.
    /// Omit the configuration argument to use the SDK's default result and retry behavior.
    /// Presentation and delegate callbacks are delivered on the main queue.
    public static func present(from: UIViewController,
                               withInitRequest request: PHInitialRequest,
                               configuration: PHPaymentConfiguration = .default,
                               delegate: PHViewControllerDelegate) {
        PHPaymentPresenter.present(from: from,
                                   withInitRequest: request,
                                   configuration: configuration,
                                   delegate: delegate)
    }
}
