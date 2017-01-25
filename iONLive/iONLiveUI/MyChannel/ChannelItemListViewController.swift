
import UIKit

class ChannelItemListViewController: UIViewController, CAAnimationDelegate {
    
    @IBOutlet weak var channelTitleLabel: UILabel!
    
    @IBOutlet weak var channelItemCollectionView: UICollectionView!
    
    @IBOutlet var deleteButton: UIButton!
    @IBOutlet var addButton: UIButton!
    @IBOutlet var selectionButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var backButton: UIButton!
    
    @IBOutlet var bottomView: UIView!
    
    static let identifier = "ChannelItemListViewController"
    
    let imageUploadManger = ImageUpload.sharedInstance
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    let cameraController = IPhoneCameraViewController()
    
    var operationQueueObjInChannelImageList = OperationQueue()
    var operationInChannelImageList = BlockOperation()
    
    var lastContentOffset: CGPoint = CGPoint()
    
    var loadingOverlay: UIView?
    var customView = CustomInfiniteIndicator()
    
    var addToDict : [[String:Any]] = [[String:Any]]()
    
    var selected: NSMutableArray = NSMutableArray()
    var selectedArray:[Int] = [Int]()
    var deletedMediaArray : NSMutableArray = NSMutableArray()
    
    var selectionFlag : Bool = false
    var downloadingFlag : Bool = false
    
    var channelId:String!
    var channelName:String!
    
    var userId : String = String()
    var accessToken: String = String()
    
    var totalCount = 0
    
    var totalMediaCount: Int = Int()
    var scrollObj = UIScrollView()
    
    var NoDatalabelFormyChanelImageList : UILabel = UILabel()
    
    let defaults = UserDefaults.standard
    
    var vc = MovieViewController()
    
    var operationQueueObjRedirectionCh = OperationQueue()
    var operationInRedirectionCh = BlockOperation()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        bottomView.isHidden = true
        deleteButton.isHidden = true
        addButton.isHidden = true
        cancelButton.isHidden = true
        selectionFlag = false
        self.channelItemCollectionView.alwaysBounceVertical = true
        
