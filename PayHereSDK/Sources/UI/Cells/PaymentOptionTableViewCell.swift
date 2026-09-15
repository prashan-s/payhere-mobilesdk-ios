//
//  PaymentOptionTableViewCell.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2022-01-04.
//  Copyright © 2022 PayHere. All rights reserved.
//

import UIKit


public protocol PaymentOptionTableViewCellDelegate: AnyObject{
    func didSelectedPaymentOption(paymentMethod : PaymentMethod,selectedSection : Int)
}

public class PaymentOptionTableViewCell: UITableViewCell {
    
    private var list : [PaymentMethod] = []
    private var sectionID : Int = 0
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate : PaymentOptionTableViewCellDelegate?
    
    
    public static func dequeue(fromTableView tv: UITableView,list : [PaymentMethod],indexPath path : IndexPath,delegate : PaymentOptionTableViewCellDelegate) -> PaymentOptionTableViewCell{
        let cell = tv.dequeueReusableCell(withIdentifier: "PaymentOptionTableViewCell") as! PaymentOptionTableViewCell
        cell.list = list
        cell.selectionStyle = .none
        cell.delegate = delegate
        cell.sectionID = path.section
        cell.collectionView.reloadData()
        return cell
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        collectionView.visibleCells.forEach { ($0 as? PayOptionCollectionViewCell)?.cancelImageLoad() }
        list.removeAll()
        delegate = nil
        sectionID = 0
        collectionView.setContentOffset(.zero, animated: false)
        collectionView.reloadData()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        collectionView?.visibleCells.forEach { cell in
            guard let cell = cell as? PayOptionCollectionViewCell else { return }
            if window == nil { cell.cancelImageLoad() }
            else { cell.loadImageIfNeeded() }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}

extension PaymentOptionTableViewCell {
    
    private func setupUI() {
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        
        
        let nib = UINib(nibName: "PayOptionCollectionViewCell", bundle: Bundle.payHereBundle)
        
        collectionView.register(nib, forCellWithReuseIdentifier: "PayOptionCollectionViewCell")
        
       
        collectionView.delegate = self
        collectionView.dataSource = self
        

    }
}

extension PaymentOptionTableViewCell: UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return list.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PayOptionCollectionViewCell", for: indexPath) as! PayOptionCollectionViewCell
        
        let method  = list[indexPath.row]
        
        let imageURL = method.view?.imageUrl.flatMap { URL(string: $0) }
        cell.configure(imageURL: imageURL,
                       placeholder: getImage(withImageName: method.method?.lowercased() ?? "visa"))
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        (cell as? PayOptionCollectionViewCell)?.loadImageIfNeeded()
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        (cell as? PayOptionCollectionViewCell)?.cancelImageLoad()
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard list.indices.contains(indexPath.item) else { return }
        delegate?.didSelectedPaymentOption(paymentMethod: list[indexPath.row],selectedSection: sectionID)
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    private func getImage(withImageName : String) -> UIImage{
        if let image =  UIImage(named: withImageName, in: Bundle.payHereBundle, compatibleWith: nil){
            return image
        }else{
            return UIImage()
        }
    }
}

extension PaymentOptionTableViewCell: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 54, height: 54)
    }
}
