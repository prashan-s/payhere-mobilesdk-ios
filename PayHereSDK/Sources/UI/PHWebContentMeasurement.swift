//
//  PHWebContentMeasurement.swift
//  payHereSDK
//
//  Created by Prashan Samarathunge on 2026-10-15.
//  Copyright © 2026 PayHere. All rights reserved.
//

import CoreGraphics

internal struct PHWebContentMeasurement {
    let isCardForm: Bool
    let height: CGFloat
    let bottomSpacing: CGFloat
    let viewportWidth: CGFloat
    let viewportFloorBottom: CGFloat
    let documentID: String

    init?(_ result: Any?) {
        guard let values = result as? [String: Any],
              let kind = values["kind"] as? String, kind == "card" || kind == "page",
              let documentID = values["documentID"] as? String, !documentID.isEmpty,
              let height = values["height"] as? Double, height.isFinite, height >= 0,
              let bottomSpacing = values["bottomSpacing"] as? Double, bottomSpacing.isFinite, bottomSpacing >= 0,
              let viewportWidth = values["viewportWidth"] as? Double, viewportWidth.isFinite, viewportWidth > 0,
              let viewportHeight = values["viewportHeight"] as? Double, viewportHeight.isFinite, viewportHeight > 0,
              let documentHeight = values["documentHeight"] as? Double, documentHeight.isFinite, documentHeight >= 0,
              let viewportFloorBottom = values["viewportFloorBottom"] as? Double,
              viewportFloorBottom.isFinite, viewportFloorBottom >= 0,
              kind != "card" || height > 0 else { return nil }
        self.isCardForm = kind == "card"
        self.height = CGFloat(height)
        self.bottomSpacing = CGFloat(bottomSpacing)
        self.viewportWidth = CGFloat(viewportWidth)
        self.viewportFloorBottom = CGFloat(viewportFloorBottom)
        self.documentID = documentID
    }

    func matches(_ other: PHWebContentMeasurement) -> Bool {
        // Automatic safe-area adjustment can change WebKit's viewport floor while
        // painted content is unchanged. Only content demand must agree to resize.
        return isCardForm == other.isCardForm && documentID == other.documentID &&
            abs(height - other.height) <= 1 && abs(bottomSpacing - other.bottomSpacing) <= 1 &&
            abs(viewportWidth - other.viewportWidth) <= 1 &&
            abs(viewportFloorBottom - other.viewportFloorBottom) <= 1
    }
}
