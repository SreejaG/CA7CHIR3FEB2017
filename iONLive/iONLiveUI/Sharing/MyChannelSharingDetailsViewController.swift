
import UIKit

class MyChannelSharingDetailsViewController: UIViewController {
    
    var totalMediaCount: Int = Int()
    var channelId:String!
    var channelName:String!
    var loadingOverlay: UIView?
    
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    
    var dataSource:[[String:AnyObject]] = [[String:AnyObject]]()
//    var fullDataSource:[[String:AnyObject]] = [[String:AnyObject]]()
    var searchDataSource:[[String:AnyObject]] = [[String:AnyObject]]()
    
    var addUserArray : NSMutableArray = NSMutableArray()
    var deleteUserArray : NSMutableArray = NSMutableArray()
    
    let userNameKey = "userName"
    let profileImageKey = "profileImage"
    let subscribedKey = "sharedindicator"
    let selectionKey = "selected"
    let profileImageUrlKey = "profile_image_URL"
    
    let defaults = NSUserDefaults .standardUserDefaults()
    var userId = String()
    var accessToken = String()
    
    var searchActive: Bool = false
    
    @IBOutlet var inviteButton: UIButton!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var channelTitleLabel: UILabel!
    @IBOutlet var contactSearchBar: UISearchBar!
    @IBOutlet var contactTableView: UITableView!
    
