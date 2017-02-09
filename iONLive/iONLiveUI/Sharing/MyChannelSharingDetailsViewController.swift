
import UIKit

class MyChannelSharingDetailsViewController: UIViewController {
    
    var totalMediaCount: Int = Int()
    var channelId:String!
    var channelName:String!
    var loadingOverlay: UIView?
    
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    
    var dataSource:[[String:Any]] = [[String:Any]]()
    var searchDataSource:[[String:Any]] = [[String:Any]]()
    
    var addUserArray : NSMutableArray = NSMutableArray()
    var deleteUserArray : NSMutableArray = NSMutableArray()
    
    let userNameKey = "userName"
    let profileImageKey = "profileImage"
    let subscribedKey = "sharedindicator"
    let selectionKey = "selected"
    let profileImageUrlKey = "profile_image_URL"
    
    let defaults = UserDefaults.standard
    var userId = String()
    var accessToken = String()
    
    var searchActive: Bool = false
    
    @IBOutlet var inviteButton: UIButton!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var channelTitleLabel: UILabel!
    @IBOutlet var contactSearchBar: UISearchBar!
    @IBOutlet var contactTableView: UITableView!
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint!
    
    var NoContactsAddedList : UILabel = UILabel()
    
    var operationQueueObjInSharingContactList = OperationQueue()
    var operationInSharingScreenContactList = BlockOperation()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.contactTableView.alwaysBounceVertical = true
        initialise()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        UserDefaults.standard.set(1, forKey: "tabToAppear")
        self.tabBarItem.selectedImage = UIImage(named:"friend_avatar_blue")?.withRenderingMode(.alwaysOriginal)
        if let channelName = channelName
        {
            channelTitleLabel.text = channelName.uppercased()
        }
        
        let refreshContactSharing = Notification.Name("refreshContactSharingTableView")
        NotificationCenter.default.addObserver(self, selector:#selector(MyChannelSharingDetailsViewController.callRefreshContactSharingTableView(notif:)), name: refreshContactSharing, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("refreshContactSharingTableView"), object: nil)
    }
    
