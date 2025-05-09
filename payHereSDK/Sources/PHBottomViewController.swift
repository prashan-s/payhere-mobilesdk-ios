//
//  PHBottomViewController.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 12/17/19.
//  Copyright © 2019 PayHere. All rights reserved.
//

import UIKit
import Alamofire
import ObjectMapper
@preconcurrency import WebKit

public protocol PHViewControllerDelegate: AnyObject{
    func onResponseReceived(response : PHResponse<Any>?)
    func onErrorReceived(error : Error)
}
internal class PHBottomViewController: UIViewController {
    
    
    //MARK: TypeAlias
    
    
    //MARK: - Enum
    
    
    
    //MARK: - Classes
    
    
    
    //MARK: - Structs
    
    
    
    //MARK: - Constants
    private let net                                 : NetworkReachabilityManager    = NetworkReachabilityManager(host: "payhere.lk")!
    
    
    
    // MARK: - Variables
    internal var initialRequest                     : PHInitialRequest?
    internal var isSandBoxEnabled                   : Bool                          = false
    internal var orgHeight                          : CGFloat                       = 0
    internal var keyBoardHeightMax                  : CGFloat                       = 0
    internal var shouldShowSucessView               : Bool                          = true
    
    private var ignoreProgressBarInNextNavigation   : Bool                          = false
    private var didHandlePaymentStatus              : Bool                          = false
    private var count                               : Int                           = 5
    private var statusResponse                      : StatusResponse?
    private var timer                               : Timer?
    private var isBackPressed                       : Bool                          = false
    private var waitUntilPaymentUI                  : WaitUntil!
    
    
    private var bankAccount                         : [PaymentMethod]               = []
    private var bankCard                            : [PaymentMethod]               = []
    private var other                               : [PaymentMethod]               = []
    
    private var initRequest                         : PHInitRequest?
    private var initResponse                        : PHInitResponse?
    private var paymentUI                           : PaymentUI                     = PaymentUI()
    private var selectedPaymentOption               : PaymentOption?
    private var apiMethod                           : SelectedAPI                   = .CheckOut
    private var selectedPaymentMethod               : PaymentMethod?
    
    private var paymentOption                       : [PaymentOption] {
        
        get{
            return [
                PaymentOption(name: "Visa"          , image: getImage(withImageName: "visa")    , optionValue: "VISA"),
                PaymentOption(name: "Master"        , image: getImage(withImageName: "master")  , optionValue: "MASTER"),
                PaymentOption(name: "Amex"          , image: getImage(withImageName: "amex")    , optionValue: "AMEX"),
                PaymentOption(name: "Discover"      , image: getImage(withImageName: "discover"), optionValue: "AMEX"),
                PaymentOption(name: "Diners Club"   , image: getImage(withImageName: "diners")  , optionValue: "AMEX"),
                PaymentOption(name: "Genie"         , image: getImage(withImageName: "genie")   , optionValue: "GENIE"),
                PaymentOption(name: "Frimi"         , image: getImage(withImageName: "frimi")   , optionValue: "FRIMI"),
                PaymentOption(name: "Ez Cash"       , image: getImage(withImageName: "ezcash")  , optionValue: "EZCASH"),
                PaymentOption(name: "m Cash"        , image: getImage(withImageName: "mcash")   , optionValue: "MCASH"),
                PaymentOption(name: "Vishwa"        , image: getImage(withImageName: "vishwa")  , optionValue: "VISHWA"),
                PaymentOption(name: "HNB"           , image: getImage(withImageName: "hnb")     , optionValue: "HNB"),
                PaymentOption(name: "QPLUS"         , image: getImage(withImageName: "QPLUS")   , optionValue: "QPLUS")
            ]
            
        }
        
    }

    
    // WEAK VAR
    internal weak var delegate : PHViewControllerDelegate?
    private weak var alertController:UIAlertController?
    
    // MARK: - IBOutlets & Weak Views
    @IBOutlet private weak var progressBar: UIActivityIndicatorView!
    @IBOutlet private weak var height: NSLayoutConstraint!
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var webView: WKWebView!
    @IBOutlet private weak var bottomView: UIView!
    @IBOutlet private weak var viewSandboxNoteBanner: UIView!
    @IBOutlet private weak var tableView: UITableView!
    
    @IBOutlet private weak var lblPayWithTitle: UILabel!
    @IBOutlet private weak var btnBackImage: UIImageView!
    @IBOutlet private weak var stackViewBackViewWrapper: UIStackView!
    
    @IBOutlet private weak var viewPaymentSucess: UIView!
    @IBOutlet private weak var viewBackground: UIView!
    
    @IBOutlet private weak var checkMark: WVCheckMark!
    @IBOutlet private weak var imgDeclined: UIImageView!
    @IBOutlet private weak var lblPaymentStatus: UILabel!
    @IBOutlet private weak var lblBottomMessage: UILabel!
    @IBOutlet private weak var lblPaymentID: UILabel!
    
    @IBOutlet private weak var btnDone: UIButton!
    @IBOutlet private weak var btnCancel: UIButton!
    @IBOutlet private weak var btnTryAgain: UIButton!
    
    
    // MARK: - Object Creation
    
    
    
    // MARK: - Object Life Cycle
    
