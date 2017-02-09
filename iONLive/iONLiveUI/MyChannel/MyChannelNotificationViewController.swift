
import UIKit

class MyChannelNotificationViewController: UIViewController {
    
    static let identifier = "MyChannelNotificationViewController"
    
    @IBOutlet var triangleView: UIImageView!
    @IBOutlet var NotificationLabelView: UIView!
    @IBOutlet var NotificationTableView: UITableView!
    
    let channelManager = ChannelManager.sharedInstance
    let requestManager = RequestManager.sharedInstance
    
    var loadingOverlay: UIView?
    
    var mediaDataSource:[[String:Any]] = [[String:Any]]()
    var channelDataSource:[[String:Any]] = [[String:Any]]()
    var dataSource:[[String:Any]] = [[String:Any]]()
    var fulldataSource : [[String:Any]] = [[String:Any]]()
    
    let usernameKey = "userName"
    let profileImageKey = "profileImage"
    let notificationTypeKey = "notificationType"
    let mediaTypeKey = "mediaType"
    let mediaImageKey = "mediaImage"
    let messageKey = "message"
    let notificationTimeKey = "notifTime"
    
    var operationQueueObjInNotif = OperationQueue()
    var operationInNotif = BlockOperation()
    
    let defaults = UserDefaults.standard
    var userId = String()
    var accessToken = String()
    
    @IBOutlet var notifImage: UIButton!
    
