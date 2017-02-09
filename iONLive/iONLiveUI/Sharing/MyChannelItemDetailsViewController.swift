
import UIKit

class MyChannelItemDetailsViewController: UIViewController {
    
    let imageUploadManger = ImageUpload.sharedInstance
    let requestManager = RequestManager.sharedInstance
    
    var operationQueueObjInSharingImageList = OperationQueue()
    var operationInSharingImageList = BlockOperation()
    
    @IBOutlet weak var channelItemsCollectionView: UICollectionView!
    @IBOutlet weak var channelTitleLabel: UILabel!
    
    let cameraController = IPhoneCameraViewController()
    
    var customView = CustomInfiniteIndicator()
    
    var loadingOverlay: UIView?
    
    var lastContentOffset: CGPoint = CGPoint()
    
    var refreshControl:UIRefreshControl!
    
    var totalMediaCount: Int = Int()
    var tapCount : Int = 0
    var totalCount : Int = 0
    
    var channelId:String!
    var channelName:String!
    
    var downloadingFlag : Bool = false
    
    var scrollObjSharing = UIScrollView()
    var NoDatalabelFormySharingImageList : UILabel = UILabel()
    
    var vc = MovieViewController()
    
    var operationQueueObjRedirectionSh = OperationQueue()
    var operationInRedirectionSh = BlockOperation()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.channelItemsCollectionView.alwaysBounceVertical = true
        
