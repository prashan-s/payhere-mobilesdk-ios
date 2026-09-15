import XCTest
import UIKit
import SDWebImage
@testable import PayHereSDK

final class PHPaymentImageTests: XCTestCase {
    @MainActor
    func testConfigurationIsLazyAndMemoryHitDoesNotFlashPlaceholder() throws {
        let cell = try makeCell()
        let url = try XCTUnwrap(URL(string: "https://images.example.invalid/\(UUID().uuidString).png"))
        let remote = makeImage(.red)
        let placeholder = makeImage(.blue)
        SDImageCache.shared.store(remote, forKey: url.absoluteString, toDisk: false, completion: nil)
        defer { SDImageCache.shared.removeImageFromMemory(forKey: url.absoluteString) }

        cell.configure(imageURL: url, placeholder: placeholder)
        XCTAssertNil(cell.imgOptionImage.sd_currentImageURL)
        XCTAssertTrue(cell.imgOptionImage.image === placeholder)

        cell.loadImageIfNeeded()
        XCTAssertEqual(cell.imgOptionImage.sd_currentImageURL, url)
        XCTAssertTrue(cell.imgOptionImage.image === remote, "A memory hit must be ready in the same display pass")
        XCTAssertTrue(cell.imgOptionImage.layer.animationKeys()?.isEmpty ?? true)

        cell.cancelImageLoad()
        cell.loadImageIfNeeded()
        XCTAssertTrue(cell.imgOptionImage.image === remote, "Returning onscreen must retain the resolved logo")
    }

    @MainActor
    func testReuseCancelsPendingDiskResultAndRestoresSelection() async throws {
        let cell = try makeCell()
        let url = try XCTUnwrap(URL(string: "https://images.example.invalid/\(UUID().uuidString).png"))
        let remote = makeImage(.red)
        let replacement = makeImage(.green)
        await withCheckedContinuation { continuation in
            SDImageCache.shared.store(remote, forKey: url.absoluteString, toDisk: true) {
                continuation.resume()
            }
        }
        defer { SDImageCache.shared.removeImage(forKey: url.absoluteString, withCompletion: nil) }
        SDImageCache.shared.removeImageFromMemory(forKey: url.absoluteString)

        cell.configure(imageURL: url, placeholder: nil)
        cell.loadImageIfNeeded()
        cell.isSelected = true
        cell.isHighlighted = true
        cell.prepareForReuse()
        XCTAssertNil(cell.imgOptionImage.image)
        XCTAssertFalse(cell.isSelected)
        XCTAssertFalse(cell.isHighlighted)
        XCTAssertNil(cell.imgOptionImage.sd_imageTransition)
        XCTAssertTrue(cell.viewBackground.layer.animationKeys()?.isEmpty ?? true)

        cell.configure(imageURL: nil, placeholder: replacement)
        cell.loadImageIfNeeded()
        // Drain a subsequent query on the cache's serial disk queue before checking
        // that the earlier asynchronous image result cannot replace the new method.
        await withCheckedContinuation { continuation in
            SDImageCache.shared.queryCacheOperation(forKey: url.absoluteString) { _, _, _ in
                continuation.resume()
            }
        }
        XCTAssertTrue(cell.imgOptionImage.image === replacement)
    }

    @MainActor
    func testTableReuseClearsDataDelegateAndScrollPosition() throws {
        let table = UITableView()
        table.register(UINib(nibName: "PaymentOptionTableViewCell", bundle: .payHereBundle),
                       forCellReuseIdentifier: "PaymentOptionTableViewCell")
        let delegate = ImageTestSelectionDelegate()
        var method = PaymentMethod()
        method.method = "VISA"
        let row = PaymentOptionTableViewCell.dequeue(fromTableView: table,
            list: [method], indexPath: IndexPath(row: 0, section: 1), delegate: delegate)
        row.collectionView.contentOffset = CGPoint(x: 54, y: 0)
        row.prepareForReuse()

        XCTAssertNil(row.delegate)
        XCTAssertEqual(row.collectionView.contentOffset, CGPoint.zero)
        XCTAssertEqual(row.collectionView(row.collectionView, numberOfItemsInSection: 0), 0)
        row.collectionView(row.collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(delegate.selectionCount, 0)
        XCTAssertTrue(row.collectionView.dataSource === row)
        XCTAssertTrue(row.collectionView.delegate === row)
    }

    @MainActor
    private func makeCell() throws -> PayOptionCollectionViewCell {
        try XCTUnwrap(UINib(nibName: "PayOptionCollectionViewCell", bundle: .payHereBundle)
            .instantiate(withOwner: nil).first as? PayOptionCollectionViewCell)
    }

    @MainActor
    private func makeImage(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

private final class ImageTestSelectionDelegate: PaymentOptionTableViewCellDelegate {
    private(set) var selectionCount = 0

    func didSelectedPaymentOption(paymentMethod: PaymentMethod, selectedSection: Int) {
        selectionCount += 1
    }
}
