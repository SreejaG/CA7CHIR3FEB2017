
import UIKit

class ChannelSharedListAPI: NSObject {
    var  dummy:[[String:Any]] = [[String:Any]]()
    var dataSource:[[String:Any]] = [[String:Any]]()
    var SharedChannelListDataSource:[[String:Any]] = [[String:Any]]()
    var pullToRefreshSource:[[String:Any]] = [[String:Any]]()
    var mediaSharedCountArray:[[String:Any]] = [[String:Any]]()
    var mediaShared:[[String:Any]] = [[String:Any]]()
    var pullTorefresh : Bool = false
    var operationQueue = OperationQueue()
    var operation2 : BlockOperation = BlockOperation()
    
    class var sharedInstance: ChannelSharedListAPI
    {
        struct Singleton
        {
            static let instance = ChannelSharedListAPI()
            private init() {}
        }
        return Singleton.instance
    }
    
    func initialisedata()
    {
        let userId = UserDefaults.standard.value(forKey: userLoginIdKey) as! String
        let accessToken = UserDefaults.standard.value(forKey: userAccessTockenKey) as! String
        getChannelSharedDetails(userName: userId, token: accessToken)
    }
    
    func cancelOperationQueue()
    {
        operation2.cancel()
    }
    
    func getChannelSharedDetails(userName: String, token: String)
    {
        ChannelManager.sharedInstance.getChannelShared(userName: userName, accessToken: token, success: { (response) -> () in
            self.authenticationSuccessHandler(response: response)
            
        }) { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
        }
    }
    
