
import UIKit

class StreamsListViewController: UIViewController{
    static let identifier = "StreamsListViewController"
    let imageUploadManger = ImageUpload.sharedInstance
    let profileManager = ProfileManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    var channelId:String!
    var channelName:String!
    var firstTap : Int = 0
    var offset: String = "0"
    var offsetToInt : Int = Int()
    var loadingOverlay: UIView?
    var imageDataSource: [[String:Any]] = [[String:Any]]()
    var fullImageDataSource: [[String:Any]] = [[String:Any]]()
    var mediaAndLiveArray:[[String:Any]] = [[String:Any]]()
    let cameraController = IPhoneCameraViewController()
    var mediaShared:[[String:Any]] = [[String:Any]]()
    var tapCount : Int = 0
    let livestreamingManager = LiveStreamingManager()
    let requestManager = RequestManager()
    var refreshControl:UIRefreshControl!
    var pullToRefreshActive = false
    var  liveStreamSource: [[String:Any]] = [[String:Any]]()
    var count : Int = 0
    var limit : Int = 27
    var scrollObj = UIScrollView()
    @IBOutlet weak var sharedNewMediaLabel: UILabel!
    var downloadCompleteFlagStream : String = "start"
    var lastContentOffset: CGPoint = CGPoint()
    var NoDatalabel : UILabel = UILabel()
    var selectedMediaId : String = String()
    var isMovieView : Bool = false
    var vc : MovieViewController = MovieViewController()
    var customView = CustomInfiniteIndicator()
    let isWatched = "isWatched"
    
    
    var operationQueueObjRedirection = OperationQueue()
    var operationInRedirection = BlockOperation()
    
    
    @IBOutlet weak var streamListCollectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.setValue("0", forKey: "notificationArrived")
        firstTap = 0
        sharedNewMediaLabel.isHidden = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.streamListCollectionView.alwaysBounceVertical = true
        
