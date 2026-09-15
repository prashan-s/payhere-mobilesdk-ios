//
//  Extention.swift
//  sdk
//
//  Created by Kamal Sampath Upasena on 3/6/18.
//  Copyright © 2018 PayHere. All rights reserved.
//

import Foundation

extension Bundle{
    
    internal static var payHereBundle: Bundle{
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: PayHereSDK.self)
        #endif
    }
    
}
