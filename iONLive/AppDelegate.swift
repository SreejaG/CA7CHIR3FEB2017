
import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    var photoViewController : PhotoViewerViewController?
    let requestManager = RequestManager.sharedInstance
    
    var mediaShared:[[String:Any]] = [[String:Any]]()
    let sharedMediaCount = "total_no_media_shared"
    var deleteQueue : NSMutableArray = NSMutableArray()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        if(UserDefaults.standard.bool(forKey: "StartedStreaming"))
        {
            UserDefaults.standard.set(false, forKey: "StartedStreaming")
        }
        UserDefaults.standard.setValue("Empty", forKey: "EmptyMedia")
        UserDefaults.standard.setValue("Empty", forKey: "EmptyShare")
        
        let settings : UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .sound, .badge ], categories: nil)
        UIApplication.shared.registerUserNotificationSettings(settings)
        UIApplication.shared.registerForRemoteNotifications()
        
        UserDefaults.standard.set(0, forKey: "badgeCount")
        UIApplication.shared.applicationIconBadgeNumber = UserDefaults.standard.integer(forKey: "badgeCount")
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0] + "/GCSCA7CH"
        if(FileManager.default.fileExists(atPath: documentsPath))
        {
        }
        else{
            _ = FileManagerViewController.sharedInstance.createParentDirectory()
        }
        let defaults = UserDefaults.standard
        defaults.set(nil, forKey: "uploaObjectDict")
        defaults.set(nil, forKey: "ProgressDict")
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window!.backgroundColor = UIColor.white
        if let remoteNotification = launchOptions?[UIApplicationLaunchOptionsKey.remoteNotification] as? NSDictionary {
            UserDefaults.standard.setValue(remoteNotification, forKey: "remote")
            GlobalDataChannelList.sharedInstance.initialise()
            ChannelSharedListAPI.sharedInstance.initialisedata()
            let result = remoteNotification["messageFrom"] as! NSDictionary
            if(result["type"] as! String == "liveStream")
            {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PushNotification"), object:result)
                if(result["subType"] as! String == "started"){
                    defaults.setValue("1", forKey: "notificationArrived")
                }
                else{
                    defaults.setValue("0", forKey: "notificationArrived")
                }
            }
            else if (result["type"] as! String == "share")
            {
                defaults.setValue("1", forKey: "notificationArrived")
            }
            else{
                defaults.setValue("0", forKey: "notificationArrived")
            }
            if UserDefaults.standard.value(forKey: "notificationArrived") as! String == "1"
            {
                loadNotificationView()
            }
            else{
                let defaults = UserDefaults.standard
                defaults.setValue("0", forKey: "notificationArrived")
                initialViewController()
            }
        }
        else{
            let defaults = UserDefaults.standard
            defaults.setValue("0", forKey: "notificationArrived")
            initialViewController()
        }
        self.window!.makeKeyAndVisible()
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        UserDefaults.standard.set(0, forKey: "badgeCount")
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "enterBackground"), object:nil)
        if UserDefaults.standard.value(forKey: "notificationArrived") != nil{
            if UserDefaults.standard.value(forKey: "notificationArrived") as! String == "1"
            {
                if(application.applicationState == .inactive || application.applicationState == .background)
                {
                    GlobalDataChannelList.sharedInstance.initialise()
                    ChannelSharedListAPI.sharedInstance.initialisedata()
                    loadNotificationView()
                }
            }
        }
        if(deleteQueue.count > 0)
        {
            for i in 0  ..< deleteQueue.count
            {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MediaDelete"), object:deleteQueue[i])
            }
        }
        deleteQueue.removeAllObjects()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        self.saveContext()
        UserDefaults.standard.setValue("0", forKey: "notificationArrived")
        
        UIApplication.shared.applicationIconBadgeNumber = UserDefaults.standard.integer(forKey: "badgeCount")
    }
    
    func initialViewController()
    {
        let defaults = UserDefaults.standard
        defaults.setValue("0", forKey: "notificationFlag")
        var controller : UIViewController = UIViewController()
        UserDefaults.standard.set(1, forKey: "shutterActionMode");
        if (UserDefaults.standard.object(forKey: "flashMode") == nil)
        {
            UserDefaults.standard.set(0, forKey: "flashMode")
        }
        if (UserDefaults.standard.object(forKey: "SaveToCameraRoll") == nil)
        {
            UserDefaults.standard.set(1, forKey: "SaveToCameraRoll")
        }
        //Auto login check
        if (UserDefaults.standard.object(forKey: "userAccessTockenKey") == nil)
        {
            let defaults = UserDefaults .standard
            defaults.setValue("login", forKey: "loadingView")
            let authenticationStoryboard = UIStoryboard(name:"Authentication" , bundle: nil)
            controller = authenticationStoryboard.instantiateViewController(withIdentifier: "AuthenticateNavigationController")
            self.window!.rootViewController = controller
        }
        else
        {
            loadCameraViewController()
        }
    }
    
    func clearStreamingUserDefaults(defaults:UserDefaults)
    {
        defaults.removeObject(forKey: streamingToken)
        defaults.removeObject(forKey: startedStreaming)
        defaults.removeObject(forKey: initializingStream)
    }
    
    func loadCameraViewController()
    {
        let defaults = UserDefaults.standard
        defaults.setValue("appDelegateRedirection", forKey: "viewFromWhichPage")
        var navigationController:UINavigationController?
        let cameraViewStoryboard = UIStoryboard(name:"IPhoneCameraView" , bundle: nil)
        let iPhoneCameraViewController = cameraViewStoryboard.instantiateViewController(withIdentifier: "IPhoneCameraViewController") as! IPhoneCameraViewController
        
        navigationController = UINavigationController(rootViewController: iPhoneCameraViewController)
        navigationController!.isNavigationBarHidden = true
        self.window!.rootViewController = navigationController
    }
    
    func loadLiveStreamView()
    {
        var navigationController:UINavigationController?
        let vc = MovieViewController.movieViewController(withContentPath: "rtsp://192.168.42.1:554/live", parameters: nil , liveVideo: true) as! UIViewController
        clearStreamingUserDefaults(defaults: UserDefaults.standard)
        navigationController = UINavigationController(rootViewController: vc)
        navigationController!.isNavigationBarHidden = true
        self.window!.rootViewController = navigationController
    }
    
    func  loadNotificationView()  {
        UserDefaults.standard.set(1, forKey: "SelectedTab")
        let defaults = UserDefaults .standard
        defaults.setValue("1", forKey: "notificationFlag")
        var navigationController:UINavigationController?
        let notificationStoryboard = UIStoryboard(name:"Streaming" , bundle: nil)
        let notificationViewController = notificationStoryboard.instantiateViewController(withIdentifier: StreamsGalleryViewController.identifier) as! StreamsGalleryViewController
        navigationController = UINavigationController(rootViewController: notificationViewController)
        navigationController!.isNavigationBarHidden = true
        self.window?.rootViewController = navigationController
    }
    
    // MARK: - Core Data stack
    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1] as NSURL
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "GalleryModel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            var dict = [String: Any]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            abort()
        }
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Core Data Saving support
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                _ = error as NSError
                abort()
            }
        }
    }
    
    //push notification
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        if(deviceTokenString != ""){
            let defaults = UserDefaults.standard
            defaults.setValue(deviceTokenString, forKey: "deviceToken")
        }
        else{
            ErrorManager.sharedInstance.installFailure()
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        if(application.applicationState == .inactive || application.applicationState == .background)
        {
            let olderBadgeCount =  UserDefaults.standard.integer(forKey: "badgeCount")
            let badgeTotalCount = olderBadgeCount + 1
            UserDefaults.standard.set(badgeTotalCount, forKey: "badgeCount")
            UIApplication.shared.applicationIconBadgeNumber = badgeTotalCount
        }
        
        let result = userInfo["messageFrom"] as? NSDictionary
        let defaults = UserDefaults.standard
        var checkFlag : Bool = false
        if( application.applicationState == .inactive )
        {
            checkFlag = true
        }
        if(result?["type"] as! NSString  == "delete" || result?["type"] as! NSString == "media" )
        {
            defaults.setValue("0", forKey: "notificationArrived")
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MediaDelete"), object:result)
            
            if ( result?["type"] as! NSString == "media")
            {
                
                if(application.applicationState == .inactive || application.applicationState == .background)
                {
                    deleteQueue.add(result!)
                }
            }
        }
        else if ( (result?["type"] as! NSString == "share") || (result?["type"] as! NSString == "channel") || (result?["type"] as! NSString == "liveStream") || (result?["type"] as! NSString == "My Day Cleaning")){
            
            if (result?["type"] as! NSString == "share"){
                
                UserDefaults.standard.set("share", forKey: "NotificationText")
                let chid : String = "\(result!["channelId"]!)"
                if(!checkFlag)
                {
                    updateCount(channelId: chid)
                }
            }
            if (result?["type"] as! NSString == "channel"){
                
                if (result?["subType"] as! NSString == "deleted")
                {
                    let chid : String = "\(result!["channelId"]!)"
                    defaults.setValue("0", forKey: "notificationArrived")
                    
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PushNotification"), object:result)
                    
                    removeEntryFromShare(channelId: chid)
                    removeEntryFromGlobal(channelId: chid)
                }
                if(result?["subType"] as! NSString == "useradded")
                {
                    defaults.setValue("0", forKey: "notificationArrived")
                    
                    UserDefaults.standard.set(result?["messageText"] as! String, forKey: "NotificationChannelText")
                    UserDefaults.standard.set(result?["messageText"] as! String, forKey: "NotificationText")
                }
            }
            else if (result?["type"] as! NSString == "My Day Cleaning")
            {
                let chid : String = "\(result!["channelId"]!)"
                
                for i in 0 ..< GlobalDataChannelList.sharedInstance.globalChannelDataSource.count
                {
                    if(i < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count){
                        let channame = GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelNameKey] as! String
                        if channame == "My Day"
                        {
                            let chanId = GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelIdKey] as! String
                            if(chid == chanId){
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "myDayCleanNotif"), object:result)
                                break
                            }
                        }
                    }
                }
                myDayCleanUpChannel(channelId: chid)
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PushNotificationStream"), object:result)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PushNotificationChannel"), object:result)
            }
        }
        
        if(result?["type"] as! NSString == "liveStream")
        {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PushNotification"), object:result)
            if(result?["subType"] as! NSString == "started"){
                defaults.setValue("1", forKey: "notificationArrived")
                
            }
            else{
                defaults.setValue("0", forKey: "notificationArrived")
            }
        }
        else if  (result?["type"] as! NSString == "share")
        {
            defaults.setValue("1", forKey: "notificationArrived")
        }
        else if (result?["type"] as! NSString == "like")
        {
            if(result?["subType"] as! NSString != "liveStream"){
                defaults.setValue("2", forKey: "notificationArrived")
            }
            else{
                defaults.setValue("0", forKey: "notificationArrived")
            }
        }
    }
    
    func myDayCleanUpChannel(channelId : String)
    {
        let index  = getUpdateIndexChannel(channelIdValue: channelId, isCountArray: true)
        if(index != -1)
        {
            if(mediaShared.count > 0)
            {
                let  latestCount : Int = 0
                mediaShared[index][sharedMediaCount]  = "\(latestCount)"
                UserDefaults.standard.set(mediaShared, forKey: "Shared")
            }
        }
        let indexOfChannelList =  getUpdateIndexChannel(channelIdValue: channelId, isCountArray: false)
        if(indexOfChannelList != -1)
        {
            var mediaImage : UIImage?
            mediaImage = UIImage()
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexOfChannelList][mediaImageKey] = mediaImage
        }
    }
    
    func updateCount( channelId : String)
    {
        let index  = getUpdateIndexChannel(channelIdValue: channelId, isCountArray: true)
        if(index != -1)
        {
            if(mediaShared.count > 0)
            {
                let sharedCount = mediaShared[index][sharedMediaCount] as! String
                let  latestCount : Int = Int(sharedCount)! + 1
                mediaShared[index][sharedMediaCount]  = "\(latestCount)"
                UserDefaults.standard.set(mediaShared, forKey: "Shared")
            }
        }
        
        let indexOfChannelList =  getUpdateIndexChannel(channelIdValue: channelId, isCountArray: false)
        if(indexOfChannelList != -1)
        {
            if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > 0)
            {
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexOfChannelList][sharedMediaCount]  = "1"
            }
            let timeStamp = "created_time_stamp"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
            let currentDate = dateFormatter.string(from: NSDate() as Date)
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexOfChannelList][timeStamp] = currentDate
            let filteredData = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.filter(thumbExists)
            let totalCount = filteredData.count
            let itemToMove = ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource[indexOfChannelList]
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.remove(at: indexOfChannelList)
            ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.insert(itemToMove, at: totalCount)
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PushNotificationIphone"), object:nil)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "CountIncrementedPushNotification"), object:channelId)
    }
    
    func thumbExists (item: [String : Any]) -> Bool {
        let liveStreamStatus = "liveChannel"
        return item[liveStreamStatus] as! String == "1"
    }
    
    
    func removeEntryFromShare(channelId : String)
    {
        let index  = getUpdateIndexChannel(channelIdValue: channelId, isCountArray: true)
        if(index != -1)
        {
            if(mediaShared.count > 0)
            {
                mediaShared.remove(at: index)
                UserDefaults.standard.set(mediaShared, forKey: "Shared")
            }
        }
    }
    
    func removeEntryFromGlobal(channelId : String)
    {
        let index  = getUpdateIndexChannel(channelIdValue: channelId, isCountArray: false)
        if(index != -1)
        {
            if(ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.count > 0)
            {
                ChannelSharedListAPI.sharedInstance.SharedChannelListDataSource.remove(at: index)
            }
        }
    }
    
    func getUpdateIndexChannel(channelIdValue : String , isCountArray : Bool) -> Int
    {
        let channelIdkey = "ch_detail_id"
        var selectedArray = [[String: Any]]()
        var indexOfRow : Int = -1
        if(isCountArray)
        {
            if (UserDefaults.standard.object(forKey: "Shared") != nil)
            {
                mediaShared.removeAll()
                mediaShared = UserDefaults.standard.value(forKey: "Shared") as! [[String : Any]]
                selectedArray = mediaShared as Array
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
    
    func convertStringToDictionary(text: String) -> [String:Any]? {
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
            } catch  _ as NSError {
            }
        }
        return nil
    }
    
    //Called if unable to register for APNS.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
}

