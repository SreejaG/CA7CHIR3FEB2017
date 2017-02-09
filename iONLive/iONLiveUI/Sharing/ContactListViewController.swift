
import AddressBook
import AddressBookUI
import UIKit

class ContactListViewController: UIViewController
{
    private var addressBookRef: ABAddressBook?
    
    func setAddressBook(addressBook: ABAddressBook) {
        addressBookRef = addressBook
    }
    
    static let identifier = "ContactListViewController"
    
    var channelId:String!
    var totalMediaCount: Int = Int()
    var channelName:String!
    
    var loadingOverlay: UIView?
    
    var contactPhoneNumbers: [String] = [String]()
    
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    let contactManagers = contactManager.sharedInstance
    
    var dataSource:[[String:Any]] = [[String:Any]]()
    var dummySource:[[String:Any]] = [[String:Any]]()
    var searchDataSource:[[String:Any]] = [[String:Any]]()
    
    let defaults = UserDefaults.standard
    var userId = String()
    var accessToken = String()
    
    let userNameKey = "userName"
    let profileImageKey = "profileImage"
    let subscribedKey = "sharedindicator"
    let selectionKey = "selected"
    let profileImageUrlKey = "profile_image_URL"
    
    var searchActive: Bool = false
    
    var addUserArray : NSMutableArray = NSMutableArray()
    
    @IBOutlet var contactListSearchBar: UISearchBar!
    @IBOutlet var contactListTableView: UITableView!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint!
    
    var NoDatalabelFormySharingImageList : UILabel = UILabel()
    
    //Pull to refresh
    var refreshControl:UIRefreshControl!
    var pullToRefreshActive = false
    
    var operationQueueObjInSharingContactList = OperationQueue()
    var operationInSharingContactList = BlockOperation()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        
        addKeyboardObservers()
        
        let refreshContactList = Notification.Name("refreshContactListTableView")
        NotificationCenter.default.addObserver(self, selector:#selector(ContactListViewController.callRefreshContactListTableView(notif:)), name: refreshContactList, object: nil)
        
        contactAuthorizationAlert()
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: #selector(ContactListViewController.pullToRefresh), for: .valueChanged)
        self.contactListTableView.addSubview(self.refreshControl)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        operationInSharingContactList.cancel()
        searchDataSource.removeAll()
        dataSource.removeAll()
        addUserArray.removeAllObjects()
        NotificationCenter.default.removeObserver(self, name: Notification.Name("refreshContactListTableView"), object: nil)
    }
    
