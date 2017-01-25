
import UIKit

class OtherChannelViewController: UIViewController  {
    let imageUploadManger = ImageUpload.sharedInstance
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    static let identifier = "OtherChannelViewController"
    var lastContentOffset: CGPoint = CGPoint()
    var totalMediaCount: String = String()
    var channelId:String!
    var channelName:String!
    var userName:String!
    var profileImage : UIImage!
    var offset: String = "0"
    var offsetToInt : Int = Int()
    let isWatched = "isWatched"
    var loadingOverlay: UIView?
    var mediaSharedCountArray:[[String:Any]] = [[String:Any]]()
    let cameraController = IPhoneCameraViewController()
    var refreshControl:UIRefreshControl!
    var limit : Int = Int()
    var fixedLimit : Int =  0
    var isLimitReached : Bool = true
    var currentLimit : Int = 0
    var limitMediaCount : Int = Int()
    var downloadCompleteFlag : String = "start"
    var pullToRefreshActive = false
    @IBOutlet weak var channelItemsCollectionView: UICollectionView!
    @IBOutlet weak var channelTitleLabel: UILabel!
    let sharedMediaCount = "total_no_media_shared"
    var scrollObj = UIScrollView()
    var NoDatalabel : UILabel = UILabel()
    var liveStreamFlag : Bool = false
    var vc : MovieViewController = MovieViewController()
    var customView = CustomInfiniteIndicator()
    
