import CoreGraphics

/// Height calculations in the legacy outer-panel coordinate system.
/// Presentation adapters supply container geometry and retain the resting height.
enum PHSheetHeightPolicy {
    static func dashboardHeight(containerWidth: CGFloat) -> CGFloat {
        let cellHeight = (((containerWidth - 20) / 5) - 15) * 3
        let constHeight = 45.0 + (50.0 * 3.0)
        return cellHeight + CGFloat(constHeight) + 20
    }

    static func initialWebHeight(
        selectedHeight: Int?,
        visaHeight: Int?,
        restingHeight: CGFloat,
        containerHeight: CGFloat
    ) -> CGFloat {
        let selectedHeight = CGFloat(selectedHeight ?? 0)
        let visaHeight = CGFloat(visaHeight ?? 0)
        let contentHeight: CGFloat

        if selectedHeight > 0, visaHeight > 0, restingHeight > 0 {
            contentHeight = (selectedHeight / visaHeight) * restingHeight
        } else {
            contentHeight = containerHeight * 0.48
        }

        let maximumHeight = containerHeight - 20
        var totalHeight = contentHeight + 64
        if totalHeight > maximumHeight {
            totalHeight = maximumHeight
        }
        return totalHeight
    }

    static func cardFormHeight(
        contentHeight: CGFloat,
        chromeHeight: CGFloat,
        explicitBottomInset: CGFloat,
        safeAreaBottom: CGFloat,
        containerHeight: CGFloat,
        safeAreaTop: CGFloat
    ) -> CGFloat {
        let bottomInset = max(explicitBottomInset, safeAreaBottom)
        let maximumHeight = max(0, containerHeight - safeAreaTop)
        let fittedHeight = min(contentHeight + chromeHeight + bottomInset, maximumHeight)
        return max(0, fittedHeight)
    }

    static func keyboardVisibleHeight(
        restingHeight: CGFloat,
        containerHeight: CGFloat,
        safeAreaTop: CGFloat,
        keyboardOverlap: CGFloat
    ) -> CGFloat {
        let availableHeight = max(0, containerHeight - safeAreaTop - keyboardOverlap)
        return min(restingHeight, availableHeight)
    }
}
