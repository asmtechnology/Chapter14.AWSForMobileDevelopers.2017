//
//  Friend.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 09/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSDynamoDB

class Friend : AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    
    var id: String?
    var user_id: String?
    var friend_id: String?
    
    override init() {
        super.init()
    }
    
    override init(dictionary dictionaryValue: [AnyHashable : Any]!, error: ()) throws {
        super.init()
        id = dictionaryValue["id"] as? String
        user_id = dictionaryValue["user_id"] as? String
        friend_id = dictionaryValue["friend_id"] as? String
    }
   
    required init!(coder: NSCoder!) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func dynamoDBTableName() -> String {
        return "Friend"
    }
    
    class func hashKeyAttribute() -> String {
        return "id"
    }
}