        let myDayCleanUp = Notification.Name("myDayCleanUp")
        NotificationCenter.default.addObserver(self, selector:#selector(MyChannelItemDetailsViewController.myDayCleanUp(notif:)), name: myDayCleanUp, object: nil)
        
        initialise()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        let tokenExpired = Notification.Name("tokenExpired")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelItemListViewController.loadInitialViewControllerTokenExpire(notif:)), name: tokenExpired, object: nil)
        
        let removeActivityIndicatorMyChannel = Notification.Name("removeActivityIndicatorMyChannel")
        NotificationCenter.default.addObserver(self, selector:#selector(MyChannelItemDetailsViewController.removeActivityIndicator(notif:)), name: removeActivityIndicatorMyChannel, object: nil)
        
        UserDefaults.standard.set(0, forKey: "tabToAppear")
        self.tabBarItem.selectedImage = UIImage(named:"all_media_blue")?.withRenderingMode(.alwaysOriginal)
        if let channelName = channelName
        {
            channelTitleLabel.text = channelName.uppercased()
        }
        downloadingFlag = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        self.channelItemsCollectionView.alpha = 1.0
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeActivityIndicatorMyChannel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("tokenExpired"), object: nil)
    }
    
    func  loadInitialViewControllerTokenExpire(notif:NSNotification){
        if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
        {
            if tokenValid as! String == "true"
            {
                operationInSharingImageList.cancel()
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
                    
                    let code = notif.object as! String
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
        let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
        let sharingVC = sharingStoryboard.instantiateViewController(withIdentifier: MySharedChannelsViewController.identifier) as! MySharedChannelsViewController
        sharingVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(sharingVC, animated: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func inviteContacts(_ sender: Any) {
        let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
        let inviteContactsVC = sharingStoryboard.instantiateViewController(withIdentifier: ContactListViewController.identifier) as! ContactListViewController
        inviteContactsVC.channelId = channelId
        inviteContactsVC.channelName = channelName
        inviteContactsVC.totalMediaCount = totalMediaCount
        inviteContactsVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(inviteContactsVC, animated: false)
    }
    
    func initialise()
    {
        channelId = (self.tabBarController as! MyChannelDetailViewController).channelId
        channelName = (self.tabBarController as! MyChannelDetailViewController).channelName
        totalMediaCount = (self.tabBarController as! MyChannelDetailViewController).totalMediaCount
        
        showOverlay()
        createScrollViewAnimations()
        if totalMediaCount == 0
        {
            removeOverlay()
            addNoDataLabel()
        }
        else
        {
            if (GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0)
            {
                let channelKeys = Array(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.keys)
                if(channelKeys.contains(channelId)){
                    let filteredData = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.filter(thumbExists)
                    totalCount = filteredData.count
                }
                if totalCount > 0
                {
                    removeOverlay()
                    DispatchQueue.main.async {
                        self.channelItemsCollectionView.reloadData()
                    }
                    if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > totalCount){
                        if(totalCount < 18){
                            DispatchQueue.main.async {
                                self.customView.stopAnimationg()
                                self.customView.removeFromSuperview()
                                self.customView = CustomInfiniteIndicator(frame: CGRect(x:(self.channelItemsCollectionView.layer.frame.width/2 - 20), y:(self.channelItemsCollectionView.layer.frame.height - 100), width:40, height:40))
                                self.channelItemsCollectionView.addSubview(self.customView)
                                self.customView.startAnimating()
                            }
                        }
                    }
                }
                else if totalCount <= 0
                {
                    totalCount = 0
                    self.channelItemsCollectionView.reloadData()
                }
                self.downloadImagesFromGlobalChannelImageMapping(limit: 21)
            }
        }
    }
    
    func thumbExists (item: [String : Any]) -> Bool {
        return item[tImageKey] != nil
    }
    
    func downloadImagesFromGlobalChannelImageMapping(limit : Int)  {
        operationInSharingImageList.cancel()
        let start = totalCount
        var end = 0
        if((totalCount + limit) <= GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count){
            end = limit
        }
        else{
            end = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count - totalCount
        }
        end = start + end
        if end <= GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count
        {
            operationInSharingImageList  = BlockOperation (block: {
                GlobalChannelToImageMapping.sharedInstance.downloadMediaFromGCS(chanelId: self.channelId, start: start, end: end, operationObj: self.operationInSharingImageList)
            })
            self.operationQueueObjInSharingImageList.addOperation(operationInSharingImageList)
        }
    }
    
    func createScrollViewAnimations()  {
        channelItemsCollectionView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x:0, y:0, width:40, height:40))
        channelItemsCollectionView.infiniteScrollIndicatorMargin = 50
        channelItemsCollectionView.addInfiniteScroll { [weak self] (scrollView) -> Void in
            if self!.totalCount > 0
            {
                if(self!.totalCount < GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self!.channelId]!.count)
                {
                    if self!.downloadingFlag == false
                    {
                        self!.scrollObjSharing = scrollView
                        self!.downloadingFlag = true
                        self!.downloadImagesFromGlobalChannelImageMapping(limit: 12)
                    }
                }
                else{
                    scrollView.finishInfiniteScroll()
                }
            }
            else{
                scrollView.finishInfiniteScroll()
            }
        }
    }
    
    func addNoDataLabel()
    {
        self.NoDatalabelFormySharingImageList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100),y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoDatalabelFormySharingImageList.textAlignment = NSTextAlignment.center
        self.NoDatalabelFormySharingImageList.text = "No Media Available"
        self.view.addSubview(self.NoDatalabelFormySharingImageList)
    }
    
    func removeActivityIndicator(notif : NSNotification){
        operationInSharingImageList.cancel()
        let filteredData = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.filter(thumbExists)
        totalCount = filteredData.count
        
        DispatchQueue.main.async {
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
            self.removeOverlay()
            self.scrollObjSharing.finishInfiniteScroll()
            self.scrollObjSharing = UIScrollView()
            self.channelItemsCollectionView.reloadData()
        }
        
        if(totalCount == 0){
            DispatchQueue.main.async {
                self.addNoDataLabel()
            }
        }
        
        if downloadingFlag == true
        {
            downloadingFlag = false
        }
    }
    
    func myDayCleanUp(notif : NSNotification){
        if(channelName == "My day"){
            operationInSharingImageList.cancel()
            let setOj = SetUpView()
            setOj.cleanMyDayCall(obj: vc, chanelId: channelId)
            let refreshAlert = UIAlertController(title: "Cleaning", message: "My Day Cleaning In Progress.", preferredStyle: UIAlertControllerStyle.alert)
            
            refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            }))
            self.present(refreshAlert, animated: true, completion: nil)
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

