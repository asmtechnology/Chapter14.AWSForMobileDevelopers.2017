//
//  AddFriendViewController.swift
//  AWSChat
//
//  Created by Abhishek Mishra on 10/04/2017.
//  Copyright © 2017 ASM Technology Ltd. All rights reserved.
//

import UIKit

class AddFriendViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Add friend"

        // get list of available users who are not friends of this user
        let cognitoIdentityPoolController = CognitoIdentityPoolController.sharedInstance
        guard let curentIdentityID = cognitoIdentityPoolController.currentIdentityID else {
            print("Cognito Identity is missing.")
            return
        }
        
        let dynamoDBController = DynamoDBController.sharedInstance
        dynamoDBController.refreshPotentialFriendList(currentUserId: curentIdentityID) { (error) in
            
            if let error = error {
                self.displayError(error: error as NSError)
                return
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func displayError(error:NSError) {
        
        let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                message: error.userInfo["message"] as? String,
                                                preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
}


extension AddFriendViewController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let chatManager = ChatManager.sharedInstance
        
        if let potentialFriendList = chatManager.potentialFriendList {
            return potentialFriendList.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendTableViewCell", for: indexPath) as? FriendTableViewCell
        
        let chatManager = ChatManager.sharedInstance
        
        if let cell = cell,
            let potentialFriendList = chatManager.potentialFriendList {
            let user = potentialFriendList[indexPath.row]
            cell.nameLabel.text = user.username
            cell.emailAddressLabel.text = user.email_address
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let chatManager = ChatManager.sharedInstance
        
        guard let potentialFriendList = chatManager.potentialFriendList else {
            return
        }
        
        let cognitoIdentityPoolController = CognitoIdentityPoolController.sharedInstance
        guard let curentIdentityID = cognitoIdentityPoolController.currentIdentityID else {
            print("Cognito Identity is missing.")
            return
        }
        
        let potentialFriend = potentialFriendList[indexPath.row]
        
        let dynamoDBController = DynamoDBController.sharedInstance
        dynamoDBController.addFriend(currentUserId: curentIdentityID, friendUserId:potentialFriend.id!) { (error) in
            
            if let error = error {
                self.displayError(error: error as NSError)
                return
            }
            
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        }

    }
    
}

