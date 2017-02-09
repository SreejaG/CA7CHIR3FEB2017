
import UIKit

class GlobalDataChannelList: NSObject {
    
    var globalChannelDataSource: [[String:Any]] = [[String:Any]]()
    var channelDetailsDict : [[String:Any]] = [[String:Any]]()
    
    var operationQueueObjInChannelList = OperationQueue()
    var operationInChannelList = BlockOperation()
    
    let defaults = UserDefaults.standard
    
    var userId : String = String()
    var accessToken : String = String()
    
    class var sharedInstance: GlobalDataChannelList
    {
        struct Singleton
        {
            static let instance = GlobalDataChannelList()
            private init() {}
        }
        return Singleton.instance
    }
    
    func initialise()
    {
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        getChannelDetails(userName: userId, token: accessToken)
    }
    
    func getChannelDetails(userName: String, token: String)
    {
        ChannelManager.sharedInstance.getChannelDetails(userName: userName, accessToken: token, success: { (response) -> () in
            self.authenticationSuccessHandler(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandlerChannel(error: error, code: message)
        }
    }
    
    func authenticationSuccessHandler(response:Any?)
    {
        if let json = response as? [String: Any]
        {
            channelDetailsDict.removeAll()
            channelDetailsDict = json["channels"] as! [[String:Any]]
            setChannelDetails()
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func authenticationFailureHandlerChannel(error: NSError?, code: String)
    {
        var codeString : String = String()
        
        if !RequestManager.sharedInstance.validConnection() {
            codeString = "noNetwork"
        }
        else if code.isEmpty == false {
            codeString = code
        }
        else{
            if(UIApplication.shared.applicationState == .inactive)
            {
                codeString = "Nothing"
            }
            else{
                codeString = "ResponseError"
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "stopInitialising"), object:codeString)
    }
    
    func setChannelDetails()
    {
        globalChannelDataSource.removeAll()
        for element in channelDetailsDict{
            let channelId = "\(element[channelIdKey]!)"
            var mediaId = String()
            if let _ = element[latestMediaIdKey] as? Int
            {
                mediaId = String(element[latestMediaIdKey] as! Int)
            }
            else{
                mediaId = ""
            }
            let channelName = element[channelNameKey] as! String
            let mediaSharedCount = String(element[totalMediaKey] as! Int)
            let createdTime = element[ChannelCreatedTimeKey] as! String
            let sharedBool = (element[chanelSharedIndicatorKey] as! Bool).hashValue
            
            self.globalChannelDataSource.append([channelIdKey: channelId,channelNameKey: channelName,mediaIdKey: mediaId,totalMediaKey: mediaSharedCount,ChannelCreatedTimeKey: createdTime,sharedOriginalKey: sharedBool,sharedTemporaryKey: sharedBool])
        }
        
        if(self.globalChannelDataSource.count > 0){
            sortChannelList()
            operationInChannelList  = BlockOperation (block: {
                self.downloadMediaFromGCS()
            })
            self.operationQueueObjInChannelList.addOperation(operationInChannelList)
        }
    }
    
    func downloadMediaFromGCS(){
//        var url: NSURL = NSURL()
        for i in 0 ..< globalChannelDataSource.count
        {
            if operationInChannelList.isCancelled
            {
                return
            }
            var imageForMedia : UIImage = UIImage()
            if(i < globalChannelDataSource.count){
                if let mediaIdChk = globalChannelDataSource[i][mediaIdKey]
                {
                    let mediaIdForFilePath = "\(mediaIdChk as! String)thumb"
                    let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                    let savingPath = parentPath! + "/" + mediaIdForFilePath
                    let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: savingPath)
                    if fileExistFlag == true{
                        let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: savingPath)
                        imageForMedia = mediaImageFromFile!
                    }
                    else{
                        let mediaUrl = UrlManager.sharedInstance.getThumbImageForMedia(mediaId: mediaIdChk as! String, userName: userId, accessToken: accessToken)
                        let url: NSURL  = convertStringtoURL(url: mediaUrl)
                        downloadMedia(downloadURL: url, key: "ThumbImage", completion: { (result) -> Void in
                            if(result != UIImage()){
                                let imageDataFromresult = UIImageJPEGRepresentation(result, 0.5)
                                if(imageDataFromresult != nil){
                                    let imageDataFromresultAsNsdata = (imageDataFromresult as NSData?)!
                                    let imageDataFromDefault = UIImageJPEGRepresentation(UIImage(named: "thumb12")!, 0.5)
                                    let imageDataFromDefaultAsNsdata = (imageDataFromDefault as NSData?)!
                                    if(imageDataFromresultAsNsdata.isEqual(imageDataFromDefaultAsNsdata)){
                                        
                                    }
                                    else{
                                        _ = FileManagerViewController.sharedInstance.saveImageToFilePath    (mediaName: mediaIdForFilePath, mediaImage: result)
                                    }
                                    imageForMedia = result
                                }
                                else{
                                    imageForMedia =  UIImage(named: "thumb12")!
                                }
                            }
                            else{
                                imageForMedia =  UIImage(named: "thumb12")!
                            }
                        })
                    }
                }else{
                    imageForMedia =  UIImage(named: "thumb12")!
                }
                self.globalChannelDataSource[i][tImageKey] = imageForMedia
            }
        }
    }
    
    func downloadMedia(downloadURL : NSURL ,key : String , completion: (_ result: UIImage) -> Void)
    {
        var mediaImage : UIImage = UIImage()
        do {
            let data = try NSData(contentsOf: downloadURL as URL,options: NSData.ReadingOptions())
            if let imageData = data as NSData? {
                if let mediaImage1 = UIImage(data: imageData as Data)
                {
                    mediaImage = mediaImage1
                    completion(mediaImage)
                }
                else{
                    let failedString = String(data: imageData as Data, encoding: String.Encoding.utf8)
                    let fullString = failedString?.components(separatedBy: ",")
                    let errorString = fullString?[1].components(separatedBy: ":")
                    var orgString = errorString?[1]
                    orgString = orgString?.trimmingCharacters(in: NSCharacterSet.alphanumerics.inverted)
                    if((orgString == "USER004") || (orgString == "USER005") || (orgString == "USER006")){
                        operationInChannelList.cancel()
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "stopInitialising"), object:orgString)
                    }
                    else{
                        completion(UIImage(named: "thumb12")!)
                    }
                }
            }
            else
            {
                completion(UIImage(named: "thumb12")!)
            }
            
        } catch {
            completion(UIImage(named: "thumb12")!)
        }
    }
    
    func sortChannelList(){
        globalChannelDataSource.sort(by: { p1, p2 in
            let time1 = p1[ChannelCreatedTimeKey] as! String
            let time2 = p2[ChannelCreatedTimeKey] as! String
            return time1 > time2
        })
        NotificationCenter.default.post(name:NSNotification.Name(rawValue:"removeActivityIndicatorMyChannelList"), object:nil)
        autoDownloadChannelDetails()
    }
    
    func autoDownloadChannelDetails()
    {
        GlobalChannelToImageMapping.sharedInstance.globalData(source: globalChannelDataSource)
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    func enableDisableChannelList(dataSource : [[String:Any]])  {
        for element in dataSource
        {
            let channelIdChk = element[channelIdKey] as! String
            let sharedIndicator = element[sharedTemporaryKey] as! Int
            for i in 0 ..< globalChannelDataSource.count
            {
                if(i < globalChannelDataSource.count){
                    let chanelId = globalChannelDataSource[i][channelIdKey] as! String
                    if channelIdChk == chanelId
                    {
                        globalChannelDataSource[i][sharedOriginalKey] = sharedIndicator
                        globalChannelDataSource[i][sharedTemporaryKey] = sharedIndicator
                    }
                }
            }
        }
    }
}