    func authenticationSuccessHandler(response:AnyObject?)
    {
        if let json = response as? [String: Any]
        {
            dummy.removeAll()
            dataSource.removeAll()
            let responseArrLive = json[liveChannelKey] as! [[String:Any]]
            if (UserDefaults.standard.object(forKey: "Shared") != nil)
            {
                mediaShared = UserDefaults.standard.value(forKey: "Shared") as! NSArray as! [[String : Any]]
            }
            if (responseArrLive.count != 0)
            {
                UserDefaults.standard.setValue("NotEmpty", forKey: "MEDIA")
                
                for element in responseArrLive{
                    let channelId = String(element[ch_channelIdkey] as! Int)
                    let channelName = element[ch_channelNameKey] as! String
                    let streamTocken = element[streamTockenKey] as! String
                    let mediaSharedCount = String(element[sharedMediaCount] as! Int)
                    let username = element[usernameKey] as! String
                    let liveStream = "1"
                    let channelSubId = String(element[subChannelIdKey] as! Int)
                    let profileImageUserName = nullToNil(value: element[usernameKey]!)
                    let mediaUrl =  "noimage"
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
                    let localDateStr = dateFormatter.string(from: NSDate() as Date)
                    var flag: Bool = false
                    var thumbUrl : String = String()
                    if("\(profileImageUserName)" != "")
                    {
                        let profileImageNameBeforeNullChk = UrlManager.sharedInstance.getProfileURL(userId: profileImageUserName! as! String)
                        thumbUrl =  nullToNil(value: profileImageNameBeforeNullChk)! as! String
                    }
                    
                    if(mediaShared.count > 0)
                    {
                        for i in 0  ..< mediaShared.count
                        {
                            if let val = mediaShared[i][ch_channelIdkey] {
                                if((val as! String) == channelId)
                                {
                                    flag = true
                                }
                            }
                        }
                        if(!flag)
                        {
                            mediaShared.append([ch_channelIdkey:channelId,sharedMediaCount:mediaSharedCount])
                        }
                    }
                    else{
                        mediaShared.append([ch_channelIdkey:channelId,sharedMediaCount:mediaSharedCount])
                    }
                    dataSource.append([ch_channelIdkey:channelId,ch_channelNameKey:channelName,subChannelIdKey : channelSubId,sharedMediaCount:mediaSharedCount, streamTockenKey:streamTocken,timeStamp:localDateStr,usernameKey:username,liveStreamStatus:liveStream, profileImageKey:thumbUrl,mediaImageKey:mediaUrl])
                }
            }
            
            let responseArr = json[subscribedChannelsKey] as! [[String:Any]]
            if(responseArr.count == 0)
            {
                UserDefaults.standard.setValue("Empty", forKey: "EmptyShare")
            }
            if (responseArr.count != 0)
            {
                UserDefaults.standard.setValue("NotEmpty", forKey: "EmptyShare")
                for element in responseArr{
                    
                    let channelId = String(element[ch_channelIdkey] as! Int)
                    let channelName = element[ch_channelNameKey] as! String
                    let mediaSharedCount = String(element[sharedMediaCount] as! Int)
                    let time = element[lastUpdatedTimeStamp] as! String
                    let username = element[usernameKey] as! String
                    let channelSubId = String(element[subChannelIdKey] as! Int)
                    let liveStream = "0"
                    let thumbID  = nullToNil(value: element[latest_thumbnail_idKey])
                    let profileImageUserName = nullToNil(value: element[usernameKey]!)
                    var mediaThumbUrl : String = String()
                    var thumbUrl : String = String()
                    if liveStream == "0"
                    {
                        if("\(thumbID)"  != "")
                        {
                            let mediaThumbUrlBeforeNullChk = UrlManager.sharedInstance.getMediaURL(mediaId: "\(thumbID!)")
                            mediaThumbUrl = nullToNil(value: mediaThumbUrlBeforeNullChk)! as! String
                        }
                        else{
                            mediaThumbUrl = "noimage"
                            
                        }
                    }
                    else
                    {
                        mediaThumbUrl = "noimage"
                    }
                    if("\(profileImageUserName)" != "")
                    {
                        let profileImageNameBeforeNullChk = UrlManager.sharedInstance.getProfileURL(userId: profileImageUserName! as! String)
                        thumbUrl =  nullToNil(value: profileImageNameBeforeNullChk)! as! String
                    }
                    var flag: Bool = false
                    
                    if(mediaShared.count > 0)
                    {
                        for i in 0  ..< mediaShared.count
                        {
                            if let val = mediaShared[i][ch_channelIdkey] {
                                if((val as! String) == channelId)
                                {
                                    flag = true
                                }
                            }
                        }
                        if(!flag)
                        {
                            mediaShared.append([ch_channelIdkey:channelId,sharedMediaCount:mediaSharedCount])
                        }
                    }
                    else{
                        mediaShared.append([ch_channelIdkey:channelId,sharedMediaCount:mediaSharedCount])
                    }
                    dummy.append([ch_channelIdkey:channelId, subChannelIdKey : channelSubId,ch_channelNameKey:channelName,sharedMediaCount:mediaSharedCount,timeStamp:time,usernameKey:username,liveStreamStatus:liveStream,streamTockenKey:"0", profileImageKey:thumbUrl,mediaImageKey:mediaThumbUrl])
                }
            }
            if(dummy.count > 0)
            {
                
                dummy.sort(by: { p1, p2 in
                    
                    let time1 = p1[timeStamp] as! String
                    let time2 = p2[timeStamp] as! String
                    return time1 > time2
                })
            }
            
            for element in dummy
            {
                dataSource.append(element)
            }
            
            UserDefaults.standard.set(dummy.count, forKey: "streamChannelCount")
            UserDefaults.standard.set(mediaShared, forKey: "Shared")
            
            if(dataSource.count > 0){
                
                operation2  = BlockOperation (block: {
                    self.downloadMediaFromGCS()
                })
                self.operationQueue.addOperation(operation2)
            }
            else{
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PullToRefreshSharedChannelList"), object:"failure")
            }
        }
        else
        {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PullToRefreshSharedChannelList"), object:"failure")
            
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func pullToRefreshData( subID : String)
    {
        pullTorefresh = true
        let userId = UserDefaults.standard.value(forKey: userLoginIdKey) as! String
        let accessToken = UserDefaults.standard.value(forKey: userAccessTockenKey) as! String
        if( SharedChannelListDataSource.count > 0 )
        {
            ChannelManager.sharedInstance.getChannelSharedPullToRefresh(userName: userId, accessToken:    accessToken, channelSubId: subID, success: { (response) in
                self.authenticationSuccessHandler(response: response)
            }) { (error, code) in
                self.authenticationFailureHandler(error: error, code: code)
            }
        }
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    func nullToNil(value : Any?) -> Any? {
        if value is NSNull {
            return ""
        } else {
            return value
        }
    }
    
    func downloadMediaFromGCS(){
        for i in 0 ..< dataSource.count
        {
            var mediaImage : UIImage?
            var profileImage : UIImage?
            if(dataSource.count > 0 && dataSource.count > i)
            {
                let profileImageName = dataSource[i][profileImageKey] as! String
                if(profileImageName != "")
                {
                    profileImage = createProfileImage(profileName: profileImageName)
                }
                else{
                    profileImage = UIImage(named: "dummyUser")
                }
                
                if(dataSource.count > 0 && i < dataSource.count)
                {
                    if let media1 = dataSource[i][mediaImageKey]
                    {
                        if(media1 as! String != "noimage"){
                            if(media1 as! String != "")
                            {
                                mediaImage = createMediaThumb(mediaName: media1 as! String)
                                if(mediaImage == nil){
                                    mediaImage = UIImage()
                                }
                            }
                            else{
                                mediaImage = UIImage()
                            }
                        }
                        else{
                            mediaImage = UIImage()
                        }
                        
                    }
                }
            }
            if(!pullTorefresh)
            {
                if(dataSource.count > 0)
                {
                    if (i < self.dataSource.count )
                    {
                        if(!checkDuplicate(chId: self.dataSource[i][ch_channelIdkey] as! String))
                        {
                            if(dataSource.count > 0)
                            {
                                SharedChannelListDataSource.append([ch_channelIdkey:self.dataSource[i][ch_channelIdkey]!,ch_channelNameKey:self.dataSource[i][ch_channelNameKey]!,sharedMediaCount:self.dataSource[i][sharedMediaCount]!,timeStamp:self.dataSource[i][timeStamp]!,usernameKey:self.dataSource[i][usernameKey]!,liveStreamStatus:self.dataSource[i][liveStreamStatus]!,streamTockenKey:self.dataSource[i][streamTockenKey]!,profileImageKey:profileImage!,mediaImageKey:mediaImage!, subChannelIdKey :self.dataSource[i][subChannelIdKey]!])
                            }
                        }
                    }
                }
            }
            else
            {
                if(dataSource.count > 0 && i < dataSource.count)
                {
                    pullToRefreshSource.append([ch_channelIdkey:self.dataSource[i][ch_channelIdkey]!,ch_channelNameKey:self.dataSource[i][ch_channelNameKey]!,sharedMediaCount:self.dataSource[i][sharedMediaCount]!,timeStamp:self.dataSource[i][timeStamp]!,usernameKey:self.dataSource[i][usernameKey]!,liveStreamStatus:self.dataSource[i][liveStreamStatus]!,streamTockenKey:self.dataSource[i][streamTockenKey]!,profileImageKey:profileImage!,mediaImageKey:mediaImage!,subChannelIdKey:self.dataSource[i][subChannelIdKey]!])
                }
            }
        }
        
        /* if data available while pull to refresh no need to add data to global here
         / access datasource from calling view and insert respected rows to table view and update global source there in main view */
        if(pullTorefresh)
        {
            if(pullToRefreshSource.count > 0)
            {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PullToRefreshSharedChannelList"), object:"success")
            }
            else
            {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PullToRefreshSharedChannelList"), object:"failure")
            }
        }
        else
        {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SharedChannelList"), object:"success")
        }
    }
    
    func checkDuplicate( chId : String) -> Bool
    {
        var flag: Bool = false
        for i in 0  ..< SharedChannelListDataSource.count
        {
            if SharedChannelListDataSource[i][ch_channelIdkey] as! String == chId{
                flag = true
            }
        }
        return flag
    }
    
    func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        if !RequestManager.sharedInstance.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
            }
            else{
            }
        }
        else{
        }
    }
    
