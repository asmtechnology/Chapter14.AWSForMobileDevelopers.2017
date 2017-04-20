//
//  ChatViewController.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 13/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import UIKit

class ChatViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var uploadImageButton: UIButton!
    @IBOutlet weak var sendTextButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var from_userId:String?
    var to_userId:String?
    
    fileprivate var originalScrollViewYOffset: CGFloat = 0.0
    fileprivate var currentChat:Chat?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.stopAnimating()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        if (currentChat == nil) {
            prepareForChat(between: from_userId, and: to_userId)
        
        } else {
        
            disableUI()
            
            self.refreshMessages { () in
                self.messageTextField.isEnabled = true
                self.enableUI()
            }

        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func uploadImage(_ sender: Any) {
        self.performSegue(withIdentifier: "uploadImage", sender: nil)
    }
    

    @IBAction func sendText(_ sender: Any) {
        self.messageTextField.resignFirstResponder()
        
        guard let textToSend = self.messageTextField.text,
            let chat = self.currentChat else {
            return
        }
        
        if textToSend.characters.count == 0 {
            return
        }
        
        disableUI()
        
        let chatManager = ChatManager.sharedInstance
        chatManager.sendTextMessage(chat: chat, messageText: textToSend) { (error) in
            
            self.enableUI()

            if let error = error {
                self.displayError(error: error as NSError)
                return
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    @IBAction func didEndOnExit(_ sender: Any) {
        self.messageTextField.resignFirstResponder()
    }

    
    func refresh(_ refreshControl: UIRefreshControl) {
        
        self.messageTextField.isEnabled = false
        self.uploadImageButton.isEnabled = false
        self.sendTextButton.isEnabled = false
        
        self.refreshMessages { () in
            self.messageTextField.isEnabled = true
            self.uploadImageButton.isEnabled = true
            self.sendTextButton.isEnabled = true
            refreshControl.endRefreshing()
        }
        
    }
    
    private func refreshMessages(postRefreshActions:@escaping (Void)->Void) {

        let chatManager = ChatManager.sharedInstance
        chatManager.refreshAllMessages(chat: self.currentChat!, completion: { (error) in
            
            DispatchQueue.main.async {
                postRefreshActions()
            }
            
            if let error = error {
                self.displayError(error: error as NSError)
                return
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        })
    }
    
    private func prepareForChat(between sourceUserId:String?, and destinationUserId:String?) {
        self.activityIndicator.startAnimating()
        self.messageTextField.isEnabled = false
        self.uploadImageButton.isEnabled = false
        self.sendTextButton.isEnabled = false
        
        guard let fromUserId = sourceUserId ,
            let toUserId = destinationUserId else  {
                
                let error = NSError(domain: "com.asmtechnology.awschat",
                                    code: 100,
                                    userInfo: ["__type":"Error", "message":"Could not load chat."])
                displayError(error: error)
                return
        }
        
        let chatManager = ChatManager.sharedInstance
        chatManager.loadChat(fromUserId: fromUserId, toUserId: toUserId) { (error, chat) in
            if let error = error {
                self.displayError(error: error as NSError)
                return
            }
            
            // save reference to chat object
            self.currentChat = chat
            
            // refresh message list
            chatManager.refreshAllMessages(chat: chat!, completion: { (error) in
                if let error = error {
                    self.displayError(error: error as NSError)
                    return
                }
                
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.messageTextField.isEnabled = true
                    self.uploadImageButton.isEnabled = true
                    self.sendTextButton.isEnabled = true
                    self.tableView.reloadData()
                }
            })
        }
        
    }
    
    
    private func displayError(error:NSError) {
        
        let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                message: error.userInfo["message"] as? String,
                                                preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    private func disableUI() {
        DispatchQueue.main.async {
            self.messageTextField.isEnabled = false
            self.uploadImageButton.isEnabled = false
            self.sendTextButton.isEnabled = false
            self.activityIndicator.startAnimating()
            UIApplication.shared.beginIgnoringInteractionEvents()
        }
    }
    
    private func enableUI() {
        DispatchQueue.main.async {
            self.uploadImageButton.isEnabled = true
            self.sendTextButton.isEnabled = true
            self.activityIndicator.stopAnimating()
            UIApplication.shared.endIgnoringInteractionEvents()
        }
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier?.compare("uploadImage") != .orderedSame {
            return
        }
        
        if let destinationViewController = segue.destination as? UploadImageViewController {
            destinationViewController.currentChat = self.currentChat
        }
    }

}


extension ChatViewController : UITextFieldDelegate {
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.originalScrollViewYOffset = scrollView.contentOffset.y
        scrollView.setContentOffset(CGPoint(x: 0, y: 190), animated: true)
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        scrollView.setContentOffset(CGPoint(x: 0, y: self.originalScrollViewYOffset), animated: true)
    }
}

extension ChatViewController : UITableViewDataSource , UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let chatManager = ChatManager.sharedInstance
        
        if let chat = self.currentChat,
            let messages = chatManager.conversations?[chat] {
            return messages!.count
        }

        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let chatManager = ChatManager.sharedInstance
        guard let chat = self.currentChat,
            let messages = chatManager.conversations?[chat],
            let message = messages?[indexPath.row],
            let messageText = message.message_text,
            let messageImagePreview = message.mesage_image_preview,
            let senderId = message.sender_id else {
            return UITableViewCell()
        }

        let cognitoIdentityPoolController = CognitoIdentityPoolController.sharedInstance
        guard let currentUserID = cognitoIdentityPoolController.currentIdentityID else {
            return UITableViewCell()
        }
        
        if messageText.compare("NA") != .orderedSame {
            // text
            if senderId.compare(currentUserID) == .orderedSame {
                // sent by this user
                let cell = tableView.dequeueReusableCell(withIdentifier: "SentTextTableViewCell", for: indexPath) as? SentTextTableViewCell
                
                cell?.messageTextLabel.text = messageText
                return cell!
            } else {
                // sent by friend
                let cell = tableView.dequeueReusableCell(withIdentifier: "ReceivedTextTableViewCell", for: indexPath) as? ReceivedTextTableViewCell
                
                cell?.messageTextLabel.text = messageText
                return cell!
            }
        } else {
            // image
            if senderId.compare(currentUserID) == .orderedSame {
                // sent by this user
                let cell = tableView.dequeueReusableCell(withIdentifier: "SentImageTableViewCell", for: indexPath) as? SentImageTableViewCell
                
                // replace this with code to show preview image
                cell?.messageImageView.image = UIImage(named: "placeholder")
                return cell!
                
            } else {
                // sent by friend
                let cell = tableView.dequeueReusableCell(withIdentifier: "ReceivedImageTableViewCell", for: indexPath) as? ReceivedImageTableViewCell
                
                // replace this with code to show preview image
                cell?.messageImageView.image = UIImage(named: "placeholder")
                return cell!
            }
        }

    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }

}
