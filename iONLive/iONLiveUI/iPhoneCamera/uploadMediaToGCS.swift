
import UIKit

class uploadMediaToGCS: UIViewController, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate {
    
    let cameraController = IPhoneCameraViewController()
    let imageUploadManager = ImageUpload.sharedInstance
    let requestManager = RequestManager.sharedInstance
    let mediaBeforeUploadCompleteManager = MediaBeforeUploadComplete.sharedInstance
    
    let defaults = NSUserDefaults .standardUserDefaults()
    
    var userId : String = String()
    var accessToken : String = String()
    
    var path : String = String()
    var media : String = String()
    var videoSavedURL : NSURL = NSURL()
    var videoDuration : String = String()
    
    var imageFromDB : UIImage = UIImage()
    var imageAfterConversionThumbnail : UIImage = UIImage()
    
    var uploadThumbImageURLGCS : String = String()
    var uploadFullImageOrVideoURLGCS : String = String()
    var uploadImageNameForGCS : String = String()
    var mediaId : String = String()
    
    var videoData : NSData = NSData()
    
    var dataRowFromLocal : [String:AnyObject] = [String:AnyObject]()
    
    var progressDictionary : [[String:AnyObject]]  = [[String:AnyObject]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func initialise(){
        userId = defaults.valueForKey(userLoginIdKey) as! String
        accessToken = defaults.valueForKey(userAccessTockenKey) as! String
        getMediaFromDB()
    }
    
    //get image from local db
    func getMediaFromDB(){
        imageFromDB = FileManagerViewController.sharedInstance.getImageFromFilePath(path)!
        
        var sizeThumb : CGSize = CGSize()
        if(media == "image"){
            sizeThumb = CGSizeMake(70,70)
        }
        else{
            sizeThumb = CGSizeMake(140, 140)
        }
        imageAfterConversionThumbnail = cameraController.thumbnaleImage(imageFromDB, scaledToFillSize: sizeThumb)
        
        getSignedURLFromCloud()
    }
    
    //get signed url from cloud
    func getSignedURLFromCloud(){
        if(media == "video"){
            
        }
        else{
            videoDuration = ""
        }
        userId = defaults.valueForKey(userLoginIdKey) as! String
        accessToken = defaults.valueForKey(userAccessTockenKey) as! String
        self.imageUploadManager.getSignedURL(userId, accessToken: accessToken, mediaType: media, videoDuration: videoDuration, success: { (response) -> () in
            self.authenticationSuccessHandlerSignedURL(response)
            }, failure: { (error, message) -> () in
                self.authenticationFailureHandler(error, code: message)
        })
    }
    
    func setGlobalValuesForUploading(MediaIDGlob: String, thumbURL: String, fullURL: String, mediaType: String){
        self.mediaId = MediaIDGlob
        self.media = mediaType
        self.uploadFullImageOrVideoURLGCS = fullURL
        self.uploadThumbImageURLGCS = thumbURL
        let mediaIdForFilePath = "\(MediaIDGlob)full"
        let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath()
        let savingPathfull = "\(parentPath)/\(mediaIdForFilePath)"
        let fileExistFlagFull = FileManagerViewController.sharedInstance.fileExist(savingPathfull)
        if fileExistFlagFull == true{
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(savingPathfull)
            self.imageFromDB =  mediaImageFromFile!
        }
        let mediaIdForFilePaththumb = "\(MediaIDGlob)thumb"
        let savingPaththumb = "\(parentPath)/\(mediaIdForFilePaththumb)"
        let fileExistFlagthumb = FileManagerViewController.sharedInstance.fileExist(savingPaththumb)
        if fileExistFlagthumb == true{
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(savingPaththumb)
            self.imageAfterConversionThumbnail =  mediaImageFromFile!
        }
        startUploadingToGCS()
    }
    
    func setGlobalValuesForMapping(MediaIDGlob : String)  {
        self.mediaId = MediaIDGlob
        mapMediaToDefaultChannels()
    }
    
    func authenticationSuccessHandlerSignedURL(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            uploadFullImageOrVideoURLGCS = json["UploadObjectUrl"] as! String
            uploadThumbImageURLGCS = json["UploadThumbnailUrl"] as! String
            let mediaDetailId = json["MediaDetailId"]
            mediaId = "\(mediaDetailId!)"
            uploadImageNameForGCS = json["ObjectName"] as! String
            self.saveImageToLocalCache()
            startUploadingToGCS()
        }
    }
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(code)
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    //save image to local cache
    func saveImageToLocalCache(){
        
        let filePathToSaveThumb = "\(mediaId)thumb"
        FileManagerViewController.sharedInstance.saveImageToFilePath(filePathToSaveThumb, mediaImage: imageAfterConversionThumbnail)
        let filePathToSaveFull = "\(mediaId)full"
        FileManagerViewController.sharedInstance.saveImageToFilePath(filePathToSaveFull, mediaImage: imageFromDB)
        
        if (media == "video"){
            saveVideoToCahce()
        }
        updateDataToLocalDataSource()
    }
    