        let removeActivityIndicatorMyChannel = Notification.Name("removeActivityIndicatorMyChannel")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelItemListViewController.removeActivityIndicatorMyChanel(notif:)), name: removeActivityIndicatorMyChannel, object: nil)
        
        let myDayCleanNotif = Notification.Name("myDayCleanNotif")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelItemListViewController.cleanMyDayNotif(notification:)), name: myDayCleanNotif, object: nil)
        
        let tokenExpired = Notification.Name("tokenExpired")
        NotificationCenter.default.addObserver(self, selector:#selector(ChannelItemListViewController.loadInitialViewControllerTokenExpire(notif:)), name: tokenExpired, object: nil)
        
        //        NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: #selector(ChannelItemListViewController.cleanMyDay), userInfo: nil, repeats: true)
        
        showOverlay()
        totalCount = 0
        createScrollViewAnimations()
        if totalMediaCount == 0
        {
            selectionButton.isHidden = true
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
                    selectionButton.isHidden = false
                    removeOverlay()
                    DispatchQueue.main.async {
                        self.channelItemCollectionView.reloadData()
                    }
                    if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > totalCount){
                        if(totalCount < 18){
                            DispatchQueue.main.async {
                                self.customView.stopAnimationg()
                                self.customView.removeFromSuperview()
                                self.customView = CustomInfiniteIndicator(frame: CGRect(x:(self.channelItemCollectionView.layer.frame.width/2 - 20), y:(self.channelItemCollectionView.layer.frame.height - 100), width:40, height:40))
                                self.channelItemCollectionView.addSubview(self.customView)
                                self.customView.startAnimating()
                            }
                        }
                    }
                }
                else if totalCount <= 0
                {
                    selectionButton.isHidden = true
                    totalCount = 0
                    self.channelItemCollectionView.reloadData()
                }
                downloadImagesFromGlobalChannelImageMapping(limit: 21)
            }
        }
    }
    
    //    func cleanMyDay(){
    //        var chanId: String = String()
    //        for i in 0 ..< GlobalDataChannelList.sharedInstance.globalChannelDataSource.count
    //        {
    //            if(i < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count){
    //                let channame = GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelNameKey] as! String
    //                if channame == "My Day"
    //                {
    //                    NSNotificationCenter.defaultCenter().postNotificationName("myDayCleanUp", object:nil)
    //                    operationInChannelImageList.cancel()
    //                    chanId = GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelIdKey] as! String
    //                    GlobalChannelToImageMapping.sharedInstance.cleanMyDayBasedOnTimeStamp(chanId)
    //                    let setOj = SetUpView()
    //                    setOj.cleanMyDayCall(vc, chanelId: chanId)
    //                    if(channelName == "My Day"){
    //                        let refreshAlert = UIAlertController(title: "Cleaning", message: "My Day Cleaning In Progress.", preferredStyle: UIAlertControllerStyle.Alert)
    //
    //                        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
    //                        }))
    //                        self.presentViewController(refreshAlert, animated: true, completion: nil)
    //                    }
    //                    break
    //                }
    //            }
    //        }
    //    }
    
    func cleanMyDayNotif(notification: NSNotification){
        let info = notification.object as! [String : AnyObject]
        if (info["type"] as! String == "My Day Cleaning")
        {
            let chanId = info["channelId"]!
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "myDayCleanUp"), object:nil)
            operationInChannelImageList.cancel()
            GlobalChannelToImageMapping.sharedInstance.cleanMyDayBasedOnTimeStamp(MyDayChanelId: chanId as! String)
            let setOj = SetUpView()
            setOj.cleanMyDayCall(obj: vc, chanelId: chanId as! String)
            if(channelName == "My Day"){
                let refreshAlert = UIAlertController(title: "Cleaning", message: "My Day Cleaning In Progress.", preferredStyle: UIAlertControllerStyle.alert)
                
                refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
                }))
                self.present(refreshAlert, animated: true, completion: nil)
            }
        }
        NotificationCenter.default.removeObserver(notification)
    }
    
    func addNoDataLabel()
    {
        self.NoDatalabelFormyChanelImageList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100),y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoDatalabelFormyChanelImageList.textAlignment = NSTextAlignment.center
        self.NoDatalabelFormyChanelImageList.text = "No Media Available"
        self.view.addSubview(self.NoDatalabelFormyChanelImageList)
    }
    
    func removeActivityIndicatorMyChanel(notif : NSNotification){
        operationInChannelImageList.cancel()
        let filteredData = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.filter(thumbExists)
        totalCount = filteredData.count
        
        DispatchQueue.main.async {
            if self.selectionFlag == false {
                self.selectionButton.isHidden = false
            }
            else{
                self.cancelButton.isHidden = false
            }
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
            self.removeOverlay()
            self.scrollObj.finishInfiniteScroll()
            self.scrollObj = UIScrollView()
            self.channelItemCollectionView.reloadData()
        }
        
        if(totalCount == 0){
            DispatchQueue.main.async {
                self.selectionButton.isHidden = true
                self.addNoDataLabel()
            }
        }
        
        if downloadingFlag == true
        {
            downloadingFlag = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        channelTitleLabel.minimumScaleFactor = 2
        channelTitleLabel.adjustsFontSizeToFitWidth = true
        downloadingFlag = false
        if let channelName = channelName
        {
            channelTitleLabel.text = channelName.uppercased()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        operationInChannelImageList.cancel()
        removeOverlay()
        self.channelItemCollectionView.alpha = 1.0
        customView.stopAnimationg()
        customView.removeFromSuperview()
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeActivityIndicatorMyChannel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("tokenExpired"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func thumbExists (item: [String : Any]) -> Bool {
        return item[tImageKey] != nil
    }
    
    func createScrollViewAnimations()  {
        customView.stopAnimationg()
        customView.removeFromSuperview()
        channelItemCollectionView.infiniteScrollIndicatorView = CustomInfiniteIndicator(frame: CGRect(x:0, y:0, width:40, height:40))
        channelItemCollectionView.infiniteScrollIndicatorMargin = 40
        channelItemCollectionView.addInfiniteScroll { [weak self] (scrollView) -> Void in
            if self!.totalCount > 0
            {
                if(self!.totalCount < GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self!.channelId]!.count)
                {
                    if self!.downloadingFlag == false
                    {
                        self!.scrollObj = scrollView
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
    
    func downloadImagesFromGlobalChannelImageMapping(limit:Int)  {
        operationInChannelImageList.cancel()
        let start = totalCount
        var end = 0
        
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId] != nil
        {
            if((totalCount + limit) <= GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count){
                end = limit
            }
            else{
                end = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count - totalCount
            }
            end = start + end
            if end <= GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count
            {
                operationInChannelImageList  = BlockOperation (block: {
                    GlobalChannelToImageMapping.sharedInstance.downloadMediaFromGCS(chanelId: self.channelId, start: start, end: end, operationObj: self.operationInChannelImageList)
                })
                self.operationQueueObjInChannelImageList.addOperation(operationInChannelImageList)
            }
            else{
                removeOverlay()
            }
        }
    }
    
    func  loadInitialViewControllerTokenExpire(notif:NSNotification){
        if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
        {
            if tokenValid as! String == "true"
            {
                operationInChannelImageList.cancel()
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
    
    func  loadInitialViewController(code: String){
        if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
        {
            if tokenValid as! String == "true"
            {
                operationInChannelImageList.cancel()
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
    
    @IBAction func didTapBackButton(_ sender: Any)
    {
        let notificationStoryboard = UIStoryboard(name:"MyChannel", bundle: nil)
        let channelVC = notificationStoryboard.instantiateViewController(withIdentifier: MyChannelViewController.identifier) as! MyChannelViewController
        channelVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(channelVC, animated: false)
    }
    
    @IBAction func didTapAddtoButton(_ sender: Any) {
        for i in 0 ..< selectedArray.count
        {
            if i < selectedArray.count
            {
                let mediaSelectedId = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![selectedArray[i]][mediaIdKey]
                selected.add(mediaSelectedId!)
                addToDict.append(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![selectedArray[i]])
            }
        }
        
        let channelStoryboard = UIStoryboard(name:"MyChannel", bundle: nil)
        let addChannelVC = channelStoryboard.instantiateViewController(withIdentifier: AddChannelViewController.identifier) as! AddChannelViewController
        
        addChannelVC.mediaDetailSelected = selected
        addChannelVC.selectedChannelId = channelId
        addChannelVC.localMediaDict = addToDict
        
        addChannelVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(addChannelVC, animated: false)
    }
    
    @IBAction func didTapSelectionButton(_ sender: Any) {
        selected.removeAllObjects()
        selectedArray.removeAll()
        selectionFlag = true
        self.channelItemCollectionView.allowsMultipleSelection = true
        channelTitleLabel.text = "SELECT"
        cancelButton.isHidden = false
        selectionButton.isHidden = true
        bottomView.isHidden = false
        deleteButton.isHidden = false
        addButton.isHidden = false
        backButton.isHidden = true
        deleteButton.isEnabled = false
        addButton.isEnabled = false
        deleteButton.setTitleColor(UIColor.lightGray, for: UIControlState.normal)
        addButton.setTitleColor(UIColor.lightGray, for: UIControlState.normal)
        DispatchQueue.main.async {
            self.channelItemCollectionView.reloadData()
        }
    }
    
    @IBAction func didTapCancelButton(_ sender: Any) {
        removeOverlay()
        selected.removeAllObjects()
        selectedArray.removeAll()
        channelTitleLabel.text = channelName.uppercased()
        cancelButton.isHidden = true
        selectionButton.isHidden = false
        bottomView.isHidden = true
        deleteButton.isHidden = true
        addButton.isHidden = true
        backButton.isHidden = false
        selectionFlag = false
        DispatchQueue.main.async {
            self.channelItemCollectionView.reloadData()
        }
        
    }
    
    @IBAction func didTapDeleteButton(_ sender: Any) {
        
        var mesg = String()
        if channelName == "Archive"
        {
            mesg = "Are you sure you want to permanently delete these pictures from all your channels?"
        }
        else{
            mesg =  "Are you sure you want to permanently delete these pictures from " + channelName + "?"
        }
        let alert = UIAlertController(title: "", message: mesg , preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: {(
            action:UIAlertAction!) in
            
            var channelIds : [Int] = [Int]()
            self.scrollObj.finishInfiniteScroll()
            self.operationInChannelImageList.cancel()
            for i in 0 ..< self.selectedArray.count
            {
                if(i < self.selectedArray.count){
                    let mediaSelectedId = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![self.selectedArray[i]][mediaIdKey]
                    self.selected.add(mediaSelectedId!)
                }
            }
            
            if(self.selected.count > 0){
                channelIds.append(Int(self.channelId)!)
                self.showOverlay()
                self.selectionButton.isHidden = true
                self.imageUploadManger.deleteMediasByChannel(userName: self.userId, accessToken: self.accessToken, mediaIds: self.selected, channelId: channelIds as NSArray, success: { (response) -> () in
                    self.authenticationSuccessHandlerDelete(response: response)
                }, failure: { (error, message) -> () in
                    self.authenticationFailureHandlerDelete(error: error, code: message)
                })
            }
            
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: {
            (action:UIAlertAction!) in
        }))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func authenticationSuccessHandlerDelete(response:AnyObject?)
    {
        removeOverlay()
        if (response as? [String: AnyObject]) != nil
        {
            GlobalChannelToImageMapping.sharedInstance.deleteMediasFromChannel(channelId: channelId, mediaIdChkS: selected)
            totalMediaCount = totalMediaCount - selected.count
            
            let filteredData = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.filter(thumbExists)
            totalCount = filteredData.count
            
            downloadingFlag = false
            selectionFlag = false
            
            if(totalCount == GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count){
                
            }
            else{
                if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > totalCount){
                    if(totalCount < 18 && totalCount > 0){
                        DispatchQueue.main.async {
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                            self.customView = CustomInfiniteIndicator(frame: CGRect(x:(self.channelItemCollectionView.layer.frame.width/2 - 20), y:(self.channelItemCollectionView.layer.frame.height - 100), width:40, height:40))
                            self.channelItemCollectionView.addSubview(self.customView)
                            self.customView.startAnimating()
                        }
                    }
                    else if totalCount == 0
                    {
                        DispatchQueue.main.async {
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                            self.showOverlay()
                            self.selectionButton.isHidden = true
                        }
                    }
                    else{
                        DispatchQueue.main.async {
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                            self.removeOverlay()
                            self.selectionButton.isHidden = false
                        }
                    }
                }
                else{
                    customView.stopAnimationg()
                    customView.removeFromSuperview()
                }
                if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > totalCount){
                    if(totalCount < 18){
                        downloadImagesFromGlobalChannelImageMapping(limit: 18)
                    }
                    else{
                        downloadImagesFromGlobalChannelImageMapping(limit: selected.count)
                    }
                }
            }
            
            selectedArray.removeAll()
            selected.removeAllObjects()
            channelTitleLabel.text = channelName.uppercased()
            cancelButton.isHidden = true
            bottomView.isHidden = true
            deleteButton.isHidden = true
            addButton.isHidden = true
            backButton.isHidden = false
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > 0){
                selectionButton.isHidden = false
            }
            else{
                selectionButton.isHidden = true
            }
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count == 0){
                addNoDataLabel()
            }
            
            DispatchQueue.main.async {
                self.channelItemCollectionView.reloadData()
            }
        }
    }
    
    func authenticationFailureHandlerDelete(error: NSError?, code: String)
    {
        self.removeOverlay()
        selectionButton.isHidden = false
        cancelButton.isHidden = true
        backButton.isHidden = false
        bottomView.isHidden = true
        downloadingFlag = false
        selectionFlag = false
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if code.isEmpty == false {
            
            if((code == "USER004") || (code == "USER005") || (code == "USER006")){
                loadInitialViewController(code: code)
            }
            else{
                ErrorManager.sharedInstance.mapErorMessageToErrorCode(errorCode: code)
            }
        }
        else{
            ErrorManager.sharedInstance.inValidResponseError()
        }
        selectedArray.removeAll()
        if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > 0){
            selectionButton.isHidden = false
        }
        else{
            selectionButton.isHidden = true
        }
        
        DispatchQueue.main.async {
            self.channelItemCollectionView.reloadData()
        }
    }
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
    }
}

extension ChannelItemListViewController : UICollectionViewDataSource,UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChannelItemListCollectionViewCell.identifier, for: indexPath as IndexPath) as! ChannelItemListCollectionViewCell
        
        cell.layer.shouldRasterize = true
        cell.layer.rasterizationScale = UIScreen.main.scale
        
        cell.selectionView.alpha = 0.4
        cell.tickButton.frame = CGRect(x: ((UIScreen.main.bounds.width/3)-2) - 25, y: 3, width: 20, height: 20)
        
        let channelItemImageView = cell.viewWithTag(100) as! UIImageView
        
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]!.count > 0
        {
            let mediaType = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][mediaTypeKey] as! String
            if let imageData =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][tImageKey]
            {
                channelItemImageView.image = imageData as? UIImage
            }
            else{
                channelItemImageView.image = UIImage(named: "thumb12")
            }
            
            
            if mediaType == "video"
            {
                cell.videoView.isHidden = false
                if let vDuration =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][videoDurationKey]
                {
                    cell.videoDurationLabel.text = vDuration as? String
                }
                cell.videoDurationLabel.isHidden = true
            }
            else{
                cell.videoView.isHidden = true
            }
            
            cell.insertSubview(cell.videoView, aboveSubview: cell.channelItemImageView)
            
            if(selectionFlag){
                
                if(selectedArray.contains(indexPath.row)){
                    
                    cell.selectionView.isHidden = false
                    cell.insertSubview(cell.selectionView, aboveSubview: cell.videoView)
                }
                else{
                    
                    cell.selectionView.isHidden = true
                    cell.insertSubview(cell.videoView, aboveSubview: cell.selectionView)
                }
            }
            else{
                cell.selectionView.isHidden = true
            }
        }
        else{
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
        if(selectionFlag){
            deleteButton.setTitleColor(UIColor.red, for: UIControlState.normal)
            deleteButton.isEnabled = true
            addButton.isEnabled = true
            addButton.setTitle("Add to", for: .normal)
            addButton.setTitleColor(UIColor.blue, for: UIControlState.normal)
            if(selectedArray.contains(indexPath.row)){
                let elementIndex = selectedArray.index(of: indexPath.row)
                selectedArray.remove(at: elementIndex!)
            }
            else{
                selectedArray.append(indexPath.row)
            }
            if(selectedArray.count <= 0){
                deleteButton.setTitleColor(UIColor.lightGray, for: UIControlState.normal)
                addButton.setTitleColor(UIColor.lightGray, for: UIControlState.normal)
                deleteButton.isEnabled = false
                addButton.isEnabled = false
            }
            DispatchQueue.main.async {
                self.channelItemCollectionView.reloadData()
            }
        }
        else{
            
            if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelId]![indexPath.row][tImageKey] != nil
            {
                self.showOverlay()
                self.channelItemCollectionView.alpha = 0.4
                operationInRedirectionCh.cancel()
                operationInRedirectionCh  = BlockOperation (block: {
                    self.redirectToFullview(indexPath: indexPath)
                })
                self.operationQueueObjRedirectionCh.addOperation(operationInRedirectionCh)
            }
        }
    }
    
    func redirectToFullview(indexPath:IndexPath)
    {
        if operationInRedirectionCh.isCancelled
        {
            return
        }
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
            self.vc = MovieViewController.movieViewController(withImageVideo: self.channelName, channelId: self.channelId as String, userName: self.userId, mediaType: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][mediaTypeKey] as! String, profileImage: imageForProfile, videoImageUrl: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][tImageKey] as! UIImage, notifType: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][notifTypeKey] as! String,mediaId: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][mediaIdKey] as! String, timeDiff: imageTakenTime,likeCountStr: "0",selectedItem:index,pageIndicator: 0, videoDuration:  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.channelId]![indexPath.row][videoDurationKey] as? String) as! MovieViewController
            self.present(self.vc, animated: false) { () -> Void in
                self.removeOverlay()
                self.channelItemCollectionView.alpha = 1.0
            }
        }
    }
}

extension ChannelItemListViewController: UIScrollViewDelegate
{
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if(totalCount > 0){
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
        }
    }
}
