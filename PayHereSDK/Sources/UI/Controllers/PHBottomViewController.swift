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

public class PHBottomViewController: UIViewController {
    
    
    //MARK: TypeAlias
    
    
    //MARK: - Enum
    
    
    
    //MARK: - Classes
    
    
    
    //MARK: - Structs
    
    
    
    //MARK: - Constants
    private let net = NetworkReachabilityManager(host: "payhere.lk")!

    
    
    // MARK: - Variables
    internal var initialRequest                     : PHInitialRequest?
    internal var isSandBoxEnabled                   : Bool                          = false
    internal var orgHeight                          : CGFloat                       = 0
    internal var keyBoardHeightMax                  : CGFloat                       = 0
    internal var configuration                      : PHPaymentConfiguration        = .default
    internal var networkSession: Session = AF
    
    private var ignoreProgressBarInNextNavigation   : Bool                          = false
    private var lifecycle = PHPaymentLifecycle()
    private var statusResponse                      : StatusResponse?
    private var timer                               : Timer?
    private var statusTimer: Timer?
    private var paymentRequest: DataRequest?
    private var statusRequest: DataRequest?
    private var requestID = UUID()
    private var activeNavigation: WKNavigation?
    private var isHostedCardForm = false
    private var cardFormBottomSpacingReduction: CGFloat = 0
    private let navigationAttempts = NSMapTable<WKNavigation, NSUUID>.weakToStrongObjects()
    private var waitUntilPaymentUI                  : WaitUntil!
    private var initialBottomConstant               : CGFloat                       = 0
    
    
    private var bankAccount                         : [PaymentMethod]               = []
    private var bankCard                            : [PaymentMethod]               = []
    private var other                               : [PaymentMethod]               = []
    
    private var initRequest                         : PHInitRequest?
    private var initResponse                        : PHInitResponse?
    private var paymentUI                           : [String: PaymentMethod]       = [:]
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
    private weak var cancellationAlert: UIAlertController?
    
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
    
    private var step: Step = .Dashboard
    
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
        
        //
        // if let data = UserDefaults().data(forKey: PHConstants.UI){
        //     do{
        //         self.paymentUI = try newJSONDecoder().decode(PaymentUI.self, from: data)
        //     }catch{
        //         xprint(error)
        //     }
        //     self.getPaymentUI()
        // }
        // else{
        //     self.getPaymentUI()
        // }
        
        webView.backgroundColor = UIColor.PrimaryTheme.ViewBackground
        webView.scrollView.delegate = self
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.zoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0
        webView.isMultipleTouchEnabled = false
        
