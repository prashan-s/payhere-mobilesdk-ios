//
//  PHPaymentPresenter.swift
//  PayHereSDK
//
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation
import UIKit

/// Internal presentation implementation for the public SDK entry point.
internal enum PHPaymentPresenter {
    static func present(from: UIViewController,
                        withInitRequest request: PHInitialRequest,
                        configuration: PHPaymentConfiguration,
                        delegate: PayHereSDKDelegate) {
        let presentation = {
            // Retain the delegate through queued setup, then let the controller hold it weakly.
            defer { withExtendedLifetime(delegate) {} }
            guard let merchantID = request.merchantID,
                  !merchantID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                delegate.payHereSDK(didFailWith: PHPaymentErrorMapper.sdk(
                    code: .invalidMerchantID, stage: .presentation, legacyError: NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid merchant ID"])))
                return
            }

            let storyBoard = UIStoryboard(name: "PayHere", bundle: Bundle.payHereBundle)
            guard let initialController = storyBoard.instantiateViewController(withIdentifier: "PHBottomViewController") as? PHBottomViewController else {
                delegate.payHereSDK(didFailWith: PHPaymentErrorMapper.sdk(
                    code: .paymentViewUnavailable, stage: .presentation, legacyError: NSError(
                    domain: "", code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to load the payment view"])))
                return
            }

            initialController.initialRequest = request
            initialController.isSandBoxEnabled = merchantID.starts(with: "1")
            initialController.configuration = configuration
            initialController.delegate = delegate

            initialController.configurePresentation(from: from)

            from.present(initialController, animated: true, completion: nil)
        }

        if Thread.isMainThread {
            presentation()
        } else {
            DispatchQueue.main.async(execute: presentation)
        }
    }
}
