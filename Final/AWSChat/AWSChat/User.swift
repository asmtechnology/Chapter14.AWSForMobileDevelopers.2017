//
//  User.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 09/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSDynamoDB

class User : AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    
    var id: String?
    var username: String?
    var email_address: String?

    override init() {
        super.init()
    }
    
    override init(dictionary dictionaryValue: [AnyHashable : Any]!, error: ()) throws {
        super.init()
        id = dictionaryValue["id"] as? String
        username = dictionaryValue["username"] as? String
        email_address = dictionaryValue["email_address"] as? String
    }
    
    required init!(coder: NSCoder!) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func dynamoDBTableName() -> String {
        return "User"
    }
    
    class func hashKeyAttribute() -> String {
        return "id"
    }
}
