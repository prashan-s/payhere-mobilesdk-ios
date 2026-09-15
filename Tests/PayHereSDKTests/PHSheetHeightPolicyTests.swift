import XCTest
import CoreGraphics
@testable import PayHereSDK

final class PHSheetHeightPolicyTests: XCTestCase {
    func testDashboardHeightPreservesWidthFormulaWithoutCapOrSafeAreaAddition() {
        let cases: [(width: CGFloat, height: CGFloat)] = [
            (0, 158), (320, 350), (375, 383), (390, 392),
            (430, 416), (768, 618.8), (1024, 772.4)
        ]

        for testCase in cases {
            XCTAssertEqual(
                PHSheetHeightPolicy.dashboardHeight(containerWidth: testCase.width),
                testCase.height,
                accuracy: 0.000001,
                "Container width: \(testCase.width)")
        }
    }

    func testInitialWebHeightUsesSelectedToVisaRatioAndPrecedingRestingHeight() {
        let cases: [(selected: Int, visa: Int, resting: CGFloat, height: CGFloat)] = [
            (300, 600, 392, 260),
            (480, 600, 392, 377.6),
            (600, 600, 392, 456),
            (600, 600, 760, 824),
            (1200, 600, 392, 824),
            (300, 600, 600, 364)
        ]

        for testCase in cases {
            XCTAssertEqual(
                PHSheetHeightPolicy.initialWebHeight(
                    selectedHeight: testCase.selected,
                    visaHeight: testCase.visa,
                    restingHeight: testCase.resting,
                    containerHeight: 844),
                testCase.height,
                accuracy: 0.000001)
        }
    }

    func testMissingZeroAndNegativeMetadataRetainExistingFallback() {
        let cases: [(selected: Int?, visa: Int?, resting: CGFloat)] = [
            (nil, nil, 392), (nil, 600, 392), (600, nil, 392),
            (0, 600, 392), (600, 0, 392), (0, 0, 392),
            (-1, 600, 392), (600, -1, 392),
            (600, 600, 0), (600, 600, -1)
        ]

        for testCase in cases {
            XCTAssertEqual(
                PHSheetHeightPolicy.initialWebHeight(
                    selectedHeight: testCase.selected,
                    visaHeight: testCase.visa,
                    restingHeight: testCase.resting,
                    containerHeight: 844),
                469.12,
                accuracy: 0.000001)
        }
    }

    func testInitialWebHeightRetainsLegacyCapWithoutAddingZeroClamp() {
        XCTAssertEqual(
            PHSheetHeightPolicy.initialWebHeight(
                selectedHeight: nil,
                visaHeight: nil,
                restingHeight: 392,
                containerHeight: 10),
            -10)
    }

    func testCardFormUsesMeasuredChromeInsteadOfMetadataHeaderAllowance() {
        let metadataHeight = PHSheetHeightPolicy.initialWebHeight(
            selectedHeight: 600,
            visaHeight: 600,
            restingHeight: 392,
            containerHeight: 844)
        let cardHeight = PHSheetHeightPolicy.cardFormHeight(
            contentHeight: 392,
            chromeHeight: 61,
            explicitBottomInset: 0,
            safeAreaBottom: 0,
            containerHeight: 844,
            safeAreaTop: 59)

        XCTAssertEqual(metadataHeight, 456)
        XCTAssertEqual(cardHeight, 453)
    }

    func testCardFormUsesLargerBottomInsetWithoutAccumulatingDocumentTail() {
        let cases: [(explicitInset: CGFloat, safeBottom: CGFloat, height: CGFloat)] = [
            (0, 0, 361), (-200, 0, 361),
            (0, 34, 395), (-200, 34, 395), (-166, 34, 395),
            (34, 34, 395), (50, 34, 411)
        ]

        for testCase in cases {
            XCTAssertEqual(
                PHSheetHeightPolicy.cardFormHeight(
                    contentHeight: 300,
                    chromeHeight: 61,
                    explicitBottomInset: testCase.explicitInset,
                    safeAreaBottom: testCase.safeBottom,
                    containerHeight: 844,
                    safeAreaTop: 59),
                testCase.height)
        }
    }

    func testMetadataAndCardFormKeepTheirDistinctMaximumHeights() {
        XCTAssertEqual(
            PHSheetHeightPolicy.initialWebHeight(
                selectedHeight: 2000,
                visaHeight: 600,
                restingHeight: 392,
                containerHeight: 844),
            824)
        XCTAssertEqual(
            PHSheetHeightPolicy.cardFormHeight(
                contentHeight: 2000,
                chromeHeight: 61,
                explicitBottomInset: -200,
                safeAreaBottom: 34,
                containerHeight: 844,
                safeAreaTop: 59),
            785)
    }

    func testCardFormClampsUnavailableContainerHeightToZero() {
        XCTAssertEqual(
            PHSheetHeightPolicy.cardFormHeight(
                contentHeight: 300,
                chromeHeight: 61,
                explicitBottomInset: 0,
                safeAreaBottom: 34,
                containerHeight: 40,
                safeAreaTop: 59),
            0)
    }

    func testKeyboardVisibilityKeepsRestingHeightIndependentOfRepeatedFocus() {
        let restingHeight: CGFloat = 700
        let cases: [(overlap: CGFloat, height: CGFloat)] = [
            (0, 700), (100, 685), (336, 449),
            (336, 449), (900, 0), (0, 700)
        ]

        for testCase in cases {
            XCTAssertEqual(
                PHSheetHeightPolicy.keyboardVisibleHeight(
                    restingHeight: restingHeight,
                    containerHeight: 844,
                    safeAreaTop: 59,
                    keyboardOverlap: testCase.overlap),
                testCase.height)
        }

        XCTAssertEqual(
            PHSheetHeightPolicy.initialWebHeight(
                selectedHeight: 300,
                visaHeight: 600,
                restingHeight: restingHeight,
                containerHeight: 844),
            414)
    }

    func testKeyboardDoesNotGrowAShortRestingSheet() {
        XCTAssertEqual(
            PHSheetHeightPolicy.keyboardVisibleHeight(
                restingHeight: 300,
                containerHeight: 844,
                safeAreaTop: 59,
                keyboardOverlap: 336),
            300)
    }
}
