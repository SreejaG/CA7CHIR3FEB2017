
import UIKit

class uploadMediaToGCS: UIViewController, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    let cameraController = IPhoneCameraViewController()
    let imageUploadManager = ImageUpload.sharedInstance
    let requestManager = RequestManager.sharedInstance
    let mediaBeforeUploadCompleteManager = MediaBeforeUploadComplete.sharedInstance
    
    let defaults = UserDefaults.standard
    
    var userId : String = String()
    var accessToken : String = String()
    
    var path : String = String()
    var media : String = String()
    var videoSavedURL : NSURL?
    var videoDuration : String = String()
    
    var imageFromDB : UIImage = UIImage()
    var imageAfterConversionThumbnail : UIImage = UIImage()
    
    var uploadThumbImageURLGCS : String = String()
    var uploadFullImageOrVideoURLGCS : String = String()
    var uploadImageNameForGCS : String = String()
    var mediaId : String = String()
    
    var videoData : NSData = NSData()
    
    var dataRowFromLocal : [String:Any] = [String:Any]()
    
    var progressDictionary : [[String:Any]]  = [[String:Any]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func initialise(){
        if defaults.value(forKey: userLoginIdKey) != nil
        {
            userId = defaults.value(forKey: userLoginIdKey) as! String
            if defaults.value(forKey: userAccessTockenKey) != nil
            {
                accessToken = defaults.value(forKey: userAccessTockenKey) as! String
                getMediaFromDB()
            }
        }
    }
    
    //get image from local db
    func getMediaFromDB(){
        imageFromDB = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: path)!
        
        var sizeThumb : CGSize = CGSize()
        if(media == "image"){
            sizeThumb = CGSize(width:70, height:70)
        }
        else{
            sizeThumb = CGSize(width:140, height:140)
        }
        imageAfterConversionThumbnail = cameraController.thumbnaleImage(imageFromDB, scaledToFill: sizeThumb)
        
        getSignedURLFromCloud()
    }
    
    //get signed url from cloud
    func getSignedURLFromCloud(){
        if(media == "video"){
            
        }
        else{
            videoDuration = ""
        }
        self.imageUploadManager.getSignedURL(userName: userId, accessToken: accessToken, mediaType: media, videoDuration: videoDuration, success: { (response) -> () in
            self.authenticationSuccessHandlerSignedURL(response: response)
        }, failure: { (error, message) -> () in
            self.authenticationFailureHandler(error: error, code: message)
        })
    }
    
    func setGlobalValuesForUploading(MediaIDGlob: String, thumbURL: String, fullURL: String, mediaType: String){
        self.mediaId = MediaIDGlob
        self.media = mediaType
        self.uploadFullImageOrVideoURLGCS = fullURL
        self.uploadThumbImageURLGCS = thumbURL
        let mediaIdForFilePath =  MediaIDGlob + "full"
        let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath()
        let savingPathfull =  parentPath.absoluteString! + "/" + mediaIdForFilePath
        let fileExistFlagFull = FileManagerViewController.sharedInstance.fileExist(mediaPath: savingPathfull)
        if fileExistFlagFull == true{
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: savingPathfull)
            self.imageFromDB =  mediaImageFromFile!
        }
        let mediaIdForFilePaththumb =  MediaIDGlob + "thumb"
        let savingPaththumb =  parentPath.absoluteString! + "/" + mediaIdForFilePaththumb
        let fileExistFlagthumb = FileManagerViewController.sharedInstance.fileExist(mediaPath: savingPaththumb)
        if fileExistFlagthumb == true{
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: savingPaththumb)
            self.imageAfterConversionThumbnail =  mediaImageFromFile!
        }
        startUploadingToGCS()
    }
    
    func setGlobalValuesForMapping(MediaIDGlob : String)  {
        self.mediaId = MediaIDGlob
        mapMediaToDefaultChannels()
    }
    
    func authenticationSuccessHandlerSignedURL(response:Any?)
    {
        if let json = response as? [String: Any]
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
                if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
                {
                    if tokenValid as! String == "true"
                    {
                        let notificationName = Notification.Name("refreshLogin")
                        NotificationCenter.default.post(name: notificationName, object: self)
                    }
                }
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    //save image to local cache
    func saveImageToLocalCache(){
        let filePathToSaveThumb = mediaId + "thumb"
        _ = FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: filePathToSaveThumb, mediaImage: imageAfterConversionThumbnail)
        let filePathToSaveFull = mediaId + "full"
        _ = FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: filePathToSaveFull, mediaImage: imageFromDB)
        
        if (media == "video"){
            saveVideoToCahce()
        }
        updateDataToLocalDataSource()
    }
    
    func  saveVideoToCahce()  {
        if ((videoSavedURL?.path?.isEmpty) != nil)
        {
            do {
                var imageDatadup = try NSData(contentsOfFile: (videoSavedURL?.absoluteString!)!, options: NSData.ReadingOptions())
                videoData = imageDatadup
                
                let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                let savingPath = parentPath! + "/" + mediaId + "video.mov"
                let url = NSURL(fileURLWithPath: savingPath)
                videoData.write(to: url as URL, atomically: true)
                
                // delete video from local buffer
                let fileManager : FileManager = FileManager()
                if(fileManager.fileExists(atPath: (videoSavedURL?.absoluteString!)!)){
                    do {
                        try fileManager.removeItem(atPath: (videoSavedURL?.absoluteString!)!)
                    } catch _ as NSError {
                    }
                }
                
                imageDatadup = NSData()
                videoData = NSData()
                
                if(FileManager.default.fileExists(atPath: (videoSavedURL?.path!)!)){
                    do {
                        try FileManager.default.removeItem(atPath: (videoSavedURL?.path!)!)
                    } catch _ as NSError {
                    }
                }
                
            } catch {
                
            }
        }
    }
    
    func updateDataToLocalDataSource() {
        dataRowFromLocal.removeAll()
        let currentTimeStamp : String = getCurrentTimeStamp()
        var duration = String()
        if(media == "video"){
            duration = FileManagerViewController.sharedInstance.getVideoDurationInProperFormat(duration: videoDuration)
        }
        else{
            duration = ""
        }
        
        dataRowFromLocal = [mediaIdKey:mediaId,mediaTypeKey:media,notifTypeKey:"likes",mediaCreatedTimeKey:currentTimeStamp,progressKey:Float(0.02),tImageKey:imageAfterConversionThumbnail,videoDurationKey:duration]
        
        mediaBeforeUploadCompleteManager.updateDataSource(dataSourceRow: dataRowFromLocal)
    }
    
    func getCurrentTimeStamp() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
        let localDateStr = dateFormatter.string(from: NSDate() as Date)
        return localDateStr
    }
    
    //start Image upload after getting signed url
    func startUploadingToGCS()  {
        let backgroundQueue = DispatchQueue(label: "com.app.queue",
                                            qos: .background,
                                            target: nil)
        backgroundQueue.async {
            self.uploadFullImageOrVideoToGCS(completion: {(result) -> Void in
                if(result == "Success"){
                    self.uploadThumbImageToGCS(completion: {(result) -> Void in
                        self.deleteDataFromDB()
                        self.imageFromDB = UIImage()
                        if(result == "Success"){
                            self.imageAfterConversionThumbnail = UIImage()
                            GlobalChannelToImageMapping.sharedInstance.removeUploadSuccessMediaDetails(mediaId: self.mediaId)
                            self.mapMediaToDefaultChannels()
                        }
                        else{
                            GlobalChannelToImageMapping.sharedInstance.setFailedUploadMediaDetails(mediaId: self.mediaId, thumbURL: self.uploadThumbImageURLGCS, fullURL: self.uploadFullImageOrVideoURLGCS, mediaType: self.media)
                        }
                    })
                }
                else{
                    GlobalChannelToImageMapping.sharedInstance.setFailedUploadMediaDetails(mediaId: self.mediaId, thumbURL: self.uploadThumbImageURLGCS, fullURL: self.uploadFullImageOrVideoURLGCS, mediaType: self.media)
                }
            })
        }
    }
    
    //full image upload to cloud
    func uploadFullImageOrVideoToGCS(completion: @escaping (_ result: String) -> Void)
    {
        let url = NSURL(string: uploadFullImageOrVideoURLGCS)
        let request = NSMutableURLRequest(url: url! as URL)
        request.httpMethod = "PUT"
        let session = URLSession(configuration:URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        var imageOrVideoData: NSData = NSData()
        if(media == "image"){
            imageOrVideoData = UIImageJPEGRepresentation(imageFromDB, 0.5)! as NSData
            request.httpBody = imageOrVideoData as Data
            let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                if error != nil {
                    self.updateProgressToDefault(progress: Float(2.0), mediaIds: self.mediaId)
                    self.autoUpdateProgressAfterSuccess(progr: Float(2.0))
                    completion("Failed")
                }
                else {
                    completion("Success")
                }
            }
            dataTask.resume()
            session.finishTasksAndInvalidate()
            imageOrVideoData = NSData()
        }
        else{
            let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
            let savingPath =  parentPath! + "/" + mediaId + "video.mov"
            let url = NSURL(fileURLWithPath: savingPath)
            if NSData(contentsOf: url as URL) != nil
            {
                imageOrVideoData = NSData(contentsOf: url as URL)!
                request.httpBody = imageOrVideoData as Data
                let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                    imageOrVideoData = NSData()
                    if error != nil {
                        self.updateProgressToDefault(progress: Float(2.0), mediaIds: self.mediaId)
                        self.autoUpdateProgressAfterSuccess(progr: Float(2.0))
                        completion("Failed")
                    }
                    else {
                        completion("Success")
                    }
                }
                dataTask.resume()
                session.finishTasksAndInvalidate()
                imageOrVideoData = NSData()
            }
        }
    }
    
    //thumb image upload to cloud
    func uploadThumbImageToGCS(completion: @escaping (_ result: String) -> Void)
    {
        let url = NSURL(string: uploadThumbImageURLGCS)
        let request = NSMutableURLRequest(url: url! as URL)
        request.httpMethod = "PUT"
        let session = URLSession(configuration:URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        var imageData: NSData = NSData()
        imageData = UIImageJPEGRepresentation(imageAfterConversionThumbnail, 0.5)! as NSData
        request.httpBody = imageData as Data
        let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            if error != nil {
                self.updateProgressToDefault(progress: Float(2.0), mediaIds: self.mediaId)
                self.autoUpdateProgressAfterSuccess(progr: Float(2.0))
                completion("Failed")
            }
            else {
                completion("Success")
            }
        }
        dataTask.resume()
        imageData = NSData()
        session.finishTasksAndInvalidate()
    }
    
    //after upload complete delete data from local file and db
    func deleteDataFromDB(){
        let fileManager : FileManager = FileManager()
        if(fileManager.fileExists(atPath: path)){
            do {
                try fileManager.removeItem(atPath: path)
            } catch _ as NSError {
            }
        }
        let appDel : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context : NSManagedObjectContext = appDel.managedObjectContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SnapShots")
        fetchRequest.returnsObjectsAsFaults=false
        do
        {
            let results = try context.fetch(fetchRequest)
            for managedObject in results
            {
                let managedObjectData:NSManagedObject = managedObject as! NSManagedObject
                context.delete(managedObjectData)
            }
        }
        catch _ as NSError {
        }
    }
    
    //after uploading map media to channels
    func mapMediaToDefaultChannels(){
        if self.requestManager.validConnection() {
            if defaults.value(forKey: userLoginIdKey) != nil
            {
                userId = defaults.value(forKey: userLoginIdKey) as! String
                if defaults.value(forKey: userAccessTockenKey) != nil
                {
                    accessToken = defaults.value(forKey: userAccessTockenKey) as! String
                    imageUploadManager.setDefaultMediaChannelMapping(userName: userId, accessToken: accessToken, objectName: mediaId , success: { (response) -> () in
                        self.authenticationSuccessHandlerAfterMapping(response: response)
                    }, failure: { (error, message) -> () in
                        self.authenticationFailureHandlerMapping(error: error, code: message)
                    })
                }
            }
        }
        else{
            self.updateProgressToDefault(progress: Float(4.0), mediaIds: mediaId)
            self.autoUpdateProgressAfterSuccess(progr: Float(4.0))
        }
    }
    
    func authenticationSuccessHandlerAfterMapping(response:Any?)
    {
        self.updateProgressToDefault(progress: Float(3.0), mediaIds: "\(mediaId)")
        autoUpdateProgressAfterSuccess(progr: Float(3.0))
        if let json = response as? [String: Any]
        {
            let mediaId = json["mediaId"]
            let channelWithScrollingIds = json["channelMediaDetails"] as! [[String:Any]]
            addScrollingIdsToChannels(channelScrollsDict: channelWithScrollingIds, mediaId: "\(mediaId)")
        }
    }
    
    func autoUpdateProgressAfterSuccess(progr: Float){
        var indexOfJ = 0
        var chkFlag = false
        let archiveChanelId = String(UserDefaults.standard.value(forKey: archiveId) as! Int)
        for j in 0 ..< GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count
        {
            if j < GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count
            {
                indexOfJ = j
                let mediaIdChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![j][mediaIdKey] as! String
                if mediaId == mediaIdChk
                {
                    chkFlag = true
                    break
                }
            }
        }
        if(chkFlag == true){
            GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexOfJ][progressKey] = progr
        }
    }
    
    func authenticationFailureHandlerMapping(error: NSError?, code: String)
    {
        self.updateProgressToDefault(progress: Float(4.0), mediaIds: mediaId)
        self.autoUpdateProgressAfterSuccess(progr: Float(4.0))
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
                {
                    if tokenValid as! String == "true"
                    {
                        let notificationName = Notification.Name("refreshLogin")
                        NotificationCenter.default.post(name: notificationName, object: self)
                    }
                }
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func addScrollingIdsToChannels(channelScrollsDict: [[String:Any]], mediaId: String)
    {
        //all channelIds from global channel image mapping data source to a channelids array
        let channelIds : Array = Array(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.keys)
        
        for i in 0  ..< channelScrollsDict.count
        {
            let chanelIdChk : String = String(describing: channelScrollsDict[i][channelIdKey]!)
            let chanelMediaId : String = String(describing: channelScrollsDict[i][channelMediaIdKey]!)
            var indexOfJ = 0
            var chkFlag = false
            
            if channelIds.contains(chanelIdChk)
            {
                for j in 0 ..< GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]!.count
                {
                    if j < GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]!.count
                    {
                        indexOfJ = j
                        let mediaIdChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]![j][mediaIdKey] as! String
                        if mediaId == mediaIdChk
                        {
                            chkFlag = true
                            break
                        }
                    }
                }
                
                if chkFlag == true
                {
                    GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[chanelIdChk]![indexOfJ][channelMediaIdKey] = chanelMediaId as Any?
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let myAlert = UIAlertView(title: "Alert", message: error?.localizedDescription, delegate: nil, cancelButtonTitle: "Ok")
        myAlert.show()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let uploadProgress:Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        updateProgressToDefault(progress: uploadProgress,mediaIds: mediaId)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    }
    
    func updateProgressToDefault(progress:Float, mediaIds: String)
    {
        var dict = [mediaIdKey: mediaIds, progressKey: progress] as [String : Any]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "upload"), object:dict)
        dict = NSDictionary() as! [String : Any]
    }
}
