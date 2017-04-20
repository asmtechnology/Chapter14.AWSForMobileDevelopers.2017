//
//  SignupViewController.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 07/03/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import UIKit
import AWSCognitoIdentityProvider

class SignupViewController: UIViewController {

    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var createAccountButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.createAccountButton.isEnabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onCreateAccount(_ sender: Any) {
        
        guard let username = self.usernameField.text,
            let password = self.passwordField.text,
            let emailAddress = self.emailField.text else {
                return
        }
        

        let userpoolController = CognitoUserPoolController.sharedInstance
        userpoolController.signup(username: username, password: password, emailAddress: emailAddress) { (error: Error?, user: AWSCognitoIdentityUser?) in
            
            if let error = error {
                self.displaySignupError(error: error as NSError, completion:nil)
                return
            }
            
            guard let user = user else {
                
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 1021,
                                    userInfo: ["__type":"Unknown Error", "message":"Missing User object"])
                
                self.displaySignupError(error: error, completion:nil)
                return
            }

            if user.confirmedStatus != AWSCognitoIdentityUserStatus.confirmed {
                self.requestConfirmationCode(user)
            } else {
                self.getFederatedIdentity(user)
            }
        }
    }

    @IBAction func usernameDidEndOnExit(_ sender: Any) {
        dismissKeyboard()
    }
    
    @IBAction func passwordDidEndOnExit(_ sender: Any) {
        dismissKeyboard()
    }
    
    @IBAction func emailDidEndOnExit(_ sender: Any) {
        dismissKeyboard()
    }
}


extension SignupViewController : UITextFieldDelegate {
    
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        
        if let username = self.usernameField.text,
            let password = self.passwordField.text,
            let emailAddress = self.emailField.text {
            
            if ((username.characters.count > 0) &&
                (password.characters.count > 0) &&
                (emailAddress.characters.count > 0)) {
                self.createAccountButton.isEnabled = true
            }
        }
        
        return true
    }
}

extension SignupViewController {
    
    fileprivate func dismissKeyboard() {
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
        emailField.resignFirstResponder()
    }
    
    fileprivate func displaySignupError(error:NSError, completion:(() -> Void)?) {
        
        let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                message: error.userInfo["message"] as? String,
                                                preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            if let completion = completion {
                completion()
            }
        }

        alertController.addAction(okAction)
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    fileprivate func requestConfirmationCode(_ user:AWSCognitoIdentityUser) {
        
        let alertController = UIAlertController(title: "Confirmation.",
                                                message: "Please type the 6-digit confirmation code that has been sent to your email address.",
                                                preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.placeholder = "######"
        }
        
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { action in
            if let firstTextField = alertController.textFields?.first,
                let confirmationCode = firstTextField.text {
                
                let userpoolController = CognitoUserPoolController.sharedInstance
                userpoolController.confirmSignup(user: user, confirmationCode: confirmationCode) { (error: Error?) in
                    
                    if let error = error {
                        self.displaySignupError(error: error as NSError, completion: {() in
                            self.requestConfirmationCode(user)
                        })
                        return
                    }

                    self.getFederatedIdentity(user)
                }
            }
        })
        
        let resendAction = UIAlertAction(title: "Resend code", style: UIAlertActionStyle.default, handler: { action in
            
            let userpoolController = CognitoUserPoolController.sharedInstance
            userpoolController.resendConfirmationCode(user: user) { (error: Error?) in
                
                if let error = error {
                    self.displaySignupError(error: error as NSError, completion: { (Void) in
                        self.requestConfirmationCode(user)
                    })
                    return
                }
             
                self.displayCodeResentMessage(user)
            }

        })
        
        alertController.addAction(okAction)
        alertController.addAction(resendAction)
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion:  nil)
        }
    }
    
    
    fileprivate func displaySuccessMessage() {
        let alertController = UIAlertController(title: "Success.",
                                                message: "Your account has been created!.",
                                                preferredStyle: .alert)
        
        let action = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { action in
            let storyboard = UIStoryboard(name: "ChatJourney", bundle: nil)
                
            let viewController = storyboard.instantiateInitialViewController()
            self.present(viewController!, animated: true, completion: nil)
        })
        
        alertController.addAction(action)
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion:  nil)
        }
    }
    
    
    
    fileprivate func displayCodeResentMessage(_ user:AWSCognitoIdentityUser) {
        
        let alertController = UIAlertController(title: "Code Resent.",
                                                message: "A 6-digit confirmation code has been sent to your email address.",
                                                preferredStyle: .alert)
        
        
        
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { action in
            self.requestConfirmationCode(user)
        })
        
        
        alertController.addAction(okAction)
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion:  nil)
        }
    }
    
    fileprivate func getFederatedIdentity(_ user:AWSCognitoIdentityUser) {
        
        let name = usernameField.text!
        let emailAddress = emailField.text!
        let password = passwordField.text!
        
        let task = user.getSession(name, password: password, validationData:nil)
        
        task.continueWith(block: { (task: AWSTask<AWSCognitoIdentityUserSession>) -> Any? in
            
            if let error = task.error {
                self.displaySignupError(error: error as NSError, completion: nil)
                return nil
            }
            
            
            let userSession = task.result!
            let idToken = userSession.idToken!
            
            let userpoolController = CognitoUserPoolController.sharedInstance
            let indentityPoolController = CognitoIdentityPoolController.sharedInstance
            indentityPoolController.getFederatedIdentityForAmazon(idToken: idToken.tokenString,
                                                                  username: name, emailAddress: emailAddress,
                                                                  userPoolRegion: userpoolController.userPoolRegionString,
                                                                  userPoolID: userpoolController.userPoolD,
                                                                  completion: { (error: Error?) in
                                                                    
                                                                    if let error = error {
                                                                        self.displaySignupError(error: error as NSError, completion: nil)
                                                                        return
                                                                    }
                                                                    
                                                                    self.displaySuccessMessage()
                                                                    return
            })
            
            
            return nil

        })
        

    }
}

