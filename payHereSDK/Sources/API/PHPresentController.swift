//
//  PHPresentController.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-14.
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation
import UIKit

/// Presents the PayHere payment view from a merchant's view controller.
public final class PHPresentController {

    /// Presents a payment using optional merchant preferences scoped to this presentation.
    /// Omit the configuration argument to use the SDK's default result and retry behavior.
    /// Presentation and delegate callbacks are delivered on the main queue.
    public static func present(from: UIViewController,
                               withInitRequest request: PHInitialRequest,
                               configuration: PHPaymentConfiguration = .default,
                               delegate: PHViewControllerDelegate) {
        let presentation = {
            guard let merchantID = request.merchantID,
                  !merchantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                delegate.onErrorReceived(error: NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid merchant ID"]))
                return
            }

            let storyBoard = UIStoryboard(name: "PayHere", bundle: Bundle.payHereBundle)
            guard let initialController = storyBoard.instantiateViewController(withIdentifier: "PHBottomViewController") as? PHBottomViewController else {
                delegate.onErrorReceived(error: NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to load the payment view"]))
                return
            }

            initialController.initialRequest = request
            initialController.isSandBoxEnabled = merchantID.starts(with: "1")
            initialController.configuration = configuration
            initialController.delegate = delegate

            from.modalPresentationStyle = .overCurrentContext
            from.modalTransitionStyle = .crossDissolve
            initialController.modalPresentationStyle = .overCurrentContext
            initialController.modalTransitionStyle = .crossDissolve

            from.present(initialController, animated: true, completion: nil)
        }

        if Thread.isMainThread {
            presentation()
        } else {
            DispatchQueue.main.async(execute: presentation)
        }
    }
}
