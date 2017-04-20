//
//  Message.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 09/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSDynamoDB

class Message : AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    
    var chat_id:String?
    var date_sent:NSNumber?
    var message_id: String?
    var message_text:String?
    var message_image:String?
    var mesage_image_preview:String?
    var sender_id:String?

    override init() {
        super.init()
    }
    
    override init(dictionary dictionaryValue: [AnyHashable : Any]!, error: ()) throws {
        super.init()
        chat_id = dictionaryValue["chat_id"] as? String
        date_sent = dictionaryValue["date_sent"] as? NSNumber
        message_id = dictionaryValue["message_id"] as? String
        message_text = dictionaryValue["message_text"] as? String
        message_image = dictionaryValue["message_image"] as? String
        mesage_image_preview = dictionaryValue["mesage_image_preview"] as? String
        sender_id = dictionaryValue["sender_id"] as? String
    }

    required init!(coder: NSCoder!) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func dynamoDBTableName() -> String {
        return "Message"
    }
    
    class func hashKeyAttribute() -> String {
        return "chat_id"
    }
    
    class func rangeKeyAttribute() -> String {
        return "date_sent"
    }
    
}
