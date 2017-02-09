
import UIKit

class EditProfileViewController: UIViewController, UINavigationControllerDelegate,UIImagePickerControllerDelegate,URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate,UITextFieldDelegate, UIScrollViewDelegate {
    
    static let identifier = "EditProfileViewController"
    @IBOutlet weak var editProfileTableView: UITableView!
    
    var fullNames : String = String()
    var userName : String = String()
    var emails : String = String()
    var mobileNo : String = String()
    var timeZoneInSecondsFromAPI : String = String()
    var timeZoneInSecondsUpdated : String = String()
    var timeZoneOffsetInUTCOriginal = String()
    var timeZoneOffsetInUTCUpdated : String = String()
    var isKeyBoardUp : Bool = false
    
    var email: String = String()
    var mobNo: String = String()
    var fullName: String = String()
    var ZoneInSeconds : String = String()
    
    let requestManager = RequestManager.sharedInstance
    let profileManager = ProfileManager.sharedInstance
    let imageUploadManger = ImageUpload.sharedInstance
    
    var activeField: UITextField = UITextField()
    
    var loadingOverlay: UIView?
    let imagePicker = UIImagePickerController()
    var imageForProfile : UIImage = UIImage()
    var imageForProfileOld : UIImage = UIImage()
    
    var fullImageURL : String = String()
    var thumbURL : String = String()
    
    var cellSection = Int()
    
    var photoTakenFlag : Bool = false
    
    @IBOutlet weak var tableViewBottomConstaint: NSLayoutConstraint!
    
    @IBOutlet weak var saveButton: UIButton!
    
    let userNameKey = "userNameKey"
    let displayNameKey = "displayNameKey"
    let titleKey = "titleKey"
    let privateInfoKey = "privateInfo"
    
    let personalInfoCell = "personalInfoCell"
    let accountInfoCell = "accountInfoCell"
    let privateInfoCell = "privateInfoCell"
    let countryPickerCell = "countryPickerCell"
    
    var profileInfoOptions = [[String:String]]()
    var privateInfoOptions = [[String:String]]()
    var accountInfoOptions = [[String:String]]()
    var button : UIButton = UIButton()
    var dataSource:[[[String:String]]]?
    
    var userDetails: NSMutableDictionary = NSMutableDictionary()
    
    let defaults = UserDefaults.standard
    var userId : String = String()
    var accessToken: String = String()
    
    @IBOutlet weak var editProfTableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        initialise()
        self.editProfTableView.delegate = self
        self.editProfTableView.dataSource = self
        