    func addKeyboardObservers()
    {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MyChannelSharingDetailsViewController.keyboardDidShow(notification:)),
                                               name: NSNotification.Name.UIKeyboardDidShow,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MyChannelSharingDetailsViewController.keyboardDidHide),
                                               name: NSNotification.Name.UIKeyboardDidHide,
                                               object: nil)
    }
    
    func keyboardDidShow(notification:NSNotification)
    {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if tableViewBottomConstraint.constant == 49
        {
            self.tableViewBottomConstraint.constant = keyboardFrame.size.height
        }
    }
    
    func keyboardDidHide()
    {
        if tableViewBottomConstraint.constant != 49
        {
            self.tableViewBottomConstraint.constant = 49
        }
    }
    
    @IBAction func gestureTapped(_ sender: Any) {
        view.endEditing(true)
        self.contactSearchBar.text = ""
        self.contactSearchBar.resignFirstResponder()
        searchActive = false
        self.contactTableView.reloadData()
    }
    
    @IBAction func backClicked(_ sender: Any)
    {
        if(doneButton.isHidden == false){
            inviteButton.isHidden = false
            doneButton.isHidden = true
            if(searchActive){
                for i in 0 ..< searchDataSource.count
                {
                    if(i < searchDataSource.count){
                        let selectionValue : Int = searchDataSource[i][sharedOriginalKey] as! Int
                        searchDataSource[i][sharedTemporaryKey] = selectionValue
                    }
                }
            }
            for i in 0 ..< dataSource.count
            {
                if(i < dataSource.count){
                    let selectionValue : Int = dataSource[i][sharedOriginalKey] as! Int
                    dataSource[i][sharedTemporaryKey] = selectionValue
                }
            }
            contactTableView.reloadData()
        }
        else{
            let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
            let sharingVC = sharingStoryboard.instantiateViewController(withIdentifier: MySharedChannelsViewController.identifier) as! MySharedChannelsViewController
            sharingVC.navigationController?.isNavigationBarHidden = true
            self.navigationController?.pushViewController(sharingVC, animated: false)
        }
    }
    
    @IBAction func inviteContacts(_ sender: Any) {
        let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
        let inviteContactsVC = sharingStoryboard.instantiateViewController(withIdentifier: ContactListViewController.identifier) as! ContactListViewController
        inviteContactsVC.channelId = channelId
        inviteContactsVC.channelName = channelName
        inviteContactsVC.totalMediaCount = totalMediaCount
        inviteContactsVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(inviteContactsVC, animated: false)
    }
    
    @IBAction func didTapDoneButton(_ sender: Any) {
        doneButton.isHidden = true
        inviteButton.isHidden = false
        contactTableView.reloadData()
        contactTableView.layoutIfNeeded()
        addUserArray.removeAllObjects()
        deleteUserArray.removeAllObjects()
        
        for i in 0 ..< dataSource.count
        {
            if(i < dataSource.count){
                let userId = dataSource[i][userNameKey] as! String
                let selectionValue : Int = dataSource[i][sharedTemporaryKey] as! Int
                if(selectionValue == 1){
                    addUserArray.add(userId)
                }
                else{
                    deleteUserArray.add(userId)
                }
            }
        }
        
        if((addUserArray.count > 0) || (deleteUserArray.count > 0))
        {
            inviteContactList(userName: userId, accessToken: accessToken, channelid: channelId, addUser: addUserArray, deleteUser: deleteUserArray)
        }
    }
    
    func inviteContactList(userName: String, accessToken: String, channelid: String, addUser: NSMutableArray, deleteUser:NSMutableArray){
        showOverlay()
        channelManager.inviteContactList(userName: userName, accessToken: accessToken, channelId: channelid, adduser: addUser, deleteUser: deleteUser, success: { (response) -> () in
            self.authenticationSuccessHandlerInvite(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func addNoDataLabel()
    {
        self.NoContactsAddedList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoContactsAddedList.textAlignment = NSTextAlignment.center
        self.NoContactsAddedList.text = "No Shared Contacts"
        self.view.addSubview(self.NoContactsAddedList)
    }
    
    func authenticationSuccessHandlerInvite(response:AnyObject?)
    {
        removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            let status = json["status"] as! Int
            if(status == 1){
                for i in 0 ..< dataSource.count
                {
                    if(i < dataSource.count){
                        let selectionValue : Int = dataSource[i][sharedTemporaryKey] as! Int
                        dataSource[i][sharedOriginalKey] = selectionValue
                    }
                }
                contactTableView.reloadData()
            }
        }
    }
    
    func initialise()
    {
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        
        addKeyboardObservers()
        
        searchDataSource.removeAll()
        dataSource.removeAll()
        addUserArray.removeAllObjects()
        deleteUserArray.removeAllObjects()
        
        searchActive = false
        
        doneButton.isHidden = true
        inviteButton.isHidden = false
        
        channelId = (self.tabBarController as! MyChannelDetailViewController).channelId
        channelName = (self.tabBarController as! MyChannelDetailViewController).channelName
        totalMediaCount = (self.tabBarController as! MyChannelDetailViewController).totalMediaCount
        
        getChannelContactDetails(username: userId, token: accessToken, channelid: channelId)
    }
    
    func getChannelContactDetails(username: String, token: String, channelid: String)
    {
        showOverlay()
        channelManager.getChannelContactDetails(channelId: channelid, userName: username, accessToken: token, success: { (response) -> () in
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
        removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            dataSource.removeAll()
            let responseArr = json["contactList"] as! [AnyObject]
            for element in responseArr{
                let userName = element["user_name"] as! String
                let imageName = UrlManager.sharedInstance.getUserProfileImageBaseURL() + userId + "/" + accessToken + "/" + userName
                let subscriptionValue =  (element["sub_enable_ind"] as! Bool).hashValue
                
                let savingPath = "\(userName)Profile"
                let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                let profileImagePath = parentPath! + "/" + savingPath
                let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: profileImagePath)
                
                var profileImage : UIImage?
                
                if fileExistFlag == true{
                    let profileImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: profileImagePath)
                    profileImage = profileImageFromFile!
                }
                else{
                    profileImage = UIImage(named: "dummyUser")
                }
                dataSource.append([userNameKey:userName, profileImageUrlKey: imageName, sharedTemporaryKey: subscriptionValue, sharedOriginalKey: subscriptionValue, profileImageKey: profileImage!,"profileFlag" : fileExistFlag])
            }
            contactTableView.reloadData()
            if(dataSource.count > 0){
                operationInSharingScreenContactList  = BlockOperation (block: {
                    self.downloadMediaFromGCS(operationObj: self.operationInSharingScreenContactList)
                })
                self.operationQueueObjInSharingContactList.addOperation(operationInSharingScreenContactList)
            }
            else
            {
                removeOverlay()
                addNoDataLabel()
                doneButton.isHidden = true
                inviteButton.isHidden = false
            }
        }
        else
        {
            ErrorManager.sharedInstance.addContactError()
        }
    }
    
    func downloadMediaFromGCS(operationObj: BlockOperation){
        var localArray = [[String:Any]]()
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
            self.contactTableView.reloadData()
        }
    }
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        removeOverlay()
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                loadInitialViewController(code: code)
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
            }
        }
        else{
            ErrorManager.sharedInstance.addContactError()
        }
        
        for i in 0 ..< dataSource.count
        {
            if(i < dataSource.count){
                let selectionValue : Int = dataSource[i][sharedOriginalKey] as! Int
                dataSource[i][sharedTemporaryKey] = selectionValue
            }
        }
        contactTableView.reloadData()
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
    
    func callRefreshContactSharingTableView(notif:NSNotification){
        if(doneButton.isHidden == true){
            doneButton.isHidden = false
            inviteButton.isHidden = true
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
                    if(i < dataSource.count){
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
                let org = dataSource[k][sharedOriginalKey] as! Int
                if temp != org
                {
                    doneButtonHideFlag = true
                    break
                }
            }
        }
        if(doneButtonHideFlag){
            doneButton.isHidden = false
            inviteButton.isHidden = true
        }
        else{
            doneButton.isHidden = true
            inviteButton.isHidden = false
        }
        
        contactTableView.reloadData()
    }
    
    func showOverlay(){
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = CGRect(x:0, y:64, width:self.view.frame.width, height:(self.view.frame.height - (64 + 50)))
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.view .addSubview(self.loadingOverlay!)
    }
    
    func removeOverlay(){
        self.loadingOverlay?.removeFromSuperview()
    }
    
    func generateWaytoSendAlert(ContactId: String, indexpath: Int)
    {
        let alert = UIAlertController(title: "Delete!!!", message: "Do you want to delete the contact", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            self.deleteContactDetails(userName: self.userId, token: self.accessToken, contactName: ContactId, channelid: self.channelId, index: indexpath)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        self.present(alert, animated: false, completion: nil)
    }
    
    func  deleteContactDetails(userName: String, token:String, contactName:String, channelid:String, index:Int){
        showOverlay()
        channelManager.deleteContactDetails(userName: userName, accessToken: token, channelId: channelid, contactName: contactName, success: { (response) in
            self.authenticationSuccessHandlerDeleteContact(response: response,index: index)
        }) { (error, message) in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func authenticationSuccessHandlerDeleteContact(response:AnyObject?, index: Int)
    {
        removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            let status = json["status"] as! Int
            if(status == 1){
                if(searchActive){
                    let channelId = searchDataSource[index][userNameKey] as! String
                    searchDataSource.remove(at: index)
                    for i in 0 ..< dataSource.count
                    {
                        if(i < dataSource.count){
                            let orgChannel = dataSource[i][userNameKey] as! String
                            if(orgChannel == channelId){
                                dataSource.remove(at: i)
                            }
                        }
                    }
                }
                else{
                    dataSource.remove(at: index)
                }
            }
            
            if dataSource.count == 0
            {
                addNoDataLabel()
                doneButton.isHidden = true
                inviteButton.isHidden = false
            }
            else{
                var doneButtonHideFlag : Bool  = false
                for k in 0 ..< dataSource.count
                {
                    if k < dataSource.count
                    {
                        let temp =  dataSource[k][sharedTemporaryKey] as! Int
                        let org = dataSource[k][sharedOriginalKey] as! Int
                        if temp != org
                        {
                            doneButtonHideFlag = true
                            break
                        }
                    }
                }
                if(doneButtonHideFlag){
                    doneButton.isHidden = false
                    inviteButton.isHidden = true
                }
                else{
                    doneButton.isHidden = true
                    inviteButton.isHidden = false
                }
            }
            contactTableView.reloadData()
        }
    }
}

extension MyChannelSharingDetailsViewController:UITableViewDelegate,UITableViewDataSource
{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 45.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let  headerCell = tableView.dequeueReusableCell(withIdentifier: "contactHeaderTableViewCell") as! contactHeaderTableViewCell
        
        headerCell.contactHeaderTitle.text = "SHARING WITH"
        headerCell.isUserInteractionEnabled = false
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
        
        let cell = tableView.dequeueReusableCell(withIdentifier: contactSharingDetailTableViewCell.identifier, for:indexPath as IndexPath) as! contactSharingDetailTableViewCell
        
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
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            var deletedUserId : String = String()
            if(searchActive){
                deletedUserId = self.searchDataSource[indexPath.row][self.userNameKey]! as! String
            }
            else{
                deletedUserId = self.dataSource[indexPath.row][self.userNameKey]! as! String
            }
            generateWaytoSendAlert(ContactId: deletedUserId, indexpath: indexPath.row)
        }
    }
}

extension MyChannelSharingDetailsViewController: UISearchBarDelegate{
    
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
        
        if contactSearchBar.text!.isEmpty
        {
            searchDataSource = dataSource
            contactSearchBar.resignFirstResponder()
            self.contactTableView.reloadData()
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
                self.contactTableView.reloadData()
            }
        }
    }
}
