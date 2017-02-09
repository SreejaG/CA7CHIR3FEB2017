
import UIKit

class ChannelsSharedController: UIViewController,UIScrollViewDelegate  {
    var mediaShared:[[String:Any]] = [[String:Any]]()
    var loadingOverlay: UIView?
    var refreshControl:UIRefreshControl!
    var downloadCompleteFlag : String = "start"
    var pullToRefreshActive = false
    @IBOutlet weak var ChannelSharedTableView: UITableView!
    var tapCountChannelShared : Int = 0
    var isNeedRefresh : Bool = false
    @IBOutlet weak var leadingLabelConstraint: NSLayoutConstraint!
    var pushNotificationFlag : Bool = false
    @IBOutlet weak var newShareAvailabellabel: UILabel!
    let calendar = NSCalendar.current
    var refreshAlert : UIAlertController = UIAlertController()
    var NoDatalabel : UILabel = UILabel()
    var timer : Timer = Timer()
    var customViewForStreamChannelFlag : Bool = false
    var customViewForStreamChannel = CustomInfiniteIndicator()
    override func viewDidLoad() {
        super.viewDidLoad()
        newShareAvailabellabel.layer.cornerRadius = 5
        initialise()
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(ChannelsSharedController.timerFunc(timer:)), userInfo: nil, repeats: false)
        
