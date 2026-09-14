//
//  PHPrecentController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 10/8/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import Foundation
import UIKit

public class PHPrecentController{
    
    @available(*, deprecated, renamed: "present", message: "Use present(from:,withInitRequest:,shouldShowPaymentStatus:,delegate) instead!")
    public static func precent(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        present(from: from,
                withInitRequest: request,
                shouldShowPaymentStatus: showPaymentStatus,
                delegate: delegate)
    }
    
    public static func present(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        present(from: from,
                withInitRequest: request,
                configuration: PHPaymentConfiguration(showResultScreen: showPaymentStatus),
                delegate: delegate)
    }

    /// Presents a payment using preferences scoped to this presentation.
    /// Presentation and delegate callbacks are delivered on the main queue.
    public static func present(from: UIViewController,
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
