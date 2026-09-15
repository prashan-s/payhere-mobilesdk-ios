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
        
        //MARK: CheckOut API
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
        
        
        // Configuration is optional. You do not need to create or pass one to integrate the SDK.
        // The defaults show the result screen and offer Retry after a failed payment.
        // Set `showResultScreen` to false if your app handles the outcome through the delegate.
        // Set `showRetryOnResultScreen` to false to hide Retry on the failed result screen.
        // `showRetryOnResultScreen` is ignored when showResultScreen is false.
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
        
        //MARK: Pre Approval API
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
        
        
        
        // Optional configuration for this payment only; omit it to use SDK defaults.
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
        
        
        //MARK: Recurring API
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
        
        // Optional configuration for this payment only; omit it to use SDK defaults.
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
        
        //MARK: CheckOut API
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
        
      
        
        
        // Optional configuration for this payment only; omit it to use SDK defaults.
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

extension ViewController : PHViewControllerDelegate{
    
    func onErrorReceived(error: Error) {
        print("✋ Error",error)
        
        let ac = UIAlertController(title: "Error Occurred", message: error.localizedDescription, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        ac.addAction(okAction)
        present(ac, animated: true, completion: nil)
    }
    
    func onResponseReceived(response: PHResponse<Any>?) {
        if(response?.isSuccess())!{
            
            guard let resp = response?.getData() as? StatusResponse else{
        
                return
            }
            print(resp.message ?? "" as Any)
            //Payment Sucess
            
        }else{
            print(response?.getMessage() ?? "")
            
        }
    }
    
    
}
