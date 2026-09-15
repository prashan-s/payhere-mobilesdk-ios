//
//  PayOptionCollectionViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 12/18/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import UIKit
import SDWebImage

final public class PayOptionCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imgOptionImage: UIImageView!
    @IBOutlet weak var viewBackground: UIView!
    private var imageURL: URL?
    private var imageRequestStarted = false
    private var imageRequestID = UUID()

    internal func configure(imageURL: URL?, placeholder: UIImage?) {
        cancelImageLoad()
        self.imageURL = imageURL
        imgOptionImage.image = placeholder
        imgOptionImage.contentMode = .scaleAspectFit
    }

    internal func loadImageIfNeeded() {
        guard !imageRequestStarted, let url = imageURL else { return }
        imageRequestStarted = true
        let requestID = imageRequestID
        // Keep the current logo while resuming. Guard even queued completions from
        // superseded requests, and never animate synchronous memory-cache hits.
        imgOptionImage.sd_setImage(with: url, placeholderImage: imgOptionImage.image,
                                  options: [.retryFailed, .avoidAutoSetImage]) { [weak self] image, _, cacheType, _ in
            guard let self = self, self.imageRequestID == requestID, let image = image else { return }
            if cacheType == .memory || UIAccessibility.isReduceMotionEnabled {
                self.imgOptionImage.image = image
            } else {
                UIView.transition(with: self.imgOptionImage, duration: PHConfigs.kCellAnimateDuration,
                                  options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction]) {
                    self.imgOptionImage.image = image
                }
            }
        }
    }

    internal func cancelImageLoad() {
        imageRequestID = UUID()
        imgOptionImage.sd_cancelCurrentImageLoad()
        imgOptionImage.layer.removeAllAnimations()
        imageRequestStarted = false
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        cancelImageLoad()
        imageURL = nil
        imgOptionImage.image = nil
        viewBackground.layer.removeAllAnimations()
        UIView.performWithoutAnimation {
            isSelected = false
            isHighlighted = false
            updateSelection()
        }
    }
    
    public override var isSelected: Bool{
        didSet{
            updateSelection()
        }
    }
    
    public override var isHighlighted: Bool{
        didSet{
            updateSelection()
        }
    }
    
    private func updateSelection(){
        UIView.animate(withDuration: PHConfigs.kCellAnimateDuration, delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            if self.isSelected || self.isHighlighted{
                self.viewBackground.backgroundColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.4)
            }
            else{
                self.viewBackground.backgroundColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.04)
            }
        }
    }

}