    var NoContactsAddedList : UILabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MyChannelSharingDetailsViewController.callRefreshContactSharingTableView(_:)), name: "refreshContactSharingTableView", object: nil)
        self.contactTableView.alwaysBounceVertical = true
        initialise()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true)
        NSUserDefaults.standardUserDefaults().setInteger(1, forKey: "tabToAppear")
        self.tabBarItem.selectedImage = UIImage(named:"friend_avatar_blue")?.imageWithRenderingMode(.AlwaysOriginal)
        if let channelName = channelName
        {
            channelTitleLabel.text = channelName.uppercaseString
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(true)
    }
    
    @IBAction func gestureTapped(sender: AnyObject) {
        view.endEditing(true)
        self.contactSearchBar.text = ""
        self.contactSearchBar.resignFirstResponder()
        searchActive = false
        self.contactTableView.reloadData()
    }
    
    @IBAction func backClicked(sender: AnyObject)
    {
        if(doneButton.hidden == false){
            inviteButton.hidden = false
            doneButton.hidden = true
            for i in 0 ..< dataSource.count
            {
                if(i < dataSource.count){
                    let selectionValue : Int = dataSource[i]["orgSelected"] as! Int
                    dataSource[i]["tempSelected"] = selectionValue
                }
            }
            contactTableView.reloadData()
        }
        else{
            let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
            let sharingVC = sharingStoryboard.instantiateViewControllerWithIdentifier(MySharedChannelsViewController.identifier) as! MySharedChannelsViewController
            sharingVC.navigationController?.navigationBarHidden = true
            self.navigationController?.pushViewController(sharingVC, animated: false)
        }
    }
    
    @IBAction func inviteContacts(sender: AnyObject) {
        let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
        let inviteContactsVC = sharingStoryboard.instantiateViewControllerWithIdentifier(OtherContactListViewController.identifier) as! OtherContactListViewController
        inviteContactsVC.channelId = channelId
        inviteContactsVC.channelName = channelName
        inviteContactsVC.totalMediaCount = totalMediaCount
        inviteContactsVC.navigationController?.navigationBarHidden = true
        self.navigationController?.pushViewController(inviteContactsVC, animated: false)
    }
    
    @IBAction func didTapDoneButton(sender: AnyObject) {
        doneButton.hidden = true
        inviteButton.hidden = false
        contactTableView.reloadData()
        contactTableView.layoutIfNeeded()
        addUserArray.removeAllObjects()
        deleteUserArray.removeAllObjects()
        
        for i in 0 ..< dataSource.count
        {
            if(i < dataSource.count){
                let userId = dataSource[i][userNameKey] as! String
                let selectionValue : Int = dataSource[i]["tempSelected"] as! Int
                if(selectionValue == 1){
                    addUserArray.addObject(userId)
                }
                else{
                    deleteUserArray.addObject(userId)
                }
            }
        }
        
        if((addUserArray.count > 0) || (deleteUserArray.count > 0))
        {
            inviteContactList(userId, accessToken: accessToken, channelid: channelId, addUser: addUserArray, deleteUser: deleteUserArray)
        }
    }
    
    func inviteContactList(userName: String, accessToken: String, channelid: String, addUser: NSMutableArray, deleteUser:NSMutableArray){
        showOverlay()
        channelManager.inviteContactList(userName, accessToken: accessToken, channelId: channelid, adduser: addUser, deleteUser: deleteUser, success: { (response) -> () in
            self.authenticationSuccessHandlerInvite(response)
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error, code: message)
            return
        }
    }
    
    func addNoDataLabel()
    {
        self.NoContactsAddedList = UILabel(frame: CGRectMake((self.view.frame.width/2) - 100,(self.view.frame.height/2) - 35, 200, 70))
        self.NoContactsAddedList.textAlignment = NSTextAlignment.Center
        self.NoContactsAddedList.text = "No Shared Contacts"
        self.view.addSubview(self.NoContactsAddedList)
    }
    
    func  loadInitialViewController(code: String){
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            
            let documentsPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] + "/GCSCA7CH"
            
            if(NSFileManager.defaultManager().fileExistsAtPath(documentsPath))
            {
                let fileManager = NSFileManager.defaultManager()
                do {
                    try fileManager.removeItemAtPath(documentsPath)
                }
                catch _ as NSError {
                }
                FileManagerViewController.sharedInstance.createParentDirectory()
            }
            else{
                FileManagerViewController.sharedInstance.createParentDirectory()
            }
            
            let deviceToken = self.defaults.valueForKey("deviceToken") as! String
            self.defaults.removePersistentDomainForName(NSBundle.mainBundle().bundleIdentifier!)
            self.defaults.setValue(deviceToken, forKey: "deviceToken")
            self.defaults.setObject(1, forKey: "shutterActionMode");
            
            let sharingStoryboard = UIStoryboard(name:"Authentication", bundle: nil)
            let channelItemListVC = sharingStoryboard.instantiateViewControllerWithIdentifier("AuthenticateNavigationController") as! AuthenticateNavigationController
            channelItemListVC.navigationController?.navigationBarHidden = true
            self.presentViewController(channelItemListVC, animated: false) { () -> Void in
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(code)
            }
        })
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
                        let selectionValue : Int = dataSource[i]["tempSelected"] as! Int
                        dataSource[i]["orgSelected"] = selectionValue
                    }
                }
                contactTableView.reloadData()
            }
        }
    }
    
    func initialise()
    {
        userId = defaults.valueForKey(userLoginIdKey) as! String
        accessToken = defaults.valueForKey(userAccessTockenKey) as! String
        
        searchDataSource.removeAll()
        dataSource.removeAll()
        addUserArray.removeAllObjects()
        deleteUserArray.removeAllObjects()
        
        searchActive = false
        
        doneButton.hidden = true
        inviteButton.hidden = false
        
        channelId = (self.tabBarController as! MyChannelDetailViewController).channelId
        channelName = (self.tabBarController as! MyChannelDetailViewController).channelName
        totalMediaCount = (self.tabBarController as! MyChannelDetailViewController).totalMediaCount
        
        getChannelContactDetails(userId, token: accessToken, channelid: channelId)
    }
    
    func getChannelContactDetails(username: String, token: String, channelid: String)
    {
        showOverlay()
        channelManager.getChannelContactDetails(channelid, userName: username, accessToken: token, success: { (response) -> () in
            self.authenticationSuccessHandler(response)
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error, code: message)
            return
        }
    }
    
    func nullToNil(value : AnyObject?) -> AnyObject? {
        if value is NSNull {
            return ""
        } else {
            return value
        }
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    func authenticationSuccessHandler(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            dataSource.removeAll()
            let responseArr = json["contactList"] as! [AnyObject]
            for element in responseArr{
                let userName = element["user_name"] as! String
                let imageName = UrlManager.sharedInstance.getUserProfileImageBaseURL() + userId + "/" + accessToken + "/" + userName
                let subscriptionValue =  Int(element["sub_enable_ind"] as! Bool)
                dataSource.append([userNameKey:userName, profileImageUrlKey: imageName, "tempSelected": subscriptionValue, "orgSelected": subscriptionValue])
            }
            if(dataSource.count > 0){
                let qualityOfServiceClass = QOS_CLASS_BACKGROUND
                let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
                dispatch_async(backgroundQueue, {
                    self.downloadMediaFromGCS()
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    })
                })
            }
            else
            {
                removeOverlay()
                addNoDataLabel()
            }
        }
        else
        {
            ErrorManager.sharedInstance.addContactError()
        }
    }
    
    func createProfileImage(profileName: String) -> UIImage
    {
        var profileImage : UIImage = UIImage()
        let url: NSURL = convertStringtoURL(profileName)
        if let data = NSData(contentsOfURL: url){
            let imageDetailsData = (data as NSData?)!
            profileImage = UIImage(data: imageDetailsData)!
        }
        else{
            profileImage = UIImage(named: "dummyUser")!
        }
        return profileImage
    }
    
    func downloadMediaFromGCS(){
        for i in 0 ..< dataSource.count
        {
            if(i < dataSource.count){
                var profileImage : UIImage?
                let profileImageName = dataSource[i][profileImageUrlKey] as! String
                if(profileImageName != "")
                {
                    profileImage = createProfileImage(profileImageName)
                }
                else{
                    profileImage = UIImage(named: "dummyUser")
                }
                
                self.dataSource[i][profileImageKey] = profileImage
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.removeOverlay()
                    self.contactTableView.reloadData()
                })
            }
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
                loadInitialViewController(code)
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(code)
            }
        }
        else{
            ErrorManager.sharedInstance.addContactError()
        }
        
        for i in 0 ..< dataSource.count
        {
            if(i < dataSource.count){
                let selectionValue : Int = dataSource[i]["orgSelected"] as! Int
                dataSource[i]["tempSelected"] = selectionValue
            }
        }
        contactTableView.reloadData()
    }
    
    func callRefreshContactSharingTableView(notif:NSNotification){
        if(doneButton.hidden == true){
            doneButton.hidden = false
            inviteButton.hidden = true
        }
        let indexpath = notif.object as! Int
        
        if(searchActive)
        {
            if(indexpath < searchDataSource.count){
                let selectedValue =  searchDataSource[indexpath]["tempSelected"] as! Int
                if(selectedValue == 1)
                {
                    searchDataSource[indexpath]["tempSelected"] = 0
                }
                else
                {
                    searchDataSource[indexpath]["tempSelected"] = 1
                }
                
                let selecteduserId =  searchDataSource[indexpath][userNameKey] as! String
                for i in 0 ..< dataSource.count
                {
                    if(i < dataSource.count){
                        let dataSourceUserId = dataSource[i][userNameKey] as! String
                        if(selecteduserId == dataSourceUserId)
                        {
                            dataSource[i]["tempSelected"] = searchDataSource[indexpath]["tempSelected"]
                        }
                    }
                }
            }
        }
        else
        {
            if(indexpath < dataSource.count){
                let selectedValue =  dataSource[indexpath]["tempSelected"] as! Int
                if(selectedValue == 1){
                    dataSource[indexpath]["tempSelected"] = 0
                }
                else{
                    dataSource[indexpath]["tempSelected"] = 1
                }
            }
        }
        contactTableView.reloadData()
    }
    
    func showOverlay(){
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = CGRectMake(0, 64, self.view.frame.width, self.view.frame.height - (64 + 50))
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.view .addSubview(self.loadingOverlay!)
    }
    
    func removeOverlay(){
        self.loadingOverlay?.removeFromSuperview()
    }
    
    func generateWaytoSendAlert(ContactId: String, indexpath: Int)
    {
        
        let alert = UIAlertController(title: "Delete!!!", message: "Do you want to delete the contact", preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            self.deleteContactDetails(self.userId, token: self.accessToken, contactName: ContactId, channelid: self.channelId, index: indexpath)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
        
        self.presentViewController(alert, animated: false, completion: nil)
    }
    
    func  deleteContactDetails(userName: String, token:String, contactName:String, channelid:String, index:Int){
        showOverlay()
        channelManager.deleteContactDetails(userName: userName, accessToken: token, channelId: channelid, contactName: contactName, success: { (response) in
            self.authenticationSuccessHandlerDeleteContact(response,index: index)
        }) { (error, message) in
            self.authenticationFailureHandler(error, code: message)
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
                    searchDataSource.removeAtIndex(index)
                    for i in 0 ..< dataSource.count
                    {
                        if(i < dataSource.count){
                            let orgChannel = dataSource[i][userNameKey] as! String
                            if(orgChannel == channelId){
                                dataSource.removeAtIndex(i)
                            }
                        }
                    }
                }
                else{
                    dataSource.removeAtIndex(index)
                }
            }
            if dataSource.count == 0
            {
                addNoDataLabel()
            }
            contactTableView.reloadData()
        }
    }
}

