//
//  PHPaymentLifecycle.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-14.
//  Copyright © 2026 PayHere. All rights reserved.
//

import Foundation

/// Serializes attempt ownership and terminal delivery with the payment UI.
@MainActor
internal struct PHPaymentLifecycle {
    internal enum Phase {
        case idle, active, result, closing, closed
    }

    private(set) var attemptID = UUID()
    private(set) var phase: Phase = .idle

    mutating func beginAttempt() -> UUID? {
        guard phase != .closing, phase != .closed else { return nil }
        attemptID = UUID()
        phase = .active
        return attemptID
    }

    func accepts(_ attemptID: UUID) -> Bool {
        return phase == .active && self.attemptID == attemptID
    }

    mutating func receiveTerminalStatus(_ status: StatusResponse.Status?) -> Bool {
        guard phase == .active else { return false }
        switch status {
        case .SUCCESS?, .FAILED?, .AUTHORIZED?:
            phase = .result
            return true
        default:
            return false
        }
    }

    func canRetry(configuration: PHPaymentConfiguration, status: StatusResponse.Status?) -> Bool {
        return phase == .result && status == .FAILED &&
            configuration.showResultScreen && configuration.showRetryOnResultScreen
    }

    mutating func beginClosing() -> Bool {
        guard phase != .closing, phase != .closed else { return false }
        phase = .closing
        return true
    }

    mutating func finishClosing() -> Bool {
        guard phase == .closing else { return false }
        phase = .closed
        return true
    }
}
