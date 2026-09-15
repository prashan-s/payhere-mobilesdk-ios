//
//  PHWebLayoutMessageHandler.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

@preconcurrency import WebKit

@MainActor
internal final class PHWebLayoutMessageHandler: NSObject, WKScriptMessageHandler {
    private let receive: (WKScriptMessage) -> Void

    init(receive: @escaping (WKScriptMessage) -> Void) { self.receive = receive }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        receive(message)
    }
}
