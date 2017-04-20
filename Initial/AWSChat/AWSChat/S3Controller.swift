//
//  S3Controller.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 16/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import Foundation
import AWSS3

class S3Controller {
    
    private let imageBucketName = "com.asmtechnology.awschat.images"
    private let thumbnailsBucketName = "com.asmtechnology.awschat.thumbnails"
    static let sharedInstance: S3Controller = S3Controller()
    
    private init() { }
    
    func uploadImage(localFilePath:String, remoteFileName:String,
                     completion:@escaping (Error?)->Void) {

        
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = {(task: AWSS3TransferUtilityTask, progress: Progress) in
            print("Uploaded: \(progress.fractionCompleted)%")
        }

        let transferUtility = AWSS3TransferUtility.default()
    
        let task = transferUtility.uploadFile(URL(fileURLWithPath: localFilePath),
            bucket: imageBucketName,
            key: "\(remoteFileName).png",
            contentType: "image/png",
            expression: expression) { (task, error) in
                
                if error != nil {
                    completion(error)
                } else {
                    completion(nil)
                }
        }
        
        task.continueWith { (task) -> Any? in
            if let error = task.error as? NSError {
                completion(error)
                return nil
            }

            return nil
        }
        
    }
}
