//
//  PHPresentController.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-14.
//  Copyright © 2026 PayHere. All rights reserved.
//

import UIKit

/// Compatibility entry point. Use `PayHereSDK` for new integrations.
@available(*, deprecated, renamed: "PayHereSDK")
public final class PHPresentController {

    /// Presents a payment using optional merchant preferences scoped to this presentation.
    /// Presentation and delegate callbacks are delivered on the main queue.
    public static func present(from: UIViewController,
                               withInitRequest request: PHInitialRequest,
                               configuration: PHPaymentConfiguration = .default,
                               delegate: PHViewControllerDelegate) {
        PayHereSDK.present(from: from,
                           withInitRequest: request,
                           configuration: configuration,
                           delegate: delegate)
    }
}