    var operationQueueObjRedirectionOtherChannel = OperationQueue()
    var operationInRedirectionOtherChannel = BlockOperation()

    
    @IBOutlet weak var notificationLabel: UILabel!
    override func viewDidLoad()
    {
        super.viewDidLoad()
        NotificationCenter.default.removeObserver(self)
        
        let SharedChannelMediaDetail = Notification.Name("SharedChannelMediaDetail")
        NotificationCenter.default.addObserver(self, selector:#selector(OtherChannelViewController.updateChannelMediaList(notif:)), name: SharedChannelMediaDetail, object: nil)
        
        let DeletedObject = Notification.Name("DeletedObject")
        NotificationCenter.default.addObserver(self, selector:#selector(OtherChannelViewController.ObjectDeleted(notif:)), name: DeletedObject, object: nil)
        
        let PushNotification = Notification.Name("PushNotification")
        NotificationCenter.default.addObserver(self, selector:#selector(OtherChannelViewController.pushNotificationUpdateStream(notif:)), name: PushNotification, object: nil)
        
        let CountIncrementedPushNotification = Notification.Name("CountIncrementedPushNotification")
        NotificationCenter.default.addObserver(self, selector:#selector(OtherChannelViewController.checkCountIncrementInSelectedChannel(notif:)), name: CountIncrementedPushNotification, object: nil)
        
        let ViewMediaDeleted = Notification.Name("ViewMediaDeleted")
        NotificationCenter.default.addObserver(self, selector:#selector(OtherChannelViewController.dismissFullView(notif:)), name: ViewMediaDeleted, object: nil)
        
        let ViewMediaDeletedMyDAyCleanUp = Notification.Name("ViewMediaDeletedMyDAyCleanUp")
        NotificationCenter.default.addObserver(self, selector:#selector(OtherChannelViewController.dismissFullViewWhileMyDayCleanUp(notif:)), name: ViewMediaDeletedMyDAyCleanUp, object: nil)
        
        self.notificationLabel.isHidden = true
        self.refreshControl = UIRefreshControl()
        self.channelItemsCollectionView.alwaysBounceVertical = true
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: #selector(StreamsListViewController.pullToRefresh),for : UIControlEvents.valueChanged)
        self.channelItemsCollectionView.addSubview(self.refreshControl)
        isWatchedTrue()
        createScrollViewAnimations()
        
        showOverlay()
        SharedChannelDetailsAPI.sharedInstance.getSubscribedChannelData(channelId: channelId
            , selectedChannelName: channelName, selectedChannelUserName: userName , sharedCount: totalMediaCount)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        channelItemsCollectionView.alpha = 1.0
        self.tabBarItem.selectedImage = UIImage(named:"all_media_blue")?.withRenderingMode(.alwaysOriginal)
        if let channelName = channelName
        {
            channelTitleLabel.text = channelName.uppercased()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        operationQueueObjRedirectionOtherChannel.cancelAllOperations()
        channelItemsCollectionView.alpha = 1.0
        self.customView.removeFromSuperview()
        removeOverlay()
        NotificationCenter.default.removeObserver(self, name: Notification.Name("SharedChannelMediaDetail"), object: nil)
    }
    func dismissFullView(notif: NSNotification)
    {
        let mediaId = notif.object as! String
        let obj : SetUpView = SetUpView()
        obj.callDelete(obj: vc, mediaId: mediaId)
    }
    
    func dismissFullViewWhileMyDayCleanUp(notif: NSNotification)
    {
        if UserDefaults.standard.value(forKey: "SharedChannelId") != nil{
            let channelIdValue = UserDefaults.standard.value(forKey: "SharedChannelId") as! String
            let obj : SetUpView = SetUpView()
            obj.callDeleteWhileMyDayCleanUp(obj: vc, channelId:channelIdValue)
        }
    }
    
    func pushNotificationUpdateStream(notif: NSNotification)
    {
        let info = notif.object as! [String : Any]
        if (info["type"] as! String == "liveStream")
        {
            channelPushNotificationLiveStarted(info: info)
        }
        else if (info["type"] as! String == "channel")
        {
            if (info["subType"] as! String == "deleted")
            {
                let chId = info["channelId"]!
                if("\(chId)" == channelId as String )
                {
                    channelRemoved()
                }
            }
        }
    }
    
    func channelRemoved()
    {
        DispatchQueue.main.async {
            let refreshAlert = UIAlertController(title: "Deleted", message: "User deleted shared channel.", preferredStyle: UIAlertControllerStyle.alert)
            
            refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            }))
            self.present(refreshAlert, animated: true, completion: nil)
            self.channelItemsCollectionView.reloadData()
            self.NoDatalabel.removeFromSuperview()
            SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.removeAll()
            if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count == 0)
            {
                self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                self.NoDatalabel.textAlignment = NSTextAlignment.center
                self.NoDatalabel.text = "No Media Available"
                self.view.addSubview(self.NoDatalabel)
            }
            if(self.pullToRefreshActive)
            {
                self.pullToRefreshActive = false
                self.refreshControl.endRefreshing()
                
            }
        }
    }
    
    func checkCountIncrementInSelectedChannel(notif : NSNotification)
    {
        let channel = notif.object!
        if  "\(channel)" == channelId as String
        {
            DispatchQueue.main.async {
                self.notificationLabel.isHidden = false
                self.notificationLabel.text = "Pull to get new media"
            }
        }
    }
    
    func channelPushNotificationLiveStarted(info: [String : Any])
    {
        let subType = info["subType"] as! String
        let chId = info["channelId"]!
        
        switch subType {
        case "started":
            liveStreamFlag = false
            if("\(chId)" == channelId as String )
            {
                notificationLabel.isHidden = false
                notificationLabel.text = "pull to get livestream"
            }
            break;
        case "stopped":
            liveStreamFlag = true
            updateLiveStreamStoppeddEntry(info: info)
            break;
        default:
            break;
        }
    }
    
    func updateLiveStreamStartedEntry(info:[String : Any])
    {
        ErrorManager.sharedInstance.streamAvailable()
    }
    
    func updateLiveStreamStoppeddEntry(info:[String : Any])
    {
        if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
        {
            let type = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[0][stream_mediaTypeKey] as! String
            if(type == "live")
            {
                DispatchQueue.main.async {
                    if ( SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
                    {
                        SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.remove(at: 0)
                        self.channelItemsCollectionView.reloadData()
                    }
                }
            }
            else
            {
                DispatchQueue.main.async {
                    self.channelItemsCollectionView.reloadData()
                }
            }
        }
    }
    
    func createScrollViewAnimations()  {
        channelItemsCollectionView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x:0, y:0, width:40, height:40))
        channelItemsCollectionView.infiniteScrollIndicatorMargin = 50
        channelItemsCollectionView.addInfiniteScroll {  (scrollView) -> Void in
            
            if(!self.pullToRefreshActive)
            {
                self.scrollObj = scrollView
                self.getInfinteScrollData()
            }
            else
            {
                scrollView.finishInfiniteScroll()
            }
        }
    }
    
    func pullToRefresh()
    {
        if(!pullToRefreshActive){
            pullToRefreshActive = true
            do {
                if SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0
                {
                    getPullToRefreshData()
                }
                    
                else{
                    if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count == 0)
                    {
                        if self.downloadCompleteFlag == "end"
                        {
                            self.downloadCompleteFlag = "start"
                            SharedChannelDetailsAPI.sharedInstance.getMedia(channelId: channelId
                                , selectedChannelName: channelName, selectedChannelUserName: userName , sharedCount: totalMediaCount)
                        }
                    }
                }
            }
        }
        else
        {
            pullToRefreshActive = false
            self.refreshControl.endRefreshing()
        }
    }
    
    func ObjectDeleted(notif: NSNotification)
    {
        DispatchQueue.main.async {
            self.channelItemsCollectionView.reloadData()
            self.NoDatalabel.removeFromSuperview()
            if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count == 0)
            {
                self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                self.NoDatalabel.textAlignment = NSTextAlignment.center
                self.NoDatalabel.text = "No Media Available"
                self.view.addSubview(self.NoDatalabel)
            }
            if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count < 18 && SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count != 0)
            {
                self.getInfinteScrollData()
                DispatchQueue.main.async {
                    self.customView.removeFromSuperview()
                    self.channelItemsCollectionView.isUserInteractionEnabled = false
                    self.customView  = CustomInfiniteIndicator(frame: CGRect(x:(self.channelItemsCollectionView.layer.frame.width/2 - 20), y:(self.channelItemsCollectionView.layer.frame.height - 100), width:40, height:40))
                    self.channelItemsCollectionView.addSubview(self.customView)
                    self.customView.startAnimating()
                }
                
            }
            if(self.pullToRefreshActive)
            {
                self.pullToRefreshActive = false
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    func updateChannelMediaList(notif: NSNotification)
    {
        DispatchQueue.main.async {
            self.scrollObj.finishInfiniteScroll()
            self.scrollObj = UIScrollView()
            self.notificationLabel.isHidden = true
            if(self.downloadCompleteFlag == "start")
            {
                self.downloadCompleteFlag = "end"
            }
            if(self.pullToRefreshActive){
                self.refreshControl.endRefreshing()
                self.pullToRefreshActive = false
            }
        }
        let success =  notif.object as! String
        if(success == "success")
        {
            DispatchQueue.main.async {
                if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
                {
                    self.removeOverlay()
                    self.channelItemsCollectionView.reloadData()
                    self.NoDatalabel.removeFromSuperview()
                }
                
            }
        }
        else if((success == "USER004") || (success == "USER005") || (success == "USER006")){
            loadInitialViewController(code: success)
        }
        else{
            DispatchQueue.main.async {
                self.removeOverlay()
                self.NoDatalabel.removeFromSuperview()
                if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count == 0)
                {
                    self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                    self.NoDatalabel.textAlignment = NSTextAlignment.center
                    self.NoDatalabel.text = "No Media Available"
                    self.view.addSubview(self.NoDatalabel)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.channelItemsCollectionView.isUserInteractionEnabled = true
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
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
    
    @IBAction func backClicked(_ sender: Any)
    {
        self.setMediaimage()
        UserDefaults.standard.set(0, forKey: "SelectedTab")
        let sharingStoryboard = UIStoryboard(name:"Streaming", bundle: nil)
        let sharingVC = sharingStoryboard.instantiateViewController(withIdentifier: StreamsGalleryViewController.identifier) as! StreamsGalleryViewController
        sharingVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(sharingVC, animated: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
    
    func isWatchedTrue(){
        let defaults = UserDefaults.standard
        mediaSharedCountArray = defaults.value(forKey: "Shared") as! NSArray as! [[String : AnyObject]]
        for i in 0  ..< mediaSharedCountArray.count
        {
            if  mediaSharedCountArray[i][channelIdkey] as! String == channelId as String
            {
                mediaSharedCountArray[i][sharedMediaCount] = "0"
                let defaults = UserDefaults .standard
                defaults.set(mediaSharedCountArray, forKey: "Shared")
            }
        }
    }
    
    func setMediaimage()
    {
        let mediaImageKey = "mediaImage"
        var flag : Bool = false
        var index : Int = Int()
        for i in 0  ..< ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count
        {
            if  ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[i][channelIdkey] as! String == channelId as String
            {
                if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
                {
                    flag = true
                    index = i
                }
                else{
                    index = i
                }
            }
        }
        if(flag)
        {
            if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
            {
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][mediaImageKey] = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[0][stream_thumbImageKey] as! UIImage
            }
        }
        else{
            if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count == 0)
            {
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[index][mediaImageKey] =  UIImage()
            }
        }
    }
    
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        self.lastContentOffset = scrollView.contentOffset
    }
    
    func getInfinteScrollData()
    {
        self.downloadCompleteFlag = "start"
        let sortList : Array = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource
        var subIdArray : [Int] = [Int]()
        for i in 0  ..< sortList.count
        {
            let id = sortList[i]["channel_media_detail_id"] as! String
            if(id != "")
            {
                subIdArray.append(Int(id)!)
            }
        }
        if(subIdArray.count > 0)
        {
            let subid = subIdArray.min()!
            let channelSelectedMediaId =  "\(subid)"
            let userId = UserDefaults.standard.value(forKey: userLoginIdKey) as! String
            SharedChannelDetailsAPI.sharedInstance.infiniteScroll(channelId: channelId, selectedChannelName: channelName, selectedChannelUserName: userId, channelMediaId: channelSelectedMediaId)
        }
        else{
            self.downloadCompleteFlag = "end"
            removeOverlay()
        }
        
    }
    
    func getPullToRefreshData()
    {
        if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count >= 2)
        {
            let type  = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[0][stream_mediaTypeKey] as! String
            if type != "live"
            {
                let sortList : Array = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource
                if self.downloadCompleteFlag == "end"
                {
                    self.downloadCompleteFlag = "start"
                    var subIdArray : [Int] = [Int]()
                    for i in 0  ..< sortList.count
                    {
                        subIdArray.append(Int(sortList[i]["channel_media_detail_id"] as! String)!)
                    }
                    if(subIdArray.count > 0)
                    {
                        let subid = subIdArray.max()
                        let channelSelectedMediaId = subid!
                        let userId = UserDefaults.standard.value(forKey: userLoginIdKey) as! String
                        SharedChannelDetailsAPI.sharedInstance.pullToRefresh(channelId: channelId, selectedChannelUserName: userId, channelMediaId: "\(channelSelectedMediaId)")
                    }
                }
            }
            else{
                let userId = UserDefaults.standard.value(forKey: userLoginIdKey) as! String
                if self.downloadCompleteFlag == "end"
                {
                    let sortList : Array = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource
                    self.downloadCompleteFlag = "start"
                    var subIdArray : [Int] = [Int]()
                    for i in 1  ..< sortList.count
                    {
                        subIdArray.append(Int(sortList[i]["channel_media_detail_id"] as! String)!)
                    }
                    if subIdArray.count > 0
                    {
                        let subid = subIdArray.max()
                        let channelSelectedMediaId = subid!
                        SharedChannelDetailsAPI.sharedInstance.pullToRefresh(channelId: channelId, selectedChannelUserName: userId, channelMediaId: "\(channelSelectedMediaId)")
                    }
                }
            }
        }
        else
        {
            if self.downloadCompleteFlag == "end"
            {
                self.downloadCompleteFlag = "start"
                SharedChannelDetailsAPI.sharedInstance.getMedia(channelId: channelId
                    , selectedChannelName: channelName, selectedChannelUserName: userName , sharedCount: totalMediaCount)
            }
        }
    }
    
    func  didSelectExtension(indexPathRow: Int, operation: BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        getLikeCountForSelectedIndex(indexpathRow: indexPathRow, operation: operation)
    }
    
    func getLikeCountForSelectedIndex(indexpathRow:Int, operation: BlockOperation)  {
        if(operation.isCancelled){
            return
        }
        let mediaId = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexpathRow][stream_mediaIdKey] as! String
        getLikeCount(mediaId: mediaId, indexpathRow: indexpathRow, operation:operation)
    }
    
    func getLikeCount(mediaId: String,indexpathRow:Int, operation:BlockOperation) {
        if(operation.isCancelled){
            return
        }
        let defaults = UserDefaults.standard
        let userId = defaults.value(forKey: userLoginIdKey) as! String
        let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        let mediaTypeSelected : String = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexpathRow][stream_mediaTypeKey] as! String
        channelManager.getMediaLikeCountDetails(userName: userId, accessToken: accessToken, mediaId: mediaId, mediaType: mediaTypeSelected, success: { (response) in
            self.successHandlerForMediaCount(response: response,indexpathRow:indexpathRow, operation:operation)
        }, failure: { (error, message) -> () in
            self.failureHandlerForMediaCount(error: error, code: message,indexPathRow:indexpathRow,operation:operation)
            return
        })
    }
    
    var likeCountSelectedIndex : String = "0"
    
    func successHandlerForMediaCount(response:AnyObject?,indexpathRow:Int, operation:BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        if let json = response as? [String: AnyObject]
        {
            likeCountSelectedIndex = "\(json["likeCount"]!)"
        }
        loadmovieViewController(indexPathRow: indexpathRow, likeCount: likeCountSelectedIndex,operation:operation)
    }
    
    func failureHandlerForMediaCount(error: NSError?, code: String,indexPathRow:Int, operation:BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        likeCountSelectedIndex = "0"
        loadmovieViewController(indexPathRow: indexPathRow, likeCount: likeCountSelectedIndex,operation:operation)
    }
    
    func loadmovieViewController(indexPathRow:Int,likeCount:String, operation:BlockOperation) {
        self.removeOverlay()
        channelItemsCollectionView.alpha = 1.0
        if(operation.isCancelled){
            return
        }
        if (SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
        {
            let type = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][stream_mediaTypeKey] as! String
            if((type ==  "image") || (type == "video"))
            {
                let dateString = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow]["createdTime"] as! String
                let index = Int32 (indexPathRow)
                let imageTakenTime = FileManagerViewController.sharedInstance.getTimeDifference(dateStr: dateString)
                vc = MovieViewController.movieViewController(withImageVideo: self.channelName,channelId: self.channelId as String, userName: userName, mediaType: SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][stream_mediaTypeKey] as! String, profileImage:self.profileImage,videoImageUrl:SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][mediaUrlKey] as! UIImage, notifType: SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][notificationKey] as! String, mediaId: SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][stream_mediaIdKey] as! String,timeDiff: imageTakenTime,likeCountStr: likeCount, selectedItem: index,pageIndicator: 2, videoDuration: SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][videoDurationKey] as? String) as! MovieViewController
                self.present(vc, animated: false) { () -> Void in
                }
            }
            else
            {
                let streamTocken = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][ stream_streamTockenKey] as! String
                if streamTocken != ""
                {
                    let parameters : NSDictionary = ["channelName": self.channelName, "userName":userName ,    "mediaType":type, "profileImage":self.profileImage, "notifType":SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][notificationKey] as! String, "mediaId": SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPathRow][stream_mediaIdKey] as! String,"channelId":self.channelId, "likeCount":likeCount ]
                    vc = MovieViewController.movieViewController(withContentPath: "rtsp://\(vowzaIp):1935/live/\(streamTocken)", parameters: parameters as [NSObject : AnyObject] , liveVideo: false) as! MovieViewController
                    self.present(vc, animated: false) { () -> Void in
                    }
                }
                else
                {
                    ErrorManager.sharedInstance.alert(title: "Streaming error", message: "Not a valid stream tocken")
                }
            }
        }
    }
}

