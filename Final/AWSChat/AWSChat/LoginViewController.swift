//
//  LoginViewController.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 07/03/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import UIKit
import GoogleSignIn
import AWSCognitoIdentityProvider

class LoginViewController: UIViewController {

    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var signupButton: UIButton!
    
    @IBOutlet weak var facebookButton: FBSDKLoginButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.loginButton.isEnabled = false
        
        // log out the user if previously logged in.
        let facebookLoginManager = FBSDKLoginManager()
        facebookLoginManager.logOut()
        
        // set up the information you want to read from the user's Facebook account.
        facebookButton.readPermissions = ["public_profile", "email"];
        
        // Google sign-in setup
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().shouldFetchBasicProfile = true
        GIDSignIn.sharedInstance().signOut()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onLogin(_ sender: Any) {
        
        dismissKeyboard()
        
        guard let username = self.usernameField.text,
            let password = self.passwordField.text  else {
            return
        }
        
        let userpoolController = CognitoUserPoolController.sharedInstance
        userpoolController.login(username: username, password: password) { (error) in
            
            if let error = error {
                self.displayLoginError(error: error as NSError)
                return
            }
            
            self.getFederatedIdentity(userpoolController.currentUser!)
        }
    }
    
    @IBAction func usernameDidEndOnExit(_ sender: Any) {
        dismissKeyboard()
    }
    
    @IBAction func passwordDidEndOnExit(_ sender: Any) {
        dismissKeyboard()
    }
    
}

extension LoginViewController : UITextFieldDelegate {
    
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        
        if let username = self.usernameField.text,
            let password = self.passwordField.text {
            
            if ((username.characters.count > 0) &&
                (password.characters.count > 0)) {
                self.loginButton.isEnabled = true
            }
        }
        
        return true
    }

}


extension LoginViewController {
    
    fileprivate func dismissKeyboard() {
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
    }
    
    
    fileprivate func displayLoginError(error:NSError) {
        
        let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                message: error.userInfo["message"] as? String,
                                                preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    fileprivate func displaySuccessMessage() {
        let alertController = UIAlertController(title: "Success.",
                                                message: "Login succesful!",
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

    fileprivate func getFederatedIdentity(_ user:AWSCognitoIdentityUser) {
        
        
        let userpoolController = CognitoUserPoolController.sharedInstance
        userpoolController.getUserDetails(user: userpoolController.currentUser!) { (error: Error?, details:AWSCognitoIdentityUserGetDetailsResponse?) in
            
            if let error = error {
                self.displayLoginError(error: error as NSError)
                return
            }
            
            var email:String? = nil
            if let userAttributes = details?.userAttributes {
                for attribute in userAttributes {
                    if attribute.name?.compare("email") == .orderedSame {
                        email = attribute.value
                    }
                }
            }
            
            guard let emailAddress = email else {
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 100,
                                    userInfo: ["__type":"Cognito error", "message":"Missing email address."])
                self.displayLoginError(error: error)
                return
            }
            
            let name = self.usernameField.text!
            let password = self.passwordField.text!
            
            let task = user.getSession(name, password: password, validationData:nil)
            
            task.continueWith(block: { (task: AWSTask<AWSCognitoIdentityUserSession>) -> Any? in
                
                if let error = task.error {
                    self.displayLoginError(error: error as NSError)
                    return nil
                }
                
                let userSession = task.result!
                let idToken = userSession.idToken!
                
                let userpoolController = CognitoUserPoolController.sharedInstance
                let indentityPoolController = CognitoIdentityPoolController.sharedInstance
                indentityPoolController.getFederatedIdentityForAmazon(idToken: idToken.tokenString,
                                                                      username: name,
                                                                      emailAddress: emailAddress,
                                                                      userPoolRegion: userpoolController.userPoolRegionString,
                                                                      userPoolID: userpoolController.userPoolD,
                                                                      completion: { (error: Error?) in
                                                                        
                                                                        if let error = error {
                                                                            self.displayLoginError(error: error as NSError)
                                                                            return
                                                                        }
                                                                        
                                                                        self.displaySuccessMessage()
                                                                        return
                })
                
                
                return nil
                
            })

        }
        
    }

}


extension LoginViewController : FBSDKLoginButtonDelegate {
    
    func loginButton(_ loginButton: FBSDKLoginButton!,
                     didCompleteWith result: FBSDKLoginManagerLoginResult!,
                     error: Error!) {
        
        if error != nil {
            displayLoginError(error: error as NSError)
            return
        }
        
        if result.isCancelled {
                return
        }
        
        guard let idToken = FBSDKAccessToken.current() else {
            let error = NSError(domain: "com.asmtechnology.awschat",
                                code: 100,
                                userInfo: ["__type":"Unknown Error", "message":"Facebook JWT token error."])
            self.displayLoginError(error: error)
            return
        }
        
        
        let graphRequest : FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me",
                                                                 parameters: ["fields":"email,name"])
        
        graphRequest.start(completionHandler: { (connection, result, error) -> Void in
            
            if let error = error {
                self.displayLoginError(error: error as NSError)
                return
            }
            
            if let result = result as? [String : AnyObject],
                let name = result["name"] as? String {
                
                let email = result["email"] as? String
                
                let indentityPoolController = CognitoIdentityPoolController.sharedInstance
                indentityPoolController.getFederatedIdentityForFacebook(idToken: idToken.tokenString,
                    username: name, emailAddress: email,
                    completion: { (error: Error?) in
                        
                        if let error = error {
                            self.displayLoginError(error:error as NSError)
                            return
                        }
                        
                        self.displaySuccessMessage()
                        return
                })
                
            }
            
        })
        
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        // do nothing.
    }
    
}

extension LoginViewController : GIDSignInDelegate, GIDSignInUIDelegate {

    func sign(_ signIn: GIDSignIn!,
              didSignInFor user: GIDGoogleUser!,
              withError error: Error?) {
        
        if let error = error {
            displayLoginError(error: error as NSError)
            return
        }
        
        let idToken = user.authentication.idToken
        let name = user.profile.name
        let email = user.profile.email
        
        let indentityPoolController = CognitoIdentityPoolController.sharedInstance
        indentityPoolController.getFederatedIdentityForGoogle(idToken: idToken!,
                                                                username: name!,
                                                                emailAddress: email,
                                                                completion: { (error: Error?) in
                                                                    
                        if let error = error {
                            self.displayLoginError(error:error as NSError)
                            return
                        }
                        
                        self.displaySuccessMessage()
                        return
        })
        
    }
    
    
}
