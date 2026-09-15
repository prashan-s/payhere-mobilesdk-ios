//
//  ViewController.swift
//  demoapp
//
//  Created by Kamal Upasena on 1/9/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import UIKit
import PayHereSDK

class ViewController: UIViewController {
    
    let merchantID = "1211149" // <YOUR_MERCHANT_ID>

    var initRequest : PHInitialRequest?

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    @IBAction func btnCheckOutPressed(_ sender: UIButton) {
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 25.00)
        let item2 = Item(id: "002", name: "PayHere Test Item 02", quantity: 2, amount: 25.0)
        
        // MARK: - Checkout API
        initRequest = PHInitialRequest(merchantID: merchantID,
                                       notifyURL: "",
                                       firstName: "Pay",
                                       lastName: "Here",
                                       email: "test@test.com",
                                       phone: "+9477123456",
                                       address: "Colombo",
                                       city: "Colombo",
                                       country: "Sri Lanka",
                                       orderID: "001",
                                       itemsDescription: "PayHere SDK Sample",
                                       itemsMap: [item1,item2],
                                       currency: .LKR,
                                       amount: 50.00,
                                       deliveryAddress: "",
                                       deliveryCity: "",
                                       deliveryCountry: "",
                                       custom1: "custom 01",
                                       custom2: "custom 02")
        
        
        // Configuration applies to this presentation; both settings default to true.
        // Set `showResultScreen` to false to handle result UI in your app.
        // Delegate callbacks deliver outcomes with either result-screen setting.
        // `showRetryOnResultScreen` controls Retry for final failed payment results only.
        // It is ignored when the result screen is hidden and does not retry SDK errors.
        let paymentConfiguration = PHPaymentConfiguration(
            showResultScreen: true,
            showRetryOnResultScreen: true
        )

        // To use SDK defaults, omit the configuration argument:
        // PayHereSDK.present(from: self, withInitRequest: initRequest!, delegate: self)
        PayHereSDK.present(from: self, withInitRequest: initRequest!,
                                    configuration: paymentConfiguration,
                                    delegate: self)
    }
    
    
    @IBAction func btnPreApprovalPressed(_ sender: Any) {
        
         let item1 = Item(id: "001",
                          name: "PayHere Test Item 01",
                          quantity: 1,
                          amount: 60.00)
        
        // MARK: - Preapproval API
        initRequest = PHInitialRequest(merchantID: merchantID,
                                       notifyURL: "",
                                       firstName: "",
                                       lastName: "",
                                       email: "",
                                       phone: "",
                                       address: "",
                                       city: "",
                                       country: "",
                                       orderID: "001",
                                       itemsDescription: "",
                                       itemsMap: [item1],
                                       currency: .LKR,
                                       custom1: "",
                                       custom2: "")
        
        
        
        // Optional, per-presentation preferences; omit them to use the defaults shown below.
        let paymentConfiguration = PHPaymentConfiguration(
            showResultScreen: true,
            showRetryOnResultScreen: true
        )

        PayHereSDK.present(from: self, withInitRequest: initRequest!,
                                    configuration: paymentConfiguration,
                                    delegate: self)
    }
    
    @IBAction func btnRecurringPressed(_ sender: UIButton) {
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 60.00)
        
        
        // MARK: - Recurring API
        initRequest = PHInitialRequest(
            merchantID: merchantID,
            notifyURL: "",
            firstName: "",
            lastName: "",
            email: "",
            phone: "",
            address: "",
            city: "",
            country: "",
            orderID: "002",
            itemsDescription: "",
            itemsMap: [item1],
            currency: .LKR,
            amount: 60.50,
            deliveryAddress: "",
            deliveryCity: "",
            deliveryCountry: "",
            custom1: "",
            custom2: "",
            startupFee: 0.0,
            recurrence: .Month(period: 2),
            duration: .Forver)
        
        // Optional, per-presentation preferences; omit them to use the defaults shown below.
        let paymentConfiguration = PHPaymentConfiguration(
            showResultScreen: true,
            showRetryOnResultScreen: true
        )

        PayHereSDK.present(from: self,
                                    withInitRequest: initRequest!,
                                    configuration: paymentConfiguration,
                                    delegate: self)
        
    }
    
    @IBAction func btnHoldOnCardPressed(_ sender: UIButton) {
        
        let item1 = Item(id: "001", name: "PayHere Test Item 01", quantity: 1, amount: 25.00)
        let item2 = Item(id: "002", name: "PayHere Test Item 02", quantity: 2, amount: 25.0)
        
        // MARK: - Authorize API (hold on card)
        initRequest = PHInitialRequest(
            merchantID: merchantID,
            notifyURL: "",
            firstName: "Pay",
            lastName: "Here",
            email: "test@test.com",
            phone: "+9477123456",
            address: "Colombo",
            city: "Colombo",
            country: "Sri Lanka",
            orderID: "001",
            itemsDescription: "PayHere SDK Sample",
            itemsMap: [item1,item2],
            currency: .LKR,
            amount: 50.00,
            deliveryAddress: "",
            deliveryCity: "",
            deliveryCountry: "",
            custom1: "custom 01",
            custom2: "custom 02",
            isHoldOnCardEnabled: true
        )
        
      
        
        
        // Optional, per-presentation preferences; omit them to use the defaults shown below.
        let paymentConfiguration = PHPaymentConfiguration(
            showResultScreen: true,
            showRetryOnResultScreen: true
        )

        PayHereSDK.present(from: self,
                                    withInitRequest: initRequest!,
                                    configuration: paymentConfiguration,
                                    delegate: self)
    }
}

extension ViewController: PayHereSDKDelegate {

    // Handle SDK errors and user actions using `code`, `category`, and `stage`.
    // Use `message` for display. Final payment results arrive through `didReceive`.
    // `.paymentStatusUnavailable` means the status is unknown; verify it before retrying.
    func payHereSDK(didFailWith error: PHPaymentError) {
        guard error.category != .userAction else {
            print(error.message)
            return
        }
        
        showPaymentError(message: error.message)
    }

 
    
    // Receives final successful, failed, or authorized payment results after dismissal.
    // `isSuccess()` is true only for SUCCESS; inspect StatusResponse to distinguish AUTHORIZED.
    func payHereSDK(didReceive response: PHResponse<Any>) {
        if response.isSuccess() {
            
            guard let resp = response.getData() as? StatusResponse else{
        
                return
            }
            print(resp.message ?? "" as Any)
            // Handle a successful payment using the details in `resp`.
            
        }else{
            print(response.getMessage() ?? "")
            showPaymentError(message: response.getMessage() ?? "")
            
        }
    }
    
    private func showPaymentError(message: String) {
        let alert = UIAlertController(title: "Payment", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // Required for deprecated compatibility; the SDK uses the typed error callback above.
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
    }
}
