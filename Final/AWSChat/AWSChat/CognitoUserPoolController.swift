//
//  CognitoUserPoolController.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 14/03/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

class CognitoUserPoolController {
    
    let userPoolRegionString = "us-east-1"
    let userPoolRegion: AWSRegionType = .USEast1
    let userPoolD = "us-east-1_qEyg0l636"

    let appClientID = "5o6ge7468o0iuaso9ego20e2s5"
    let appClientSecret = "ou0po8kqd8v9pjsthprac2r5msuq2b5otoi2dbbk1cjcl4nspl1"
    
    
    private var userPool:AWSCognitoIdentityUserPool?
    
    var currentUser:AWSCognitoIdentityUser? {
        get {
            return userPool?.currentUser()
        }
    }
    
    static let sharedInstance: CognitoUserPoolController = CognitoUserPoolController()
    
    private init() {
        
        let serviceConfiguration = AWSServiceConfiguration(region: userPoolRegion, credentialsProvider: nil)
        
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: appClientID,
                                                                        clientSecret: appClientSecret,
                                                                        poolId: userPoolD)
        
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration,
                                            userPoolConfiguration: poolConfiguration,
                                            forKey:"AWSChat")
        
        userPool = AWSCognitoIdentityUserPool(forKey: "AWSChat")
        
        AWSLogger.default().logLevel = .verbose
    }
    
    
    
    func login(username: String, password:String, completion:@escaping (Error?)->Void) {
    
        let user = self.userPool?.getUser(username)
        let task = user?.getSession(username, password: password, validationData:nil)
        
        task?.continueWith(block: { (task: AWSTask<AWSCognitoIdentityUserSession>) -> Any? in
            if let error = task.error {
                completion(error)
                return nil
            }
            
            completion(nil)
            return nil
            
        })
    }
    
    
    func signup(username: String, password:String, emailAddress:String, completion:@escaping (Error?, AWSCognitoIdentityUser?)->Void) {
        
        var attributes = [AWSCognitoIdentityUserAttributeType]()
        let emailAttribute = AWSCognitoIdentityUserAttributeType(name: "email", value: emailAddress)
        attributes.append(emailAttribute)
        
        let task = self.userPool?.signUp(username, password: password, userAttributes: attributes, validationData: nil)
        
        task?.continueWith(block: {(task: AWSTask<AWSCognitoIdentityUserPoolSignUpResponse>) -> Any? in
            if let error = task.error {
                completion(error, nil)
                return nil
            }
            
            guard let result = task.result else {
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 100,
                                    userInfo: ["__type":"Unknown Error", "message":"Cognito user pool error."])
                completion(error, nil)
                return nil
            }
            
            completion(nil, result.user)
            return nil
        })
        
    }
    
    
    
    func confirmSignup(user: AWSCognitoIdentityUser, confirmationCode:String, completion:@escaping (Error?)->Void) {
        
        let task = user.confirmSignUp(confirmationCode)
        
        task.continueWith { (task: AWSTask<AWSCognitoIdentityUserConfirmSignUpResponse>) -> Any? in
            if let error = task.error {
                completion(error)
                return nil
            }
            
            completion(nil)
            return nil
        }

    }
    
    func resendConfirmationCode(user: AWSCognitoIdentityUser, completion:@escaping (Error?)->Void) {
        
        let task = user.resendConfirmationCode()
        task.continueWith { (task: AWSTask<AWSCognitoIdentityUserResendConfirmationCodeResponse>) -> Any? in
            if let error = task.error {
                completion(error)
                return nil
            }
            
            completion(nil)
            return nil
        }
        
    }
    
    func getUserDetails(user: AWSCognitoIdentityUser, completion:@escaping (Error?, AWSCognitoIdentityUserGetDetailsResponse?)->Void) {
        
        let task = user.getDetails()
        task.continueWith(block: { (task: AWSTask<AWSCognitoIdentityUserGetDetailsResponse>) -> Any? in
            if let error = task.error {
                completion(error, nil)
                return nil
            }
            
            guard let result = task.result else {
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 100,
                                    userInfo: ["__type":"Unknown Error", "message":"Cognito user pool error."])
                completion(error, nil)
                return nil
            }
            
            completion(nil, result)
            return nil
        })
    }
}
