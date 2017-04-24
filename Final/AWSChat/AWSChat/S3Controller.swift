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
    
    
    func downloadThumbnail(localFilePath:String, remoteFileName:String,
                     completion:@escaping (Error?)->Void) {
        
        let s3Key = "\(remoteFileName).png"
        let fileURL = URL(fileURLWithPath: localFilePath)
        
        let expression = AWSS3TransferUtilityDownloadExpression()
        expression.progressBlock = {(task: AWSS3TransferUtilityTask, progress: Progress) in
            print("Downloaded: \(progress.fractionCompleted)%")
        }
        
        let transferUtility = AWSS3TransferUtility.default()
        let task = transferUtility.download(to: fileURL,
                                            bucket: thumbnailsBucketName,
                                            key: s3Key,
                                            expression: expression) {(task, url, data, error) in
                                                
            let fileManager = FileManager.default
                                                
            if error != nil {
                
                if fileManager.fileExists(atPath: localFilePath) == true {
                    try? fileManager.removeItem(atPath: localFilePath)
                }
                
                completion(error)
                return
            }
                                                
           
            if fileManager.fileExists(atPath: localFilePath) == false {
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 600,
                                    userInfo: nil)
                completion(error)
                return
            }
            
            let data = NSData(contentsOf: fileURL)
            if data?.length == 0 {
                
                try? fileManager.removeItem(atPath: localFilePath)
                
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 600,
                                    userInfo: nil)
                completion(error)
                return
            }
                                                
            completion(nil)
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