    func createMediaThumb(mediaName: String) -> UIImage
    {
        var mediaImage : UIImage?
        if(mediaName != "")
        {
            let url: NSURL = convertStringtoURL(url: mediaName)
            if let mediaData = NSData(contentsOf: url as URL){
                let mediaImageData = (mediaData as NSData?)!
                mediaImage = UIImage(data: mediaImageData as Data)
                if(mediaImage == nil){
                    mediaImage = UIImage()
                }
            }
            else{
                mediaImage = UIImage()
            }
        }
        else{
            mediaImage = UIImage()
        }
        return mediaImage!
    }
    
    func createProfileImage(profileName: String) -> UIImage
    {
        var profileImage : UIImage = UIImage()
        let url: NSURL = convertStringtoURL(url: profileName)
        if let data = NSData(contentsOf: url as URL){
            let imageDetailsData = (data as NSData?)!
            if let profile = UIImage(data: imageDetailsData as Data){
                profileImage = profile
            }
            else{
                profileImage = UIImage(named: "dummyUser")!
            }
        }
        else{
            profileImage = UIImage(named: "dummyUser")!
        }
        return profileImage
    }
    
    func callAbsolute(value : Int ) -> Int
    {
        if (value < 0)
        {
            let value1 = value * -1;
            return value1
        }
        return value
    }
}