    override public func viewDidLoad() {
        
        UIFont.loadFonts()
        
        super.viewDidLoad()
        
        self.lblPayWithTitle.font =  UIFont(name: "HPayBold", size: 18)
        self.lblPaymentStatus.font = UIFont(name: "HPay", size: 16)
        self.lblPaymentID.font = UIFont(name: "HPay", size: 14)
        self.lblBottomMessage.font = UIFont(name: "HPay", size: 12)
        
        self.btnDone.titleLabel?.font = UIFont(name: "HPayBold", size: PHConfigs.kFontSize)!
        self.btnCancel.titleLabel?.font = UIFont(name: "HPayBold", size: PHConfigs.kFontSize)!
        self.btnTryAgain.titleLabel?.font = UIFont(name: "HPayBold", size: PHConfigs.kFontSize)!
        
        if(isSandBoxEnabled){
            PHConfigs.setBaseUrl(url: PHConfigs.SANDBOX_URL)
            self.viewSandboxNoteBanner.isHidden = false
        }else{
            PHConfigs.setBaseUrl(url: PHConfigs.LIVE_URL)
            self.viewSandboxNoteBanner.isHidden = true
        }
        
        setInitialHeight()
        
        
        self.viewPaymentSucess.isHidden = true
        
        
        self.initRequest = createInitRequest(phInitialRequest: initialRequest!)
        
        // Keyboard Notifications
        // WillShow and not Did ;) The View will run animated and smooth
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShowFunction(notification:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHideFunction(notification:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
        
        
        if let data = UserDefaults().data(forKey: PHConstants.UI){
            do{
                self.paymentUI = try newJSONDecoder().decode(PaymentUI.self, from: data)
            }catch{
                xprint(error)
            }
            self.getPaymentUI()
        }
        else{
            self.getPaymentUI()
        }
        
        webView.scrollView.delegate = self
        
        
        let helaPayNib = UINib(nibName: "PayWithHelaPayTableViewCell", bundle: Bundle.payHereBundle)
        self.tableView.register(helaPayNib, forCellReuseIdentifier: "PayWithHelaPayTableViewCell")
        
        let paymentOptionNib = UINib(nibName: "PaymentOptionTableViewCell", bundle: Bundle.payHereBundle)
        self.tableView.register(paymentOptionNib, forCellReuseIdentifier: "PaymentOptionTableViewCell")
        
        let nib = UINib(nibName: "PHBottomSheetTableViewSectioHeader", bundle: Bundle.payHereBundle)
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "PHBottomSheetTableViewSectioHeader")
        
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.bottomView.layer.cornerRadius = 12
        self.bottomView.layer.masksToBounds = true
        
        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 0.00001))
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(backButtonClicked))
        stackViewBackViewWrapper.addGestureRecognizer(tap)
        
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(forceClose))
        self.viewBackground.addGestureRecognizer(backgroundTap)
    
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        bottomConstraint.constant = -height.constant
        performInitialSteps()
        
    }
    
    private func performInitialSteps(){
        self.didHandlePaymentStatus = false
        self.progressBar.isHidden = true
        
        if apiMethod == .CheckOut{
            self.btnBackImage.isHidden = true
        }
        
        self.handleNavigation(stepId: .Dashboard, sectionId: -1)
        self.startProcess(selectedAPI: self.apiMethod)
    }
    
    @objc func keyboardWillShowFunction(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            
            if(keyBoardHeightMax == 0){
                keyBoardHeightMax = keyboardSize.height
            }
            
            keyBoardHeightMax = max(keyboardSize.height, keyBoardHeightMax)
            
            if((keyBoardHeightMax  + orgHeight) > self.view.frame.height){
                keyBoardHeightMax = keyBoardHeightMax / 2
            }
            
            height.constant = orgHeight + keyBoardHeightMax
            animateChanges()
            
        }
        
    }
    
    @objc func keyboardWillHideFunction(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            
            if(keyBoardHeightMax == 0){
                keyBoardHeightMax = keyboardSize.height
            }
            
            keyBoardHeightMax = max(keyboardSize.height, keyBoardHeightMax)
            
            height.constant = orgHeight//height.constant - keyBoardHeightMax
            animateChanges()
            
        }
        
    }
    
    private func close(animate:Bool = true,and callback: (() -> Void)? = nil){
        timer?.invalidate()
        webView.scrollView.delegate = nil
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        if animate {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut) {
                self.bottomConstraint.constant = -self.height.constant
                self.view.layoutIfNeeded()
            }completion: { _ in
                self.dismiss(animated: true) {
                    DispatchQueue.main.async {
                        callback?()
                    }
                }
            }
        }else {
            dismiss(animated: false) {
                callback?()
            }
        }

    }
    
    private func createInitRequest(phInitialRequest : PHInitialRequest) ->PHInitRequest{
        
        let initialSubmitRequest = PHInitRequest()
        
        initialSubmitRequest.merchantID = phInitialRequest.merchantID
        
        initialSubmitRequest.returnURL = PHConstants.dummyUrl
        initialSubmitRequest.cancelURL = PHConstants.dummyUrl
        
        if (phInitialRequest.notifyURL == nil || phInitialRequest.notifyURL?.count == 0){
            initialSubmitRequest.notifyURL = PHConstants.dummyUrl
        }else{
            initialSubmitRequest.notifyURL = phInitialRequest.notifyURL
        }
        
        initialSubmitRequest.firstName = phInitialRequest.firstName
        initialSubmitRequest.lastName = phInitialRequest.lastName
        initialSubmitRequest.email = phInitialRequest.email
        initialSubmitRequest.phone = phInitialRequest.phone
        
        initialSubmitRequest.address = phInitialRequest.address
        initialSubmitRequest.city = phInitialRequest.city
        initialSubmitRequest.country = phInitialRequest.country
        
        initialSubmitRequest.orderID = phInitialRequest.orderID
        initialSubmitRequest.itemsDescription = phInitialRequest.itemsDescription
        
        if(phInitialRequest.itemsMap != nil){
            
            if(phInitialRequest.itemsMap!.count > 0){
                
                var itemMap : [String : String] = [:]
                
                for (i,item) in (phInitialRequest.itemsMap?.enumerated())!{
                    
                    itemMap[String(format: "item_name_%d", i+1)] = item.name
                    itemMap[String(format: "item_number_%d", i+1)] = item.id
                    itemMap[String(format: "amount_%d", i+1)] =  String(format : "%.2f",item.amount ?? 0.0)
                    itemMap[String(format: "quantity_%d", i+1)] = String(format : "%d",item.quantity ?? 0)
                    
                }
                
                initialSubmitRequest.itemsMap = itemMap
                
            }else{
                initialSubmitRequest.itemsMap = nil
            }
            
        }else{
            initialSubmitRequest.itemsMap = nil
        }
        
        initialSubmitRequest.currency = phInitialRequest.currency?.rawValue
        if(phInitialRequest.amount == nil){
            initialSubmitRequest.amount = nil
            //            self.apiMethod = .PreApproval
        }else{
            initialSubmitRequest.amount = phInitialRequest.amount
        }
        
        initialSubmitRequest.deliveryAddress = phInitialRequest.deliveryAddress
        initialSubmitRequest.deliveryCity = phInitialRequest.deliveryCity
        initialSubmitRequest.deliveryCountry = phInitialRequest.deliveryCountry
        
        initialSubmitRequest.platform = PHConstants.PLATFORM
        
        initialSubmitRequest.custom1 = phInitialRequest.custom1
        initialSubmitRequest.custom2 = phInitialRequest.custom2
        
        if(phInitialRequest.startupFee == nil){
            initialSubmitRequest.startupFee = nil
        }else{
            initialSubmitRequest.startupFee = phInitialRequest.startupFee
        }
        
        
        if(phInitialRequest.recurrence == nil){
            initialSubmitRequest.recurrence = nil
            initialSubmitRequest.auto = false
            
        }else{
            
            var recurrenceString : String = ""
            
            switch phInitialRequest.recurrence {
            case .Month(period: (let period)):
                recurrenceString = String(format : "%d Month",period)
                
            case .Week(period: (let period)):
                recurrenceString = String(format : "%d Week",period)
                
            case .Year(period: (let period)):
                recurrenceString = String(format : "%d Year",period)
                
            default:
                break
            }
            initialSubmitRequest.recurrence = recurrenceString
            initialSubmitRequest.auto = true
            //            self.apiMethod = .Recurrence
        }
        
        if(phInitialRequest.duration == nil){
            initialSubmitRequest.duration = nil
            initialSubmitRequest.auto = false
            
        }else{
            
            var durationString : String = ""
            
            switch phInitialRequest.duration {
            case .Week(duration: (let duration)):
                durationString = String(format : "%d Week",duration)
                
            case .Month(duration: (let duration)):
                durationString = String(format : "%d Month",duration)
                
            case .Year(duration: (let duration)):
                durationString = String(format : "%d Year",duration)
                
            case .Forver:
                durationString = "Forever"
                
            default:
                break
            }
            
            initialSubmitRequest.duration = durationString
            initialSubmitRequest.auto = true
        }
        
        
        
        initialSubmitRequest.authorize = phInitialRequest.isHoldOnCardEnabled
        
        
        self.apiMethod = phInitialRequest.api
        
        
        initialSubmitRequest.referer = Bundle.main.bundleIdentifier
        
        initialSubmitRequest.hash = ""
        
        return initialSubmitRequest
        
    }
    
    
    
    
    private func startProcess(selectedAPI : SelectedAPI){
        
        self.viewPaymentSucess.isHidden = true
        self.progressBar.isHidden = false
        self.tableView.isHidden  = true
        
        let validate = self.Validate()
        
        if(validate == nil){
            checkNetworkAvailability(selectedAPI: selectedAPI);
        }else{
            close(animate: false) {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: validate as Any])
                self.delegate?.onErrorReceived(error: error)
            }
        }
        
    }
    
    private func checkNetworkAvailability(selectedAPI : SelectedAPI){
        
        var connection : Bool = false
        
        net.startListening(onUpdatePerforming: { [weak self] (status) in
            guard let `self` = self else { return }
            
            if(self.net.isReachable){
                
                switch status{
                case .reachable(.ethernetOrWiFi):
                    connection = true
                    
                case .reachable(.cellular):
                    connection = true
                    
                case .notReachable:
                    connection = false
                    
                case .unknown :
                    connection = false
                    
                }
                
                if (!connection) {
                    
                    self.close(animate: false) {
                        let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unable to connect to the internet"])
                        self.delegate?.onErrorReceived(error: error)
                    }
                    
                }else{
                    
                    if(self.apiMethod == .PreApproval || self.apiMethod == .Recurrence || self.apiMethod == .Authorize){
                        self.tableView.isHidden = true
                        self.progressBar.isHidden = true
                        self.selectedPaymentOption = PaymentOption(name: "Visa", image: self.getImage(withImageName: "visa"), optionValue: "VISA")
                        
                        self.initRequest?.method = "VISA"
                        self.sentInitNSubmitRequest()
                    }else{
                        self.handleNavigation(stepId: .Dashboard, sectionId: -1)
                        self.sentInitRequest()
                    }
                    
                }
            }
        })
    }
    
    @objc private func backButtonClicked(){
        
        if(apiMethod == .CheckOut && selectedPaymentOption != nil){
            
            self.selectedPaymentOption = nil
            self.selectedPaymentMethod = nil
            
            self.animateChanges {
                self.setInitialHeight()
            } completion: {
                self.webView.loadHTMLString("", baseURL: nil)
            }
            
            self.webView.isHidden = true
            self.tableView.isHidden = false
            
            self.isBackPressed = true
            self.progressBar.isHidden = true
            
            self.handleNavigation(stepId: .Dashboard, sectionId: -1)
        }
        else{
            self.close {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
                self.delegate?.onErrorReceived(error: error)
            }
        }
        
    }
    
    @objc private func forceClose(){
        let alert = UIAlertController(
            title: "Cancel Payment?",
            message: "This payment is still being processed!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {_ in
            // Cancel Occured
        }))
        
        alert.addAction(UIAlertAction(title: "Exit Now", style: .destructive) { [weak self] _ in
            // Force exit logic here
            self?.close { [self] in
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
                self?.delegate?.onErrorReceived(error: error)
            }
        })
        
        self.present(alert, animated: true)
        
    }
    
    
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        bottomConstraint.constant = 0
        animateChanges()
        
    }
    
    
    
    private func animateChanges(animationBlock:(() ->())? = nil,completion : (() ->())? = nil) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            animationBlock?()
            self?.view?.layoutIfNeeded()
        }, completion: { _ in completion?() })
    }
    
    
    private func setInitialHeight(){
        
        let cellHeight = (((self.view.frame.width - 20) / 5) - 15) * 3
        let constHeight = 45.0 + (50.0 * 3.0)
        let calculatedHeight = cellHeight +  CGFloat(constHeight) +  20
        self.height.constant = calculatedHeight
        
        self.orgHeight = self.height.constant
        
        self.bottomView.layer.cornerRadius = 12
    }
    
    @IBAction func panGestureRegonizer(_ sender: UIPanGestureRecognizer) {
        
        if(sender.state == .changed){
            let translation = sender.translation(in: bottomView)
            self.bottomConstraint.constant = -translation.y
        }else if(sender.state == .ended){
            let velocity = sender.velocity(in: bottomView)
            let translation = sender.translation(in: bottomView)
            
            
            
            if(velocity.y > 1000.0 || translation.y > (self.height.constant / 2)){
                
                self.bottomConstraint.constant = -self.height.constant
                animateChanges(completion:  {
                    self.close {
                        let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
                        self.delegate?.onErrorReceived(error: error)
                    }
                })
                
            }else{
                self.bottomConstraint.constant = 0
                self.animateChanges()
            }
        }
    }
    
    private func sentInitRequest(){
        
        //TODO Submit And Init
        isBackPressed = false
        
        self.progressBar.isHidden = false
        self.webView.isHidden = true
        //        self.collectionView.isHidden = true
        
        
        let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INIT)")
        
        AF.request(request!)
            .validate()
            .responseString{response in
                switch response.result{
                case .success(let value):
                    xprint(value)
                case .failure(let error):
                    xprint(error.localizedDescription)
                }
            }
            .responseData { response in
                
                self.progressBar.isHidden = true
                self.tableView.isHidden  = false
                
                switch response.result {
                case .success(let data):
                    do{
                        let  temp = try newJSONDecoder().decode(PHInitResponse.self, from: data)
                        
                        if(temp.status == 1){
                            self.initResponse = temp
                            self.progressBar.isHidden = true
                            //                            self.collectionView.isHidden = true
                            
                            if(!self.isBackPressed){
                                
                                self.initalizedUI(self.initResponse!)
                            }
                            
                        }else{
                            self.close(animate: false) {
                                let error = NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey: temp.msg ?? ""])
                                self.delegate?.onErrorReceived(error: error)
                            }
                        }
                        
                        
                    }catch let err{
                        self.close(animate: false) {
                            self.delegate?.onErrorReceived(error: err)
                        }
                    }
                    
                case .failure(let error):
                    self.close(animate: false) {
                        
                        let err = NSError(domain: "", code: error.responseCode ?? 0, userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? ""])
                        
                        self.delegate?.onErrorReceived(error: err)
                    }
                }
            }
        
    }
    
    private func sentInitNSubmitRequest(){
        
        //TODO Submit And Init
        isBackPressed = false
        
        self.progressBar.isHidden = false
        self.tableView.isHidden = true
        
        
        xprint("Url :","\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INITNSUBMIT)")
        
        let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INITNSUBMIT)")
        
        
        AF.request(request!)
            .validate()
            .responseData { response in
                
                self.progressBar.isHidden = true
                self.tableView.isHidden  = false
                
                switch response.result {
                case .success(let data):
                    do{
                        let  temp = try newJSONDecoder().decode(PayHereInitnSubmitResponse.self, from: data)
                        
                        if(temp.status == 1){
                            if self.initResponse == nil{
                                self.initResponse = PHInitResponse(temp)
                            }
                            else{
                                self.initResponse?.data?.order = temp.data?.order
                            }
                            self.progressBar.isHidden = true
                            self.tableView.isHidden = true
                            
                            if(!self.isBackPressed){
                                self.initWebView(temp)
                            }
                            
                        }else{
                            self.close(animate: false) {
                                let error = NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey: temp.msg ?? ""])
                                self.delegate?.onErrorReceived(error: error)
                            }
                        }
                        
                        
                    }catch let err{
                        self.close(animate: false) {
                            self.delegate?.onErrorReceived(error: err)
                        }
                    }
                    
                case .failure(let error):
                    self.close(animate: false) {
                        
                        let err = NSError(domain: "", code: error.responseCode ?? 0, userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? ""])
                        
                        self.delegate?.onErrorReceived(error: err)
                    }
                }
            }
        
    }
    
    private func createSubmitRequest(method : String){
        
        let submitObject = SubmitRequest()
        
        submitObject.method = method
        submitObject.key = self.initResponse?.data?.order?.orderKey
        
        
        let request = submitObject.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.SUBMIT)")
        
        AF.request(request)
            .validate()
            .responseString{ response  in
                switch response.result{
                case .success(let data):
                    xprint(data)
                case .failure(let error):
                    xprint(error)
                }
            }
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do{
                        let  temp = try newJSONDecoder().decode(PayHereSubmitResponse.self, from: data)
                        
                        if temp != nil{
                            self.initWebView(temp)
                        }
                        
                        
                    }catch let err{
                        self.close {
                            self.delegate?.onErrorReceived(error: err)
                        }
                    }
                    
                    
                case .failure(let error):
                    self.close {
                        
                        let err = NSError(domain: "", code: error.responseCode ?? 0, userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? ""])
                        
                        self.delegate?.onErrorReceived(error: err)
                    }
                }
                
            }
        
        
    }
    
    private func initalizedUI(_ response : PHInitResponse){
        let bankCardMethods = ["MASTER", "VISA", "MASTER", "AMEX", "DISCOVER", "DINERS"]
        
        bankAccount = []
        bankCard = []
        other = []
        
        if let paymentMethods = response.data?.paymentMethods{
            
            for method in paymentMethods{
                // .uppercased() is important!
                if let methodName = method.method?.uppercased(){
                    if methodName == "HELAPAY"{
                        bankAccount.append(method)
                    }
                    else if bankCardMethods.contains(methodName){
                        bankCard.append(method)
                    }
                    else{
                        other.append(method)
                    }
                }
            }
            
            bankCard = bankCard.sorted{ $0.orderNo! < $1.orderNo! }
            other = other.sorted{ $0.orderNo! < $1.orderNo! }
            
            self.tableView.reloadData()
        }
    }
    
    private func initWebView(_ submitResponse :PayHereSubmitResponse){
        //MARK: TODO Remove comment when submit API Precent
        
        if let url = submitResponse.data?.url{
            
            waitUntilPaymentUI = WaitUntil(
                condition: { [weak self] in
                    return (self?.paymentUI.getDataCount() ?? 0) > 0
                },
                onCompletion: { [weak self] in
                    self?.loadPayHereSubmitUI(url: url)
                }
            )
            
        }else{
            self.close {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                self.delegate?.onErrorReceived(error: error)
            }
        }
        
    }
    
    private func loadPayHereSubmitUI(url: String){
        self.tableView.isHidden  = true
        self.webView.isHidden = false
        
        self.webView.contentMode = .scaleAspectFill
        self.webView.uiDelegate = self
        self.webView.navigationDelegate = self
        
        self.updateWebHeight {  [weak self] in
            guard let `self` else {return}
            self.reloadWebView(url: url)
        }
    }
    
    private func reloadWebView(url: String) {
        if let URL = URL(string: url){
            
            let request = URLRequest(url: URL)
            self.webView.load(request)
            self.progressBar.isHidden = false
            self.webView.isHidden = true
            
            
        }else{
            //MARK:TODO
            //ERROR HANDLING
            self.close {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                self.delegate?.onErrorReceived(error: error)
            }
        }
    }
    
    private func initWebView(_ submitResponse : PayHereInitnSubmitResponse){
        
        //        MARK: TODO Remove comment when submit API Precent
        
        if let url = submitResponse.data?.redirection?.url{
            
            //            self.collectionView.isHidden = true
            
            waitUntilPaymentUI = WaitUntil(
                condition: { [weak self] in
                    return (self?.paymentUI.getDataCount() ?? 0) > 0
                },
                onCompletion: { [weak self] in
                    self?.loadPayHereInitAndSubmitUI(url: url)
                }
            )
            
        }else{
            self.close {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                self.delegate?.onErrorReceived(error: error)
            }
        }
        
    }
    
    private func loadPayHereInitAndSubmitUI(url: String){
        self.webView.isHidden = false
        
        self.webView.contentMode = .scaleAspectFill
        self.webView.uiDelegate = self
        self.webView.navigationDelegate = self
        
        self.updateWebHeight {  [weak self] in
            guard let `self` else {return}
            self.reloadWebView(url: url)
        }
    }
     
    func updateWebHeight(completion: @escaping () -> Void) {
        
        let calculatedHeight = self.calculateWebHeight()
        
        
        
        DispatchQueue.main.async {  [weak self] in
            // Apply UI Changes
            self?.animateChanges {
                
                self?.height.constant = calculatedHeight
                self?.orgHeight = calculatedHeight
                
            } completion: {
                DispatchQueue.main.async{
                    completion()
                }
            }

        }
    }
    
    func calculateWebHeight() -> CGFloat{
        
        var viewSize : ViewSize?
        
        if selectedPaymentMethod != nil{
            viewSize = selectedPaymentMethod?.view?.windowSize
        }else{
            let data = paymentUI.data![self.selectedPaymentOption!.optionValue]
            viewSize = data?.viewSize
        }
        
        
        let visa = paymentUI.data!["VISA"]
        
        
        
        if viewSize == nil{
            viewSize = paymentUI.data!["VISA"]?.viewSize
        }
        
        
        let selectedHeight = CGFloat(viewSize?.height ?? 0)
        let visaHeight = CGFloat(visa?.viewSize?.height ?? 0)
        
        
        let headerHeight:CGFloat = 64.0
        var calcHeight = ((selectedHeight/visaHeight) * orgHeight) + headerHeight
        
        if(calcHeight > self.view.frame.size.height){
            calcHeight = (self.view.frame.size.height - 20)
        }
        
       return calcHeight
        
    }
    
    
    
    private func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                
            }
        }
        return nil
    }
    
    
    private func getImage(withImageName : String) -> UIImage{
        return UIImage(named: withImageName, in: Bundle.payHereBundle, compatibleWith: nil)  ?? UIImage()
    }
    
    private func startOrderStatusCheckTimer(){
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(orderStatusTimerTicked), userInfo: nil, repeats: true)
    }
    
    private func checkStatus(orderKey: String, showProgress: Bool, _ completion: ((_ response: StatusResponse?) -> Void)? = nil){
        
        if showProgress{
            self.progressBar?.startAnimating()
            self.progressBar?.isHidden = false
        }
        
        let params = [
            "order_key" : orderKey
        ]
        
        let headers : HTTPHeaders = [
            "Content-Type": "application/x-www-form-urlencoded"
        ]
        
        AF.request(PHConfigs.BASE_URL! + PHConfigs.STATUS,
                   method: .post,
                   parameters: params,
                   headers: headers).validate()
            .responseString(completionHandler: { (response) in
                switch response.result{
                case let .success(value):
                    xprint(value)
                case .failure(_):
                    xprint("Error")
                }
            })
            .responseData(completionHandler: { response in
                
                let handler = completion ?? self.handlePaymentStatus
                
                switch response.result{
                case .success(let data):
                    guard let jsonString = String(data: data, encoding: .utf8) else {
                        handler(nil)
                        return
                    }
                    
                    guard let obj = Mapper<StatusResponse>().map(JSONString: jsonString) else{
                        handler(nil)
                        return
                    }
                    
                    handler(obj)
                case .failure(_):
                    handler(nil)
                }
                
            })
//            //OLD IMPLEMENTATION
//            .responseObject(completionHandler: { (response: DataResponse<StatusResponse,AFError>) in
//                
//                let handler = completion ?? self.handlePaymentStatus
//                
//                switch response.result{
//                case let .success(statusResponse):
//                    handler(statusResponse)
//                case .failure(_):
//                    handler(nil)
//                }
//            })
    }
    
    private func createErrorResponse<T: Mappable>(_ request: URLRequest, response:AFDataResponse<Data>) -> DataResponse<T, AFError>{
        let error: AFError = .responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
        let result: Result<T, AFError> = .failure(error)
        let failedResponse = DataResponse<T, AFError>(
            request: request, response: response.response,
            data: response.data, metrics: response.metrics,
            serializationDuration: 0, result: result
        )
        
        return failedResponse
    }
                          
    private func handlePaymentStatus(response : StatusResponse?){
        
        guard !didHandlePaymentStatus else { return }
        didHandlePaymentStatus = true
        
        xprint("handlePaymentStatus called")
        
        //        self.lblThankYou.isHidden = false
        //        self.viewNavigationWrapper.isHidden = true
        //        self.lblselectedMethod.isHidden = true
        //        self.collectionView.isHidden = true
        self.viewPaymentSucess.isHidden = false
        
        guard let lastResponse = response else{
            
            self.close {
                self.delegate?.onResponseReceived(response: nil)
            }
            
            return
        }
        
        if(shouldShowSucessView){
            handleNavigation(stepId: .Complete, sectionId: -1)
            showStatus(response: lastResponse)
        }else{
            
            if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS ||
               lastResponse.getStatusState() == StatusResponse.Status.FAILED ||
               lastResponse.getStatusState() == StatusResponse.Status.AUTHORIZED){
                delegate?.onResponseReceived(response: PHResponse(status: self.getStatusFromResponse(lastResponse: lastResponse), message: "Payment completed. Check response data", data: lastResponse))
            }
            
            self.close {
                self.progressBar?.stopAnimating()
                self.progressBar?.isHidden = true
            }
            
        }
    }
    
    private func showStatus(response : StatusResponse?){
        
        guard let lastResponse = response else{
            self.close {
                self.delegate?.onResponseReceived(response: nil)
            }
            return
        }
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            imgDeclined.isHidden = true
            checkMark.isHidden = false
            checkMark.clear()
            checkMark.start()
            self.lblPaymentID.textColor = PHConfigs.kBlue
            
            if self.apiMethod == .PreApproval{
                self.lblPaymentStatus.text = "Card Saved"
                self.lblPaymentID.text = String(format : "Reference ID #%.0f",lastResponse.paymentNo ?? 0.0)
                self.lblBottomMessage.text = "You’ll receive an email with above Reference ID for further reference."
                self.lblPayWithTitle.text = "Saved"
            }
            else{
                self.lblPaymentStatus.text = "Payment Approved"
                self.lblPaymentID.text = String(format : "Payment ID #%.0f",lastResponse.paymentNo ?? 0.0)
                self.lblBottomMessage.text = "You’ll receive an email with above Payment ID for further reference."
                self.lblPayWithTitle.text = "Paid"
            }
            
            btnDone.isHidden = false
            btnTryAgain.isHidden = true
            btnCancel.isHidden = true
        }
        else if(lastResponse.getStatusState() == StatusResponse.Status.AUTHORIZED){
            imgDeclined.isHidden = true
            checkMark.isHidden = false
            checkMark.clear()
            checkMark.start()
            self.lblPaymentID.textColor = PHConfigs.kBlue
            self.lblPaymentStatus.text = "Payment Authorized"
            self.lblBottomMessage.text = "You'll be charged once the merchant process this payment"
            self.lblPaymentID.text = String(format : lastResponse.message ?? "")
            self.lblPayWithTitle.text = "Paid"
            
            btnDone.isHidden = false
            btnTryAgain.isHidden = true
            btnCancel.isHidden = true
        }
        else{
            imgDeclined.isHidden = false
            checkMark.isHidden = true
            checkMark.clear()
            checkMark.startX()
            
            self.lblPaymentID.textColor = PHConfigs.kRed
            self.lblPaymentStatus.text = "Your bank declined the payment"
            self.lblPaymentID.text = lastResponse.message ?? "Error completing the payment"
            self.lblBottomMessage.text = "Please try again with a different card or method"
            self.lblPayWithTitle.text = "Declined"
            
            btnDone.isHidden = true
            btnTryAgain.isHidden = false
            btnCancel.isHidden = false
        }
        
        self.statusResponse = lastResponse
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: false)
    }
    
    @objc private func update() {
        delegate?.onResponseReceived(response: PHResponse(status: self.getStatusFromResponse(lastResponse: statusResponse!), message: "Payment completed. Check response data", data: statusResponse!))

        self.timer?.invalidate()
        self.close {
            self.progressBar?.stopAnimating()
            self.progressBar?.isHidden = true
        }
        
        /*
        if(count > 0) {
            count = count - 1
            lblSecureWindow.text = String(format :"This secure payment window is closing in %d seconds...",count)
        }else{
            delegate?.onResponseReceived(response: PHResponse(status: self.getStatusFromResponse(lastResponse: statusResponse!), message: "Payment completed. Check response data", data: statusResponse!))

            self.timer?.invalidate()

            self.close {
                self.progressBar?.stopAnimating()
                self.progressBar?.isHidden = true
            }
        }
         */
    }
    
    private func getStatusFromResponse(lastResponse : StatusResponse) -> Int{
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            return PHResponse<Any>.STATUS_SUCCESS
        }else{
            return PHResponse<Any>.STATUS_ERROR_PAYMENT
        }
        
    }
    
    private func Validate() -> String?{
        
        if (PHConfigs.BASE_URL == nil) {
            return "BASE_URL not set";
        }
        
        if(apiMethod == .CheckOut || apiMethod == .Recurrence){
            if ((initRequest?.amount)! <= 0.0) {
                return "Invalid amount";
            }
        }
        
        if (initRequest?.currency == nil || initRequest?.currency?.count != 3) {
            return "Invalid currency";
        }
        if (initRequest?.merchantID == nil || initRequest?.merchantID?.count == 0) {
            return "Invalid merchant ID";
        }
        
        if(initRequest?.notifyURL == nil || initRequest?.notifyURL?.count == 0){
            initRequest?.notifyURL = PHConstants.dummyUrl
        }
        
        if(initRequest?.returnURL == nil || initRequest?.returnURL?.count == 0){
            initRequest?.returnURL = PHConstants.dummyUrl
        }
        
        if(initRequest?.cancelURL == nil || initRequest?.cancelURL?.count == 0){
            initRequest?.cancelURL = PHConstants.dummyUrl
        }
        
        initRequest?.referer = Bundle.main.bundleIdentifier
        
        if(self.apiMethod == .PreApproval){
            initRequest?.auto  = true
        }else{
            initRequest?.auto = false
        }
        
        
        
        
        return nil
    }
    
    func getPaymentUI(){
        let urlRequest = URLRequest(url: URL(string: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.UI)")!)

        AF.request(urlRequest).validate()
            .responseData { (response) in

                switch response.result{
                case let .success(data):
                    do{
                        let  temp = try newJSONDecoder().decode(PaymentUI.self, from: data)

                        if(temp.status == 1){

                            UserDefaults().set(data, forKey: PHConstants.UI)

                            self.paymentUI = temp


                        }else{
                            self.close {
                                let error = NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey: temp.msg ?? ""])
                                self.delegate?.onErrorReceived(error: error)
                            }
                        }

                    }catch{

                        self.close {
                            self.delegate?.onErrorReceived(error: error)
                        }
                    }

                case .failure(let error):
                    self.close {
                        self.delegate?.onErrorReceived(error: error)
                    }
                    break
                }

            }
    }
    
    private func handleNavigation(stepId : Step,sectionId : Int){
        
        switch(stepId){
        case .Dashboard:
            self.lblPayWithTitle.text = "Pay with"
            self.btnBackImage.isHidden = true
        case .Payment:
            
            var title = ""
            
            if sectionId == 0{
                title = "Bank Account"
            }else if sectionId == 1{
                title = "Bank Card"
            }else{
                title = "Other"
            }
            
            self.tableView.isHidden  = true
            self.webView.isHidden = true
            self.progressBar.isHidden = false
            self.lblPayWithTitle.text = title
            self.btnBackImage.isHidden = false
        case .Complete:
            self.tableView.isHidden = true
            self.viewPaymentSucess.isHidden = false
            self.btnBackImage.isHidden = true
        }
        
    }
    
    @objc private func orderStatusTimerTicked(){
        let orderKey = initResponse?.data!.order?.orderKey ?? ""
        self.checkStatus(orderKey: orderKey, showProgress: false){ [weak self] (statusResponse) in
            guard let `self` = self else { return }
            guard let status = statusResponse?.status else { return }
            guard status != StatusResponse.Status.INIT.rawValue else { return }
            self.handlePaymentStatus(response: statusResponse)
        }
    }
    
    @IBAction private func btnDoneTapped(){
        delegate?.onResponseReceived(
            response: PHResponse(
                status: self.getStatusFromResponse(lastResponse: statusResponse!),
                message: "Payment completed. Check response data",
                data: statusResponse!))
        
        self.timer?.invalidate()
        self.close {
            self.progressBar?.stopAnimating()
            self.progressBar?.isHidden = true
        }
    }
    
    @IBAction private func btnCancelTapped(){
        self.timer?.invalidate()
        self.close { [weak self] in
            let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
            self?.delegate?.onErrorReceived(error: error)
        }
    }
    
    @IBAction private func btnTryAgainTapped(){
        performInitialSteps()
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension PHBottomViewController : WKUIDelegate,WKNavigationDelegate{
    
    internal func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
        guard !ignoreProgressBarInNextNavigation else {
            self.webView.isHidden = false
            self.progressBar.isHidden = true
            return
        }
        
        self.webView.isHidden = true
        self.progressBar.isHidden = false
        
    }
    
    internal func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let optUrl = navigationAction.request.mainDocumentURL?.absoluteString
        xprint(optUrl ?? "Navigating to unknown location")
        ignoreProgressBarInNextNavigation = false
        
        if let url = optUrl{
            if((url.contains(PHConstants.kLiveCompleteURL)) || (url.contains(PHConstants.kSandboxCompleteURL))){
                if(self.initResponse?.data?.order != nil){
                    if isSandBoxEnabled{
                        
                        DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                            self.checkStatus(orderKey: self.initResponse?.data!.order?.orderKey ?? "", showProgress: true)
                        }
                        
                    }else{
                        self.checkStatus(orderKey: self.initResponse?.data!.order?.orderKey ?? "", showProgress: true)
                    }
                }
            }
            else if url.contains(PHConstants.kProgressBarWhitelistKeywordFrimi){
                // Fix for issue Prevent progress bar hiding the Frimi steps
                ignoreProgressBarInNextNavigation = true
                
                if url.contains(PHConstants.kProgressBarWhitelistKeywordFrimiResponse){
                    // Fix for issue where Frimi steps don't load the first time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        decisionHandler(.allow)
                    }
                    return;
                }
            }
        }
        
        decisionHandler(.allow)
    }
    
    internal func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        insertCSSString(into: webView) // 1
        self.webView.isHidden = false
        self.progressBar.isHidden = true
    }
    
    private func insertCSSString(into webView: WKWebView) {
        
        var scriptContent = "var meta = document.createElement('meta');"
        scriptContent += "meta.name='viewport';"
        scriptContent += "meta.content='width=device-width';"
        scriptContent += "document.getElementsByTagName('head')[0].appendChild(meta);"
        
        webView.evaluateJavaScript(scriptContent) { (response, error) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.webView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)
            }
            
        }
        
    }
    
}