        if UserDefaults.standard.object(forKey: "NotificationChannelText") != nil{
            let messageText = UserDefaults.standard.object(forKey: "NotificationChannelText") as! String
            if(messageText != "")
            {
                self.newShareAvailabellabel.isHidden = false
                self.newShareAvailabellabel.text = messageText
            }
            UserDefaults.standard.set("", forKey: "NotificationChannelText")
        }
    }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        SharedChannelDetailsAPI.sharedInstance.imageDataSource.removeAll()
        SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.removeAll()
        let cameraViewStoryboard = UIStoryboard(name:"IPhoneCameraView" , bundle: nil)
        let iPhoneCameraVC = cameraViewStoryboard.instantiateViewController(withIdentifier: "IPhoneCameraViewController") as! IPhoneCameraViewController
        iPhoneCameraVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(iPhoneCameraVC, animated: false)
        
    }
    func timerFunc(timer:Timer!) {
        
        if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count == 0)
        {
            DispatchQueue.main.async {
                self.removeOverlay()
                if (GlobalStreamList.sharedInstance.GlobalStreamDataSource.count == 0)
                {
                    let startcount : Int = UserDefaults.standard.value(forKey: "streamChannelCount") as! Int
                    if startcount <= 0
                    {
                        self.removeOverlay()
                        self.NoDatalabel.removeFromSuperview()
                        self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                        self.NoDatalabel.textAlignment = NSTextAlignment.center
                        self.NoDatalabel.text = "No Channel Available"
                        self.view.addSubview(self.NoDatalabel)
                    }
                }
            }
        }
        else
        {
            DispatchQueue.main.async {
                self.removeOverlay()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        ChannelSharedTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        refreshAlert = UIAlertController()
        ChannelSharedListAPI.sharedInstance.cancelOperationQueue()
    }
    
    func initialise()
    {
        self.refreshControl = UIRefreshControl()
        let startcount : Int = UserDefaults.standard.value(forKey: "streamChannelCount") as! Int
        if ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count >= startcount
        {
            customViewForStreamChannelFlag = false
            self.NoDatalabel.removeFromSuperview()
            self.removeOverlay()
            self.refreshControl.addTarget(self, action: #selector(ChannelsSharedController.pullToRefresh), for: UIControlEvents.valueChanged)
            self.ChannelSharedTableView.addSubview(self.refreshControl)
            self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
            self.ChannelSharedTableView.alwaysBounceVertical = true
        }
        else{
            customViewForStreamChannelFlag = true
            self.NoDatalabel.removeFromSuperview()
            self.refreshControl.endRefreshing()
            self.refreshControl.removeTarget(self, action: #selector(ChannelsSharedController.pullToRefresh), for: UIControlEvents.valueChanged)
            DispatchQueue.main.async {
                self.removeOverlay()
                self.customViewForStreamChannel.stopAnimationg()
                self.customViewForStreamChannel.removeFromSuperview()
                self.customViewForStreamChannel = CustomInfiniteIndicator(frame: CGRect(x:(self.ChannelSharedTableView.layer.frame.width/2 - 20), y:(self.ChannelSharedTableView.contentSize.height + 20), width:40, height:40))
                self.ChannelSharedTableView.addSubview(self.customViewForStreamChannel)
                self.customViewForStreamChannel.startAnimating()
            }
        }
        
        let SharedChannelList = Notification.Name("SharedChannelList")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelsSharedController.updateChannelList(notif:)), name: SharedChannelList, object: nil)
        
        let PushNotificationChannel = Notification.Name("PushNotificationChannel")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelsSharedController.pushNotificationUpdate(notif:)), name: PushNotificationChannel, object: nil)
        
        let PullToRefreshSharedChannelList = Notification.Name("PullToRefreshSharedChannelList")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelsSharedController.pullToRefreshUpdate(notif:)), name: PullToRefreshSharedChannelList, object: nil)
        
        let RemoveOverlay = Notification.Name("RemoveOverlay")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelsSharedController.removeOverlay), name: RemoveOverlay, object: nil)
        
        newShareAvailabellabel.isHidden = true
        if startcount > 0
        {
            self.NoDatalabel.removeFromSuperview()
            if (ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count == 0)
            {
                let userId = UserDefaults.standard.value(forKey: userLoginIdKey) as! String
                let accessToken = UserDefaults.standard.value(forKey: userAccessTockenKey) as! String
                ChannelSharedListAPI.sharedInstance.getChannelSharedDetails(userName: userId, token: accessToken)
            }else
            {
                DispatchQueue.main.async {
                    self.ChannelSharedTableView.reloadData()
                    self.removeOverlay()
                }
            }
        }
        else{
            if (ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count == 0)
            {
                self.NoDatalabel.removeFromSuperview()
                self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                self.NoDatalabel.textAlignment = NSTextAlignment.center
                self.NoDatalabel.text = "No Channel Available"
                self.view.addSubview(self.NoDatalabel)
            }
        }
    }
    
    // channel delete push notification handler
    func channelDeletionPushNotification(info:  [String : AnyObject])
    {
        DispatchQueue.main.async {
            if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count == 0)
            {
                self.NoDatalabel.removeFromSuperview()
                self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                self.NoDatalabel.textAlignment = NSTextAlignment.center
                self.NoDatalabel.text = "No Channel Available"
                self.view.addSubview(self.NoDatalabel)
            }
            else
            {
                UserDefaults.standard.set(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count, forKey: "streamChannelCount")
                
                self.NoDatalabel.removeFromSuperview()
            }
            self.ChannelSharedTableView.reloadData()
        }
    }
    
    func channelPushNotificationLiveStarted(info: [String : AnyObject])
    {
        let subType = info["subType"] as! String
        
        switch subType {
        case "started":
            ErrorManager.sharedInstance.streamAvailable()
            updateLiveStreamStartedEntry(info: info)
            break;
        case "stopped":
            updateLiveStreamStoppeddEntry(info: info)
            break;
            
        default:
            break;
        }
    }
    
    func updateLiveStreamStartedEntry(info:[String : Any])
    {
        let channelId = info["channelId"] as! Int
        let index  = getUpdateIndexChannel(channelIdValue: "\(channelId)", isCountArray: false)
        if(index != -1)
        {
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][liveStreamStatus] = "1"
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][streamTockenKey] = "1"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
            let currentDate = dateFormatter.string(from: NSDate() as Date)
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][timeStamp] = currentDate
            DispatchQueue.main.async {
                let itemToMove = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index]
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.remove(at: index)
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.insert(itemToMove, at: 0)
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.sort(by: { p1, p2 in
                    
                    let time1 = p1[liveStreamStatus] as! String
                    let time2 = p2[liveStreamStatus] as! String
                    return time1 > time2
                })
                self.ChannelSharedTableView.reloadData()
            }
        }
        else{
            newShareAvailabellabel.isHidden = false
            newShareAvailabellabel.text = "Live stream available"
        }
    }
    
    func isVisibleCell(index : Int ) -> Bool
    {
        if let indices = ChannelSharedTableView.indexPathsForVisibleRows {
            for index1 in indices {
                if Int(index1.row) == index {
                    return true
                }
            }
        }
        return false
    }
    
    func thumbExists (item: [String : Any]) -> Bool {
        let liveStreamStatus = "liveChannel"
        return item[liveStreamStatus] as! String == "1"
    }
    
    func updateLiveStreamStoppeddEntry(info:[String : AnyObject])
    {
        let channelId = info["channelId"] as! Int
        let index  = getUpdateIndexChannel(channelIdValue: "\(channelId)", isCountArray: false)
        if(index != -1)
        {
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][ liveStreamStatus] = "0"
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][ streamTockenKey] = "0"
            
            let filteredData = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.filter(thumbExists)
            let totalCount = filteredData.count
            
            DispatchQueue.main.async {
                let itemToMove = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index]
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.remove(at: index)
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.insert(itemToMove, at: totalCount)
                self.ChannelSharedTableView.reloadData()
            }
        }
    }
    
    func pushNotificationUpdate(notif: NSNotification)
    {
        let info = notif.object as! [String : AnyObject]
        if (info["type"] as! String == "share"){
            DispatchQueue.main.async {
                if(self.downloadCompleteFlag != "end")
                {
                    self.newShareAvailabellabel.isHidden = true
                }
                self.ChannelSharedTableView.reloadData()
            }
        }
        else if (info["type"] as! String == "channel")
        {
            self.pushNotificationFlag = false
            
            if(info["subType"] as! String == "useradded")
            {
                newShareAvailabellabel.isHidden = false
                newShareAvailabellabel.text = info[ "messageText"] as? String
            }
            else{
                if(!ChannelSharedTableView.visibleCells.isEmpty)
                {
                    refreshAlert = UIAlertController(title: "Deleted", message: "Shared channel deleted.", preferredStyle: UIAlertControllerStyle.alert)
                    
                    refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
                    }))
                    self.present(refreshAlert, animated: true, completion: nil)
                    self.channelDeletionPushNotification(info: info)
                }
            }
        }
        else if (info["type"] as! String == "liveStream")
        {
            channelPushNotificationLiveStarted(info: info)
        }
        else
        {
            ChannelSharedTableView.reloadData()
        }
    }
    
    func topMostController() -> UIViewController {
        var topController: UIViewController = UIApplication.shared.keyWindow!.rootViewController!
        while (topController.presentedViewController != nil) {
            topController = topController.presentedViewController!
        }
        return topController
    }
    
    func getUpdateIndexChannel(channelIdValue : String , isCountArray : Bool) -> Int
    {
        var selectedArray : [[String:Any]] = [[String:Any]]()
        var indexOfRow : Int = -1
        if(isCountArray)
        {
            if (UserDefaults.standard.object(forKey: "Shared") != nil)
            {
                mediaShared.removeAll()
                mediaShared = UserDefaults.standard.value(forKey: "Shared") as! NSArray as! [[String : AnyObject]]
                selectedArray = mediaShared as Array
            }
            
        }
        else{
            selectedArray = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource
        }
        var  checkFlag : Bool = false
        var index : Int =  Int()
        
        for i in 0  ..< selectedArray.count
        {
            let channelId = selectedArray[i][ch_channelIdkey]!
            if "\(channelId)"  == channelIdValue
            {
                checkFlag = true
                index = i
            }
        }
        if(checkFlag)
        {
            indexOfRow = index
        }
        return indexOfRow
    }
    
    func updateChannelList(notif : NSNotification)
    {
        UserDefaults.standard.set(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count, forKey: "streamChannelCount")
        customViewForStreamChannelFlag = false
        DispatchQueue.main.async {
            self.customViewForStreamChannel.stopAnimationg()
            self.customViewForStreamChannel.removeFromSuperview()
            self.refreshControl.endRefreshing()
            self.refreshControl.removeTarget(self, action: #selector(ChannelsSharedController.pullToRefresh), for: UIControlEvents.valueChanged)
            self.refreshControl.addTarget(self, action: #selector(ChannelsSharedController.pullToRefresh), for: UIControlEvents.valueChanged)
            self.ChannelSharedTableView.addSubview(self.refreshControl)
            self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
            self.ChannelSharedTableView.alwaysBounceVertical = true
        }
        if(self.downloadCompleteFlag == "start")
        {
            downloadCompleteFlag = "end"
        }
        DispatchQueue.main.async {
            self.newShareAvailabellabel.isHidden = true
            self.removeOverlay()
            if(self.pullToRefreshActive){
                self.refreshControl.endRefreshing()
                self.pullToRefreshActive = false
            }
        }
        let success =  notif.object as! String
        if(success == "success")
        {
            if !pushNotificationFlag
            {
                DispatchQueue.main.async {
                    self.removeOverlay()
                    self.ChannelSharedTableView.reloadData()
                    if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > 0)
                    {
                        self.NoDatalabel.removeFromSuperview()
                    }
                }
            }
            else{
                DispatchQueue.main.async {
                    self.pushNotificationFlag = false
                    self.removeOverlay()
                    self.ChannelSharedTableView.reloadData()
                }
            }
        }
        else{
            DispatchQueue.main.async {
                self.removeOverlay()
                self.pushNotificationFlag = false
            }
            DispatchQueue.main.async {
                if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count == 0)
                {
                    self.NoDatalabel.removeFromSuperview()
                    self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                    self.NoDatalabel.textAlignment = NSTextAlignment.center
                    self.NoDatalabel.text = "No Channel Available"
                    self.view.addSubview(self.NoDatalabel)
                }
                else
                {
                    self.NoDatalabel.removeFromSuperview()
                }
            }
        }
    }
    
    func pullToRefresh()
    {
        newShareAvailabellabel.isHidden = true
        UserDefaults.standard.set("", forKey: "NotificationChannelText")
        pullToRefreshActive = true
        let sortList : Array = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource
        var subIdArray : [Int] = [Int]()
        
        for i in 0  ..< sortList.count
        {
            let subId = sortList[i][subChannelIdKey] as! String
            subIdArray.append(Int(subId)!)
        }
        if(subIdArray.count > 0)
        {
            let subid = subIdArray.max()!
            
            if(!pushNotificationFlag)
            {
                if(pullToRefreshActive){
                    pushNotificationFlag = true
                    isNeedRefresh = false
                    ChannelSharedListAPI.sharedInstance.dataSource.removeAll()
                    ChannelSharedListAPI.sharedInstance.dummy.removeAll()
                    ChannelSharedListAPI.sharedInstance.pullToRefreshSource.removeAll()
                    ChannelSharedListAPI.sharedInstance.pullToRefreshData(subID: "\(subid)")
                }
            }
            else{
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                }
                self.pullToRefreshActive = false
            }
        }
        else
        {
            ChannelSharedListAPI.sharedInstance.dataSource.removeAll()
            ChannelSharedListAPI.sharedInstance.dummy.removeAll()
            ChannelSharedListAPI.sharedInstance.pullToRefreshSource.removeAll()
            ChannelSharedListAPI.sharedInstance.initialisedata()
        }
    }
    
    func pullToRefreshUpdate(notif : NSNotification)
    {
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
            self.pullToRefreshActive = false
        }
        let success =  notif.object as! String
        if(success == "success")
        {
            DispatchQueue.main.async {
                var dataSourceIndex = ChannelSharedListAPI.sharedInstance.pullToRefreshSource.count - 1
                while(dataSourceIndex >= 0){
                    var flag : Bool = false
                    for i in 0  ..< ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count
                    {
                        let chId =  ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[i][ch_channelIdkey] as! String
                        
                        let chId2 = ChannelSharedListAPI.sharedInstance.pullToRefreshSource[dataSourceIndex][ch_channelIdkey] as! String
                        if(chId == chId2)
                        {
                            flag = true
                        }
                    }
                    if(!flag)
                    {
                        ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.insert(ChannelSharedListAPI.sharedInstance.pullToRefreshSource[dataSourceIndex] , at: 0)
                    }
                    dataSourceIndex -= 1
                }
                DispatchQueue.main.async {
                    if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > 0)
                    {
                        self.NoDatalabel.removeFromSuperview()
                    }
                    self.ChannelSharedTableView.reloadData()
                }
            }
            UserDefaults.standard.set(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count, forKey: "streamChannelCount")
        }
        else{
            
            DispatchQueue.main.async {
                self.customViewForStreamChannel.stopAnimationg()
                self.customViewForStreamChannel.removeFromSuperview()
                self.refreshControl.endRefreshing()
                self.refreshControl.removeTarget(self, action: #selector(ChannelsSharedController.pullToRefresh), for: UIControlEvents.valueChanged)
                self.refreshControl.addTarget(self, action: #selector(ChannelsSharedController.pullToRefresh), for: UIControlEvents.valueChanged)
                self.ChannelSharedTableView.addSubview(self.refreshControl)
                self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
                self.ChannelSharedTableView.alwaysBounceVertical = true
            }
            self.pullToRefreshActive = false
        }
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
}

extension ChannelsSharedController:UITableViewDataSource, UITableViewDelegate
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > 0
        {
            return ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count
        }
        else
        {
            return 0
        }
        
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        DispatchQueue.main.async {
            if(self.customViewForStreamChannelFlag){
                self.customViewForStreamChannel.stopAnimationg()
                self.customViewForStreamChannel.removeFromSuperview()
                self.customViewForStreamChannel = CustomInfiniteIndicator(frame: CGRect(x:(self.ChannelSharedTableView.layer.frame.width/2 - 20), y:(self.ChannelSharedTableView.contentSize.height + 20), width:40, height:40))
                self.ChannelSharedTableView.addSubview(self.customViewForStreamChannel)
                self.customViewForStreamChannel.startAnimating()
            }
            self.removeOverlay()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > indexPath.row
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: ChannelSharedCell.identifier, for:indexPath) as! ChannelSharedCell
            cell.channelProfileImage.image = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][profileImageKey] as? UIImage
            cell.channelNameLabel.text =   ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][ch_channelNameKey] as? String
            cell.countLabel.isHidden = true
            if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][liveStreamStatus] as! String == "1")
            {
                cell.currentUpdationImage.isHidden = false
                cell.latestImage.isHidden = true
                let text = "@" + (ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][usernameKey] as! String) + " Live"
                cell.currentUpdationImage.image  = UIImage(named: "Live_camera")
                let linkTextWithColor = "Live"
                let range = (text as NSString).range(of: linkTextWithColor)
                let attributedString = NSMutableAttributedString(string:text)
                attributedString.addAttribute(NSForegroundColorAttributeName, value: UIColor.red , range: range)
                cell.detailLabel.attributedText = attributedString
            }
            else
            {
                if (UserDefaults.standard.object(forKey: "Shared") != nil)
                {
                    mediaShared.removeAll()
                    mediaShared = UserDefaults.standard.value(forKey: "Shared") as! NSArray as! [[String : Any]]
                }
                cell.countLabel.isHidden = false
                cell.currentUpdationImage.isHidden = true
                for i in 0  ..< mediaShared.count
                {
                    if(Int(mediaShared[i][ch_channelIdkey] as! String) == Int(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][ch_channelIdkey] as! String))
                    {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                        dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
                        var date = dateFormatter.date(from: ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][timeStamp] as! String)
                        let fromdateStr = dateFormatter.string(from: NSDate() as Date)
                        var fromdate = dateFormatter.date(from: fromdateStr)
                        let sdifferentString = offset(fromDate: date!, toDate: fromdate!)
                        let count = Int(mediaShared[i][sharedMediaCount] as! String)!
                        let text = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][usernameKey] as! String
                        if( count == 0)
                        {
                            cell.latestImage.isHidden = false
                            cell.countLabel.isHidden = true
                            cell.latestImage.image  = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][mediaImageKey] as? UIImage
                            cell.detailLabel.text = "@" + text + " " +  sdifferentString
                        }
                        else
                        {
                            cell.latestImage.isHidden = true
                            cell.countLabel.isHidden = false
                            cell.countLabel.text = String(count)
                            cell.detailLabel.text = "@" + text + " " +  sdifferentString
                        }
                        
                        date = nil
                        fromdate = nil
                    }
                }
            }
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let streamingStoryboard = UIStoryboard(name:"Streaming", bundle: nil)
        let channelItemListVC = streamingStoryboard.instantiateViewController(withIdentifier: OtherChannelViewController.identifier) as! OtherChannelViewController
        let chId = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][ch_channelIdkey] as! String
        UserDefaults.standard.set(chId, forKey: "SharedChannelId")
        let index  = getUpdateIndexChannel(channelIdValue: chId, isCountArray: true)
        if(index != -1)
        {
            let sharedCount = mediaShared[index][sharedMediaCount] as! String
            channelItemListVC.channelId = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][ch_channelIdkey] as! String
            channelItemListVC.channelName = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][ch_channelNameKey] as! String
            channelItemListVC.totalMediaCount = sharedCount
            channelItemListVC.userName = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][usernameKey] as! String
            channelItemListVC.profileImage = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexPath.row][profileImageKey] as! UIImage
            channelItemListVC.navigationController?.isNavigationBarHidden = true
            self.navigationController?.pushViewController(channelItemListVC, animated: false)
        }
    }
    
    func loadLiveStreamView(streamTocken:String)
    {
        let vc = MovieViewController.movieViewController(withContentPath: "rtsp://\(vowzaIp):1935/live/\(streamTocken)", parameters: nil , liveVideo: false) as! UIViewController
        self.present(vc, animated: false) { () -> Void in
            
        }
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
            return "\(months(fromDate: fromDate, toDate: toDate))M"
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
            return "\(minutes(fromDate: fromDate, toDate: toDate))m"
        }
        if seconds(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(seconds(fromDate: fromDate, toDate: toDate))s"
        }
        if seconds(fromDate: fromDate, toDate: toDate) == 0
        {
            return "0s"
        }
        return ""
    }
}

