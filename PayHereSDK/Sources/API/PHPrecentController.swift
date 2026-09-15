//
//  PHPrecentController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 10/8/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import Foundation
import UIKit

/// Retained only to provide migration diagnostics for the former presentation API.
@available(*, unavailable, renamed: "PayHereSDK")
public final class PHPrecentController {
    
    @available(*, unavailable, message: "Use PayHereSDK.present(from:withInitRequest:configuration:delegate:) and PHPaymentConfiguration(showResultScreen:).")
    public static func precent(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        // Unavailable: use the modern entry point and configuration.
    }
    
    @available(*, unavailable, message: "Use PayHereSDK.present(from:withInitRequest:configuration:delegate:) and PHPaymentConfiguration(showResultScreen:).")
    public static func present(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        // Unavailable: use the modern entry point and configuration.
    }
}
