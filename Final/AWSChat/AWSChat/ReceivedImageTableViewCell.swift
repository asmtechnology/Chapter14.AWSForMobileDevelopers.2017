//
//  ReceivedImageTableViewCell.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 14/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import UIKit

class ReceivedImageTableViewCell: UITableViewCell {

    @IBOutlet weak var messageImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func loadImage(imageFile:String) {
        
        // image exists locally. use local copy.
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let localFilePath = documentsDirectory.appending("/\(imageFile).png")
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: localFilePath) {
            self.messageImageView.image = UIImage(contentsOfFile: localFilePath)
            return
        }
        
        // image does not exist locally,
        // download from S3 and save to documents directory.
        self.messageImageView.image = UIImage(named: "placeholder")
        
        let s3Controller = S3Controller.sharedInstance
        s3Controller.downloadThumbnail(localFilePath: localFilePath, remoteFileName: imageFile) { (error) in
            if error != nil {
                return
            }
            
            DispatchQueue.main.async {
                self.messageImageView.image = UIImage(contentsOfFile: localFilePath)
                self.setNeedsLayout()
            }
        }
    }
    
}
