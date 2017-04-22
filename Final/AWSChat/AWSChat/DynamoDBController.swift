//
//  DynamoDBController.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 08/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSDynamoDB

class DynamoDBController {
    
    static let sharedInstance: DynamoDBController = DynamoDBController()
    
    private init() { }
    
    func refreshFriendList(userId: String, completion:@escaping (Error?)->Void) {
        
        retrieveFriendIds(userId: userId) { (error:Error?, friendUserIDArray:[String]?) in
            
            if let error = error as? NSError {
                completion(error)
                return
            }
            
            // clear friend list in ChatManager
            let chatManager = ChatManager.sharedInstance
            chatManager.clearFriendList()
            
            if friendUserIDArray == nil {
                // user has no friends
                completion(nil)
                return
            }
         
            // get all entries in the User table
            let scanExpression = AWSDynamoDBScanExpression()
        
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let task = dynamoDBObjectMapper.scan(User.self, expression: scanExpression)
            
            task.continueWith { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                
                if let error = task.error as? NSError {
                    completion(error)
                    return nil
                }
                
                guard let paginatedOutput = task.result else {
                    let error = NSError(domain: "com.asmtechnology.awschat",
                                        code: 200,
                                        userInfo: ["__type":"Unknown Error", "message":"DynamoDB error."])
                    completion(error)
                    return nil
                }
                
                
                if paginatedOutput.items.count == 0 {
                    completion(nil)
                    return nil
                }
                
                for index in 0...(paginatedOutput.items.count - 1) {
                    
                    guard let user = paginatedOutput.items[index] as? User,
                        let userId = user.id else {
                            continue
                    }
                    
                    if friendUserIDArray!.contains(userId) {
                        chatManager.addFriend(user: user)
                    }
                }
                
                
                completion(nil)
                return nil
            }


        }

    }
    
    
    