        let tapTableView: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(EditProfileViewController.tableViewTap(recognizer:)))
        editProfTableView.addGestureRecognizer(tapTableView)
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func tapGestureRecognizer(_ sender: Any) {
        view.endEditing(true)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        view.endEditing(true)
    }
    
    func tableViewTap(recognizer: UITapGestureRecognizer)
    {
        if recognizer.state == UIGestureRecognizerState.ended {
            let swipeLocation = recognizer.location(in: self.editProfTableView)
            if let swipedIndexPath = editProfTableView.indexPathForRow(at: swipeLocation) {
                if swipedIndexPath.section == 1 && swipedIndexPath.row == 2
                {
                    let sharingStoryboard = UIStoryboard(name:"EditProfile", bundle: nil)
                    let channelItemListVC = sharingStoryboard.instantiateViewController(withIdentifier: "ResetPasswordViewController") as! ResetPasswordViewController
                    channelItemListVC.navigationController?.isNavigationBarHidden = true
                    self.present(channelItemListVC, animated: false) { () -> Void in
                    }
                }
                else if (swipedIndexPath.section == 1 && swipedIndexPath.row == 3)
                {
                    synchronisingTapped()
                }
                else{
                    view.endEditing(true)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.editProfTableView.backgroundView = nil
        self.editProfTableView.backgroundColor = UIColor(red: 249.0/255, green: 249.0/255, blue: 249.0/255, alpha: 1)
        addKeyboardObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
    }
    
    func initialise()
    {
        photoTakenFlag = false
        saveButton.isHidden = true
        imageForProfile = UIImage()
        getUserDetails()
    }
    
    func getUserDetails()
    {
        showOverlay()
        profileManager.getUserDetails(userName: userId, accessToken:accessToken, success: { (response) -> () in
            self.authenticationSuccessHandler(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func nullToNil(value : Any?) -> Any? {
        if value is NSNull {
            return ""
        } else {
            return value
        }
    }
    
    func authenticationSuccessHandler(response:AnyObject?)
    {
        removeOverlay()
        if let json = response as? [String: Any]
        {
            var userDict: [String: Any] = [String: Any]()
            userDict = json["user"] as!  [String: Any]
            for (key,value) in userDict
            {
                let valueAfterNullCheck =  nullToNil(value: value)
                userDetails.setValue(valueAfterNullCheck!, forKey: key)
            }
            setUserDetails()
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        self.removeOverlay()
        
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                loadInitialViewController(code: code)
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
                if((dataSource?.count)! > 0)
                {
                    dataSource![0][0][displayNameKey] = fullNames
                    dataSource![2][0][privateInfoKey] = emails
                    dataSource![2][1][privateInfoKey] = mobileNo
                    dataSource![1][3][titleKey] = timeZoneOffsetInUTCOriginal
                }
                editProfTableView.reloadData()
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
            if((dataSource?.count)! > 0)
            {
                dataSource![0][0][displayNameKey] = fullNames
                dataSource![2][0][privateInfoKey] = emails
                dataSource![2][1][privateInfoKey] = mobileNo
                dataSource![1][3][titleKey] = timeZoneOffsetInUTCOriginal
            }
            editProfTableView.reloadData()
        }
    }
    
    func  loadInitialViewController(code: String){
        if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
        {
            if tokenValid as! String == "true"
            {
                DispatchQueue.main.async {
                    let documentsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0] + "/GCSCA7CH"
                    
                    if(FileManager.default.fileExists(atPath: documentsPath))
                    {
                        let fileManager = FileManager.default
                        do {
                            try fileManager.removeItem(atPath: documentsPath)
                        }
                        catch _ as NSError {
                        }
                        _ = FileManagerViewController.sharedInstance.createParentDirectory()
                    }
                    else{
                        _ = FileManagerViewController.sharedInstance.createParentDirectory()
                    }
                    
                    let defaults = UserDefaults .standard
                    let deviceToken = defaults.value(forKey: "deviceToken") as! String
                    defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                    defaults.setValue(deviceToken, forKey: "deviceToken")
                    defaults.set(1, forKey: "shutterActionMode");
                    defaults.setValue("false", forKey: "tokenValid")
                    
                    ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
                    
                    let sharingStoryboard = UIStoryboard(name:"Authentication", bundle: nil)
                    let channelItemListVC = sharingStoryboard.instantiateViewController(withIdentifier: "AuthenticateViewController") as! AuthenticateViewController
                    channelItemListVC.navigationController?.isNavigationBarHidden = true
                    self.navigationController?.pushViewController(channelItemListVC, animated: false)
                }
            }
        }
    }
    
    func setUserDetails()
    {
        fullNames = userDetails["full_name"] as! String
        userName = userDetails["user_name"] as! String
        emails = userDetails["email"] as! String
        mobileNo = userDetails["mobile_no"] as! String
        timeZoneInSecondsFromAPI = userDetails["user_time_zone"] as! String
        
        let hoursFromOffset = Int(timeZoneInSecondsFromAPI)! / 3600
        let minutesFromOffset = (Int(timeZoneInSecondsFromAPI)! % 3600) / 60
        var addOrMinusChk = String()
        if timeZoneInSecondsFromAPI.hasPrefix("-"){
            addOrMinusChk = ""
        }
        else{
            addOrMinusChk = "+"
        }
        
        timeZoneOffsetInUTCOriginal = "UTC\(addOrMinusChk)\(hoursFromOffset):\(minutesFromOffset)"
        
        let actualImage = userDetails["actual_image"] as! String
        if actualImage != ""
        {
            let savingPath = "\(userName)Profile"
            
            let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
            let profileImagePath = parentPath! + "/" + savingPath
            let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: profileImagePath)
            
            if fileExistFlag == true{
                let profileImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: profileImagePath)
                imageForProfile = profileImageFromFile!
            }
            else{
                let thumbUrl = UrlManager.sharedInstance.getUserProfileImageBaseURL() + userId + "/" + accessToken + "/" + userId
                imageForProfile = FileManagerViewController.sharedInstance.getProfileImage(profileNameURL: thumbUrl)
                let profileImageData = UIImageJPEGRepresentation(imageForProfile, 0.5)
                let profileImageDataAsNsdata = (profileImageData as NSData?)!
                let imageFromDefault = UIImageJPEGRepresentation(UIImage(named: "dummyUser")!, 0.5)
                let imageFromDefaultAsNsdata = (imageFromDefault as NSData?)!
                if(profileImageDataAsNsdata.isEqual(imageFromDefaultAsNsdata)){
                }
                else{
                    _ = FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: savingPath, mediaImage: imageForProfile)
                }
            }
        }
        else{
            imageForProfile = UIImage(named: "dummyUser")!
        }
        
        imageForProfileOld = imageForProfile
        
        profileInfoOptions = [[displayNameKey:fullNames, userNameKey:userName]]
        accountInfoOptions = [[titleKey:"Upgrade to Premium Account"], [titleKey:"Status"], [titleKey:"Reset Password"], [titleKey:timeZoneOffsetInUTCOriginal]]
        privateInfoOptions = [[privateInfoKey:emails],/*[titleKey:location],*/[privateInfoKey:mobileNo]]
        
        dataSource = [profileInfoOptions,accountInfoOptions,privateInfoOptions]
        editProfTableView.reloadData()
    }
    
    func ltzAbbrev() -> String
    {
        let zoneName = NSTimeZone.local.identifier
        let timeValue = NSTimeZone.local.localizedName(for: .shortStandard, locale: NSLocale.init(localeIdentifier: zoneName) as Locale)
        return timeValue!
    }
    
    func showOverlay(){
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = CGRect(x:0, y:64, width:self.view.frame.width, height:self.view.frame.height - 64)
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.view .addSubview(self.loadingOverlay!)
    }
    
    func removeOverlay(){
        self.loadingOverlay?.removeFromSuperview()
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    @IBAction func saveClicked(_ sender: Any) {
        view.endEditing(true)
        if(((dataSource![0][0][displayNameKey]?.characters.count)! < 5) || ((dataSource![0][0][displayNameKey]?.characters.count)! > 15))
        {
            ErrorManager.sharedInstance.InvalidUsernameEnteredError()
        }
        else
        {
            saveButton.isHidden = true
            if(photoTakenFlag == false){
                updateProfileDetails()
            }
            else{
                showOverlay()
                getSignedUrl()
            }
        }
    }
    
    func generateWaytoSendAlert()
    {
        let alert = UIAlertController(title: "Not Saved", message: "Do you want to save the details", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            self.saveButton.isHidden = true
            if(self.photoTakenFlag == true){
                self.showOverlay()
                self.getSignedUrl()
            }
            else{
                self.updateProfileDetails()
            }
            
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler: {
            (action) -> Void in
            self.redirect()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func redirect() {
        _ = self.navigationController?.popViewController(animated: false)
    }
    
    @IBAction func backClicked(_ sender: Any) {
        if(saveButton.isHidden == false){
            generateWaytoSendAlert()
        }
        else{
            _ = self.navigationController?.popViewController(animated: false)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func getSignedUrl()  {
        let defaults = UserDefaults.standard
        let userId = defaults.value(forKey: userLoginIdKey) as! String
        let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        profileManager.getUploadProfileImageURL(userName: userId, accessToken: accessToken, success: { (response) in
            self.authenticationSuccessHandlerSignedUrl(response: response)
        }) { (error, message) in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func authenticationSuccessHandlerSignedUrl(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            if let fullUrl = json["UploadActualImageUrl"]{
                fullImageURL = fullUrl as! String
            }
            if let thumbUrl = json["UploadThumbnailUrl"]{
                thumbURL = thumbUrl as! String
            }
            
            let cameraController = IPhoneCameraViewController()
            let sizeThumb = CGSize(width:70, height:70)
            let imageAfterConversionThumbnail = cameraController.thumbnaleImage(self.imageForProfile, scaledToFill: sizeThumb)
            let imageData = UIImageJPEGRepresentation(imageAfterConversionThumbnail!, 0.5)
            let imagethumbDetailsData = (imageData as NSData?)!
            let thumbImageForProfile = UIImage(data:imagethumbDetailsData as Data)
            
            uploadImage(signedUrl: fullImageURL, imageToSave: imageForProfile, completion: { (result) in
                self.uploadImage(signedUrl: self.thumbURL, imageToSave: thumbImageForProfile!, completion: { (result) in
                    if(result == "Success"){
                        self.removeOverlay()
                        self.imageForProfileOld = self.imageForProfile
                        let alert = UIAlertController(title: "Success", message: "Profile updated successfully", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { (action) -> Void in
                            _ = self.navigationController?.popViewController(animated: false)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                    else{
                        self.removeOverlay()
                        self.imageForProfile = self.imageForProfileOld
                    }
                })
            })
            self.updateProfileDetails()
        }
    }
    
    func  updateProfileDetails() {
        view.endEditing(true)
        editProfTableView.reloadData()
        editProfTableView.layoutIfNeeded()
        let defaults = UserDefaults.standard
        let userId = defaults.value(forKey: userLoginIdKey) as! String
        let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        
        for i in 0 ..< dataSource!.count
        {
            if(i < dataSource!.count){
                var j = 0
                if i == 0
                {
                    for  element in  dataSource![i]
                    {
                        fullName = element[displayNameKey]!
                    }
                }
                else if( i == 2){
                    for  element in  dataSource![i]
                    {
                        if j == 0
                        {
                            email = element[privateInfoKey]!
                        }
                        else{
                            mobNo = element[privateInfoKey]!
                        }
                        j = j + 1
                    }
                }
            }
        }
        var timeUpdate = String()
        if timeZoneInSecondsUpdated == ""
        {
            timeUpdate = timeZoneInSecondsFromAPI
        }
        else{
            timeUpdate = timeZoneInSecondsUpdated
        }
        let phoneNumberStringArray = (mobNo as NSString).components(
            separatedBy: CharacterSet.decimalDigits.inverted)
        
        let phoneNumber = ("+" as NSString).appending(NSArray(array: phoneNumberStringArray).componentsJoined(by: "")) as String
        profileManager.updateUserDetails(userName: userId, accessToken: accessToken, email: email, location: "", mobNo: phoneNumber, fullName: fullName, timeZone: timeUpdate, success: { (response) in
            let savingPath = "\(userId)Profile"
            _ =
                FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: savingPath, mediaImage: self.imageForProfile)
            self.fullNames = self.fullName
            self.mobileNo = self.mobNo
            self.emails = self.email
            if(self.timeZoneOffsetInUTCUpdated != ""){
                self.timeZoneOffsetInUTCOriginal = self.timeZoneOffsetInUTCUpdated
            }
            if(self.timeZoneInSecondsUpdated != ""){
                self.timeZoneInSecondsFromAPI = self.timeZoneInSecondsUpdated
            }
            if(self.photoTakenFlag == false){
                let alert = UIAlertController(title: "Success", message: "Profile updated successfully", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { (action) -> Void in
                    _ = self.navigationController?.popViewController(animated: false)
                }))
                self.present(alert, animated: true, completion: nil)
            }
            self.photoTakenFlag = false
            
        }) { (error, message) in
            self.photoTakenFlag = false
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func  uploadImage(signedUrl: String, imageToSave: UIImage, completion: @escaping (_ result: String) -> Void)
    {
        let url = NSURL(string: signedUrl)
        let request = NSMutableURLRequest(url: url! as URL)
        request.httpMethod = "PUT"
        let session = URLSession(configuration:URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        var imageData: NSData = NSData()
        imageData = UIImageJPEGRepresentation(imageToSave, 0.5)! as NSData
        request.httpBody = imageData as Data
        let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            if error != nil {
                completion("Failed")
            }
            else {
                completion("Success")
            }
        }
        dataTask.resume()
    }
    
    func addKeyboardObservers()
    {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(EditProfileViewController.keyBoardWasShown(notif:)),
                                               name: NSNotification.Name.UIKeyboardDidShow,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(EditProfileViewController.keyboardDidHide),
                                               name: NSNotification.Name.UIKeyboardDidHide,
                                               object: nil)
    }
    
    func keyboardDidShow(notification:NSNotification)
    {
        isKeyBoardUp = true
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if tableViewBottomConstaint.constant == 0
        {
            self.tableViewBottomConstaint.constant = self.tableViewBottomConstaint.constant + keyboardFrame.size.height
        }
    }
    
    func keyboardDidHide()
    {
        if tableViewBottomConstaint.constant != 0
        {
            self.tableViewBottomConstaint.constant = 0
        }
        isKeyBoardUp = false
    }
}

extension EditProfileViewController: UITableViewDelegate, UITableViewDataSource
{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        if section == 0
        {
            return 30.0
        }
        else if section == 3
        {
            return 60.0
        }
        else
        {
            return 55.0
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        
    }
    
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let  headerCell = tableView.dequeueReusableCell(withIdentifier: EditProfileHeaderCell.identifier) as! EditProfileHeaderCell
        
        headerCell.borderLine.isHidden = false
        headerCell.topBorderLine.isHidden = false
        
        switch (section) {
        case 0:
            headerCell.headerTitleLabel.text = ""
            headerCell.topBorderLine.isHidden = true
        case 1:
            headerCell.headerTitleLabel.text = "ACCOUNT INFO"
        case 2:
            headerCell.headerTitleLabel.text = "PRIVATE INFO"
        case 3:
            let privacyPolicyDesc = NSMutableAttributedString(string: "All your Media is Private unless Channels are shared to specific people. Archive is always private to you.")
            let privacyPolicyString = NSMutableAttributedString(string:"\nPrivacy Policy")
            privacyPolicyString.addAttribute(NSForegroundColorAttributeName, value: UIColor(red: 44.0/255, green: 214.0/255, blue: 229.0/255, alpha: 1.0), range: NSMakeRange(0, privacyPolicyString.length))
            privacyPolicyDesc.append(privacyPolicyString)
            
            headerCell.headerTitleLabel.attributedText = privacyPolicyDesc
            headerCell.borderLine.isHidden = true
            
        default:
            headerCell.headerTitleLabel.text = ""
        }
        return headerCell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        if indexPath.section == 0
        {
            return 90.0
        }
        else
        {
            return 44.0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch section
        {
        case 0:
            return dataSource != nil ? (dataSource?[0].count)! :0
            
        case 1:
            return dataSource != nil ? (dataSource?[1].count)! :0
            
        case 2:
            return dataSource != nil ? (dataSource?[2].count)! :0
            
        case 3:
            return 0
            
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if let dataSource = dataSource
        {
            if dataSource.count > indexPath.section && dataSource[indexPath.section].count > indexPath.row
            {
                var cellDataSource = dataSource[indexPath.section][indexPath.row]
                switch indexPath.section
                {
                case 0:
                    let cell = tableView.dequeueReusableCell(withIdentifier: EditProfPersonalInfoCell.identifier, for:indexPath) as! EditProfPersonalInfoCell
                    cell.editProfileImageButton.addTarget(self, action: #selector(EditProfileViewController.editProfileTapped(sender:)), for: UIControlEvents.touchUpInside)
                    
                    if cellDataSource[displayNameKey] == ""
                    {
                        cell.displayNameTextField.attributedPlaceholder = NSAttributedString(string: "Name", attributes:[NSForegroundColorAttributeName: UIColor.lightGray,NSFontAttributeName: UIFont.italicSystemFont(ofSize: 14.0)])
                    }
                    let cameraController = IPhoneCameraViewController()
                    let sizeThumb = CGSize(width:70, height:70)
                    let imageAfterConversionThumbnail = cameraController.thumbnaleImage(self.imageForProfileOld, scaledToFill: sizeThumb)
                    imageForProfileOld = imageAfterConversionThumbnail!
                    cell.userImage.image = imageForProfile
                    
                    cell.userNameTextField.text = cellDataSource[userNameKey]
                    cell.userNameTextField.isUserInteractionEnabled = false
                    
                    cell.displayNameTextField.text = cellDataSource[displayNameKey]
                    
                    cell.displayNameTextField.tag = indexPath.section
                    cell.displayNameTextField.delegate = self
                    
                    cell.selectionStyle = .none
                    return cell
                case 1:
                    let cell = tableView.dequeueReusableCell(withIdentifier: EditProfAccountInfoCell.identifier, for:indexPath) as! EditProfAccountInfoCell
                    cell.accountInfoTitleLabel.text = cellDataSource[titleKey]
                    if dataSource[indexPath.section].count-1 == indexPath.row
                    {
                        cell.borderLine.isHidden = true
                        cell.selectionStyle = .default
                    }
                    else
                    {
                        cell.borderLine.isHidden = false
                        cell.selectionStyle = .default
                    }
                    
                    if indexPath.row == 3
                    {
                        button.removeFromSuperview()
                        cell.accessoryType = .none
                        cell.selectionStyle = .none
                        let image = UIImage(named: "synchronising.png")
                        button = UIButton(type: UIButtonType.custom) as UIButton
                        button.frame = CGRect(x:(cell.frame.width - 35), y:(cell.frame.height/2 - 10), width:25, height:25)
                        button.backgroundColor = UIColor.clear
                        button.setImage(image, for: .normal)
                        cell.addSubview(button)
                    }
                    else
                    {
                        cell.selectionStyle = .none
                        cell.isUserInteractionEnabled = false
                        
                    }
                    return cell
                case 2:
                    let cell = tableView.dequeueReusableCell(withIdentifier: EditProfPrivateInfoCell.identifier, for:indexPath) as! EditProfPrivateInfoCell
                    cell.privateInfoTitleLabel.tag = 100 + indexPath.row
                    if(indexPath.row == 1){
                        cell.privateInfoTitleLabel.keyboardType = .phonePad
                    }
                    else{
                        cell.privateInfoTitleLabel.keyboardType = .default
                    }
                    cell.privateInfoTitleLabel.delegate = self
                    cellSection = indexPath.row
                    
                    cell.privateInfoTitleLabel.text = cellDataSource[privateInfoKey]
                    
                    if dataSource[indexPath.section].count-1 == indexPath.row
                    {
                        cell.borderLine.isHidden = true
                    }
                    else
                    {
                        cell.borderLine.isHidden = false
                    }
                    cell.selectionStyle = .none
                    return cell
                    
                default:
                    return UITableViewCell()
                }
            }
        }
        return UITableViewCell()
    }
    
    
    func synchronisingTapped()
    {
        self.button.rotate360Degrees(duration: 1.0)
        _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(EditProfileViewController.timerStop), userInfo: nil, repeats: false)
    }
    
    func timerStop()
    {
        let timeOffset = NSTimeZone.system.secondsFromGMT()
        let timeOffsetStr = String(describing: timeOffset)
        if timeOffsetStr.hasPrefix("-")
        {
            self.timeZoneInSecondsUpdated = timeOffsetStr
        }
        else
        {
            self.timeZoneInSecondsUpdated = "+\(timeOffsetStr)"
        }
        
        if self.timeZoneInSecondsUpdated != self.timeZoneInSecondsFromAPI
        {
            let timeZoneOffsetInGMT : String = self.ltzAbbrev()
            let timeZoneOffsetStr = (timeZoneOffsetInGMT as NSString).replacingOccurrences(of: "GMT", with: "UTC")
            self.dataSource![1][3][self.titleKey] = timeZoneOffsetStr
            self.saveButton.isHidden = false
        }
        let indexPath = IndexPath(row: 3, section: 1)
        self.editProfTableView.reloadRows(at: [indexPath], with: .none)
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeField = textField
        saveButton.isHidden = false
    }
    
    func keyBoardWasShown(notif:NSNotification)
    {
        if(activeField.tag == 100)
        {
            var info: NSDictionary = NSDictionary()
            info = notif .userInfo! as NSDictionary
            let kbSize : CGSize = (info.object(forKey: UIKeyboardFrameBeginUserInfoKey)! as AnyObject).cgRectValue.size
            var bkgndRect:CGRect = (activeField.superview?.frame)!
            bkgndRect.size.height += kbSize.height
            activeField.superview?.frame = bkgndRect
            editProfTableView.setContentOffset(CGPoint(x:0, y:(activeField.frame.origin.y + kbSize.height - 70)), animated: true)
        }
        else if(activeField.tag == 101)
        {
            var info: NSDictionary = NSDictionary()
            info = notif .userInfo! as NSDictionary
            let kbSize : CGSize = (info.object(forKey: UIKeyboardFrameBeginUserInfoKey)! as AnyObject).cgRectValue.size
            var bkgndRect:CGRect = (activeField.superview?.frame)!
            bkgndRect.size.height += kbSize.height
            activeField.superview?.frame = bkgndRect
            editProfTableView.setContentOffset(CGPoint(x:0, y:(activeField.frame.origin.y + kbSize.height - 20)), animated: true)
        }
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        activeField = UITextField()
        
        if(textField.tag == 0)
        {
            if((textField.text?.isEmpty) == nil){
                
                dataSource![textField.tag][0][displayNameKey] = ""
            }
            else{
                dataSource![textField.tag][0][displayNameKey] = textField.text
            }
            textField.attributedPlaceholder = NSAttributedString(string: "Name",
                                                                 attributes:[NSForegroundColorAttributeName: UIColor.lightGray,NSFontAttributeName: UIFont.italicSystemFont(ofSize: 14.0)])
        }
        else if(textField.tag == 100){
            let isEmailValid = isEmail(email: textField.text!) as Bool!
            if isEmailValid == false
            {
                ErrorManager.sharedInstance.loginInvalidEmail()
                return
            }
            else
            {
                dataSource![2][0][privateInfoKey] = textField.text
            }
            
        }
        else if(textField.tag == 101){
            let textStr = textField.text
            if(textStr!.hasPrefix("+")){
                dataSource![2][1][privateInfoKey] = textField.text
            }
            else{
                ErrorManager.sharedInstance.withouCodeMobNumber()
                return
            }
        }
    }
    
    func isEmail(email:String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,4}$", options: .caseInsensitive)
        return regex?.firstMatch(in: email, options: [], range: NSMakeRange(0, email.characters.count)) != nil
    }
    
    func editProfileTapped(sender:UIButton!)
    {
        self.imagePicker.delegate = self
        let myActionSheet = UIAlertController(title: "", message: "How would you like to set your photo?", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let takeAction = UIAlertAction(title: "Take a photo", style: UIAlertActionStyle.default) { (action) in
            if (UIImagePickerController.isSourceTypeAvailable(.camera)) {
                if UIImagePickerController.availableCaptureModes(for: .rear) != nil {
                    self.imagePicker.allowsEditing = false
                    self.imagePicker.sourceType = .camera
                    self.imagePicker.cameraCaptureMode = .photo
                    self.present(self.imagePicker, animated: true, completion: {
                        
                    })
                    
                } else {
                }
            } else {
            }
        }
        
        let chooseAction = UIAlertAction(title: "Choose a photo", style: UIAlertActionStyle.default) { (action) in
            
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .savedPhotosAlbum
            self.present(self.imagePicker, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (action) in
        }
        
        myActionSheet.addAction(takeAction)
        myActionSheet.addAction(chooseAction)
        myActionSheet.addAction(cancelAction)
        
        self.present(myActionSheet, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageForProfile = pickedImage
        }
        self.dismiss(animated: true, completion: { () -> Void in
            
        })
        
        photoTakenFlag = true
        saveButton.isHidden = false
        editProfTableView.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int
    {
        if let dataSource = dataSource
        {
            return dataSource.count + 1
        }
        else
        {
            return 0
        }
    }
}

extension UIView: CAAnimationDelegate {
    func rotate360Degrees(duration: CFTimeInterval , completionDelegate: Any? = nil) {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(M_PI * 2.0)
        rotateAnimation.duration = duration
        if let _: Any = completionDelegate {
            rotateAnimation.delegate = self
        }
        self.layer.add(rotateAnimation, forKey: nil)
    }
}