    var NoDatalabelFormyChanelImageList : UILabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.view.layer.removeAllAnimations()
        self.navigationController?.view.layer.layoutIfNeeded()
        if let notifFlag = defaults.value(forKey: "notificationArrived")
        {
            if notifFlag as! String == "0"
            {
                let image = UIImage(named: "noNotif") as UIImage?
                notifImage.setImage(image, for: .normal)
            }
        }
        else{
            let image = UIImage(named: "notif") as UIImage?
            notifImage.setImage(image, for: .normal)
        }
        initialise()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        NotificationTableView.layer.cornerRadius=10
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        operationInNotif.cancel()
        channelDataSource.removeAll()
        mediaDataSource.removeAll()
        fulldataSource.removeAll()
    }
    
    @IBAction func didTapNotificationButton(_ sender: Any) {
        let storyboard = UIStoryboard(name:"MyChannel", bundle: nil)
        let channelVC = storyboard.instantiateViewController(withIdentifier: MyChannelViewController.identifier) as! MyChannelViewController
        channelVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(channelVC, animated: false)
    }
    
    func initialise(){
        channelDataSource.removeAll()
        mediaDataSource.removeAll()
        fulldataSource.removeAll()
        
        defaults.setValue("0", forKey: "notificationFlag")
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        
        getNotificationDetails(userName: userId, token: accessToken)
    }
    
    func getNotificationDetails(userName: String, token: String)
    {
        showOverlay()
        channelManager.getMediaInteractionDetails(userName: userName, accessToken: token, limit: "300", offset: "0", success: { (response) in
            self.authenticationSuccessHandler(response: response)
            
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
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
    
    func showOverlay(){
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = CGRect(x:0, y:72, width:self.view.frame.width, height:self.view.frame.height - 72)
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.view.addSubview(self.loadingOverlay!)
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
    
    func years(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: fromDate, to: toDate).year ?? 0
    }
    
    func months(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.month], from: fromDate, to: toDate).month ?? 0
    }
    
    func weeks(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.weekOfYear], from: fromDate, to: fromDate).weekOfYear ?? 0
    }
    
    func days(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
    }
    
    func hours(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: fromDate, to: toDate).hour ?? 0
    }
    
    func minutes(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: fromDate, to: toDate).minute ?? 0
    }
    
    func seconds(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: fromDate, to: toDate).second ?? 0
    }
    
    func offset(fromDate: Date, toDate: Date ) -> String {
        if years(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(years(fromDate: fromDate, toDate: toDate))Y"
        }
        if months(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(months(fromDate: fromDate, toDate: toDate))m"
        }
        if weeks(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(weeks(fromDate: fromDate, toDate: toDate))w"
        }
        if days(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(days(fromDate: fromDate, toDate: toDate))d"
        }
        if hours(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(hours(fromDate: fromDate, toDate: toDate))h"
        }
        if minutes(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(minutes(fromDate: fromDate, toDate: toDate))min"
        }
        if seconds(fromDate: fromDate, toDate: toDate) > 0
        {
            return "Just now"
        }
        return ""
    }
    
    func authenticationSuccessHandler(response:AnyObject?)
    {
        UserDefaults.standard.setValue("0", forKey: "notificationArrived")
        let image = UIImage(named: "noNotif") as UIImage?
        notifImage.setImage(image, for: .normal)
        if let json = response as? [String: AnyObject]
        {
            let mediaResponseArr = json["notification Details"] as! [[String:AnyObject]]
            var mediaId : String = String()
            var mediaThumbUrl : String = String()
            if mediaResponseArr.count > 0
            {
                for element in mediaResponseArr{
                    let liveStreamId =  element["live_stream_detail_id"] as! NSNumber
                    if liveStreamId != 0
                    {
                        mediaId = "\(liveStreamId)"
                    }
                    else
                    {
                        mediaId = "\(element["media_detail_id"]  as! NSNumber)"
                    }
                    
                    let notifType = element["notification_type"] as! String
                    if(notifType.lowercased() == "likes"){
                        mediaThumbUrl = UrlManager.sharedInstance.getThumbImageForMedia(mediaId: mediaId, userName: userId, accessToken: accessToken)
                    }
                    else{
                        mediaThumbUrl = "nomedia"
                    }
                    let userName = element["userName"] as! String
                    
                    let profileImageName = UrlManager.sharedInstance.getUserProfileImageBaseURL() + userId + "/" + accessToken + "/" + userName
                    
                    let notTime = element["created_time_stamp"] as! String
                    let timeDiff = getTimeDifference(dateStr: notTime)
                    let messageFromCloud = element["message"] as! String
                    let message = "\(messageFromCloud)  \(timeDiff)"
                    dataSource.append([mediaIdKey:mediaId,messageKey:message,profileImageKey:profileImageName,mediaImageKey:mediaThumbUrl, notificationTimeKey:notTime, notificationTypeKey:notifType.lowercased(),usernameKey:userName])
                }
            }
            
            if(dataSource.count > 0)
            {
                dataSource.sort(by: { p1, p2 in
                    let time1 = p1[notificationTimeKey] as! String
                    let time2 = p2[notificationTimeKey] as! String
                    return time1 > time2
                })
                if(dataSource.count > 0){
                    fulldataSource.removeAll()
                    operationInNotif.cancel()
                    operationInNotif  = BlockOperation (block: {
                        self.downloadMediaFromGCS(operationObj: self.operationInNotif)
                    })
                    self.operationQueueObjInNotif.addOperation(operationInNotif)
                }
            }
            else{
                removeOverlay()
                addNoDataLabel()
            }
        }
        else
        {
            removeOverlay()
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func addNoDataLabel()
    {
        self.NoDatalabelFormyChanelImageList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoDatalabelFormyChanelImageList.textAlignment = NSTextAlignment.center
        self.NoDatalabelFormyChanelImageList.text = "No Notifications Available"
        self.view.addSubview(self.NoDatalabelFormyChanelImageList)
    }
    
    func downloadMediaFromGCS(operationObj: BlockOperation){
        for i in 0 ..< dataSource.count
        {
            if i < dataSource.count
            {
                if operationObj.isCancelled == true{
                    return
                }
                var mediaImage : UIImage?
                var profileImage : UIImage?
                
                let user = dataSource[i][usernameKey] as! String
                let savingPath = "\(user)Profile"
                let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                let profileImagePath = parentPath! + "/" + savingPath
                let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: profileImagePath)
                
                if fileExistFlag == true{
                    let profileImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: profileImagePath)
                    profileImage = profileImageFromFile!
                }
                else{
                    let profileImageName = dataSource[i][profileImageKey] as! String
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
                }
                
                let mediaThumbUrl = dataSource[i][mediaImageKey] as! String
                if(mediaThumbUrl != "nomedia"){
                    if(mediaThumbUrl != "")
                    {
                        mediaImage = createMediaThumb(mediaName: mediaThumbUrl)
                    }
                    else{
                        mediaImage = UIImage()
                    }
                }
                else{
                    mediaImage = UIImage()
                }
                
                self.fulldataSource.append([self.notificationTypeKey:self.dataSource[i][self.notificationTypeKey]!,self.messageKey:self.dataSource[i][self.messageKey]!, self.profileImageKey:profileImage!, self.mediaImageKey:mediaImage!,self.notificationTimeKey:self.dataSource[i][self.notificationTimeKey]!,mediaIdKey:self.dataSource[i][mediaIdKey]!, mediaUrlKey: mediaThumbUrl])
                
                DispatchQueue.main.async {
                    self.removeOverlay()
                    self.NotificationTableView.reloadData()
                }
            }
        }
    }
    
    func createMediaThumb(mediaName: String) -> UIImage
    {
        var mediaImage : UIImage = UIImage()
        do {
            let url: NSURL = convertStringtoURL(url: mediaName)
            let data = try NSData(contentsOf: url as URL,options: NSData.ReadingOptions())
            if let imageData = data as NSData? {
                if let mediaImage1 = UIImage(data: imageData as Data)
                {
                    mediaImage = mediaImage1
                }
            }
            else
            {
                mediaImage = UIImage(named: "thumb12")!
            }
            
        } catch {
            mediaImage = UIImage(named: "thumb12")!
        }
        return mediaImage
    }
    
    func  getTimeDifference(dateStr:String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
        
        let cloudDate = dateFormatter.date(from: dateStr)
        let localDateStr = dateFormatter.string(from: NSDate() as Date)
        let localDate = dateFormatter.date(from: localDateStr)
        let differenceString =  offset(fromDate: cloudDate!, toDate: localDate!)
        return differenceString
    }
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        UserDefaults.standard.setValue("0", forKey: "notificationArrived")
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
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
}