    func addKeyboardObservers()
    {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(ContactListViewController.keyboardDidShow(notification:)),
                                               name: NSNotification.Name.UIKeyboardDidShow,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(ContactListViewController.keyboardDidHide),
                                               name: NSNotification.Name.UIKeyboardDidHide,
                                               object: nil)
    }
    
    func keyboardDidShow(notification:NSNotification)
    {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if tableViewBottomConstraint.constant == 0
        {
            self.tableViewBottomConstraint.constant = self.tableViewBottomConstraint.constant + keyboardFrame.size.height
        }
    }
    
    func keyboardDidHide()
    {
        if tableViewBottomConstraint.constant != 0
        {
            self.tableViewBottomConstraint.constant = 0
        }
    }
    
    func pullToRefresh()
    {
        if(!pullToRefreshActive){
            pullToRefreshActive = true
            operationInSharingContactList.cancel()
            self.contactListSearchBar.text = ""
            self.contactListSearchBar.resignFirstResponder()
            searchActive = false
            self.getPullToRefreshData()
        }
        else
        {
        }
    }
    
    func getPullToRefreshData()
    {
        initialise()
    }
    
    @IBAction func didTapBackButton(_ sender: Any) {
        if(doneButton.isHidden == false){
            doneButton.isHidden = true
            if(searchActive){
                for i in 0 ..< searchDataSource.count
                {
                    if i < searchDataSource.count
                    {
                        let selectionValue : Int = searchDataSource[i][sharedOriginalKey] as! Int
                        searchDataSource[i][sharedTemporaryKey] = selectionValue
                    }
                }
                for i in 0 ..< dataSource.count
                {
                    if i < dataSource.count
                    {
                        dataSource[i][sharedTemporaryKey] = 0
                    }
                }
            }
            else{
                for i in 0 ..< dataSource.count
                {
                    if i < dataSource.count
                    {
                        let selectionValue : Int = dataSource[i][sharedOriginalKey] as! Int
                        dataSource[i][sharedTemporaryKey] = selectionValue
                    }
                }
            }
            contactListTableView.reloadData()
        }
        else{
            _ = self.navigationController?.popViewController(animated: false)
        }
    }
    
    @IBAction func gestureTapped(_ sender: Any) {
        view.endEditing(true)
        self.contactListSearchBar.text = ""
        self.contactListSearchBar.resignFirstResponder()
        searchActive = false
        self.contactListTableView.reloadData()
    }
    
    @IBAction func didTapDoneButton(_ sender: Any) {
        doneButton.isHidden = true
        contactListTableView.reloadData()
        contactListTableView.layoutIfNeeded()
        addUserArray.removeAllObjects()
        
        for i in 0 ..< dataSource.count
        {
            if i < dataSource.count
            {
                let userId = dataSource[i][userNameKey] as! String
                let selectionValue : Int = dataSource[i][sharedTemporaryKey] as! Int
                if(selectionValue == 1){
                    addUserArray.add(userId)
                }
            }
        }
        
        if addUserArray.count > 0
        {
            inviteContactList(userName: userId, accessToken: accessToken, channelid: channelId, addUser: addUserArray)
        }
    }
    
    func inviteContactList(userName: String, accessToken: String, channelid: String, addUser: NSMutableArray){
        showOverlay()
        channelManager.AddContactToChannel(userName: userName, accessToken: accessToken, channelId: channelid, adduser: addUserArray, success: { (response) -> () in
            self.authenticationSuccessHandlerInvite(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func initialise()
    {
        let addressBookRef1 = ABAddressBookCreateWithOptions(nil, nil).takeRetainedValue()
        setAddressBook(addressBook: addressBookRef1)
        
        searchDataSource.removeAll()
//        dataSource.removeAll()
        addUserArray.removeAllObjects()
        searchActive = false
        doneButton.isHidden = true
        contactPhoneNumbers.removeAll()
        NoDatalabelFormySharingImageList.removeFromSuperview()
        contactListTableView.reloadData()
        displayContacts()
    }
    
    func contactAuthorizationAlert()
    {
        let authorizationStatus = ABAddressBookGetAuthorizationStatus()
        switch authorizationStatus {
        case .denied, .restricted:
            generateContactSynchronizeAlert()
        case .authorized:
            dataSource.removeAll()
            self.initialise()
        case .notDetermined:
            promptForAddressBookRequestAccess()
        }
    }
    
    func generateContactSynchronizeAlert()
    {
        let alert = UIAlertController(title: "\"Catch\" would like to access your contacts", message: "The contacts in your address book will be transmitted to Catch for you to decide who to add", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Don't Allow", style: UIAlertActionStyle.cancel, handler: { (action) -> Void in
            
        }))
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            self.showEventsAcessDeniedAlert()
        }))
        self.present(alert, animated: false, completion: nil)
    }
    
    func promptForAddressBookRequestAccess() {
        ABAddressBookRequestAccessWithCompletion(addressBookRef, { granted, error in              DispatchQueue.main.async {
            if !granted {
                self.generateContactSynchronizeAlert()
            } else {
                self.dataSource.removeAll()
                self.initialise()
            }
            }
        })
    }
    
    func showEventsAcessDeniedAlert() {
        let alertController = UIAlertController(title: "Permission Denied!",
                                                message: "The contact permission was not authorized. Please enable it in Settings to continue.",
                                                preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (alertAction) in
            if let appSettings = NSURL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.openURL(appSettings as URL)
            }
        }
        alertController.addAction(settingsAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: false, completion: nil)
    }
    
    func displayContacts(){
        if(!pullToRefreshActive){
            showOverlay()
        }
        contactPhoneNumbers.removeAll()
        let defaults = UserDefaults.standard
        let phoneCode = defaults.value(forKey: "countryCode") as! String
        let allContacts = ABAddressBookCopyArrayOfAllPeople(addressBookRef).takeRetainedValue() as Array
        for record in allContacts {
            let phones : ABMultiValue = ABRecordCopyValue(record,kABPersonPhoneProperty).takeUnretainedValue() as ABMultiValue
            var phoneNumber: String = String()
            var appendPlus : String = String()
            for numberIndex : CFIndex in 0 ..< ABMultiValueGetCount(phones)
            {
                let phoneUnmaganed = ABMultiValueCopyValueAtIndex(phones, numberIndex)
                let phoneNumberStr = phoneUnmaganed?.takeUnretainedValue() as! String
                let phoneNumberWithCode: String!
                if(phoneNumberStr.hasPrefix("+")){
                    phoneNumberWithCode = phoneNumberStr
                }
                else if(phoneNumberStr.hasPrefix("00")){
                    let stringLength = phoneNumberStr.characters.count
                    let subStr = (phoneNumberStr as NSString).substring(with: NSRange(location: 2, length: stringLength - 2))
                    phoneNumberWithCode = (phoneCode).appending(subStr)
                }
                else if(phoneNumberStr.hasPrefix("0")){
                    let stringLength = phoneNumberStr.characters.count
                    let subStr = (phoneNumberStr as NSString).substring(with: NSRange(location: 1, length: stringLength - 1))
                    phoneNumberWithCode = (phoneCode).appending(subStr)
                }
                else{
                    phoneNumberWithCode = (phoneCode).appending(phoneNumberStr)
                }
                
                if phoneNumberWithCode.hasPrefix("+")
                {
                    appendPlus = "+"
                }
                else{
                    appendPlus = "nil"
                }
                
                let phoneNumberStringArray = (phoneNumberWithCode).components(
                    separatedBy: CharacterSet.decimalDigits.inverted)
                if appendPlus == "+"
                {
                    phoneNumber = (appendPlus).appending(NSArray(array: phoneNumberStringArray).componentsJoined(by: "")) as String
                }
                contactPhoneNumbers.append(phoneNumber)
            }
        }
        if contactPhoneNumbers.count > 0
        {
            addContactDetails(contactPhoneNumbers: self.contactPhoneNumbers as NSArray)
        }
        else{
            if(!pullToRefreshActive){
                self.removeOverlay()
            }
            else{
                self.refreshControl.endRefreshing()
                self.pullToRefreshActive = false
            }
            addNoDataLabel()
        }
    }
    
    func addNoDataLabel()
    {
        self.NoDatalabelFormySharingImageList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoDatalabelFormySharingImageList.textAlignment = NSTextAlignment.center
        self.NoDatalabelFormySharingImageList.text = "No Contacts Available"
        self.view.addSubview(self.NoDatalabelFormySharingImageList)
    }
    
    func addContactDetails(contactPhoneNumbers: NSArray)
    {
        contactManagers.addContactDetails(userName: userId, accessToken: accessToken, userContacts: contactPhoneNumbers, success:  { (response) -> () in
            self.authenticationSuccessHandlerAdd(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandlerAdd(error: error, code: message)
            return
        }
    }
    
    func authenticationSuccessHandlerAdd(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            var status: Int!
            status = json["status"] as! Int
            if(status >= 1)
            {
                getChannelContactDetails(username: userId, token: accessToken, channelid: channelId)
            }
        }
        else
        {
            ErrorManager.sharedInstance.addContactError()
        }
    }
    
    func authenticationFailureHandlerAdd(error: NSError?, code: String)
    {
        if(!pullToRefreshActive){
            self.removeOverlay()
        }
        else{
            self.refreshControl.endRefreshing()
            self.pullToRefreshActive = false
        }
        addNoDataLabel()
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if code == "CONTACT002" {
            }
            else{
                if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                    loadInitialViewController(code: code)
                }
                else{
                    ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
                    if code == "CONTACT001"{
                    }
                }
            }
        }
        else{
            ErrorManager.sharedInstance.addContactError()
        }
    }
    
    func authenticationSuccessHandlerInvite(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            let status = json["status"] as! Int
            if(status == 1){
                for i in 0 ..< dataSource.count
                {
                    if i < dataSource.count
                    {
                        let selectionValue : Int = dataSource[i][sharedTemporaryKey] as! Int
                        dataSource[i][sharedOriginalKey] = selectionValue
                    }
                }
                loadMychannelDetailController()
            }
        }
    }
    
    func loadMychannelDetailController(){
        let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
        let channelDetailVC:UITabBarController = sharingStoryboard.instantiateViewController(withIdentifier: MyChannelDetailViewController.identifier) as! UITabBarController
        (channelDetailVC as! MyChannelDetailViewController).channelId = channelId as String
        (channelDetailVC as! MyChannelDetailViewController).channelName = channelName as String
        (channelDetailVC as! MyChannelDetailViewController).totalMediaCount = Int(totalMediaCount)
        channelDetailVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(channelDetailVC, animated: false)
    }
    
    func getChannelContactDetails(username: String, token: String, channelid: String)
    {
        channelManager.getChannelNonContactDetails(channelId: channelid, userName: username, accessToken: token, success: { (response) -> () in
            self.authenticationSuccessHandler(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    func authenticationSuccessHandler(response:AnyObject?)
    {
        if(!pullToRefreshActive){
            self.removeOverlay()
        }
        else{
            self.refreshControl.endRefreshing()
            self.pullToRefreshActive = false
        }
        
        if let json = response as? [String: AnyObject]
        {
            if dataSource.count > 0
            {
                for ele in dataSource{
                    dummySource.append(ele)
                }
            }
            dataSource.removeAll()
            let responseArr = json["contactList"] as! [AnyObject]
            for element in responseArr{
                let userName = element["user_name"] as! String
                var dummyFlag = false
                if dummySource.count > 0
                {
                    for ele in dummySource
                    {
                        let dummyName = ele[userNameKey] as! String
                        if dummyName == userName
                        {
                            dummyFlag = true
                            break
                        }
                        else{
                            dummyFlag = false
                        }
                    }
                }
                if dummyFlag == false{
                    let thumbUrl = UrlManager.sharedInstance.getUserProfileImageBaseURL() + userId + "/" + accessToken + "/" + userName
                    
                    var profileImage : UIImage?
                    
                    let savingPath = "\(userName)Profile"
                    let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                    let profileImagePath = parentPath! + "/" + savingPath
                    let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: profileImagePath)
                    
                    if fileExistFlag == true{
                        let profileImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: profileImagePath)
                        profileImage = profileImageFromFile!
                    }
                    else{
                        profileImage = UIImage(named: "dummyUser")
                    }
                    dataSource.append([userNameKey:userName, profileImageUrlKey: thumbUrl, sharedTemporaryKey: 0, sharedOriginalKey : 0, profileImageKey : profileImage!, "profileFlag" : fileExistFlag])
                }
            }
            
            self.contactListTableView.reloadData()
            
            if(dataSource.count > 0){
                operationInSharingContactList  = BlockOperation (block: {
                    self.downloadMediaFromGCS(operationObj: self.operationInSharingContactList)
                })
                self.operationQueueObjInSharingContactList.addOperation(operationInSharingContactList)
            }
            else{
                if dummySource.count > 0
                {
                    for ele in dummySource
                    {
                        dataSource.append(ele)
                    }
                    dummySource.removeAll()
                    self.contactListTableView.reloadData()
                }
                else{
                    addNoDataLabel()
                }
            }
        }
        else
        {
            ErrorManager.sharedInstance.addContactError()
        }
        
    }
    
    func downloadMediaFromGCS(operationObj: BlockOperation){
        var localArray = [[String:Any]]()
        if dummySource.count > 0
        {
            for ele in dummySource
            {
                dataSource.append(ele)
            }
        }
        dummySource.removeAll()
        
        for i in 0 ..< dataSource.count
        {
            localArray.append(dataSource[i])
        }
        
        for i in 0 ..< localArray.count
        {
            if(i < localArray.count){
                if operationObj.isCancelled == true{
                    return
                }
                var profileImage : UIImage?
                let fileFlag = localArray[i]["profileFlag"] as! Bool
                if(!fileFlag)
                {
                    let user = localArray[i][userNameKey] as! String
                    let savingPath = "\(user)Profile"
                    let profileImageName = localArray[i][profileImageUrlKey] as! String
                    if(profileImageName != "")
                    {
                        profileImage = FileManagerViewController.sharedInstance.getProfileImage(profileNameURL: profileImageName)
                        let profileImageData = UIImageJPEGRepresentation(profileImage!, 0.5)
                        let profileImageDataAsNsdata = (profileImageData as NSData?)!
                        let imageFromDefault = UIImageJPEGRepresentation(UIImage(named: "dummyUser")!, 0.5)
                        let imageFromDefaultAsNsdata = (imageFromDefault as NSData?)!
                        if(profileImageDataAsNsdata.isEqual(imageFromDefaultAsNsdata)){
                        }
                        else{
                            _ =
                                FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: savingPath, mediaImage: profileImage!)
                        }
                    }
                    else{
                        profileImage = UIImage(named: "dummyUser")
                    }
                    localArray[i][profileImageKey] = profileImage
                }
            }
        }
        for j in 0 ..< dataSource.count
        {
            if operationObj.isCancelled == true{
                return
            }
            if j < dataSource.count
            {
                let userChk = dataSource[j][userNameKey] as! String
                for element in localArray
                {
                    let userLocalChk = element[userNameKey] as! String
                    if userChk == userLocalChk
                    {
                        if element[profileImageKey] != nil
                        {
                            dataSource[j][profileImageKey] = element[profileImageKey] as! UIImage
                        }
                    }
                }
            }
        }
        localArray.removeAll()
        DispatchQueue.main.async {
            self.contactListTableView.reloadData()
        }
    }
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        if(!pullToRefreshActive){
            self.removeOverlay()
        }
        else{
            self.refreshControl.endRefreshing()
            self.pullToRefreshActive = false
        }
        
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                loadInitialViewController(code: code)
            }
            else
            {
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
            }
        }
        else{
            ErrorManager.sharedInstance.addContactError()
        }
        if(dataSource.count > 0){
            for i in 0 ..< dataSource.count
            {
                if i < dataSource.count
                {
                    let selectionValue : Int = dataSource[i][sharedOriginalKey] as! Int
                    dataSource[i][sharedTemporaryKey] = selectionValue
                }
            }
        }
        else{
            addNoDataLabel()
        }
        contactListTableView.reloadData()
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
    
    func callRefreshContactListTableView(notif:NSNotification){
        if(doneButton.isHidden == true){
            doneButton.isHidden = false
        }
        let indexpath = notif.object as! Int
        if(searchActive)
        {
            if(indexpath < searchDataSource.count){
                let selectedValue =  searchDataSource[indexpath][sharedTemporaryKey] as! Int
                if(selectedValue == 1)
                {
                    searchDataSource[indexpath][sharedTemporaryKey] = 0
                }
                else
                {
                    searchDataSource[indexpath][sharedTemporaryKey] = 1
                }
                
                let selecteduserId =  searchDataSource[indexpath][userNameKey] as! String
                for i in 0 ..< dataSource.count
                {
                    if i < dataSource.count
                    {
                        let dataSourceUserId = dataSource[i][userNameKey] as! String
                        if(selecteduserId == dataSourceUserId)
                        {
                            dataSource[i][sharedTemporaryKey] = searchDataSource[indexpath][sharedTemporaryKey]
                        }
                    }
                }
            }
        }
        else
        {
            if(indexpath < dataSource.count){
                let selectedValue =  dataSource[indexpath][sharedTemporaryKey] as! Int
                if(selectedValue == 1){
                    dataSource[indexpath][sharedTemporaryKey] = 0
                }
                else{
                    dataSource[indexpath][sharedTemporaryKey] = 1
                }
            }
        }
        
        var doneButtonHideFlag : Bool  = false
        for k in 0 ..< dataSource.count
        {
            if k < dataSource.count
            {
                let temp =  dataSource[k][sharedTemporaryKey] as! Int
                if temp != 0
                {
                    doneButtonHideFlag = true
                    break
                }
            }
        }
        if(doneButtonHideFlag){
            doneButton.isHidden = false
        }
        else{
            doneButton.isHidden = true
        }
        
        contactListTableView.reloadData()
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
}