        // Inject viewport meta tag before page loads to prevent zooming
        let userScript = WKUserScript(source: PHWebViewScripts.viewport,
                                     injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(userScript)

        let cardFormLayout = WKUserScript(source: PHWebViewScripts.cardFormLayout,
                                          injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(cardFormLayout)
        
        
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
        
        let backgroundPan = UIPanGestureRecognizer(target: self, action: #selector(panGestureRegonizer(_:)))
        self.viewBackground.addGestureRecognizer(backgroundPan)
    
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if lifecycle.phase == .idle {
            bottomConstraint.constant = -height.constant
            performInitialSteps()
        }
        
    }
    
    private func performInitialSteps(){
        guard lifecycle.beginAttempt() != nil else { return }
        cancelPendingWork()
        self.statusResponse = nil
        self.initResponse = nil
        self.selectedPaymentOption = nil
        self.selectedPaymentMethod = nil
        self.ignoreProgressBarInNextNavigation = false
        self.progressBar.isHidden = true
        
        if apiMethod == .CheckOut{
            self.btnBackImage.isHidden = true
        }
        
        self.handleNavigation(stepId: .Dashboard, sectionId: -1)
        self.startProcess()
    }
    
    @objc func keyboardWillShowFunction(notification: NSNotification) {
        
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        // Ensure layout is up to date to get correct safeAreaInsets
        self.view.layoutIfNeeded()
        
        guard let window = view.window else { return }
        let keyboardViewEndFrame = view.convert(keyboardValue.cgRectValue,
                                                from: window.screen.coordinateSpace)
        let intersection = view.bounds.intersection(keyboardViewEndFrame)
        let overlap = !intersection.isNull && intersection.maxY >= view.bounds.maxY
            ? intersection.height : 0

        self.bottomConstraint.constant = overlap
        
        // Calculate available height
        // Screen Height - Safe Area Top - Overlap
        let safeAreaTop = view.safeAreaInsets.top
        let availableHeight = max(0, view.bounds.height - safeAreaTop - overlap)
        
        if self.orgHeight > availableHeight {
            self.height.constant = availableHeight
        } else {
            self.height.constant = self.orgHeight
        }
        
        self.animateChanges()
        
    }
    
    @objc func keyboardWillHideFunction(notification: NSNotification) {
        
        self.bottomConstraint.constant = 0
        self.height.constant = self.orgHeight
        self.animateChanges()
        
    }
    
    private func close(animate:Bool = true,and callback: (() -> Void)? = nil){
        guard lifecycle.beginClosing() else { return }
        cancelPendingWork()
        view.isUserInteractionEnabled = false
        webView.scrollView.delegate = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)

        let finish = {
            guard self.lifecycle.finishClosing() else { return }
            callback?()
        }
        let dismissPayment = {
            if let presenter = self.presentingViewController {
                // Dismiss the payment controller and any cancellation alert together.
                presenter.dismiss(animated: animate, completion: finish)
            } else {
                finish()
            }
        }
        
        if animate {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut) {
                self.bottomConstraint.constant = -self.height.constant
                self.view.layoutIfNeeded()
            }completion: { _ in
                dismissPayment()
            }
        }else {
            dismissPayment()
        }

    }

    private func cancelPendingWork() {
        requestID = UUID()
        net.stopListening()
        timer?.invalidate()
        timer = nil
        statusTimer?.invalidate()
        statusTimer = nil
        paymentRequest?.cancel()
        paymentRequest = nil
        statusRequest?.cancel()
        statusRequest = nil
        activeNavigation = nil
        isHostedCardForm = false
        cardFormBottomSpacingReduction = 0
        webView?.scrollView.contentInset.bottom = 0
        webView?.stopLoading()
    }

    private func finishWithError(_ error: Error, animate: Bool = true) {
        close(animate: animate) {
            self.delegate?.onErrorReceived(error: error)
        }
    }