    func  saveVideoToCahce()  {
        if ((videoSavedURL.path?.isEmpty) != nil)
        {
            if var imageDatadup = NSData(contentsOfURL: videoSavedURL){
                videoData = imageDatadup
                
                let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                let savingPath = "\(parentPath)/\(mediaId)video.mov"
                let url = NSURL(fileURLWithPath: savingPath)
                videoData.writeToURL(url, atomically: true)
                
                imageDatadup = NSData()
                videoData = NSData()
                
                if(NSFileManager.defaultManager().fileExistsAtPath(videoSavedURL.path!)){
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(videoSavedURL.path!)
                    } catch _ as NSError {
                    }
                }
            }
        }
    }
    
    func updateDataToLocalDataSource() {
        dataRowFromLocal.removeAll()
        let currentTimeStamp : String = getCurrentTimeStamp()
        var duration = String()
        if(media == "video"){
            duration = FileManagerViewController.sharedInstance.getVideoDurationInProperFormat(videoDuration)
        }
        else{
            duration = ""
        }
        
        dataRowFromLocal = [mediaIdKey:mediaId,mediaTypeKey:media,notifTypeKey:"likes",mediaCreatedTimeKey:currentTimeStamp,progressKey:0.02,tImageKey:imageAfterConversionThumbnail,videoDurationKey:duration]
        
        mediaBeforeUploadCompleteManager.updateDataSource(dataRowFromLocal)
    }
    
    func getCurrentTimeStamp() -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.timeZone = NSTimeZone(name: "UTC")
        let localDateStr = dateFormatter.stringFromDate(NSDate())
        return localDateStr
    }
    
    //start Image upload after getting signed url
    func startUploadingToGCS()  {
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            self.uploadFullImageOrVideoToGCS({(result) -> Void in
                if(result == "Success"){
                    self.uploadThumbImageToGCS({(result) -> Void in
                        self.deleteDataFromDB()
                        self.imageFromDB = UIImage()
                        if(result == "Success"){
                            self.imageAfterConversionThumbnail = UIImage()
                            GlobalChannelToImageMapping.sharedInstance.removeUploadSuccessMediaDetails(self.mediaId)
                            self.mediaBeforeUploadCompleteManager.deleteRowFromDataSource(self.mediaId)
                            self.mapMediaToDefaultChannels()
                        }
                        else{
                            GlobalChannelToImageMapping.sharedInstance.setFailedUploadMediaDetails(self.mediaId, thumbURL: self.uploadThumbImageURLGCS, fullURL: self.uploadFullImageOrVideoURLGCS, mediaType: self.media)
                        }
                    })
                }
                else{
                    GlobalChannelToImageMapping.sharedInstance.setFailedUploadMediaDetails(self.mediaId, thumbURL: self.uploadThumbImageURLGCS, fullURL: self.uploadFullImageOrVideoURLGCS, mediaType: self.media)
                }
            })
        })
    }
    
    //full image upload to cloud
    func uploadFullImageOrVideoToGCS(completion: (result: String) -> Void)
    {
        let url = NSURL(string: uploadFullImageOrVideoURLGCS)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "PUT"
        let session = NSURLSession(configuration:NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        var imageOrVideoData: NSData = NSData()
        if(media == "image"){
            imageOrVideoData = UIImageJPEGRepresentation(imageFromDB, 0.5)!
            request.HTTPBody = imageOrVideoData
            let dataTask = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
                
                if error != nil {
                    self.updateProgressToDefault(2.0, mediaIds: self.mediaId)
                    completion(result:"Failed")
                }
                else {
                    completion(result:"Success")
                }
            }
            dataTask.resume()
            session.finishTasksAndInvalidate()
            imageOrVideoData = NSData()
        }
        else{
            let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
            let savingPath = "\(parentPath)/\(mediaId)video.mov"
            let url = NSURL(fileURLWithPath: savingPath)
            if NSData(contentsOfURL: url) != nil
            {
                imageOrVideoData = NSData(contentsOfURL: url)!
                request.HTTPBody = imageOrVideoData
                let dataTask = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
                    imageOrVideoData = NSData()
                    if error != nil {
                        self.updateProgressToDefault(2.0, mediaIds: self.mediaId)
                        completion(result:"Failed")
                    }
                    else {
                        completion(result:"Success")
                    }
                }
                dataTask.resume()
                session.finishTasksAndInvalidate()
                imageOrVideoData = NSData()
            }
        }
    }
    
    //thumb image upload to cloud
    func uploadThumbImageToGCS(completion: (result: String) -> Void)
    {
        let url = NSURL(string: uploadThumbImageURLGCS)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "PUT"
        let session = NSURLSession(configuration:NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
        var imageData: NSData = NSData()
        imageData = UIImageJPEGRepresentation(imageAfterConversionThumbnail, 0.5)!
        request.HTTPBody = imageData
        let dataTask = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
            if error != nil {
                self.updateProgressToDefault(2.0, mediaIds: self.mediaId)
                completion(result:"Failed")
            }
            else {
                completion(result:"Success")
            }
        }
        dataTask.resume()
        imageData = NSData()
        session.finishTasksAndInvalidate()
    }
    
    //after upload complete delete data from local file and db
    func deleteDataFromDB(){
        let fileManager : NSFileManager = NSFileManager()
        if(fileManager.fileExistsAtPath(path)){
            do {
                try fileManager.removeItemAtPath(path)
            } catch _ as NSError {
            }
        }
        
        let appDel : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context : NSManagedObjectContext = appDel.managedObjectContext
        let fetchRequest = NSFetchRequest(entityName: "SnapShots")
        fetchRequest.returnsObjectsAsFaults=false
        do
        {
            let results = try context.executeFetchRequest(fetchRequest)
            for managedObject in results
            {
                let managedObjectData:NSManagedObject = managedObject as! NSManagedObject
                context.deleteObject(managedObjectData)
            }
        }
        catch _ as NSError {
        }
    }
    
    //after uploading map media to channels
    func mapMediaToDefaultChannels(){
        if self.requestManager.validConnection() {
            userId = defaults.valueForKey(userLoginIdKey) as! String
            accessToken = defaults.valueForKey(userAccessTockenKey) as! String
            imageUploadManager.setDefaultMediaChannelMapping(userId, accessToken: accessToken, objectName: mediaId , success: { (response) -> () in
                self.authenticationSuccessHandlerAfterMapping(response)
                }, failure: { (error, message) -> () in
                    self.authenticationFailureHandlerMapping(error, code: message)
            })
        }
        else{
            self.updateProgressToDefault(4.0, mediaIds: mediaId)
        }
    }
    
    func authenticationSuccessHandlerAfterMapping(response:AnyObject?)
    {
        if let json = response as? [String: AnyObject]
        {
            let mediaId = json["mediaId"]
            let channelWithScrollingIds = json["channelMediaDetails"] as! [[String:AnyObject]]
            self.updateProgressToDefault(3.0, mediaIds: "\(mediaId!)")
            addScrollingIdsToChannels(channelWithScrollingIds, mediaId: "\(mediaId)")
        }
    }
    
    func authenticationFailureHandlerMapping(error: NSError?, code: String)
    {
        self.updateProgressToDefault(4.0, mediaIds: mediaId)
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(code)
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func addScrollingIdsToChannels(channelScrollsDict: [[String:AnyObject]], mediaId: String)
    {
        //all channelIds from global channel image mapping data source to a channelids array
        let channelIds : Array = Array(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.keys)
        
        for i in 0  ..< channelScrollsDict.count
        {
            let chanelIdChk : String = String(channelScrollsDict[i][channelIdKey]!)
            let chanelMediaId : String = String(channelScrollsDict[i][channelMediaIdKey]!)
            var indexOfJ = 0
            var chkFlag = false
            
            if channelIds.contains(chanelIdChk)
            {
                for j in 0 ..< GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]!.count
                {
                    indexOfJ = j
                    let mediaIdChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]![j][mediaIdKey] as! String
                    if mediaId == mediaIdChk
                    {
                        chkFlag = true
                        break
                    }
                }
                
                if chkFlag == true
                {
                    GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]![indexOfJ][channelMediaIdKey] = chanelMediaId
                }
            }
        }
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?)
    {
        let myAlert = UIAlertView(title: "Alert", message: error?.localizedDescription, delegate: nil, cancelButtonTitle: "Ok")
        myAlert.show()
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    {
        let uploadProgress:Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        updateProgressToDefault(uploadProgress,mediaIds: mediaId)
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void)
    {
    }
    
    func updateProgressToDefault(progress:Float, mediaIds: String)
    {
        var dict = [mediaIdKey: mediaIds, progressKey: progress]
        NSNotificationCenter.defaultCenter().postNotificationName("upload", object:dict)
        dict = NSDictionary()
        
    }
}
