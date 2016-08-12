
import UIKit

class GlobalChannelToImageMapping: NSObject {
    
    var GlobalChannelImageDict : [String : [[String : AnyObject]]] =  [String : [[String : AnyObject]]]()
    var imageDataSource: [[String:AnyObject]] = [[String:AnyObject]]()
    
    var channelImageDataSource: [[String:AnyObject]] = [[String:AnyObject]]()
    var localDataSource: [[String:AnyObject]] = [[String:AnyObject]]()
    var dummy: [[String:AnyObject]] = [[String:AnyObject]]()
    
    var channelId : String!
    var channelDetailId : String = String()
    
    var dataSourceCount : Int = 0
    
    class var sharedInstance: GlobalChannelToImageMapping
    {
        struct Singleton
        {
            static let instance = GlobalChannelToImageMapping()
            private init() {}
        }
        return Singleton.instance
    }
    
    func globalData(source :[[String:AnyObject]])
    {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GlobalChannelToImageMapping.display), name: "success", object:nil)
        dummy = source
        
        getMediaByChannelId()
    }
    
    func display(notif: NSNotification)
    {
        if (dataSourceCount < dummy.count - 1)
        {
            dataSourceCount  = dataSourceCount + 1
            
            getMediaByChannelId()
        }
        else if dataSourceCount == dummy.count - 1
        {
            let codeString = "Success"
            NSNotificationCenter.defaultCenter().postNotificationName("stopInitialising", object: codeString)
        }
    }
    
    func getMediaByChannelId()
    {
        let totalMediaCount : Int = Int(dummy[dataSourceCount][totalMediaKey]  as! String)!
        let channelId : String =  dummy[dataSourceCount][channelIdKey] as! String
        self.channelDetailId = channelId
        self.initialise(totalMediaCount, channelid: channelId)
    }
    
    func initialise(totalMediaCount : Int, channelid : String){
        
        let defaults = NSUserDefaults .standardUserDefaults()
        let userId = defaults.valueForKey(userLoginIdKey) as! String
        let accessToken = defaults.valueForKey(userAccessTockenKey) as! String
        
        let startValue = "0"
        let endValue = String(totalMediaCount)
        
        channelDetailId = channelid
        
        if totalMediaCount <= 0
        {
            imageDataSource.removeAll()
            GlobalChannelImageDict.updateValue(imageDataSource, forKey: channelDetailId)
            NSNotificationCenter.defaultCenter().postNotificationName("success", object: channelDetailId)
        }
        else{
            
            ImageUpload.sharedInstance.getChannelMediaDetails(channelid , userName: userId, accessToken: accessToken, limit: endValue, offset: startValue, success: { (response) -> () in
                self.authenticationSuccessHandler(response,id: channelid)
            }) { (error, message) -> () in
                //   self.authenticationFailureHandler(error, code: message)
                return
            }
        }
    }
    
    func authenticationSuccessHandler(response:AnyObject?, id:String)
    {
        if let json = response as? [String: AnyObject]
        {
            imageDataSource.removeAll()
            let responseArr = json["MediaDetail"] as! [AnyObject]
            for index in 0 ..< responseArr.count
            {
                let mediaId = responseArr[index].valueForKey("media_detail_id")?.stringValue
                let channelMediaDetailId = responseArr[index].valueForKey("channel_media_detail_id")?.stringValue
                let mediaUrlBeforeNullChk = responseArr[index].valueForKey("thumbnail_name_SignedUrl")
                let mediaUrl = nullToNil(mediaUrlBeforeNullChk) as! String
                let mediaType =  responseArr[index].valueForKey("gcs_object_type") as! String
                let actualUrlBeforeNullChk =  responseArr[index].valueForKey("gcs_object_name_SignedUrl")
                let actualUrl = nullToNil(actualUrlBeforeNullChk) as! String
                let notificationType : String = "likes"
                let time = responseArr[index].valueForKey("created_time_stamp") as! String
                
                imageDataSource.append([mediaIdKey:mediaId!,channelMediaIdKey:channelMediaDetailId!,mediaTypeKey:mediaType, notifTypeKey:notificationType, createdTimeKey:time, progressKey:0.0, tImageURLKey:mediaUrl,fImageURLKey:actualUrl])
            }
            
            if(imageDataSource.count > 0){
                imageDataSource.sortInPlace({ p1, p2 in
                    let time1 = Int(p1[mediaIdKey] as! String)
                    let time2 = Int(p2[mediaIdKey] as! String)
                    return time1 > time2
                })
                
                GlobalChannelImageDict.updateValue(imageDataSource, forKey: channelDetailId)
                NSNotificationCenter.defaultCenter().postNotificationName("success", object: self.channelDetailId)
            }
        }
    }
    
    func downloadMediaFromGCS(chanelId: String, start: Int, end:Int, operationObj: NSBlockOperation){
        
        localDataSource.removeAll()
        for var i = start; i < end; i++
        {
            localDataSource.append(GlobalChannelImageDict[chanelId]![i])
        }
        if localDataSource.count > 0
        {
            for var k = 0; k < localDataSource.count; k++
            {
                if operationObj.cancelled == true{
                    return
                }
                
                print("k value in chanel image mapping ===> \(k)")
                
                var imageForMedia : UIImage = UIImage()
                let mediaId = String(localDataSource[k][mediaIdKey]!)
                let mediaIdForFilePath = "\(mediaId)thumb"
                let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath()
                let savingPath = "\(parentPath)/\(mediaIdForFilePath)"
                let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(savingPath)
                if fileExistFlag == true{
                    let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(savingPath)
                    imageForMedia = mediaImageFromFile!
                }
                else{
                    let mediaUrl = localDataSource[k][tImageURLKey] as! String
                    if(mediaUrl != ""){
                        let url: NSURL = convertStringtoURL(mediaUrl)
                        downloadMedia(url, key: "ThumbImage", completion: { (result) -> Void in
                            
                            if(result != UIImage()){
                                let imageDataFromresult = UIImageJPEGRepresentation(result, 0.5)
                                let imageDataFromresultAsNsdata = (imageDataFromresult as NSData?)!
                                let imageDataFromDefault = UIImageJPEGRepresentation(UIImage(named: "thumb12")!, 0.5)
                                let imageDataFromDefaultAsNsdata = (imageDataFromDefault as NSData?)!
                                if(imageDataFromresultAsNsdata.isEqual(imageDataFromDefaultAsNsdata)){
                                    
                                }
                                else{
                                    FileManagerViewController.sharedInstance.saveImageToFilePath(mediaIdForFilePath, mediaImage: result)
                                }
                                imageForMedia = result
                            }
                            else{
                                imageForMedia = UIImage(named: "thumb12")!
                            }
                        })
                    }
                }
                localDataSource[k][tImageKey] = imageForMedia
            }
            
            for var j = 0; j < GlobalChannelImageDict[chanelId]!.count; j++
            {
                let mediaIdChk = GlobalChannelImageDict[chanelId]![j][mediaIdKey] as! String
                for element in localDataSource
                {
                    let mediaIdFromLocal = element[mediaIdKey] as! String
                    if mediaIdChk == mediaIdFromLocal
                    {
                        GlobalChannelImageDict[chanelId]![j][tImageKey] = element[tImageKey] as! UIImage
                    }
                }
            }
            localDataSource.removeAll()
            NSNotificationCenter.defaultCenter().postNotificationName("removeActivityIndicatorMyChannel", object:nil)
        }
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
    
    func downloadMedia(downloadURL : NSURL ,key : String , completion: (result: UIImage) -> Void)
    {
        var mediaImage : UIImage = UIImage()
        let data = NSData(contentsOfURL: downloadURL)
        if let imageData = data as NSData? {
            if let mediaImage1 = UIImage(data: imageData)
            {
                mediaImage = mediaImage1
            }
            completion(result: mediaImage)
        }
        else
        {
            completion(result:UIImage(named: "thumb12")!)
        }
    }
    
    func nullToNil(value : AnyObject?) -> AnyObject? {
        if value is NSNull {
            return ""
        } else {
            return value
        }
    }
    
    //add medias to channels when user capture an image
    func mapNewMediasToAllChannels(dataSourceRow: [String:AnyObject])
    {
        for var j = 0; j < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count; j++
        {
            let chanId = GlobalDataChannelList.sharedInstance.globalChannelDataSource[j][channelIdKey] as! String
            let sharedInd = GlobalDataChannelList.sharedInstance.globalChannelDataSource[j][sharedOriginalKey] as! Bool
            let chanName = GlobalDataChannelList.sharedInstance.globalChannelDataSource[j][channelNameKey] as! String
            
            if(sharedInd == true || chanName == "Archive")
            {
                GlobalChannelImageDict[chanId]!.append(dataSourceRow)
                
                GlobalChannelImageDict[chanId]!.sortInPlace({ p1, p2 in
                    let time1 = Int(p1[mediaIdKey] as! String)
                    let time2 = Int(p2[mediaIdKey] as! String)
                    return time1 > time2
                })
                
                let thumbURL = GlobalChannelImageDict[chanId]![0][tImageURLKey] as! String
                let mediaIdForFilePath = "\(GlobalChannelImageDict[chanId]![0][mediaIdKey] as! String)thumb"
                GlobalDataChannelList.sharedInstance.globalChannelDataSource[j][totalMediaKey] = "\(GlobalChannelImageDict[chanId]!.count)"
                GlobalDataChannelList.sharedInstance.globalChannelDataSource[j][tImageURLKey] = thumbURL
                GlobalDataChannelList.sharedInstance.globalChannelDataSource[j][tImageKey] = downloadLatestMedia(mediaIdForFilePath, thumbURL: thumbURL)
                
                if chanName == "Archive"
                {
                    var archCount : Int = Int()
                    if let archivetotal =  NSUserDefaults.standardUserDefaults().valueForKey(ArchiveCount)
                    {
                        archCount = archivetotal as! Int
                    }
                    else{
                        archCount = 0
                    }
                    archCount = archCount + 1
                    NSUserDefaults.standardUserDefaults().setInteger( archCount, forKey: ArchiveCount)
                }
            }
        }
        GlobalDataChannelList.sharedInstance.globalChannelDataSource.sortInPlace({ p1, p2 in
            let time1 = p1[createdTimeKey] as! String
            let time2 = p2[createdTimeKey] as! String
            return time1 > time2
        })
        
        NSNotificationCenter.defaultCenter().postNotificationName("setFullscreenImage", object: nil)
    }
    
    // Add media from one channel to other channels
    func addMediaToChannel(channelSelectedDict: [[String:AnyObject]],  mediaDetailOfSelectedChannel : [[String:AnyObject]])
    {
        for var i = 0; i < channelSelectedDict.count; i++
        {
            let selectedChanelId = channelSelectedDict[i][channelIdKey] as! String
            var chkFlag = false
            var dataRowOfSelectedMediaArray : [String: AnyObject] = [String:AnyObject]()
            
            for element in mediaDetailOfSelectedChannel
            {
                dataRowOfSelectedMediaArray = element
                let mediaIdChk = element[mediaIdKey] as! String
                for elementGlob in GlobalChannelImageDict[selectedChanelId]!
                {
                    let mediaId = elementGlob[mediaIdKey] as! String
                    if mediaIdChk == mediaId
                    {
                        chkFlag = true
                        break
                    }
                    else{
                        chkFlag = false
                    }
                }
                if chkFlag == false
                {
                    GlobalChannelImageDict[selectedChanelId]!.append(dataRowOfSelectedMediaArray)
                }
            }
            GlobalChannelImageDict[selectedChanelId]!.sortInPlace({ p1, p2 in
                let time1 = Int(p1[mediaIdKey] as! String)
                let time2 = Int(p2[mediaIdKey] as! String)
                return time1 > time2
            })
            
            for var k = 0; k < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count; k++
            {
                let chanIdChk = GlobalDataChannelList.sharedInstance.globalChannelDataSource[k][channelIdKey] as! String
                if chanIdChk == selectedChanelId
                {
                    let thumbURL = GlobalChannelImageDict[selectedChanelId]![0][tImageURLKey] as! String
                    let mediaIdForFilePath = "\(GlobalChannelImageDict[selectedChanelId]![0][mediaIdKey] as! String)thumb"
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[k][totalMediaKey] = "\(GlobalChannelImageDict[selectedChanelId]!.count)"
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[k][tImageURLKey] = thumbURL
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[k][tImageKey] = downloadLatestMedia(mediaIdForFilePath, thumbURL: thumbURL)
                }
            }
        }
        GlobalDataChannelList.sharedInstance.globalChannelDataSource.sortInPlace({ p1, p2 in
            let time1 = p1[createdTimeKey] as! String
            let time2 = p2[createdTimeKey] as! String
            return time1 > time2
        })
    }
    
    func downloadLatestMedia(mediaIdForFilePath: String, thumbURL : String) -> UIImage
    {
        var imageForMedia : UIImage = UIImage()
        let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath()
        let savingPath = "\(parentPath)/\(mediaIdForFilePath)"
        let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(savingPath)
        if fileExistFlag == true{
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(savingPath)
            imageForMedia = mediaImageFromFile!
        }
        else{
            if(thumbURL != ""){
                let url = convertStringtoURL(thumbURL)
                downloadMedia(url, key: "ThumbImage", completion: { (result) -> Void in
                    if(result != UIImage()){
                        let imageDataFromresult = UIImageJPEGRepresentation(result, 0.5)
                        let imageDataFromresultAsNsdata = (imageDataFromresult as NSData?)!
                        let imageDataFromDefault = UIImageJPEGRepresentation(UIImage(named: "thumb12")!, 0.5)
                        let imageDataFromDefaultAsNsdata = (imageDataFromDefault as NSData?)!
                        if(imageDataFromresultAsNsdata.isEqual(imageDataFromDefaultAsNsdata)){
                            
                        }
                        else{
                            FileManagerViewController.sharedInstance.saveImageToFilePath(mediaIdForFilePath, mediaImage: result)
                        }
                        imageForMedia = result
                    }
                    else{
                        imageForMedia =  UIImage(named: "thumb12")!
                    }
                })
            }
        }
        return imageForMedia
    }
    
    // delete media from Channels
    func deleteMediasFromChannel(channelId: String, mediaIds: NSMutableArray)
    {
        let archiveChannelId = NSUserDefaults.standardUserDefaults().valueForKey(archiveId) as! Int
        
        if channelId == "\(archiveChannelId)"
        {
            deleteMediasFromAllChannels(channelId, mediaIds: mediaIds)
        }
        else{
            deleteMediaFromParticularChannel(channelId,mediaIds:mediaIds)
        }
    }
    
    //delete media from a single channel
    func deleteMediaFromParticularChannel(chanelId : String,mediaIds: NSMutableArray)
    {
        var selectedIndex : [Int] = [Int]()
        var thumbURL : String = String()
        var mediaIdForFilePath : String = String()
        
        for var i = 0; i < mediaIds.count; i++
        {
            let selectedMediaId = mediaIds[i] as! String
            var chkFlag = false
            var indexOfJ = 0
            
            for var j = 0; j < GlobalChannelImageDict[chanelId]!.count; j++
            {
                indexOfJ = j
                let mediaIdChk = GlobalChannelImageDict[chanelId]![j][mediaIdKey] as! String
                if mediaIdChk == selectedMediaId
                {
                    chkFlag = true
                    break
                }
            }
            if chkFlag == true
            {
                selectedIndex.append(indexOfJ)
            }
        }
        if selectedIndex.count > 0
        {
            selectedIndex = selectedIndex.sort()
            for var k = 0; k < selectedIndex.count; k++
            {
                let indexToDelete = selectedIndex[k] - k
                GlobalChannelImageDict[chanelId]!.removeAtIndex(indexToDelete)
            }
            GlobalChannelImageDict[chanelId]!.sortInPlace({ p1, p2 in
                let time1 = Int(p1[mediaIdKey] as! String)
                let time2 = Int(p2[mediaIdKey] as! String)
                return time1 > time2
            })
        }
        
        for var p = 0; p < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count; p++
        {
            let chanIdChk = GlobalDataChannelList.sharedInstance.globalChannelDataSource[p][channelIdKey] as! String
            if chanelId == chanIdChk
            {
                if GlobalChannelImageDict[chanelId]!.count > 0
                {
                    thumbURL = GlobalChannelImageDict[chanelId]![0][tImageURLKey] as! String
                    mediaIdForFilePath = "\(GlobalChannelImageDict[chanelId]![0][mediaIdKey] as! String)thumb"
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[p][tImageURLKey] = thumbURL
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[p][tImageKey] = downloadLatestMedia(mediaIdForFilePath, thumbURL: thumbURL)
                }else{
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[p][tImageURLKey] = "empty"
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource[p][tImageKey] = UIImage(named: "thumb12")
                }
                GlobalDataChannelList.sharedInstance.globalChannelDataSource[p][totalMediaKey] = "\(GlobalChannelImageDict[chanelId]!.count)"
            }
        }
        GlobalDataChannelList.sharedInstance.globalChannelDataSource.sortInPlace({ p1, p2 in
            let time1 = p1[createdTimeKey] as! String
            let time2 = p2[createdTimeKey] as! String
            return time1 > time2
        })
    }
    
    
    //deleting from archive needs to delete medias from all channels
    func deleteMediasFromAllChannels(chanelId : String,mediaIds: NSMutableArray)
    {
        let globalchannelIdList : Array = Array(GlobalChannelImageDict.keys)
        
        for var i = 0; i < globalchannelIdList.count; i++
        {
            let globalChanelId = globalchannelIdList[i]
            deleteMediaFromParticularChannel(globalChanelId, mediaIds: mediaIds)
        }
        
        NSUserDefaults.standardUserDefaults().setInteger(GlobalChannelImageDict[chanelId]!.count, forKey: ArchiveCount)
    }
}