extension ContactListViewController:UITableViewDelegate,UITableViewDataSource
{
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 45.0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let  headerCell = tableView.dequeueReusableCell(withIdentifier: "ContactListHeaderTableViewCell") as! ContactListHeaderTableViewCell
        
        headerCell.contactListHeaderLabel.text = "USING CA7CH"
        return headerCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(searchActive){
            return searchDataSource.count > 0 ? (searchDataSource.count) : 0
        }
        else{
            return dataSource.count > 0 ? (dataSource.count) : 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var dataSourceTmp : [[String:Any]]?
        
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactListTableViewCell.identifier, for:indexPath as IndexPath) as! ContactListTableViewCell
        
        if(searchActive){
            dataSourceTmp = searchDataSource
        }
        else{
            dataSourceTmp = dataSource
        }
        
        if (dataSourceTmp?.count)! > 0
        {
            cell.contactUserName.text = dataSourceTmp![indexPath.row][userNameKey] as? String
            let imageName =  dataSourceTmp![indexPath.row][profileImageKey]
            cell.contactProfileImage.image = imageName as? UIImage
            cell.subscriptionButton.tag = indexPath.row
            
            let selectionValue : Int = dataSourceTmp![indexPath.row][sharedTemporaryKey] as! Int
            if(selectionValue == 1){
                cell.subscriptionButton.setImage(UIImage(named:"CheckOn"), for:.normal)
            }
            else{
                cell.subscriptionButton.setImage(UIImage(named:"red-circle"), for:.normal)
            }
            
            cell.selectionStyle = .none
            return cell
        }
        else
        {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

extension ContactListViewController: UISearchBarDelegate{
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if searchBar.text != ""
        {
            searchActive = true
        }
        else{
            searchActive = false
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDataSource.removeAll()
        
        if contactListSearchBar.text!.isEmpty
        {
            searchDataSource = dataSource
            contactListSearchBar.resignFirstResponder()
            self.contactListTableView.reloadData()
        }
        else{
            if dataSource.count > 0
            {
                for element in dataSource{
                    let tmp: String = (element[userNameKey] as! String).lowercased()
                    if(tmp.range(of: searchText.lowercased()) != nil)
                    {
                        searchDataSource.append(element)
                    }
                }
                searchActive = true
                self.contactListTableView.reloadData()
            }
        }
    }
}