extension MyChannelItemDetailsViewController : UICollectionViewDataSource,UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MyChannelItemCell.identifier, for: indexPath) as! MyChannelItemCell
        cell.layer.shouldRasterize = true
        cell.layer.rasterizationScale = UIScreen.main.scale
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > 0
        {
            let mediaType = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][mediaTypeKey] as! String
            let channelImageView = cell.viewWithTag(100) as! UIImageView
            if let imageData =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][tImageKey] {
                channelImageView.image = imageData as? UIImage
            }
            else{
                channelImageView.image = UIImage(named: "thumb12")
            }
            
            if mediaType == "video"
            {
                cell.videoPlayIcon.isHidden = false
                cell.videoDurationLabel.isHidden = false
                if let vDuration =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][videoDurationKey]
                {
                    cell.videoDurationLabel.text = vDuration as? String
                }
                
            }
            else{
                cell.videoPlayIcon.isHidden = true
                cell.videoDurationLabel.isHidden = true
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(1, 1, 0, 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        return CGSize(width:((UIScreen.main.bounds.width/3)-2), height:100)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > 0){
            if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][tImageKey] != nil
            {
                self.showOverlay()
                self.channelItemsCollectionView.alpha = 0.4
                operationInRedirectionSh.cancel()
                operationInRedirectionSh  = BlockOperation (block: {
                    self.redirectToFullImagView(indexPath: indexPath)
                })
                self.operationQueueObjRedirectionSh.addOperation(operationInRedirectionSh)
            }
        }
    }
    
    func redirectToFullImagView(indexPath:IndexPath){
        if operationInRedirectionSh.isCancelled{
            return
        }
        let defaults = UserDefaults .standard
        let userId = defaults.value(forKey: userLoginIdKey) as! String
        let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        
        var imageForProfile : UIImage = UIImage()
        let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
        let profilePath = "\(userId)Profile"
        let savingPath =  parentPath! + "/" + profilePath
        let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: savingPath)
        if fileExistFlag == true{
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: savingPath)
            imageForProfile = mediaImageFromFile!
        }
        else{
            let profileUrl = UrlManager.sharedInstance.getUserProfileImageBaseURL() + userId + "/" + accessToken + "/" + userId
            let mediaImageFromFile = FileManagerViewController.sharedInstance.getProfileImage(profileNameURL: profileUrl )
            imageForProfile = mediaImageFromFile
            let profileImageData = UIImageJPEGRepresentation(imageForProfile, 0.5)
            let profileImageDataAsNsdata = (profileImageData as NSData?)!
            let imageFromDefault = UIImageJPEGRepresentation(UIImage(named: "dummyUser")!, 0.5)
            let imageFromDefaultAsNsdata = (imageFromDefault as NSData?)!
            if(profileImageDataAsNsdata.isEqual(imageFromDefaultAsNsdata)){
            }
            else{
                _ = FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: profilePath, mediaImage: imageForProfile)
            }
        }
        let dateString = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][mediaCreatedTimeKey] as! String
        let imageTakenTime = FileManagerViewController.sharedInstance.getTimeDifference(dateStr: dateString)
        
        let index = Int32(indexPath.row)
        
        DispatchQueue.main.async {
            self.vc = MovieViewController.movieViewController(withImageVideo: self.channelName, channelId: self.channelId as String, userName: userId, mediaType: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][mediaTypeKey] as! String, profileImage: imageForProfile, videoImageUrl: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][tImageKey] as! UIImage, notifType: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][notifTypeKey] as! String,mediaId: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][mediaIdKey] as! String, timeDiff: imageTakenTime,likeCountStr: "0",selectedItem: index,pageIndicator: 0 , videoDuration:  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][videoDurationKey] as? String) as! MovieViewController
            self.present(self.vc, animated: false) { () -> Void in
                self.removeOverlay()
                self.channelItemsCollectionView.alpha = 1.0
            }
        }
    }
}

extension MyChannelItemDetailsViewController: UIScrollViewDelegate
{
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if(totalCount > 0){
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
        }
    }
}