extension PHBottomViewController : UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}

extension PHBottomViewController : UITableViewDelegate,UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0{
            return bankAccount.count > 0 ? 1:0
        }else{
            return 1
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = PHBottomSheetTableViewSectioHeader.dequeue(fromTableView: tableView)
        
        if section ==  0{
            header.lblPaymentMethod.text = "Bank Account"
        }else if section == 1{
            header.lblPaymentMethod.text = "Bank Card"
        }else{
            header.lblPaymentMethod.text = "Other"
        }
        
        
        return header
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0{
            return PayWithHelaPayTableViewCell.dequeue(fromTableView: tableView)
        }else if indexPath.section == 1{
            return PaymentOptionTableViewCell.dequeue(fromTableView: tableView,list: bankCard, indexPath: indexPath, delegate: self)
        }else if indexPath.section == 2{
            return PaymentOptionTableViewCell.dequeue(fromTableView: tableView,list: other, indexPath: indexPath,delegate: self)
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0{
            
            let method = bankAccount[indexPath.row]
            
            /**
             Deep link into Helakuru > HelaPay
             */
            if let url = method.submission?.mobileUrls?.IOS{
                if let urlValue = URL(string: url){
                    UIApplication.shared.open(urlValue, options: [:], completionHandler: nil)
                    startOrderStatusCheckTimer()
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0  && bankAccount.count > 0{
            return 24
        }else if section == 1 && bankCard.count > 0{
            return 24
        }else if section == 2 && other.count > 0{
            return 24
        }else {
            return 0.0
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    
}

extension PHBottomViewController : PaymentOptionTableViewCellDelegate{
    
    func didSelectedPaymentOption(paymentMethod: PaymentMethod, selectedSection: Int) {
        //MARK: Call Submit Method With Order Key
        
        // Stop any started HelaPay counters
        timer?.invalidate()
        
        if let temp =  self.paymentOption.filter({$0.optionValue.uppercased() == paymentMethod.method?.uppercased()}).first{
            self.selectedPaymentOption = temp
        }else{
            self.selectedPaymentOption = self.paymentOption.first
        }
        
        self.selectedPaymentMethod = paymentMethod
        
        self.handleNavigation(stepId: .Payment, sectionId: selectedSection)
        self.createSubmitRequest(method: paymentMethod.submissionCode ?? "VISA")
        
    }
    
    
}



private struct PaymentOption {
    var name : String
    var image : UIImage
    var optionValue : String
    
}

private enum Step{
    case Dashboard
    case Payment
    case Complete
}

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
