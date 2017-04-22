//
//  Chat.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 09/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSDynamoDB

class Chat : AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    
    var id: String?
    var from_user_id: String?
    var to_user_id: String?
    
    override init() {
        super.init()
    }
    
    override init(dictionary dictionaryValue: [AnyHashable : Any]!, error: ()) throws {
        super.init()
        id = dictionaryValue["id"] as? String
        from_user_id = dictionaryValue["from_user_id"] as? String
        to_user_id = dictionaryValue["to_user_id"] as? String
    }
    
    required init!(coder: NSCoder!) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func dynamoDBTableName() -> String {
        return "Chat"
    }
    
    class func hashKeyAttribute() -> String {
        return "id"
    }
    
}