extension OtherChannelViewController : UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        if SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0
        {
            return SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count
        }
        else
        {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OtherChannelCell", for: indexPath) as! OtherChannelCell
        
        if SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0
        {
            if indexPath.row < SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count
            {
                let mediaType = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPath.row][stream_mediaTypeKey] as! String
                let imageData =  SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPath.row][stream_thumbImageKey] as! UIImage
                if mediaType == "video"
                {
                    let vDuration  = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[indexPath.row][videoDurationKey] as! String
                    cell.detailLabel.isHidden = true
                    cell.detailLabel.text = vDuration
                    cell.videoView.isHidden = false
                    cell.videoView.image = UIImage(named: "Live_now_off_mode")
                    let imageToConvert: UIImage = imageData
                    let sizeThumb = CGSize(width:150, height:150)
                    let imageAfterConversionThumbnail = cameraController.thumbnaleImage(imageToConvert, scaledToFill: sizeThumb)
                    cell.channelMediaImage.image = imageAfterConversionThumbnail
                }
                else if mediaType == "image" {
                    cell.detailLabel.isHidden = true
                    cell.videoView.isHidden = true
                    cell.channelMediaImage.image = imageData
                }
                else{
                    cell.detailLabel.isHidden = false
                    cell.detailLabel.text = "LIVE"
                    cell.videoView.isHidden = false
                    cell.videoView.image = UIImage(named: "Live_now")
                    cell.channelMediaImage.image = imageData
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        return UIEdgeInsetsMake(1, 1, 0, 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat
    {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat
    {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        return CGSize(width:((UIScreen.main.bounds.width/3)-2), height:100)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if  SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count>0
        {
            if SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > indexPath.row
            {
                showOverlay()
                channelItemsCollectionView.alpha = 0.4
                operationInRedirectionOtherChannel  = BlockOperation (block: {
                    self.didSelectExtension(indexPathRow: indexPath.row,operation:self.operationInRedirectionOtherChannel)
                })
                self.operationQueueObjRedirectionOtherChannel.addOperation(operationInRedirectionOtherChannel)
//                let backgroundQueue = DispatchQueue(label: "com.app.queue",
//                                                    qos: .background,
//                                                    target: nil)
//                backgroundQueue.async {
//                    self.didSelectExtension(indexPathRow: indexPath.row)
//                }
//                didSelectExtension(indexPathRow: indexPath.row)
            }
        }
    }
}
