//
//  PHViewControllerDelegate.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

/// Retained only to provide migration diagnostics for the former delegate API.
@available(*, unavailable, renamed: "PayHereSDKDelegate")
public protocol PHViewControllerDelegate: AnyObject {}

@available(*, unavailable)
public extension PHViewControllerDelegate {
    @available(*, unavailable, renamed: "payHereSDK(didReceive:)",
               message: "Use PayHereSDKDelegate with a nonoptional payment response.")
    func onResponseReceived(response: PHResponse<Any>?) {
        // Unavailable: response handling must migrate to PayHereSDKDelegate.
    }
}