        let stream = Notification.Name("stream")
        NotificationCenter.default.addObserver(self, selector:#selector(StreamsListViewController.streamUpdate(notif:)), name: stream, object: nil)
        
        let MediaDelete = Notification.Name("MediaDelete")
        NotificationCenter.default.addObserver(self, selector:#selector(StreamsListViewController.mediaDeletePushNotification(notif:)), name: MediaDelete, object: nil)
        
        let ShowAlert = Notification.Name("ShowAlert")
        NotificationCenter.default.addObserver(self, selector:#selector(StreamsListViewController.closeMovieView(notif:)), name: ShowAlert, object: nil)
        
        let PushNotificationStream = Notification.Name("PushNotificationStream")
        NotificationCenter.default.addObserver(self, selector:#selector(StreamsListViewController.pushNotificationUpdateStream(notif:)), name: PushNotificationStream, object: nil)
        
        getAllLiveStreams()
        showOverlay()
        createScrollViewAnimations()
        //          _ = NSTimer.scheduledTimerWithTimeInterval(60.0, target: self, selector: #selector(StreamsListViewController.test(_:)), userInfo: nil, repeats: true)
        if GlobalStreamList.sharedInstance.GlobalStreamDataSource.count == 0
        {
            GlobalStreamList.sharedInstance.initialiseCloudData(startOffset: count ,endValueLimit: limit)
            self.refreshControl.addTarget(self, action: #selector(StreamsListViewController.pullToRefresh), for: UIControlEvents.valueChanged)
            self.streamListCollectionView.addSubview(self.refreshControl)
        }
        else
        {
            DispatchQueue.main.async {
                self.removeOverlay()
                self.setSourceByAppendingMediaAndLive()
                self.refreshControl.addTarget(self, action: #selector(StreamsListViewController.pullToRefresh), for: UIControlEvents.valueChanged)
                self.streamListCollectionView.addSubview(self.refreshControl)
                self.streamListCollectionView.reloadData()
            }
        }
        if UserDefaults.standard.object(forKey: "NotificationText") != nil{
            if(UserDefaults.standard.object(forKey: "NotificationText") as! String != "")
            {
                self.sharedNewMediaLabel.isHidden = false
                self.sharedNewMediaLabel.text = "Pull to get new media"
            }
            UserDefaults.standard.set("", forKey: "NotificationText")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        isMovieView = false
        super.viewWillAppear(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        UserDefaults.standard.set(1, forKey: "SelectedTab")
        GlobalStreamList.sharedInstance.cancelOperationQueue()
        self.customView.removeFromSuperview()
        if mediaAndLiveArray.count > 0
        {
            removeOverlay()
            streamListCollectionView.alpha = 1.0
            operationInRedirection.cancel()
        }
    }
    
    func closeMovieView(notif : NSNotification)
    {
        vc.closeView()
    }
    
    func createScrollViewAnimations()  {
        streamListCollectionView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x:0, y:0, width:40, height:40))
        streamListCollectionView.infiniteScrollIndicatorMargin = 50
        streamListCollectionView.addInfiniteScroll {  (scrollView) -> Void in
            if(!self.pullToRefreshActive)
            {
                let sortList : Array = GlobalStreamList.sharedInstance.GlobalStreamDataSource
                var subIdArray : [Int] = [Int]()
                self.scrollObj = scrollView
                for i in 0  ..< sortList.count
                {
                    subIdArray.append(Int(sortList[i]["channel_media_detail_id"] as! String)!)
                }
                if(subIdArray.count > 0)
                {
                    let subid = subIdArray.min()!
                    self.downloadCompleteFlagStream = "start"
                    GlobalStreamList.sharedInstance.getMediaByOffset(subId: "\(subid)")
                }
            }
            else
            {
                scrollView.finishInfiniteScroll()
            }
        }
    }
    
    func pushNotificationUpdateStream(notif: NSNotification)
    {
        let info = notif.object as! [String : AnyObject]
        if (info["type"] as! String == "liveStream")
        {
            channelPushNotificationLiveStarted(info: info)
        }
        else if(info["type"] as! String == "channel")
        {
            if(info["subType"] as! String == "useradded")
            {
                DispatchQueue.main.async {
                    self.sharedNewMediaLabel.isHidden = false
                    self.sharedNewMediaLabel.text = "Pull to get new media"
                }
            }
            else{
                let channelId = info["channelId"]!
                deleteChannelSpecificMediaFromLocal(channelId: "\(channelId)")
                deleteChannelSpecificMediaFromGlobal(channelId: "\(channelId)")
            }
        }
        else if(info["type"] as! String == "share")
        {
            sharedNewMediaLabel.isHidden = false
            sharedNewMediaLabel.text = "Pull to get new media"
        }
        else if (info["type"] as! String == "My Day Cleaning")
        {
            DispatchQueue.main.async {
                let channelId = info["channelId"]!
                self.deleteFromOtherChannelIfExistDuringMyDayCleanUp(channelId: "\(channelId)")
                self.deleteChannelSpecificMediaFromLocal(channelId: "\(channelId)")
                self.deleteChannelSpecificMediaFromGlobal(channelId: "\(channelId)")
                let refreshAlert = UIAlertController(title: "Deleted", message: "My Day Cleaning In Progress.", preferredStyle: UIAlertControllerStyle.alert)
                refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
                }))
            }
        }
    }
    
    //    func test(timer : NSTimer)
    //    {
    //
    //        print("CLEANING..................")
    //      //  dispatch_async(dispatch_get_main_queue()) {
    //            let info = ["channelId": "104", "type": "My Day Cleaning"]
    //
    //            let channelId = info["channelId"]! as String
    //            self.deleteFromOtherChannelIfExistDuringMyDayCleanUp("104")
    //            self.myDayCleanUpChannel("104")
    //            self.deleteChannelSpecificMediaFromLocal(channelId)
    //            self.deleteChannelSpecificMediaFromGlobal(channelId)
    //            let refreshAlert = UIAlertController(title: "Deleted", message: "My Day Cleaning In Progress.", preferredStyle: UIAlertControllerStyle.Alert)
    //            refreshAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
    //
    //            }))
    //            self.presentViewController(refreshAlert, animated: true, completion: nil)
    //
    //      //  }
    //
    //    }
    
    func myDayCleanUpChannel(channelId : String)
    {
        let index  = getUpdateIndexChannelList(channelIdValue: channelId, isCountArray: true)
        if(index != -1)
        {
            if(mediaShared.count > 0)
            {
                let  latestCount : Int = 0
                mediaShared[index][sharedMediaCount]  = String(latestCount)
                UserDefaults.standard.set(mediaShared, forKey: "Shared")
            }
        }
        let indexOfChannelList =  getUpdateIndexChannelList(channelIdValue: channelId, isCountArray: false)
        if(indexOfChannelList != -1)
        {
            var mediaImage : UIImage?
            mediaImage = UIImage()
            
            if (ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > indexOfChannelList )
            {
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexOfChannelList][mediaImageKey] = mediaImage
            }
        }
    }
    
    func getUpdateIndexChannelList(channelIdValue : String , isCountArray : Bool) -> Int
    {
        let channelIdkey = "ch_detail_id"
        var selectedArray : [[String:Any]] = [[String:Any]]()
        var indexOfRow : Int = -1
        if(isCountArray)
        {
            if (UserDefaults.standard.object(forKey: "Shared") != nil)
            {
                mediaShared.removeAll()
                mediaShared = UserDefaults.standard.value(forKey: "Shared") as! NSArray as! [[String : Any]]
                selectedArray = mediaShared
            }
            else{
                indexOfRow = -1
            }
        }
        else{
            selectedArray = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource
        }
        
        var  checkFlag : Bool = false
        var index : Int =  -1
        
        for i in 0  ..< selectedArray.count
        {
            let channelId = selectedArray[i][channelIdkey]!
            if "\(channelId)"  == channelIdValue
            {
                checkFlag = true
                index = i
                break
            }
        }
        if(checkFlag)
        {
            indexOfRow = index
        }
        
        return indexOfRow
    }
    
    func deleteFromOtherChannelIfExistDuringMyDayCleanUp(channelId : String)
    {
        if SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0
        {
            var selectedArray : [Int] = [Int]()
            for i in 0  ..< SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count
            {
                if UserDefaults.standard.value(forKey: "SharedChannelId") != nil{
                    let channelIdValue = UserDefaults.standard.value(forKey: "SharedChannelId") as! String
                    if ( channelIdValue == "\(channelId)")
                    {
                        selectedArray.append(i)
                    }
                }
            }
            
            selectedArray =  selectedArray.sorted()
            for i in 0  ..< selectedArray.count
            {
                SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.remove(at: selectedArray[i] - i)
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ViewMediaDeletedMyDAyCleanUp"), object:nil)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DeletedObject"), object:nil)
    }
    
    func deleteChannelSpecificMediaFromLocal(channelId : String)
    {
        var selectedArray : [Int] = [Int]()
        
        for i in 0  ..< mediaAndLiveArray.count
        {
            let channelIdValue = mediaAndLiveArray[i][channelIdkey] as! String
            if ( channelIdValue == "\(channelId)")
            {
                selectedArray.append(i)
            }
        }
        
        selectedArray =  selectedArray.sorted()
        for i in 0  ..< selectedArray.count
        {
            mediaAndLiveArray.remove(at: selectedArray[i] - i)
        }
        
        DispatchQueue.main.async {
            if(self.mediaAndLiveArray.count == 0)
            {
                self.NoDatalabel.removeFromSuperview()
                self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100),y:((self.view.frame.height/2) - 35), width:200, height:70))
                self.NoDatalabel.textAlignment = NSTextAlignment.center
                self.NoDatalabel.text = "No Media Available"
                self.view.addSubview(self.NoDatalabel)
            }
            self.streamListCollectionView.reloadData()
        }
        getMediaWhileDeleted()
        
    }
    
    func deleteChannelSpecificMediaFromGlobal(channelId : String)
    {
        var selectedArray : [Int] = [Int]()
        
        for i in 0  ..< GlobalStreamList.sharedInstance.GlobalStreamDataSource.count
        {
            let channelIdValue = GlobalStreamList.sharedInstance.GlobalStreamDataSource[i][channelIdkey] as! String
            if (channelIdValue == "\(channelId)")
            {
                selectedArray.append(i)
                
            }
        }
        
        selectedArray =  selectedArray.sorted()
        if(selectedArray.count > 0)
        {
            let obj : SetUpView = SetUpView()
            obj.callDeleteWhileMyDayCleanUp(obj: vc, channelId: channelId)
        }
        for i in 0  ..< selectedArray.count
        {
            GlobalStreamList.sharedInstance.GlobalStreamDataSource.remove(at: selectedArray[i] - i)
        }
        
    }
    
    func channelPushNotificationLiveStarted(info: [String : AnyObject])
    {
        let subType = info["subType"] as! String
        switch subType {
        case "started":
            ErrorManager.sharedInstance.streamAvailable()
            updateLiveStreamStartedEntry(info: info)
            sharedNewMediaLabel.isHidden = false
            sharedNewMediaLabel.text = "Pull to get live stream"
            break;
        case "stopped":
            updateLiveStreamStoppeddEntry(info: info)
            break;
        default:
            break;
        }
    }
    
    func updateLiveStreamStartedEntry(info:[String : AnyObject])
    {
    }
    
    func updateLiveStreamStoppeddEntry(info:[String : AnyObject])
    {
        let channelId = info["channelId"] as! Int
        let livStreamId = info ["liveStreamId"] as! Int
        var  checkFlag : Bool = false
        var removeIndex : Int = Int()
        for (index, element) in mediaAndLiveArray.enumerated() {
            if element[channelIdkey] as? String == "\(channelId)"
            {
                if(element[stream_mediaIdKey] as? String == "\(livStreamId)")
                {
                    removeIndex = index
                    checkFlag = true
                }
            }
        }
        if checkFlag
        {
            mediaAndLiveArray.remove(at: removeIndex)
            DispatchQueue.main.async {
                if(self.mediaAndLiveArray.count == 0)
                {
                    self.NoDatalabel.removeFromSuperview()
                    self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100),y:((self.view.frame.height/2) - 35), width:200, height:70))
                    self.NoDatalabel.textAlignment = NSTextAlignment.center
                    self.NoDatalabel.text = "No Media Available"
                    self.view.addSubview(self.NoDatalabel)
                }
                self.streamListCollectionView.reloadData()
            }
        }
    }
    
    func getMediaWhileDeleted()
    {
        if(mediaAndLiveArray.count <  18 && mediaAndLiveArray.count != 0)
        {
            if(!self.pullToRefreshActive)
            {
                let sortList : Array = self.mediaAndLiveArray
                var subIdArray : [Int] = [Int]()
                
                for i in 0  ..< sortList.count
                {
                    subIdArray.append(Int(sortList[i]["channel_media_detail_id"] as! String)!)
                }
                if(subIdArray.count > 0)
                {
                    let subid = subIdArray.min()!
                    self.downloadCompleteFlagStream = "start"
                    GlobalStreamList.sharedInstance.getMediaByOffset(subId: "\(subid)")
                    DispatchQueue.main.async {
                        self.customView.removeFromSuperview()
                        self.streamListCollectionView.isUserInteractionEnabled = false
                        self.customView  = CustomInfiniteIndicator(frame: CGRect(x:(self.streamListCollectionView.layer.frame.width/2 - 20), y:(self.streamListCollectionView.layer.frame.height - 100), width:40, height:40))
                        self.streamListCollectionView.addSubview(self.customView)
                        self.customView.startAnimating()
                    }
                }
            }
        }
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
                mediaShared = UserDefaults.standard.value(forKey: "Shared") as! NSArray as! [[String : Any]]
            }
            selectedArray = mediaShared
        }
        else{
            selectedArray = mediaAndLiveArray
        }
        var  checkFlag : Bool = false
        var index : Int =  Int()
        for i in 0  ..< selectedArray.count
        {
            let channelId = selectedArray[i][channelIdkey]!
            
            if "\(channelId)"  == channelIdValue
            {
                checkFlag = true
                index = i
            }
        }
        if (checkFlag)
        {
            indexOfRow = index
        }
        return indexOfRow
    }
    
    func mediaDeletePushNotification(notif: NSNotification)
    {
        let info = notif.object as! [String : AnyObject]
        let type =  info["type"] as! String
        DispatchQueue.main.async {
            let refreshAlert = UIAlertController(title: "Deleted", message: "Shared media deleted.", preferredStyle: UIAlertControllerStyle.alert)
            
            refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            }))
            
            self.present(refreshAlert, animated: true, completion: nil)
        }
        if(type == "media")
        {
            //delete media from archive
            self.getDataUsingNotificationId(info: info)
        }
        else{
            let channelId = info["channelId"] as! Int
            let mediaArrayData  = info["mediaId"] as! NSArray
            self.removeDataFromGlobal(channelId: channelId, mediaArrayData: mediaArrayData)
            self.deleteFromOtherChannelIfExist(mediaArrayData: mediaArrayData)
        }
    }
    
    func removeDataFromGlobal(channelId : Int , mediaArrayData : NSArray)
    {
        var selectedArray :[Int] = [Int]()
        for mediaArrayCount in 0  ..< mediaArrayData.count
        {
            var foundFlag : Bool = false
            var removeIndex : Int = Int()
            for i in 0  ..< GlobalStreamList.sharedInstance.GlobalStreamDataSource.count
            {
                let channelIdValue = GlobalStreamList.sharedInstance.GlobalStreamDataSource[i][channelIdkey] as! String
                
                if ( channelIdValue == "\(channelId)")
                {
                    if(i < GlobalStreamList.sharedInstance.GlobalStreamDataSource.count)
                    {
                        let mediaIdValue = GlobalStreamList.sharedInstance.GlobalStreamDataSource[i][stream_mediaIdKey] as! String
                        
                        if( mediaIdValue == "\(mediaArrayData[mediaArrayCount])" )
                        {
                            foundFlag = true
                            removeIndex = i
                        }
                    }
                }
            }
            if(foundFlag)
            {
                selectedArray.append(removeIndex)
            }
        }
        selectedArray.sort()
        for i in 0  ..< selectedArray.count
        {
            if(GlobalStreamList.sharedInstance.GlobalStreamDataSource.count > 0)
            {
                GlobalStreamList.sharedInstance.GlobalStreamDataSource.remove(at: selectedArray[i]-i)
            }
        }
        self.removeFromMediaAndLiveArray(channelId: channelId, mediaData: mediaArrayData)
    }
    
    func getDataUsingNotificationId(info : [String : AnyObject])
    {
        let notifId : Int = info["notificationId"] as! Int
        let userDefault = UserDefaults.standard
        let loginId = userDefault.object(forKey: userLoginIdKey) as! String
        let accessTocken = userDefault.object(forKey: userAccessTockenKey) as! String
        channelManager.getDataByNotificationId(userName: loginId, accessToken: accessTocken, notificationId: "\(notifId)", success: { (response) in
            self.getAllChannelIdsSuccessHandler(response: response)
        }) { (error, message) in
            self.authenticationFailureHandlerForLiveStream(error: error, code: message)
        }
    }
    
    func getAllChannelIdsSuccessHandler(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            let responseArr = json["notificationMessage"] as! String
            let responseArrData = convertStringToDictionary1(text: responseArr)
            let channelIdArray : NSArray = responseArrData!["channelId"] as! NSArray
            let mediaArrayData : NSArray = responseArrData!["mediaId"] as! NSArray
            deleteFromLocal(channelIdArray: channelIdArray, mediaArrayData: mediaArrayData)
            DispatchQueue.main.async {
                self.streamListCollectionView.reloadData()
            }
            self.deleteFromGlobal(channelIdArray: channelIdArray, mediaArrayData: mediaArrayData)
            self.deleteFromOtherChannelIfExist(mediaArrayData: mediaArrayData)
        }
    }
    
    func deleteFromOtherChannelIfExist( mediaArrayData : NSArray)
    {
        if(SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count > 0)
        {
            var selectedArray : [Int] = [Int]()
            for i in 0  ..< SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count
            {
                var foundFlag : Bool = false
                if(i < SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.count)
                {
                    var  count : Int = 0
                    let mediaId = SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource[i][stream_mediaIdKey] as! String
                    
                    for mediaArrayCount in 0  ..< mediaArrayData.count
                    {
                        if("\(mediaArrayData[mediaArrayCount])" == mediaId)
                        {
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ViewMediaDeleted"), object:mediaId)
                            count = count + 1
                            foundFlag = true
                            break;
                        }
                    }
                }
                if(foundFlag)
                {
                    foundFlag = false
                    selectedArray.append(i)
                }
            }
            
            selectedArray =  selectedArray.sorted()
            for i in 0  ..< selectedArray.count
            {
                SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.remove(at: selectedArray[i] - i)
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DeletedObject"), object:nil)
    }
    
    func deleteFromGlobal (channelIdArray : NSArray, mediaArrayData : NSArray)
    {
        var selectedArray : [Int] = [Int]()
        for j in 0  ..< channelIdArray .count
        {
            let channel = channelIdArray[j] as! Int
            
            for i in 0  ..< GlobalStreamList.sharedInstance.GlobalStreamDataSource.count
            {
                let channelIdValue = GlobalStreamList.sharedInstance.GlobalStreamDataSource[i][channelIdkey] as! String
                var foundFlag : Bool = false
                
                if ( channelIdValue == "\(channel)")
                {
                    if(i < GlobalStreamList.sharedInstance.GlobalStreamDataSource.count)
                    {
                        var  count : Int = 0
                        let mediaId = GlobalStreamList.sharedInstance.GlobalStreamDataSource[i][stream_mediaIdKey] as! String
                        
                        for mediaArrayCount in 0  ..< mediaArrayData.count
                        {
                            if("\(mediaArrayData[mediaArrayCount])" == mediaId)
                            {
                                count = count + 1
                                foundFlag = true
                                break;
                            }
                        }
                    }
                    
                    if(foundFlag)
                    {
                        foundFlag = false
                        selectedArray.append(i)
                    }
                }
            }
        }
        selectedArray =  selectedArray.sorted()
        for i in 0  ..< selectedArray.count
        {
            GlobalStreamList.sharedInstance.GlobalStreamDataSource.remove(at: selectedArray[i] - i)
        }
    }
    
    func deleteFromLocal (channelIdArray : NSArray, mediaArrayData : NSArray)
    {
        var selectedArray : [Int] = [Int]()
        var channelIDCount : [String : AnyObject] = [String : AnyObject]()
        
        for j in 0  ..< channelIdArray .count
        {
            let channel = channelIdArray[j] as! Int
            for i in 0  ..< mediaAndLiveArray.count
            {
                let channelIdValue = mediaAndLiveArray[i][channelIdkey] as! String
                var foundFlag : Bool = false
                var  count : Int = 0
                if (channelIdValue == "\(channel)")
                {
                    if(i < mediaAndLiveArray.count)
                    {
                        let mediaId = mediaAndLiveArray[i][stream_mediaIdKey] as! String
                        for mediaArrayCount in 0  ..< mediaArrayData.count
                        {
                            if("\(mediaArrayData[mediaArrayCount])" == selectedMediaId)
                            {
                                if isMovieView
                                {
                                    self.vc.mediaDeletedErrorMessage()
                                    self.isMovieView = false
                                }
                            }
                            
                            if("\(mediaArrayData[mediaArrayCount])" == mediaId)
                            {
                                let obj : SetUpView = SetUpView()
                                obj.callDelete(obj: vc, mediaId: mediaId)
                                count = count + 1
                                foundFlag = true
                                break;
                            }
                        }
                        if(foundFlag)
                        {
                            foundFlag = false
                            channelIDCount.updateValue(count as AnyObject, forKey: channelIdValue)
                            selectedArray.append(i)
                        }
                    }
                }
            }
        }
        selectedArray =  selectedArray.sorted()
        for i in 0  ..< selectedArray.count
        {
            mediaAndLiveArray.remove(at: selectedArray[i] - i)
        }
        
        DispatchQueue.main.async {
            if(self.mediaAndLiveArray.count == 0)
            {
                self.NoDatalabel.removeFromSuperview()
                self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                self.NoDatalabel.textAlignment = NSTextAlignment.center
                self.NoDatalabel.text = "No Media Available"
                self.view.addSubview(self.NoDatalabel)
            }
        }
        getMediaWhileDeleted()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "StreamToChannelMedia"), object:channelIDCount)
    }
    
    func convertStringToDictionary1(text: String) -> [String:AnyObject]? {
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
            } catch _ as NSError {
            }
        }
        return nil
    }
    
    func convertStringToDictionary(text: String) -> NSArray? {
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? NSArray
            } catch _ as NSError {
            }
        }
        return nil
    }
    
    func removeLiveFromMediaAndLiveArray(channelId : Int,type : String)
    {
        var selectedArray :[Int] = [Int]()
        var foundFlag : Bool = false
        var removeIndex : Int = Int()
        for i in 0  ..< mediaAndLiveArray.count
        {
            let channelIdValue = mediaAndLiveArray[i][channelIdkey] as! String
            if (channelIdValue == "\(channelId)")
            {
                if(i < mediaAndLiveArray.count)
                {
                    let mediaIdValue = mediaAndLiveArray[i][stream_mediaTypeKey] as! String
                    if(mediaIdValue == "live" )
                    {
                        foundFlag = true
                        removeIndex = i
                        break
                    }
                }
            }
        }
        if(foundFlag)
        {
            selectedArray.append(removeIndex)
            foundFlag = false
        }
        if(selectedArray.count > 0)
        {
            var pathArray : [IndexPath] = [IndexPath]()
            selectedArray = selectedArray.sorted()
            for i in 0  ..< selectedArray.count
            {
                let index = selectedArray[i]
                let indexPath = IndexPath(row: index, section: 0)
                pathArray.append(indexPath)
                mediaAndLiveArray.remove(at: index)
            }
            DispatchQueue.main.async {
                self.streamListCollectionView.reloadData()
            }
        }
    }
    
    func removeFromMediaAndLiveArray(channelId : Int,mediaData : NSArray)
    {
        var selectedArray :[Int] = [Int]()
        for mediaArrayCount in 0  ..< mediaData.count
        {
            var foundFlag : Bool = false
            var removeIndex : Int = Int()
            for i in 0  ..< mediaAndLiveArray.count
            {
                let channelIdValue = mediaAndLiveArray[i][channelIdkey] as! String
                if (channelIdValue == "\(channelId)")
                {
                    if(i < mediaAndLiveArray.count)
                    {
                        let mediaIdValue = mediaAndLiveArray[i][stream_mediaIdKey] as! String
                        if("\(mediaData[mediaArrayCount])" == selectedMediaId)
                        {
                            if isMovieView
                            {
                                DispatchQueue.main.async {
                                    self.vc.mediaDeletedErrorMessage()
                                    self.isMovieView = false
                                }
                            }
                        }
                        if(mediaIdValue == "\(mediaData[mediaArrayCount])" )
                        {
                            let obj : SetUpView = SetUpView()
                            obj.callDelete(obj: vc, mediaId: mediaIdValue)
                            foundFlag = true
                            removeIndex = i
                            break
                        }
                    }
                }
            }
            if(foundFlag)
            {
                selectedArray.append(removeIndex)
                foundFlag = false
            }
        }
        if(selectedArray.count > 0)
        {
            var pathArray : [IndexPath] = [IndexPath]()
            selectedArray = selectedArray.sorted()
            for i in 0  ..< selectedArray.count
            {
                if(mediaAndLiveArray.count > 0)
                {
                    let index = selectedArray[i]
                    let indexPath = IndexPath(row: index, section: 0)
                    pathArray.append(indexPath)
                    mediaAndLiveArray.remove(at: index - i)
                }
            }
            DispatchQueue.main.async {
                if(self.mediaAndLiveArray.count == 0)
                {
                    self.NoDatalabel.removeFromSuperview()
                    self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
                    self.NoDatalabel.textAlignment = NSTextAlignment.center
                    self.NoDatalabel.text = "No Media Available"
                    self.view.addSubview(self.NoDatalabel)
                }
                self.streamListCollectionView.reloadData()
            }
        }
        getMediaWhileDeleted()
        
    }
    
    func remove(pathArray : NSArray) {
        
        let pathArray : [IndexPath] = [IndexPath]()
        
        DispatchQueue.main.async {
            self.streamListCollectionView.performBatchUpdates({
                self.streamListCollectionView.deleteItems(at: pathArray as [IndexPath])
            }, completion: {
                (finished: Bool) in
            })
        }
    }
    
    func getUpdateIndex(channelId : String , isCountArray : Bool) -> Int
    {
        var selectedArray : [[String:Any]] = [[String:Any]]()
        var indexOfRow : Int = Int()
        if(isCountArray)
        {
            if (UserDefaults.standard.object(forKey: "Shared") != nil)
            {
                mediaShared.removeAll()
                mediaShared = UserDefaults.standard.value(forKey: "Shared") as! [[String : Any]]
            }
            selectedArray = mediaShared as Array
        }
        else{
            selectedArray = GlobalStreamList.sharedInstance.GlobalStreamDataSource
        }
        var  checkFlag : Bool = false
        for (index, element) in selectedArray.enumerated() {
            if element["mediaId"] as? String == channelId
            {
                indexOfRow = index
                checkFlag = true
            }
        }
        if (!checkFlag)
        {
            indexOfRow = -1
        }
        return indexOfRow
    }
    
    func setSourceByAppendingMediaAndLive()
    {
        DispatchQueue.main.async {
            self.mediaAndLiveArray.removeAll()
            self.mediaAndLiveArray = self.liveStreamSource +  GlobalStreamList.sharedInstance.GlobalStreamDataSource
            if(self.mediaAndLiveArray.count > 0)
            {
                self.NoDatalabel.removeFromSuperview()
            }
            self.streamListCollectionView.reloadData()
        }
    }
    
    func streamUpdate(notif: NSNotification)
    {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "RemoveOverlay"), object:nil)
        
        DispatchQueue.main.async {
            self.scrollObj.finishInfiniteScroll()
            self.scrollObj = UIScrollView()
            if(self.downloadCompleteFlagStream == "start")
            {
                self.downloadCompleteFlagStream = "end"
            }
        }
        if(pullToRefreshActive){
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.pullToRefreshActive = false
            }
        }
        let success =  notif.object as! String
        if(success == "success")
        {
            DispatchQueue.main.async {
                self.removeOverlay()
                self.setSourceByAppendingMediaAndLive()
                self.streamListCollectionView.reloadData()
            }
        }
        else if((success == "USER004") || (success == "USER005") || (success == "USER006")){
            if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
            {
                if tokenValid as! String == "true"
                {
                    loadInitialViewController(code: success)
                }
            }
        }
        else
        {
            DispatchQueue.main.async {
                self.removeOverlay()
                if(self.liveStreamSource.count > 0)
                {
                    self.setSourceByAppendingMediaAndLive()
                    self.streamListCollectionView.reloadData()
                }
                else{
                    self.mediaAndLiveArray.removeAll()
                    self.mediaAndLiveArray = GlobalStreamList.sharedInstance.GlobalStreamDataSource
                    self.NoDatalabel.removeFromSuperview()
                    if(self.mediaAndLiveArray.count == 0)
                    {
                        self.NoDatalabel = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100),y:((self.view.frame.height/2) - 35), width:200, height:70))
                        self.NoDatalabel.textAlignment = NSTextAlignment.center
                        self.NoDatalabel.text = "No Media Available"
                        self.view.addSubview(self.NoDatalabel)
                    }
                    self.streamListCollectionView.reloadData()
                }
            }
        }
        DispatchQueue.main.async {
            self.streamListCollectionView.isUserInteractionEnabled = true
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    func downloadMedia(downloadURL : NSURL ,key : String , completion: (_ result: UIImage) -> Void)
    {
        var mediaImage : UIImage = UIImage()
        
        // Data object to fetch weather data
        do {
            let data = try NSData(contentsOf: downloadURL as URL,options: NSData.ReadingOptions())
            if let imageData = data as NSData? {
                if let mediaImage1 = UIImage(data: imageData as Data)
                {
                    mediaImage = mediaImage1
                }
                else{
                    
                    mediaImage = UIImage(named: "thumb12")!
                }
                
                completion(mediaImage)
            }
            else
            {
                completion(UIImage(named: "thumb12")!)
            }
            
        } catch {
            completion(UIImage(named: "thumb12")!)
        }
    }
    
    func showOverlay(){
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = CGRect(x:0, y:64, width:self.view.frame.width, height:self.view.frame.height - (64 + 50))
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.view .addSubview(self.loadingOverlay!)
    }
    
    func removeOverlay(){
        self.loadingOverlay?.removeFromSuperview()
    }
    
    func loadLiveStreamView(streamTocken:String)
    {
        let vc = MovieViewController.movieViewController(withContentPath: "rtsp://\(vowzaIp):1935/live/\(streamTocken)", parameters: nil , liveVideo: false) as! UIViewController
        self.present(vc, animated: false) { () -> Void in
        }
    }
    
    func pullToRefresh()
    {
        UserDefaults.standard.set("", forKey: "NotificationText")
        DispatchQueue.main.async {
            self.sharedNewMediaLabel.isHidden = true
            self.NoDatalabel.removeFromSuperview()
        }
        if(!pullToRefreshActive){
            pullToRefreshActive = true
            self.downloadCompleteFlagStream = "start"
            if(mediaAndLiveArray.count > 0){
                self.getAllLiveStreams()
                self.getPullToRefreshData()
            }
            else{
                self.downloadCompleteFlagStream = "start"
                self.getAllLiveStreams()
                GlobalStreamList.sharedInstance.imageDataSource.removeAll()
                GlobalStreamList.sharedInstance.GlobalStreamDataSource.removeAll()
                GlobalStreamList.sharedInstance.initialiseCloudData(startOffset: count ,endValueLimit: limit)
            }
        }
        else
        {
        }
    }
    
    func getPullToRefreshData()
    {
        GlobalStreamList.sharedInstance.getPullToRefreshData()
    }
    
    //PRAGMA MARK:- API Handlers
    func getAllLiveStreams()
    {
        liveStreamSource.removeAll()
        let userDefault = UserDefaults.standard
        let loginId = userDefault.object(forKey: userLoginIdKey)
        let accessTocken = userDefault.object(forKey: userAccessTockenKey)
        if let loginId = loginId, let accessTocken = accessTocken
        {
            livestreamingManager.getAllLiveStreams(loginId:loginId as! String , accesstocken:accessTocken as! String ,success: { (response) -> () in
                self.getAllStreamSuccessHandler(response: response)
            }, failure: { (error, message) -> () in
                self.authenticationFailureHandlerForLiveStream(error: error, code: message)
                return
            })
        }
        else
        {
            DispatchQueue.main.async {
                self.removeOverlay()
            }
            if(pullToRefreshActive){
                self.refreshControl.endRefreshing()
                pullToRefreshActive = false
            }
            ErrorManager.sharedInstance.authenticationIssue()
        }
    }
    
    func authenticationFailureHandlerForLiveStream(error: NSError?, code: String)
    {
        if !self.requestManager.validConnection() {
            self.removeOverlay()
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                loadInitialViewController(code: code)
            }
            else{
                self.removeOverlay()
            }
        }
        else{
            self.removeOverlay()
            
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
    
    func nullToNil(value : Any?) -> Any? {
        if value is NSNull {
            return ""
        } else {
            return value
        }
    }
    
    func getAllStreamSuccessHandler(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            let responseArrLive = json["liveStreams"] as! [[String:AnyObject]]
            if (responseArrLive.count != 0)
            {
                for element in responseArrLive{
                    let stremTockn = element[stream_streamTockenKey] as! String
                    let userId = element[userIdKey] as! String
                    let channelIdSelected = element["channel_detail_id"]?.stringValue
                    let channelname = element[stream_channelNameKey] as! String
                    let mediaId = element["live_stream_detail_id"]?.stringValue
                    let pulltorefresh = element["channel_live_stream_detail_id"]?.stringValue
                    let notificationType : String = ""
                    let thumbUrlBeforeNullChk =  UrlManager.sharedInstance.getLiveThumbUrlApi(liveStreamId: mediaId!)
                    var imageForMedia : UIImage = UIImage()
                    let thumbUrl = nullToNil(value: thumbUrlBeforeNullChk)
                    if("\(thumbUrl)" != ""){
                        let url: NSURL = convertStringtoURL(url: thumbUrl! as! String)
                        downloadMedia(downloadURL: url, key: "ThumbImage", completion: { (result) -> Void in
                            if(result != UIImage()){
                                imageForMedia = result
                            }
                        })
                    }
                    else{
                        imageForMedia = UIImage(named: "thumb12")!
                    }
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
                    let currentDate = dateFormatter.string(from: NSDate() as Date)
                    liveStreamSource.append([stream_mediaIdKey:mediaId!, mediaUrlKey:"", timestamp :currentDate,stream_thumbImageKey:imageForMedia ,stream_streamTockenKey:stremTockn,actualImageKey:"",userIdKey:userId,notificationKey:notificationType,stream_mediaTypeKey:"live",timeKey:currentDate,stream_channelNameKey:channelname, channelIdkey: channelIdSelected!,"createdTime":currentDate,pullTorefreshKey :pulltorefresh!])
                }
                DispatchQueue.main.async {
                    if(self.mediaAndLiveArray.count == 0)
                    {
                        if(self.liveStreamSource.count > 0)
                        {
                            self.setSourceByAppendingMediaAndLive()
                        }
                    }
                    else
                    {
                        if(self.liveStreamSource.count > 0)
                        {
                            self.setSourceByAppendingMediaAndLive()
                        }
                    }
                    self.streamListCollectionView.reloadData()
                }
            }
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func loadStaticImagesOnly()
    {
        self.streamListCollectionView.reloadData()
    }
    
    @IBAction func customBackButtonClicked(_ sender: Any)
    {
        SharedChannelDetailsAPI.sharedInstance.imageDataSource.removeAll()
        SharedChannelDetailsAPI.sharedInstance.selectedSharedChannelMediaSource.removeAll()
        let cameraViewStoryboard = UIStoryboard(name:"IPhoneCameraView" , bundle: nil)
        let iPhoneCameraVC = cameraViewStoryboard.instantiateViewController(withIdentifier: "IPhoneCameraViewController") as! IPhoneCameraViewController
        iPhoneCameraVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(iPhoneCameraVC, animated: false)
    }
    
    func  didSelectExtension(indexPathRow: Int, operation: BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        getProfileImageSelectedIndex(indexpathRow: indexPathRow,operation: operation)
    }
    
    var profileImageUserForSelectedIndex : UIImage = UIImage()
    
    func getProfileImageSelectedIndex(indexpathRow: Int, operation: BlockOperation)
    {
        if(mediaAndLiveArray.count > 0)
        {
            if(operation.isCancelled){
                return
            }
            let subUserName = mediaAndLiveArray[indexpathRow][userIdKey] as! String
            let profileImageNameBeforeNullChk =  UrlManager.sharedInstance.getProfileURL(userId: subUserName)
            let profileImageName = self.nullToNil(value: profileImageNameBeforeNullChk)
            if("\(profileImageName)" != "")
            {
                let url: NSURL = self.convertStringtoURL(url: profileImageName! as! String)
                if let data = NSData(contentsOf: url as URL){
                    let imageDetailsData = (data as NSData?)!
                    if let profile = UIImage(data: imageDetailsData as Data)
                    {
                        profileImageUserForSelectedIndex = profile
                    }
                    else{
                        profileImageUserForSelectedIndex = UIImage(named: "dummyUser")!
                    }
                }
                else{
                    profileImageUserForSelectedIndex = UIImage(named: "dummyUser")!
                }
            }
            else{
                profileImageUserForSelectedIndex = UIImage(named: "dummyUser")!
            }
            
        }
        else{
            profileImageUserForSelectedIndex = UIImage(named: "dummyUser")!
        }
        getLikeCountForSelectedIndex(indexpathRow: indexpathRow,profile: profileImageUserForSelectedIndex,operation: operation)
    }
    
    func failureHandlerForprofileImage(error: NSError?, code: String,indexPathRow:Int, operation: BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        profileImageUserForSelectedIndex = UIImage(named: "dummyUser")!
        getLikeCountForSelectedIndex(indexpathRow: indexPathRow,profile: profileImageUserForSelectedIndex,operation: operation)
    }
    
    func getLikeCountForSelectedIndex(indexpathRow:Int,profile:UIImage, operation: BlockOperation)  {
        if(operation.isCancelled){
            return
        }
        let mediaId = mediaAndLiveArray[indexpathRow][stream_mediaIdKey] as! String
        getLikeCount(mediaId: mediaId, indexpathRow: indexpathRow, profile: profile,operation: operation)
    }
    
    func getLikeCount(mediaId: String,indexpathRow:Int,profile:UIImage, operation: BlockOperation) {
        if(operation.isCancelled){
            return
        }
        let mediaTypeSelected : String = mediaAndLiveArray[indexpathRow][stream_mediaTypeKey] as! String
        let defaults = UserDefaults .standard
        
        let userId = defaults.value(forKey: userLoginIdKey) as! String
        let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        channelManager.getMediaLikeCountDetails(userName: userId, accessToken: accessToken, mediaId: mediaId, mediaType: mediaTypeSelected, success: { (response) in
            self.successHandlerForMediaCount(response: response,indexpathRow:indexpathRow,profile: profile,operation: operation)
        }, failure: { (error, message) -> () in
            self.failureHandlerForMediaCount(error: error, code: message,indexPathRow:indexpathRow,profile: profile,operation: operation)
            return
        })
    }
    
    var likeCountSelectedIndex : String = "0"
    
    func successHandlerForMediaCount(response:AnyObject?,indexpathRow:Int,profile:UIImage, operation: BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        if let json = response as? [String: AnyObject]
        {
            likeCountSelectedIndex = "\(json["likeCount"]!)"
        }
        loadmovieViewController(indexPathRow: indexpathRow, profileImage: profile, likeCount: likeCountSelectedIndex,operation: operation)
    }
    
    func failureHandlerForMediaCount(error: NSError?, code: String,indexPathRow:Int,profile:UIImage, operation: BlockOperation)
    {
        if(operation.isCancelled){
            return
        }
        likeCountSelectedIndex = "0"
        loadmovieViewController(indexPathRow: indexPathRow, profileImage: profile, likeCount: likeCountSelectedIndex,operation: operation)
    }
    
    func loadmovieViewController(indexPathRow:Int,profileImage:UIImage,likeCount:String, operation: BlockOperation) {
        if(operation.isCancelled){
            return
        }
        self.removeOverlay()
        streamListCollectionView.alpha = 1.0
        let index = Int32(indexPathRow)
        if (mediaAndLiveArray.count > 0)
        {
            let type = mediaAndLiveArray[indexPathRow][stream_mediaTypeKey] as! String
            if((type ==  "image") || (type == "video"))
            {
                isMovieView = true
                selectedMediaId = mediaAndLiveArray[indexPathRow][stream_mediaIdKey] as! String
                let dateString = mediaAndLiveArray[indexPathRow]["createdTime"] as! String
                let imageTakenTime = FileManagerViewController.sharedInstance.getTimeDifference(dateStr: dateString)
                vc = MovieViewController.movieViewController(withImageVideo: mediaAndLiveArray[indexPathRow][stream_channelNameKey] as! String,channelId: mediaAndLiveArray[indexPathRow][channelIdkey] as! String, userName: mediaAndLiveArray[indexPathRow][userIdKey] as! String, mediaType:mediaAndLiveArray[indexPathRow][stream_mediaTypeKey] as! String, profileImage: profileImage, videoImageUrl:mediaAndLiveArray[indexPathRow][mediaUrlKey] as! UIImage, notifType: mediaAndLiveArray[indexPathRow][notificationKey] as! String, mediaId: mediaAndLiveArray[indexPathRow][stream_mediaIdKey] as! String,timeDiff:imageTakenTime,likeCountStr:likeCount, selectedItem: index,pageIndicator: 1, videoDuration: mediaAndLiveArray[indexPathRow][videoDurationKey] as? String) as! MovieViewController
                self.present(vc, animated: false) { () -> Void in
                }
            }
            else
            {
                let streamTocken = mediaAndLiveArray[indexPathRow][stream_streamTockenKey] as! String
                if streamTocken != ""
                {
                    let parameters : NSDictionary = ["channelName": mediaAndLiveArray[indexPathRow][stream_channelNameKey] as! String, "userName":mediaAndLiveArray[indexPathRow][userIdKey] as! String, "mediaType":mediaAndLiveArray[indexPathRow][stream_mediaTypeKey] as! String, "profileImage":profileImage, "notifType":mediaAndLiveArray[indexPathRow][notificationKey] as! String, "mediaId":mediaAndLiveArray[indexPathRow][stream_mediaIdKey] as! String,"channelId":mediaAndLiveArray[indexPathRow][channelIdkey] as! String,"likeCount":likeCount ]
                    vc = MovieViewController.movieViewController(withContentPath: "rtsp://\(vowzaIp):1935/live/\(streamTocken)", parameters: parameters as [NSObject : AnyObject] , liveVideo: false)  as! MovieViewController
                    
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
    
    deinit {
    }
}

extension StreamsListViewController:UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        if  mediaAndLiveArray.count > 0
        {
            return mediaAndLiveArray.count
        }
        else
        {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StreamListCollectionViewCell", for: indexPath) as! StreamListCollectionViewCell
        
        if  mediaAndLiveArray.count > 0
        {
            if mediaAndLiveArray.count > indexPath.row
            {
                let type = mediaAndLiveArray[indexPath.row][stream_mediaTypeKey] as! String
                
                if let imageThumb = mediaAndLiveArray[indexPath.row][stream_thumbImageKey] as? UIImage
                {
                    if type == "video"
                    {
                        let vDuration  = mediaAndLiveArray[indexPath.row][videoDurationKey] as! String
                        cell.liveStatusLabel.isHidden = true
                        cell.liveStatusLabel.text = vDuration
                        cell.liveNowIcon.isHidden = false
                        cell.liveNowIcon.image = UIImage(named: "Live_now_off_mode")
                        cell.streamThumbnaleImageView.image = imageThumb
                    }
                    else if type == "image"{
                        
                        cell.liveStatusLabel.isHidden = true
                        cell.liveNowIcon.isHidden = true
                        cell.streamThumbnaleImageView.image = imageThumb
                    }
                    else
                    {
                        cell.liveStatusLabel.isHidden = false
                        cell.liveStatusLabel.text = "LIVE"
                        cell.liveNowIcon.isHidden = false
                        cell.liveNowIcon.image = UIImage(named: "Live_now")
                        cell.streamThumbnaleImageView.image = imageThumb
                    }
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if  mediaAndLiveArray.count>0
        {
            if mediaAndLiveArray.count > indexPath.row
            {
                collectionView.alpha = 0.4
                showOverlay()
                operationInRedirection  = BlockOperation (block: {
                    self.didSelectExtension(indexPathRow: indexPath.row,operation:self.operationInRedirection)
                })
                self.operationQueueObjRedirection.addOperation(operationInRedirection)

//                let backgroundQueue = DispatchQueue(label: "com.app.queue",
//                                                    qos: .background,
//                                                    target: nil)
//                backgroundQueue.async {
//                    self.didSelectExtension(indexPathRow: indexPath.row)
//                }
            }
        }
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
}

extension Dictionary {
    mutating func update(other:Dictionary) {
        for (key,value) in other {
            self.updateValue(value, forKey:key)
        }
    }
}
