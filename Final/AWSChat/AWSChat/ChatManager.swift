//
//  ChatManager.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 09/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation

class ChatManager {
    
    var conversations:[Chat:[Message]?]?
    var friendList:[User]?
    var potentialFriendList:[User]?
    
    static let sharedInstance: ChatManager = ChatManager()
    
    private init() {
        friendList =  [User]()
        potentialFriendList = [User]()
        conversations = [Chat:[Message]?]()
    }
    
    func clearFriendList() {
        friendList?.removeAll()
    }
    
    func addFriend(user:User) {
        friendList?.append(user)
    }
    
    func clearPotentialFriendList() {
        potentialFriendList?.removeAll()
    }
    
    func addPotentialFriend(user:User) {
        potentialFriendList?.append(user)
    }
    
    func clearCurrentChatList() {
        conversations?.removeAll()
    }
    
    func addChat(chat:Chat) {

        if let _ = findChat(chatId: chat.id!) {
            return
        }
        
        conversations![chat] = [Message]()
    }
    
    
    func addMessage(chatId:String, message:Message) {
        
        guard let chat = findChat(chatId: chatId) else {
            return
        }
        
        for existingMessage in conversations![chat]!! {
            if (existingMessage.message_id!.compare(message.message_id!) == .orderedSame) {
                return
            }
        }
        
        conversations![chat]!!.append(message)

    }

    func loadChat(fromUserId:String, toUserId:String, completion:@escaping (Error?, Chat?)->Void) {
    
        if let chat = findChat(fromUserId: fromUserId, toUserId: toUserId) {
            completion(nil, chat)
            return
        }
        
        let dynamoDBController = DynamoDBController.sharedInstance
        dynamoDBController.retrieveChat(fromUserId: fromUserId, toUserId: toUserId) { (error) in
            if let error = error as? NSError {
                if error.code != 210 {
                    completion(error, nil)
                    return
                }
                
                // no existing chat in dynamoDB, create one.
                dynamoDBController.createChat(fromUserId: fromUserId, toUserId: toUserId, completion: { (error) in
                    if let error = error {
                        completion(error, nil)
                        return
                    }
                    
                    if let chat = self.findChat(fromUserId: fromUserId, toUserId: toUserId) {
                        completion(nil, chat)
                        return
                    }
                    
                    let error = NSError(domain: "com.asmtechnology.awschat",
                                        code: 400,
                                        userInfo: ["__type":"Unknown Error", "message":"DynamoDB error."])
                    completion(error, nil)
                    return
                    
                })
        
                return
            }
            
            if let chat = self.findChat(fromUserId: fromUserId, toUserId: toUserId) {
                completion(nil, chat)
                return
            }
            
            let error = NSError(domain: "com.asmtechnology.awschat",
                                code: 400,
                                userInfo: ["__type":"Unknown Error", "message":"DynamoDB error."])
            completion(error, nil)
            return
        }
    }
    
    
    func refreshAllMessages(chat:Chat, completion:@escaping (Error?)->Void) {
        
        let earliestDate = Date(timeIntervalSince1970: 0)
        
        let dynamoDBController = DynamoDBController.sharedInstance
        dynamoDBController.retrieveAllMessages(chatId: chat.id!, fromDate: earliestDate) { (error) in
        
            if let error = error {
                completion (error)
            } else {
                completion(nil)
            }
            
        }
    }
    
    func sendTextMessage(chat:Chat, messageText:String, completion:@escaping (Error?)->Void) {
        
        let timeSent = Date()
        
        let cognitoIdentityPoolController = CognitoIdentityPoolController.sharedInstance
        guard let senderID = cognitoIdentityPoolController.currentIdentityID else {
            let error = NSError(domain: "com.asmtechnology.awschat",
                                code: 402,
                                userInfo: ["__type":"Unauthenticated", "message":"Sender is no longer authenticated."])
            completion(error)
            return
        }
        
        let dynamoDBController = DynamoDBController.sharedInstance
        dynamoDBController.sendTextMessage(fromUserId: senderID, chatId: chat.id!,
                                           messageText: messageText) { (error) in
            if let error = error {
                completion(error)
                return
            }
            
            dynamoDBController.retrieveAllMessages(chatId: chat.id!, fromDate: timeSent) { (error) in
                if let error = error {
                    completion (error)
                } else {
                    completion(nil)
                }
                
            }
        }
        

    }
    
    func sendImage(chat:Chat, message:UIImage, completion:@escaping (Error?)->Void) {
        
        let timeSent = Date()
        
        let cognitoIdentityPoolController = CognitoIdentityPoolController.sharedInstance
        guard let senderID = cognitoIdentityPoolController.currentIdentityID else {
            let error = NSError(domain: "com.asmtechnology.awschat",
                                code: 402,
                                userInfo: ["__type":"Unauthenticated", "message":"Sender is no longer authenticated."])
            completion(error)
            return
        }
        
        // save image to documents directory
        guard let imageData = UIImagePNGRepresentation(message) else {
            let error = NSError(domain: "com.asmtechnology.awschat",
                                code: 406,
                                userInfo: ["__type":"Error", "message":"Could not save image to documets directory."])
            completion(error)
            return
        }
        
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = NSUUID().uuidString
        let previewFileName = "NA"
        let localFilePath = documentsDirectory.appending("\(fileName).png")
        
        do {
            try imageData.write(to:URL(fileURLWithPath: localFilePath), options: .atomicWrite)
        } catch {
            let error = NSError(domain: "com.asmtechnology.awschat",
                                code: 406,
                                userInfo: ["__type":"Error", "message":"Could not save image to documets directory."])
            completion(error)
        }

        
        
        let s3Controller = S3Controller.sharedInstance
        s3Controller.uploadImage(localFilePath: localFilePath,
                                 remoteFileName: fileName) { (error) in
            
            if let error = error {
                completion(error)
                return
            }
            
            let dynamoDBController = DynamoDBController.sharedInstance
            dynamoDBController.sendImage(fromUserId: senderID, chatId: chat.id!,
                                         imageFile: fileName,
                                         previewFile:previewFileName) { (error) in
                                            if let error = error {
                                                completion(error)
                                                return
                                            }
                                            
                                            dynamoDBController.retrieveAllMessages(chatId: chat.id!, fromDate: timeSent) { (error) in
                                                if let error = error {
                                                    completion (error)
                                                } else {
                                                    completion(nil)
                                                }
                                                
                                            }
            }
  
        }
    

        
    }
    

    private func findChat(chatId:String) -> Chat? {
        
        for key in conversations!.keys {
            if key.id!.compare(chatId) == .orderedSame {
                return key
            }
        }
        
        return nil
    }
    
    private func findChat(fromUserId:String, toUserId:String) -> Chat? {
        
        // find a chat between two users.
        for key in conversations!.keys {
        
            if ((key.from_user_id!.compare(fromUserId) == .orderedSame && key.to_user_id!.compare(toUserId) == .orderedSame) ||
                (key.from_user_id!.compare(toUserId) == .orderedSame && key.to_user_id!.compare(fromUserId) == .orderedSame)) {
                return key
            }
            
        }
        
        return nil
    }
}