    private func finishWithNetworkError(_ error: AFError, animate: Bool = true) {
        let result = NSError(domain: "", code: error.responseCode ?? 0,
                             userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? ""])
        finishWithError(result, animate: animate)
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
    
    
    
    
    private func startProcess(){
        
        self.viewPaymentSucess.isHidden = true
        self.progressBar.isHidden = false
        self.tableView.isHidden  = true
        
        let validate = self.Validate()
        
        if(validate == nil){
            checkNetworkAvailability()
        }else{
            close(animate: false) {
                let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: validate as Any])
                self.delegate?.onErrorReceived(error: error)
            }
        }
        
    }
    
    private func checkNetworkAvailability() {
        let attemptID = lifecycle.attemptID
        net.startListening(onQueue: .main) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID),
                      self.paymentRequest == nil, self.initResponse == nil,
                      self.net.isReachable else { return }
                switch status {
                case .reachable:
                    self.beginInitialization()
                case .notReachable, .unknown:
                    self.finishWithError(NSError(domain: "", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to connect to the internet"]), animate: false)
                }
            }
        }
    }

    private func beginInitialization() {
        net.stopListening()
        if apiMethod == .PreApproval || apiMethod == .Recurrence || apiMethod == .Authorize {
            selectedPaymentOption = PaymentOption(name: "Visa", image: getImage(withImageName: "visa"), optionValue: "VISA")
            initRequest?.method = "VISA"
            sentInitNSubmitRequest()
        } else {
            handleNavigation(stepId: .Dashboard, sectionId: -1)
            sentInitRequest()
        }
    }

    
    @objc private func backButtonClicked(){
        guard lifecycle.phase == .active else { return }
        
        if(apiMethod == .CheckOut && selectedPaymentOption != nil){
            cancelPendingWork()
            
            self.selectedPaymentOption = nil
            self.selectedPaymentMethod = nil
            self.step = .Dashboard
            
            self.animateChanges(animationBlock: {
                self.setInitialHeight()
            })
            
            self.webView.isHidden = true
            self.tableView.isHidden = false
            
            self.progressBar.isHidden = true
            
            self.handleNavigation(stepId: .Dashboard, sectionId: -1)
        }
        else{
            self.forceClose()
        }
         
    }
    
    @objc private func forceClose(){
        guard lifecycle.phase == .active || lifecycle.phase == .result,
              cancellationAlert == nil else { return }
        let attemptID = lifecycle.attemptID
        let phase = lifecycle.phase
        let alert = UIAlertController(
            title: "Cancel Payment?",
            message: "This payment is still being processed!",
            preferredStyle: .alert
        )
        
        cancellationAlert = alert
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.cancellationAlert = nil
        }))
        
        alert.addAction(UIAlertAction(title: "Exit Now", style: .destructive) { [weak self] _ in
            guard let self = self, self.lifecycle.attemptID == attemptID,
                  self.lifecycle.phase == phase else { return }
            // Force exit logic here
            let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
            self.finishWithError(error)
        })
        
        self.present(alert, animated: true)
        
    }
    
    
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        bottomConstraint.constant = 0
        animateChanges()
        
    }
    
    
    
    private func animateChanges(animationBlock:(() ->())? = nil,completion : (() ->())? = nil) {
        self.view.setNeedsLayout()
        self.view.setNeedsDisplay()
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
        
        if sender.state == .began {
            self.initialBottomConstant = self.bottomConstraint.constant
        } else if(sender.state == .changed){
            let translation = sender.translation(in: bottomView)
            let newConstant = self.initialBottomConstant - translation.y
            
            // Prevent lifting higher than the initial state
            self.bottomConstraint.constant = min(self.initialBottomConstant, newConstant)
            
        }else if(sender.state == .ended){
            let velocity = sender.velocity(in: bottomView)
            let translation = sender.translation(in: bottomView)
            
            let screenHeight = self.view.frame.height
            let threshold = screenHeight / 3.0
            
            if(velocity.y > 1000.0 || translation.y > threshold){
                
                self.close {
                    let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
                    self.delegate?.onErrorReceived(error: error)
                }
                
            }else{
                
                self.bottomConstraint.constant = self.initialBottomConstant
                self.animateChanges()
            }
        }
    }
    
    private func sentInitRequest() {
        guard lifecycle.phase == .active, paymentRequest == nil,
              let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INIT)") else { return }
        progressBar.startAnimating()
        progressBar.isHidden = false
        webView.isHidden = true
        tableView.isHidden = true
        let attemptID = lifecycle.attemptID
        let operationID = UUID()
        requestID = operationID
        paymentRequest = networkSession.request(request).validate()
        paymentRequest?.responseData(queue: .main) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                self.paymentRequest = nil
                switch response.result {
                case .success(let data):
                    do {
                        let result = try newJSONDecoder().decode(PHInitResponse.self, from: data)
                        guard result.status == 1 else {
                            self.finishWithError(NSError(domain: "", code: 501,
                                                         userInfo: [NSLocalizedDescriptionKey: result.msg ?? ""]), animate: false)
                            return
                        }
                        self.initResponse = result
                        self.progressBar.isHidden = true
                        self.tableView.isHidden = false
                        self.initalizedUI(result.data?.paymentMethods ?? [])
                    } catch {
                        self.finishWithError(error, animate: false)
                    }
                case .failure(let error):
                    self.finishWithNetworkError(error, animate: false)
                }
            }
        }
    }

    
    private func sentInitNSubmitRequest() {
        guard lifecycle.phase == .active, paymentRequest == nil,
              let request = initRequest?.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.INITNSUBMIT)") else { return }
        progressBar.startAnimating()
        progressBar.isHidden = false
        tableView.isHidden = true
        let attemptID = lifecycle.attemptID
        let operationID = UUID()
        requestID = operationID
        paymentRequest = networkSession.request(request).validate()
        paymentRequest?.responseData(queue: .main) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                self.paymentRequest = nil
                switch response.result {
                case .success(let data):
                    do {
                        let result = try newJSONDecoder().decode(PayHereInitnSubmitResponse.self, from: data)
                        guard result.status == 1 else {
                            self.finishWithError(NSError(domain: "", code: 501,
                                                         userInfo: [NSLocalizedDescriptionKey: result.msg ?? ""]), animate: false)
                            return
                        }
                        self.initResponse = PHInitResponse(result)
                        self.step = .Payment
                        self.initWebView(result)
                    } catch {
                        self.finishWithError(error, animate: false)
                    }
                case .failure(let error):
                    self.finishWithNetworkError(error, animate: false)
                }
            }
        }
    }

    
    private func createSubmitRequest(method: String) {
        guard lifecycle.phase == .active, paymentRequest == nil,
              let key = initResponse?.data?.order?.orderKey, !key.isEmpty else { return }
        let submitObject = SubmitRequest()
        submitObject.method = method
        submitObject.key = key
        let request = submitObject.toRawRequest(url: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.SUBMIT)")
        let attemptID = lifecycle.attemptID
        let operationID = UUID()
        requestID = operationID
        paymentRequest = networkSession.request(request).validate()
        paymentRequest?.responseData(queue: .main) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID,
                      self.step == .Payment else { return }
                self.paymentRequest = nil
                switch response.result {
                case .success(let data):
                    do {
                        let result = try newJSONDecoder().decode(PayHereSubmitResponse.self, from: data)
                        self.initWebView(result)
                    } catch {
                        self.finishWithError(error)
                    }
                case .failure(let error):
                    self.finishWithNetworkError(error)
                }
            }
        }
    }

    
    private func initalizedUI(_ paymentMethods : [PaymentMethod]){
        let bankCardMethods = ["MASTER", "VISA", "MASTER", "AMEX", "DISCOVER", "DINERS"]
        
        paymentUI   = [:]
        bankAccount = []
        bankCard    = []
        other       = []
        
        for method in paymentMethods{
            
            // Exclude Justpay Web Support
            if method.method?.uppercased() == "JUSTPAY" {
                continue
            }
            
            
            if let methodName = method.method?.uppercased(){
                
                self.paymentUI[methodName] = method
                
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
    
    private func initWebView(_ submitResponse :PayHereSubmitResponse){
        
        if let url = submitResponse.data?.url{
            
            self.loadPayHereSubmitUI(url: url)
            
        }else{
            self.finishWithError(NSError(domain: "", code: 401,
                                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
    }
    
    private func loadPayHereSubmitUI(url: String){
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        self.tableView.isHidden         = true
        self.webView.isHidden           = true
        self.webView.uiDelegate         = self
        self.webView.navigationDelegate = self
        
        self.updateWebHeight {  [weak self] in
            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID, self.step == .Payment else { return }
            self.reloadWebView(url: url)
        }
    }
    
    private func reloadWebView(url: String) {
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            let navigation = webView.load(request)
            activeNavigation = navigation
            if let navigation = navigation {
                navigationAttempts.setObject(requestID as NSUUID, forKey: navigation)
            }
            progressBar.isHidden = false
            webView.isHidden = true
        } else {
            finishWithError(NSError(domain: "", code: 401,
                                   userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
    }

    private func initWebView(_ submitResponse : PayHereInitnSubmitResponse){
        if let url = submitResponse.data?.redirection?.url{
 
            
            self.loadPayHereInitAndSubmitUI(url: url)
        }else{
            self.finishWithError(NSError(domain: "", code: 401,
                                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
    }
    
    private func loadPayHereInitAndSubmitUI(url: String){
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        self.webView.isHidden = false
        
        self.webView.uiDelegate = self
        self.webView.navigationDelegate = self
        
        self.updateWebHeight {  [weak self] in
            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID, self.step == .Payment else { return }
            self.reloadWebView(url: url)
        }
    }
     
    func updateWebHeight(completion: @escaping () -> Void) {
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        
        let calculatedHeight = self.calculateWebHeight()
        
        
        
        DispatchQueue.main.async {  [weak self] in
            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
            // Apply UI Changes
            self.animateChanges {
                
                self.height.constant = calculatedHeight
                self.orgHeight = calculatedHeight
                
            } completion: {
                DispatchQueue.main.async{
                    guard self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                    completion()
                }
            }

        }
    }
    
    func calculateWebHeight() -> CGFloat {
        
        // Constants
        let headerHeight: CGFloat = 64.0
        let verticalPadding: CGFloat = 20.0
        let maxHeight = view.bounds.height - verticalPadding
        let fallbackContentHeight = view.bounds.height * 0.48
        
        // Resolve selected viewSize
        var viewSize: ViewSize?
        
        if let selectedPaymentMethod {
            viewSize = selectedPaymentMethod.view?.windowSize
        } else if let selectedOption = selectedPaymentOption,
                  let data = paymentUI[selectedOption.optionValue] {
            viewSize = data.view?.windowSize
        }
        
        // VISA as baseline
        let visaViewSize = paymentUI["VISA"]?.view?.windowSize
        
        let selectedHeight = CGFloat(viewSize?.height ?? 0)
        let visaHeight = CGFloat(visaViewSize?.height ?? 0)
        
        let contentHeight: CGFloat
        
        // Use scaled height only if we have valid non-zero dimensions
        if selectedHeight > 0,
           visaHeight > 0,
           orgHeight > 0 {
            contentHeight = (selectedHeight / visaHeight) * orgHeight
        } else {
            // Fallback when any of the required heights are zero / missing
            contentHeight = fallbackContentHeight
        }
        
        // Add header and clamp to screen
        var totalHeight = contentHeight + headerHeight
        if totalHeight > maxHeight {
            totalHeight = maxHeight
        }
        
        return totalHeight
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
    
    private func startOrderStatusCheckTimer() {
        guard lifecycle.phase == .active, statusTimer == nil else { return }
        let attemptID = lifecycle.attemptID
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] firedTimer in
            DispatchQueue.main.async {
                guard let self = self else {
                    firedTimer.invalidate()
                    return
                }
                guard self.lifecycle.accepts(attemptID), self.statusTimer === firedTimer else { return }
                self.orderStatusTimerTicked()
            }
        }
    }

    private func checkStatus(orderKey: String, showProgress: Bool,
                             _ completion: ((StatusResponse?) -> Void)? = nil) {
        guard lifecycle.phase == .active, statusRequest == nil, !orderKey.isEmpty,
              initResponse?.data?.order?.orderKey == orderKey else { return }
        if showProgress {
            progressBar.startAnimating()
            progressBar.isHidden = false
        }
        let attemptID = lifecycle.attemptID
        let request = networkSession.request((PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL) + PHConfigs.STATUS,
                                             method: .post, parameters: ["order_key": orderKey],
                                             headers: ["Content-Type": "application/x-www-form-urlencoded"]).validate()
        statusRequest = request
        request.responseData(queue: .main) { [weak self, weak request] response in
            DispatchQueue.main.async {
                guard let self = self, let request = request,
                      self.lifecycle.accepts(attemptID), self.statusRequest === request else { return }
                self.statusRequest = nil
                let handler = completion ?? self.handlePaymentStatus
                switch response.result {
                case .success(let data):
                    guard let json = String(data: data, encoding: .utf8),
                          let status = Mapper<StatusResponse>().map(JSONString: json) else {
                        handler(nil)
                        return
                    }
                    handler(status)
                case .failure:
                    handler(nil)
                }
            }
        }
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
                          
    private func handlePaymentStatus(response: StatusResponse?) {
        guard lifecycle.phase == .active else { return }
        guard let response = response else {
            close {
                self.delegate?.onResponseReceived(response: nil)
            }
            return
        }
        guard lifecycle.receiveTerminalStatus(response.getStatusState()) else { return }
        statusResponse = response
        cancelPendingWork()
        let displayResult = { [weak self] in
            guard let self = self, self.lifecycle.phase == .result else { return }
            if self.configuration.showResultScreen {
                self.handleNavigation(stepId: .Complete, sectionId: -1)
                self.showStatus(response: response)
            } else {
                self.finishWithResult()
            }
        }
        if let alert = cancellationAlert {
            cancellationAlert = nil
            alert.dismiss(animated: false, completion: displayResult)
        } else {
            displayResult()
        }
    }

    private func finishWithResult() {
        guard lifecycle.phase == .result, let response = statusResponse else { return }
        let result = PHResponse<Any>(status: getStatusFromResponse(lastResponse: response),
                                     message: "Payment completed. Check response data", data: response)
        close {
            self.delegate?.onResponseReceived(response: result)
        }
    }

    private func showStatus(response : StatusResponse){
        let lastResponse = response
        
        if(lastResponse.getStatusState() == StatusResponse.Status.SUCCESS){
            imgDeclined.isHidden = true
            checkMark.isHidden = false
            checkMark.clear()
            checkMark.start()
            self.lblPaymentID.textColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.8)
            
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
            self.lblPaymentID.textColor = UIColor.PrimaryTheme.Clickable.withAlphaComponent(0.8)
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
            
            self.lblPaymentID.textColor = UIColor.PrimaryTheme.Red.withAlphaComponent(0.8)
            self.lblPaymentStatus.text = "Your bank declined the payment"
            self.lblPaymentID.text = lastResponse.message ?? "Error completing the payment"
            self.lblBottomMessage.text = "Please try again with a different card or method"
            self.lblPayWithTitle.text = "Declined"
            
            let canRetry = lifecycle.canRetry(configuration: configuration, status: lastResponse.getStatusState())
            btnDone.isHidden = canRetry
            btnTryAgain.isHidden = !canRetry
            btnCancel.isHidden = !canRetry
            if !canRetry {
                lblBottomMessage.text = "Close this window to return to the merchant."
            }
        }
        
        self.statusResponse = lastResponse
        
        timer?.invalidate()
        let attemptID = lifecycle.attemptID
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] firedTimer in
            DispatchQueue.main.async {
                guard let self = self, self.lifecycle.attemptID == attemptID,
                      self.lifecycle.phase == .result, self.timer === firedTimer else { return }
                self.update()
            }
        }
    }
    
    @objc private func update() {
        finishWithResult()
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
            guard let amount = initRequest?.amount, amount > 0 else {
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
    
    @available(*, deprecated, message: "This method is deprecated")
    func getPaymentUI(){
//        let urlRequest = URLRequest(url: URL(string: "\(PHConfigs.BASE_URL ?? PHConfigs.LIVE_URL)\(PHConfigs.UI)")!)
//
//        AF.request(urlRequest).validate()
//            .responseData { (response) in
//
//                switch response.result{
//                case let .success(data):
//                    do{
//                        let  temp = try newJSONDecoder().decode(PaymentUI.self, from: data)
//
//                        if(temp.status == 1){
//
//                            UserDefaults().set(data, forKey: PHConstants.UI)
//
//                            self.paymentUI = temp
//
//
//                        }else{
//                            self.close {
//                                let error = NSError(domain: "", code: 501, userInfo: [NSLocalizedDescriptionKey: temp.msg ?? ""])
//                                self.delegate?.onErrorReceived(error: error)
//                            }
//                        }
//
//                    }catch{
//
//                        self.close {
//                            self.delegate?.onErrorReceived(error: error)
//                        }
//                    }
//
//                case .failure(let error):
//                    self.close {
//                        self.delegate?.onErrorReceived(error: error)
//                    }
//                    break
//                }
//
//            }
    }
    
    private func handleNavigation(stepId : Step,sectionId : Int){
        self.step = stepId
        
        switch(stepId){
        case .Dashboard:
            self.webView.stopLoading()
            self.lblPayWithTitle.text = "Pay with"
            self.btnBackImage.isHidden = false
            self.tableView.isHidden  = false
            self.progressBar.isHidden = true
            self.webView.isHidden = true
            
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
            self.webView.isHidden = true
            self.tableView.isHidden = true
            self.viewPaymentSucess.isHidden = false
            self.btnBackImage.isHidden = true
            self.progressBar.isHidden = true
        }
        
    }
    
    @objc private func orderStatusTimerTicked() {
        guard lifecycle.phase == .active,
              let key = initResponse?.data?.order?.orderKey, !key.isEmpty else { return }
        checkStatus(orderKey: key, showProgress: false) { [weak self] response in
            guard let self = self, let status = response?.getStatusState(),
                  status != .INIT, status != .PAYMENT else { return }
            self.handlePaymentStatus(response: response)
        }
    }

    @IBAction private func btnDoneTapped() {
        finishWithResult()
    }

    
    @IBAction private func btnCancelTapped(){
        self.timer?.invalidate()
        self.close { [self] in
            // Retain strong self
            let error = NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Oparation cancelled!"])
            self.delegate?.onErrorReceived(error: error)
        }
    }
    
    @IBAction private func btnTryAgainTapped(){
        guard lifecycle.canRetry(configuration: configuration, status: statusResponse?.getStatusState()) else { return }
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
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard lifecycle.phase == .active, step == .Payment,
              let navigation = navigation else { return }
        if let attempt = navigationAttempts.object(forKey: navigation) {
            guard attempt as UUID == requestID else { return }
        } else {
            guard activeNavigation != nil else { return }
            navigationAttempts.setObject(requestID as NSUUID, forKey: navigation)
        }
        activeNavigation = navigation
        isHostedCardForm = false
        cardFormBottomSpacingReduction = 0
        webView.scrollView.contentInset.bottom = 0
        webView.isHidden = !ignoreProgressBarInNextNavigation
        progressBar.isHidden = ignoreProgressBarInNextNavigation
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard lifecycle.phase == .active, step == .Payment else {
            decisionHandler(.cancel)
            return
        }
        let attemptID = lifecycle.attemptID
        let operationID = requestID
        let optUrl = navigationAction.request.mainDocumentURL?.absoluteString
        ignoreProgressBarInNextNavigation = false
        if let url = optUrl {
            if url.contains(PHConstants.kLiveCompleteURL) || url.contains(PHConstants.kSandboxCompleteURL) {
                if let key = initResponse?.data?.order?.orderKey, !key.isEmpty {
                    if isSandBoxEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                            guard let self = self, self.lifecycle.accepts(attemptID), self.requestID == operationID else { return }
                            self.checkStatus(orderKey: key, showProgress: true)
                        }
                    } else {
                        checkStatus(orderKey: key, showProgress: true)
                    }
                }
            } else if url.contains(PHConstants.kProgressBarWhitelistKeywordFrimi) {
                ignoreProgressBarInNextNavigation = true
                if url.contains(PHConstants.kProgressBarWhitelistKeywordFrimiResponse) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self = self, self.lifecycle.accepts(attemptID),
                              self.requestID == operationID else {
                            decisionHandler(.cancel)
                            return
                        }
                        decisionHandler(.allow)
                    }
                    return
                }
            }
        }
        decisionHandler(.allow)
    }

    private func ownsNavigation(_ navigation: WKNavigation?) -> Bool {
        guard lifecycle.phase == .active, step == .Payment,
              let navigation = navigation, activeNavigation === navigation,
              let attempt = navigationAttempts.object(forKey: navigation) else { return false }
        return attempt as UUID == requestID
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard ownsNavigation(navigation) else { return }
        finishWebLayout(in: webView, navigation: navigation)
        webView.isHidden = false
        progressBar.isHidden = true
    }

    private func finishWebLayout(in webView: WKWebView, navigation: WKNavigation?) {
        webView.evaluateJavaScript(PHWebViewScripts.cardFormMeasurement) { [weak self] result, _ in
            guard let self = self, self.ownsNavigation(navigation) else { return }

            if let layout = result as? [String: Double],
               let contentHeight = layout["height"], contentHeight.isFinite, contentHeight > 0,
               let bottomSpacing = layout["bottomSpacing"], bottomSpacing.isFinite, bottomSpacing >= 0 {
                self.isHostedCardForm = true
                // Only remove empty space; the newer form places Pay at the content's bottom.
                self.cardFormBottomSpacingReduction = min(20, CGFloat(bottomSpacing))
                // Trim the matching scroll inset so a shorter sheet adds no empty scroll range.
                webView.scrollView.contentInset.bottom = -self.cardFormBottomSpacingReduction
                self.view.layoutIfNeeded()
                let chromeHeight = self.bottomView.bounds.height - webView.bounds.height
                // Store the resting height even if a field is focused during page load.
                let bottomInset = max(webView.scrollView.contentInset.bottom, self.view.safeAreaInsets.bottom)
                let maximumHeight = max(0, self.view.bounds.height - self.view.safeAreaInsets.top)
                let fittedHeight = min(CGFloat(contentHeight) + chromeHeight + bottomInset, maximumHeight)
                self.orgHeight = max(0, fittedHeight - self.cardFormBottomSpacingReduction)
                self.height.constant = min(self.orgHeight, max(0, maximumHeight - self.bottomConstraint.constant))
                self.view.layoutIfNeeded()
            }

        }
    }
    
}

extension PHBottomViewController : UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isHostedCardForm, scrollView === webView.scrollView,
              bottomConstraint.constant > 0 else { return }

        // The sheet is already above the keyboard. WebKit can still include the
        // keyboard in adjustedContentInset, allowing scrolling far beyond the form.
        let minimumY = -scrollView.adjustedContentInset.top
        let bottomInset = max(scrollView.contentInset.bottom,
                              webView.safeAreaInsets.bottom - cardFormBottomSpacingReduction)
        let maximumY = max(minimumY, scrollView.contentSize.height - scrollView.bounds.height + bottomInset)
        let offsetY = min(max(scrollView.contentOffset.y, minimumY), maximumY)
        if scrollView.contentOffset.y != offsetY {
            scrollView.contentOffset.y = offsetY
        }
    }

    // Prevent zooming by returning nil for viewForZooming
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}

extension PHBottomViewController : UITableViewDelegate,UITableViewDataSource{
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0{
            return bankAccount.count > 0 ? 1:0
        }else{
            return 1
        }
        
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
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
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0{
            return PayWithHelaPayTableViewCell.dequeue(fromTableView: tableView)
        }else if indexPath.section == 1{
            return PaymentOptionTableViewCell.dequeue(fromTableView: tableView,list: bankCard, indexPath: indexPath, delegate: self)
        }else if indexPath.section == 2{
            return PaymentOptionTableViewCell.dequeue(fromTableView: tableView,list: other, indexPath: indexPath,delegate: self)
        }
        
        return UITableViewCell()
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard lifecycle.phase == .active, paymentRequest == nil else { return }
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
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
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
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    
}

extension PHBottomViewController : PaymentOptionTableViewCellDelegate{
    
    public func didSelectedPaymentOption(paymentMethod: PaymentMethod, selectedSection: Int) {
        guard lifecycle.phase == .active, paymentRequest == nil,
              step == .Dashboard else { return }
        //MARK: Call Submit Method With Order Key
        
        // Stop any started HelaPay status checks before selecting a method.
        statusTimer?.invalidate()
        statusTimer = nil
        statusRequest?.cancel()
        statusRequest = nil
        
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
