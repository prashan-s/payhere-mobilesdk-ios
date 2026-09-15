//
//  UIFont+PayHere.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

import UIKit

extension UIFont {
    private static func registerFont(withName name: String, fileExtension: String) {
        let frameworkBundle = Bundle.payHereBundle
        let pathForResourceString = frameworkBundle.path(forResource: name, ofType: fileExtension)
        let fontData = NSData(contentsOfFile: pathForResourceString!)
        let dataProvider = CGDataProvider(data: fontData!)
        let fontRef = CGFont(dataProvider!)
        var errorRef: Unmanaged<CFError>? = nil

        if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
            xprint("Error registering font")
        }
    }

    public static func loadFonts() {
        registerFont(withName: "HPay", fileExtension: "ttf")
        registerFont(withName: "HPayBold", fileExtension: "ttf")
    }
}
