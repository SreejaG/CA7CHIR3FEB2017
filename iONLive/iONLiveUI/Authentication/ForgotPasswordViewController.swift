//
//  ForgotPasswordViewController.swift
//  iONLive
//
//  Created by Gadgeon on 11/30/15.
//  Copyright © 2015 Gadgeon. All rights reserved.
//

import UIKit

class ForgotPasswordViewController: UIViewController {
    
    static let identifier = "ForgotPasswordViewController"
    
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var resetPasswdBottomConstraint: NSLayoutConstraint!
    
    var loadingOverlay: UIView?
    
    let requestManager = RequestManager.sharedInstance
    let authenticationManager = AuthenticationManager.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initialise()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func initialise()
    {
        self.title = "RESET PASSWORD"
        let backItem = UIBarButtonItem(title: "", style: .Plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backItem
        
        self.emailTextfield.becomeFirstResponder()
        
        emailTextfield.attributedPlaceholder = NSAttributedString(string: "Email address",
            attributes:[NSForegroundColorAttributeName: UIColor.lightGrayColor(),NSFontAttributeName: UIFont.italicSystemFontOfSize(14.0)])
        emailTextfield.autocorrectionType = UITextAutocorrectionType.No
        addObserver()
    }
    
    func addObserver()
    {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidShow:", name:UIKeyboardWillShowNotification , object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "KeyboardDidHide:", name:UIKeyboardWillHideNotification , object: nil)
    }
    
    //PRAGMA MARK:- keyboard notification handler
    
    func keyboardDidShow(notification: NSNotification)
    {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        self.view.layoutIfNeeded()
        if resetPasswdBottomConstraint.constant == 0
        {
            UIView.animateWithDuration(1.0, animations: { () -> Void in
               self.resetPasswdBottomConstraint.constant += keyboardFrame.size.height
                 self.view.layoutIfNeeded()
            })
        }
    }
    
    func KeyboardDidHide(notification: NSNotification)
    {
        self.view.layoutIfNeeded()
        if resetPasswdBottomConstraint.constant != 0
        {
            UIView.animateWithDuration(1.0, animations: { () -> Void in
               self.resetPasswdBottomConstraint.constant = 0
            })
        }
    }
    
    // PRAGMA MARK:- textField delegates
    
    func textFieldShouldReturn(textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
    
    //PRAGMA MARK:- IBActions
    
    @IBAction func tapGestureRecognized(sender: AnyObject) {
        view.endEditing(true)
    }
    
    @IBAction func resetPasswdClicked(sender: AnyObject)
    {
        if emailTextfield.text!.isEmpty
        {
            ErrorManager.sharedInstance.noEmailEnteredError()
        }
        else
        {
            //check for valid email
            let isEmailValid = isEmail(emailTextfield.text!) as Bool!
            if isEmailValid == false
            {
                ErrorManager.sharedInstance.loginInvalidEmail()
                return
            }
            else
            {
                 ErrorManager.sharedInstance.alert("Reset Password", message:"Instructions to reset your password has been sent to your email Id")
            }
        }
    }
    
    
    //PRAGMA MARK:- Helper functions
    
    func isEmail(email:String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,4}$", options: .CaseInsensitive)
        return regex?.firstMatchInString(email, options: [], range: NSMakeRange(0, email.characters.count)) != nil
    }
}