extension MyChannelSharingDetailsViewController:UITableViewDelegate,UITableViewDataSource
{
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        return 45.0
    }
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return 60
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        return 0.01
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let  headerCell = tableView.dequeueReusableCellWithIdentifier("contactHeaderTableViewCell") as! contactHeaderTableViewCell
        
        headerCell.contactHeaderTitle.text = "SHARING WITH"
        return headerCell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if(searchActive){
            return searchDataSource.count > 0 ? (searchDataSource.count) : 0
        }
        else{
            return dataSource.count > 0 ? (dataSource.count) : 0
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var dataSourceTmp : [[String:AnyObject]]?
        
        let cell = tableView.dequeueReusableCellWithIdentifier(contactSharingDetailTableViewCell.identifier, forIndexPath:indexPath) as! contactSharingDetailTableViewCell
        
        if(searchActive){
            dataSourceTmp = searchDataSource
        }
        else{
            dataSourceTmp = dataSource
        }
        
        if dataSourceTmp?.count > 0
        {
            cell.contactUserName.text = dataSourceTmp![indexPath.row][userNameKey] as? String
            let imageName =  dataSourceTmp![indexPath.row][profileImageKey]
            cell.contactProfileImage.image = imageName as? UIImage
            cell.subscriptionButton.tag = indexPath.row
            
            let selectionValue : Int = dataSourceTmp![indexPath.row]["tempSelected"] as! Int
            if(selectionValue == 1){
                cell.subscriptionButton.setImage(UIImage(named:"CheckOn"), forState:.Normal)
            }
            else{
                cell.subscriptionButton.setImage(UIImage(named:"red-circle"), forState:.Normal)
            }
            
            cell.selectionStyle = .None
            return cell
        }
        else
        {
            return UITableViewCell()
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            var deletedUserId : String = String()
            if(searchActive){
                deletedUserId = self.searchDataSource[indexPath.row][self.userNameKey]! as! String
            }
            else{
                deletedUserId = self.dataSource[indexPath.row][self.userNameKey]! as! String
            }
            generateWaytoSendAlert(deletedUserId, indexpath: indexPath.row)
        }
    }
}

extension MyChannelSharingDetailsViewController: UISearchBarDelegate{
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        if searchBar.text != ""
        {
            searchActive = true
        }
        else{
            searchActive = false
        }
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
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
                    let tmp: String = (element[userNameKey]?.lowercaseString)!
                    if(tmp.containsString(searchText.lowercaseString))
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
