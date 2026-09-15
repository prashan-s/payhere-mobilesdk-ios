//
//  PHPaymentPresenter.swift
//  PayHereSDK
//
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation
import UIKit

/// Internal presentation implementation shared by the public and compatibility APIs.
internal enum PHPaymentPresenter {
    static func present(from: UIViewController,
                        withInitRequest request: PHInitialRequest,
                        configuration: PHPaymentConfiguration,
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