extension MyChannelNotificationViewController: UITableViewDelegate, UITableViewDataSource
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 75.0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if fulldataSource.count > 0
        {
            return fulldataSource.count
        }
        else
        {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if fulldataSource.count > indexPath.row
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: MyChannelNotificationCell.identifier, for:indexPath) as! MyChannelNotificationCell
            
            cell.NotificationSenderImageView.image = fulldataSource[indexPath.row][profileImageKey] as? UIImage
            
            if(fulldataSource[indexPath.row][mediaUrlKey] as! String != "nomedia"){
                cell.NotificationImage.isHidden = false
                cell.notificationText.isHidden = false
                cell.notifcationTextFullscreen.isHidden = true
                
                cell.notificationText.text = fulldataSource[indexPath.row][messageKey] as? String
                
                if fulldataSource[indexPath.row][mediaImageKey] != nil
                {
                    cell.NotificationImage.image = fulldataSource[indexPath.row][mediaImageKey] as? UIImage
                }
                else{
                    cell.NotificationImage.image = UIImage(named:"thumb12")
                }
            }
            else{
                cell.NotificationImage.image = UIImage()
                cell.NotificationImage.isHidden = true
                cell.notifcationTextFullscreen.isHidden = false
                cell.notificationText.isHidden = true
                cell.notifcationTextFullscreen.text = fulldataSource[indexPath.row][messageKey] as? String
            }
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        //        print(fulldataSource[indexPath.row])
    }
}
