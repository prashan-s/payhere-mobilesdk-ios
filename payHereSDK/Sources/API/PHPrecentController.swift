//
//  PHPrecentController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 10/8/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import Foundation
import UIKit

/// Compatibility entry point. Use `PHPresentController` for new integrations.
@available(*, deprecated, renamed: "PHPresentController")
public class PHPrecentController{
    
    @available(*, deprecated, renamed: "present", message: "Use present(from:,withInitRequest:,shouldShowPaymentStatus:,delegate) instead!")
    public static func precent(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        PHPresentController.present(from: from,
                                    withInitRequest: request,
                                    configuration: .init(showResultScreen: showPaymentStatus),
                                    delegate: delegate)
    }
    
    public static func present(from : UIViewController,
                               withInitRequest request : PHInitialRequest,
                               shouldShowPaymentStatus showPaymentStatus:Bool = true,
                               delegate : PHViewControllerDelegate){
        PHPresentController.present(from: from,
                                    withInitRequest: request,
                                    configuration: .init(showResultScreen: showPaymentStatus),
                                    delegate: delegate)
    }
    
}