    private func retrieveFriendIds(userId: String, completion:@escaping (Error?, [String]?)->Void) {
        
        let scanExpression = AWSDynamoDBScanExpression()
        scanExpression.filterExpression = "user_id = :val"
        scanExpression.expressionAttributeValues = [":val":userId]
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.scan(Friend.self, expression: scanExpression)
        
        var friendUserIDArray = [String]()
        
        task.continueWith { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            
            if let error = task.error as? NSError {
                completion(error, nil)
                return nil
            }
            
            guard let paginatedOutput = task.result else {
                // user has no friends.
                completion(nil, nil)
                return nil
            }
            
            if paginatedOutput.items.count == 0 {
                // user has no friends.
                completion(nil, nil)
                return nil
            }
            
            for index in 0...(paginatedOutput.items.count - 1) {
                
                guard let friend = paginatedOutput.items[index] as? Friend,
                    let friend_user_id = friend.friend_id else {
                        continue
                }
                
                friendUserIDArray.append(friend_user_id)
            }
            
            completion(nil, friendUserIDArray)
            return nil
        }
        
    }

    
    func retrieveUser(userId: String, completion:@escaping (Error?, User?)->Void) {
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        
        let task = dynamoDBObjectMapper.load(User.self, hashKey: userId, rangeKey:nil)
        
        task.continueWith { (task: AWSTask<AnyObject>) -> Any? in
            if let error = task.error as? NSError {
                completion(error, nil)
                return nil
            }
            
            if let result = task.result as? User {
                completion(nil, result)
            } else {
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 200,
                                    userInfo: ["__type":"Unknown Error", "message":"DynamoDB error."])
                completion(error, nil)
            }
            
            return nil
        }
    
    }
    
    
    func refreshPotentialFriendList(currentUserId: String, completion:@escaping (Error?)->Void) {
        
        retrieveFriendIds(userId: currentUserId) { (error:Error?, friendUserIDArray:[String]?) in
            
            if let error = error as? NSError {
                completion(error)
                return
            }
            
            // get all entries in the User table
            let scanExpression = AWSDynamoDBScanExpression()
            
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let task = dynamoDBObjectMapper.scan(User.self, expression: scanExpression)
            
            task.continueWith { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                
                if let error = task.error as? NSError {
                    completion(error)
                    return nil
                }
                
                guard let paginatedOutput = task.result else {
                    let error = NSError(domain: "com.asmtechnology.awschat",
                                        code: 200,
                                        userInfo: ["__type":"Unknown Error", "message":"DynamoDB error."])
                    completion(error)
                    return nil
                }
                
                // clear potential friend list in ChatManager
                let chatManager = ChatManager.sharedInstance
                chatManager.clearPotentialFriendList()
                
                if paginatedOutput.items.count == 0 {
                    completion(nil)
                    return nil
                }
                
                for index in 0...(paginatedOutput.items.count - 1) {
                    
                    guard let user = paginatedOutput.items[index] as? User,
                        let userId = user.id else {
                            continue
                    }
                    
                    if (friendUserIDArray != nil && friendUserIDArray!.contains(userId)) {
                        continue
                    }
                    
                    if (currentUserId.compare(userId) == .orderedSame) {
                        continue
                    }
                    
                    chatManager.addPotentialFriend(user: user)
                }
                
                
                completion(nil)
                return nil
            }
            
        }
    }
    
    func addFriend(currentUserId: String, friendUserId:String, completion:@escaping (Error?)->Void) {
        
        //  Friend relationship between currentUserId and friendUserId
        let friendRelationship = Friend()
        friendRelationship.id = NSUUID().uuidString
        friendRelationship.user_id = currentUserId
        friendRelationship.friend_id = friendUserId
        
        //  Reverse relationship between friendUserId and currentUserId
        let reverseRelationship = Friend()
        reverseRelationship.id = NSUUID().uuidString
        reverseRelationship.user_id = friendUserId
        reverseRelationship.friend_id = currentUserId
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.save(friendRelationship)
        
        task.continueWith { (task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }
            
            // create reverse relationship.
            let task2 = dynamoDBObjectMapper.save(reverseRelationship)
            task2.continueWith(block: { (task:AWSTask<AnyObject>) -> Any? in
                if let error = task.error as? NSError {
                    completion(error)
                    return nil
                }
                
                completion(nil)
                return nil
            })
            
            return nil
        }
        
    }

    func retrieveChat(fromUserId:String, toUserId:String, completion:@escaping (Error?)->Void) {
        
        let chatID = "\(fromUserId)\(toUserId)"
        let alternateChatID = "\(toUserId)\(fromUserId)"
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.load(Chat.self, hashKey: chatID, rangeKey:nil)
        
        task.continueWith { (task: AWSTask<AnyObject>) -> Any? in
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }
            
            if let result = task.result as? Chat {
                // chat has been found.
                let chatManager = ChatManager.sharedInstance
                chatManager.addChat(chat:result)
                
                completion(nil)
            } else {
                // chat was not found, try alternateChatID
                let task2 = dynamoDBObjectMapper.load(Chat.self, hashKey: alternateChatID, rangeKey:nil)
                
                task2.continueWith { (task: AWSTask<AnyObject>) -> Any? in
                    if let error = task.error as? NSError {
                        completion(error)
                        return nil
                    }
                    
                    if let result = task.result as? Chat {
                        // chat has been found.
                        let chatManager = ChatManager.sharedInstance
                        chatManager.addChat(chat:result)
                        
                        completion(nil)
                    } else {
  
                        let error = NSError(domain: "com.asmtechnology.awschat",
                                            code: 210,
                                            userInfo: nil)
                        completion(error)
                    }
                    
                    return nil
                }
                
            }
            
            return nil
        }
    }
    
    func createChat(fromUserId:String, toUserId:String, completion:@escaping (Error?)->Void) {
        
        let chat = Chat()
        chat.id = "\(fromUserId)\(toUserId)"
        chat.from_user_id = fromUserId
        chat.to_user_id = toUserId
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.save(chat)
        
        task.continueWith { (task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }
            
            let chatManager = ChatManager.sharedInstance
            chatManager.addChat(chat:chat)
            
            completion(nil)
            return nil
        }
    }
    
    func sendTextMessage(fromUserId:String, chatId:String, messageText:String, completion:@escaping (Error?)->Void) {
        
        let message = Message()
        message.chat_id = chatId
        message.date_sent = Date().timeIntervalSince1970 as NSNumber
        message.message_id = NSUUID().uuidString
        message.message_text = messageText
        message.message_image = "NA"
        message.mesage_image_preview = "NA"
        message.sender_id = fromUserId
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.save(message)
        
        task.continueWith { (task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }
            
            let chatManager = ChatManager.sharedInstance
            chatManager.addMessage(chatId:chatId, message:message)
            
            completion(nil)
            return nil
        }
    }
    
    
    func sendImage(fromUserId:String, chatId:String,
                   imageFile:String, previewFile:String, completion:@escaping (Error?)->Void) {

        let message = Message()
        message.chat_id = chatId
        message.date_sent = Date().timeIntervalSince1970 as NSNumber
        message.message_id = NSUUID().uuidString
        message.message_text = "NA"
        message.message_image = imageFile
        message.mesage_image_preview = previewFile
        message.sender_id = fromUserId
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.save(message)
        
        task.continueWith { (task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }
            
            let chatManager = ChatManager.sharedInstance
            chatManager.addMessage(chatId:chatId, message:message)
            
            completion(nil)
            return nil
        }
    }

    
    func retrieveAllMessages(chatId:String, fromDate:Date, completion:@escaping (Error?)->Void) {
        
        let fromDateAsNumber = fromDate.timeIntervalSince1970
        
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "chat_id = :chatidentitier AND date_sent > :earliestDate";
        queryExpression.expressionAttributeValues = [":chatidentitier": chatId, ":earliestDate": fromDateAsNumber];
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let task = dynamoDBObjectMapper.query(Message.self, expression: queryExpression)
        task.continueWith(block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }
            
            guard let paginatedOutput = task.result else {
                // user has no messages.
                completion(nil)
                return nil
            }
            
            if paginatedOutput.items.count == 0 {
                // user has no messages.
                completion(nil)
                return nil
            }
            
            for index in 0...(paginatedOutput.items.count - 1) {
                
                if let message = paginatedOutput.items[index] as? Message  {
                    let chatManager = ChatManager.sharedInstance
                    chatManager.addMessage(chatId:chatId, message:message)
                }
                
            }
            
            completion(nil)
            return nil
        })

    }
    
}
