
import UIKit

class MySharedChannelsViewController: UIViewController {
    
    static let identifier = "MySharedChannelsViewController"
    
    @IBOutlet weak var sharedChannelsTableView: UITableView!
    @IBOutlet weak var sharedChannelsSearchBar: UISearchBar!
    @IBOutlet weak var tableViewBottomConstaint: NSLayoutConstraint!
    
    let channelManager = ChannelManager.sharedInstance
    let requestManager = RequestManager.sharedInstance
    
    var dataSource:[[String:Any]] = [[String:Any]]()
    
    var searchActive : Bool = false
    var searchDataSource:[[String:Any]] = [[String:Any]]()
    var addChannelArray : NSMutableArray = NSMutableArray()
    var deleteChannelArray : NSMutableArray = NSMutableArray()
    
    @IBOutlet var doneButton: UIButton!
    
    var loadingOverlay: UIView?
    
    var NoDatalabelFormyChanelImageList : UILabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let refreshMySharedChannel = Notification.Name("refreshMySharedChannelTableView")
        NotificationCenter.default.addObserver(self, selector:#selector(MySharedChannelsViewController.CallRefreshMySharedChannelTableView(notif:)), name: refreshMySharedChannel, object: nil)
        
        let removeActivityIndicatorMyChannelList = Notification.Name("removeActivityIndicatorMyChannelList")
        NotificationCenter.default.addObserver(self, selector:#selector(MySharedChannelsViewController.removeActivityIndicator(notif:)), name: removeActivityIndicatorMyChannelList, object: nil)
        
        doneButton.isHidden = true
        
        addChannelArray.removeAllObjects()
        deleteChannelArray.removeAllObjects()
        
        sharedChannelsSearchBar.delegate = self
        
        showOverlay()
        
        if (GlobalDataChannelList.sharedInstance.globalChannelDataSource.count > 0)
        {
            removeOverlay()
            createChannelDataSource()
        }
        else{
            removeOverlay()
            addNoDataLabel()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        addKeyboardObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeActivityIndicatorMyChannelList"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("refreshMySharedChannelTableView"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func addNoDataLabel()
    {
        self.NoDatalabelFormyChanelImageList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100), y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoDatalabelFormyChanelImageList.textAlignment = NSTextAlignment.center
        self.NoDatalabelFormyChanelImageList.text = "No Channel Available"
        self.view.addSubview(self.NoDatalabelFormyChanelImageList)
    }
    
    func removeActivityIndicator(notif : NSNotification){
        dataSource.removeAll()
        self.createChannelDataSource()
        DispatchQueue.main.async {
            self.removeOverlay()
        }
    }
    
    func createChannelDataSource()
    {
        for element in GlobalDataChannelList.sharedInstance.globalChannelDataSource
        {
            let chanelName = element[channelNameKey] as! String
            if chanelName != "Archive"
            {
                dataSource.append(element)
            }
        }
        if dataSource.count > 0{
            sharedChannelsTableView.reloadData()
        }
    }
    
    @IBAction func backButtonClicked(_ sender: Any)
    {
        if(doneButton.isHidden == false){
            doneButton.isHidden = true
            for i in 0 ..< dataSource.count
            {
                if i < dataSource.count
                {
                    let selectionValue : Int = dataSource[i]["orgSelected"] as! Int
                    dataSource[i]["tempSelected"] = selectionValue
                }
            }
            self.sharedChannelsTableView.reloadData()
        }
        else{
            let cameraViewStoryboard = UIStoryboard(name:"IPhoneCameraView" , bundle: nil)
            let iPhoneCameraViewController = cameraViewStoryboard.instantiateViewController(withIdentifier: "IPhoneCameraViewController") as! IPhoneCameraViewController
            self.navigationController?.isNavigationBarHidden = true
            self.navigationController?.pushViewController(iPhoneCameraViewController, animated: false)
        }
    }
    
    func addKeyboardObservers()
    {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MySharedChannelsViewController.keyboardDidShow(notification:)),
                                               name: NSNotification.Name.UIKeyboardDidShow,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MySharedChannelsViewController.keyboardDidHide),
                                               name: NSNotification.Name.UIKeyboardDidHide,
                                               object: nil)
    }
    
    func keyboardDidShow(notification:NSNotification)
    {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if tableViewBottomConstaint.constant == 0
        {
            self.tableViewBottomConstaint.constant = self.tableViewBottomConstaint.constant + keyboardFrame.size.height
        }
    }
    
    func keyboardDidHide()
    {
        if tableViewBottomConstaint.constant != 0
        {
            self.tableViewBottomConstaint.constant = 0
        }
    }
    
    @IBAction func gestureTapped(_ sender: Any) {
        view.endEditing(true)
        self.sharedChannelsSearchBar.text = ""
        self.sharedChannelsSearchBar.resignFirstResponder()
        searchActive = false
        self.sharedChannelsTableView.reloadData()
    }
    
    @IBAction func didTapDoneButton(_ sender: Any) {
        doneButton.isHidden = true
        self.sharedChannelsTableView.reloadData()
        sharedChannelsTableView.layoutIfNeeded()
        addChannelArray.removeAllObjects()
        deleteChannelArray.removeAllObjects()
        for i in 0 ..< dataSource.count
        {
            if i < dataSource.count
            {
                let channelid = dataSource[i][channelIdKey] as! String
                let selectionValue : Int = dataSource[i][sharedTemporaryKey] as! Int
                if(selectionValue == 1){
                    addChannelArray.add(channelid)
                }
                else{
                    deleteChannelArray.add(channelid)
                }
            }
        }
        if((addChannelArray.count > 0) || (deleteChannelArray.count > 0)){
            let defaults = UserDefaults .standard
            let userId = defaults.value(forKey: userLoginIdKey) as! String
            let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
            enableDisableChannels(userName: userId, token: accessToken, addChannels: addChannelArray, deleteChannels: deleteChannelArray)
        }
    }
    
    func  enableDisableChannels(userName: String, token: String, addChannels: NSMutableArray, deleteChannels:NSMutableArray) {
        showOverlay()
        channelManager.enableDisableChannels(userName: userName, accessToken: token, addChannel: addChannels, deleteChannel: deleteChannels, success: { (response) in
            self.authenticationSuccessHandlerEnableDisable(response: response)
        }) { (error, message) in
            self.authenticationFailureHandler(error: error, code: message)
            return
        }
    }
    
    func authenticationSuccessHandlerEnableDisable(response:AnyObject?)
    {
        removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            let status = json["status"] as! Int
            if(status == 1){
                for i in 0 ..< dataSource.count
                {
                    if i < dataSource.count
                    {
                        let selectionValue : Int = dataSource[i][sharedTemporaryKey] as! Int
                        dataSource[i][sharedOriginalKey] = selectionValue
                    }
                }
                sharedChannelsTableView.reloadData()
                GlobalDataChannelList.sharedInstance.enableDisableChannelList(dataSource: dataSource)
            }
        }
        else
        {
            for i in 0 ..< dataSource.count
            {
                if i < dataSource.count
                {
                    let selectionValue : Int = dataSource[i][sharedOriginalKey] as! Int
                    dataSource[i][sharedTemporaryKey] = selectionValue
                }
            }
            
            ErrorManager.sharedInstance.inValidResponseError()
            sharedChannelsTableView.reloadData()
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
    
    func convertStringtoURL(url : String) -> NSURL
    {
        let url : NSString = url as NSString
        let searchURL : NSURL = NSURL(string: url as String)!
        return searchURL
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
    
    func authenticationFailureHandler(error: NSError?, code: String)
    {
        removeOverlay()
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
        
        for i in 0 ..< dataSource.count
        {
            if i < dataSource.count
            {
                let selectionValue : Int = dataSource[i]["orgSelected"] as! Int
                dataSource[i]["tempSelected"] = selectionValue
            }
        }
        self.sharedChannelsTableView.reloadData()
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
    
    func CallRefreshMySharedChannelTableView(notif:NSNotification){
        if(doneButton.isHidden == true){
            doneButton.isHidden = false
        }
        let indexpath = notif.object as! Int
        if(searchActive)
        {
            let selectedValue =  searchDataSource[indexpath][sharedTemporaryKey] as! Int
            if(selectedValue == 1)
            {
                searchDataSource[indexpath][sharedTemporaryKey] = 0
            }
            else
            {
                searchDataSource[indexpath][sharedTemporaryKey] = 1
            }
            
            let selectedChannelId =  searchDataSource[indexpath][channelIdKey] as! String
            for i in 0 ..< dataSource.count
            {
                if i < dataSource.count
                {
                    let dataSourceChannelId = dataSource[i][channelIdKey] as! String
                    if(selectedChannelId == dataSourceChannelId)
                    {
                        dataSource[i][sharedTemporaryKey] = searchDataSource[indexpath][sharedTemporaryKey]
                    }
                }
            }
        }
        else
        {
            let selectedValue =  dataSource[indexpath][sharedTemporaryKey] as! Int
            if(selectedValue == 1){
                dataSource[indexpath][sharedTemporaryKey] = 0
            }
            else{
                dataSource[indexpath][sharedTemporaryKey] = 1
            }
        }
        
        var doneButtonHideFlag : Bool  = false
        for k in 0 ..< dataSource.count
        {
            if k < dataSource.count
            {
                let temp =  dataSource[k][sharedTemporaryKey] as! Int
                let org = dataSource[k][sharedOriginalKey] as! Int
                if temp != org
                {
                    doneButtonHideFlag = true
                    break
                }
            }
        }
        if(doneButtonHideFlag){
            doneButton.isHidden = false
        }
        else{
            doneButton.isHidden = true
        }
        
        sharedChannelsTableView.reloadData()
    }
}

extension MySharedChannelsViewController: UITableViewDelegate, UITableViewDataSource
{
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 45.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let  headerCell = tableView.dequeueReusableCell(withIdentifier: MySharedChannelsHeaderCell.identifier) as! MySharedChannelsHeaderCell
        headerCell.headerTitleLabel.text = "MY SHARED CHANNELS"
        return headerCell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(searchActive){
            return searchDataSource.count > 0 ? (searchDataSource.count) : 0
        }
        else{
            return dataSource.count > 0 ? (dataSource.count) : 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var dataSourceTmp : [[String:Any]]?
        if(searchActive){
            dataSourceTmp = searchDataSource
        }
            
        else{
            dataSourceTmp = dataSource
        }
        
        if dataSourceTmp!.count > indexPath.row
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: MySharedChannelsCell.identifier, for:indexPath as IndexPath) as! MySharedChannelsCell
            
            cell.channelNameLabel.text = dataSourceTmp![indexPath.row][channelNameKey] as? String
            cell.sharedCountLabel.text = dataSourceTmp![indexPath.row][totalMediaKey] as? String
            
            if let latestImage = dataSourceTmp![indexPath.row][tImageKey]
            {
                cell.userImage.image = latestImage as? UIImage
            }
            else
            {
                cell.userImage.image = UIImage(named: "thumb12")
            }
            
            cell.channelSelectionButton.tag = indexPath.row
            
            let selectionValue : Int = dataSourceTmp![indexPath.row][sharedTemporaryKey] as! Int
            if(selectionValue == 1){
                cell.channelSelectionButton.setImage(UIImage(named:"CheckOn"), for:.normal)
                cell.sharedCountLabel.isHidden = false
                cell.avatarIconImageView.isHidden = false
            }
            else{
                cell.channelSelectionButton.setImage(UIImage(named:"red-circle"), for:.normal)
                cell.sharedCountLabel.isHidden = true
                cell.avatarIconImageView.isHidden = true
            }
            cell.selectionStyle = .none
            return cell
        }
        else{
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaults.standard.set(1, forKey: "tabToAppear")
        let sharingStoryboard = UIStoryboard(name:"sharing", bundle: nil)
        let channelDetailVC:UITabBarController = sharingStoryboard.instantiateViewController(withIdentifier: MyChannelDetailViewController.identifier) as! UITabBarController
        if(!searchActive){
            if dataSource.count > indexPath.row
            {
                (channelDetailVC as! MyChannelDetailViewController).channelId = dataSource[indexPath.row][channelIdKey] as! String
                (channelDetailVC as! MyChannelDetailViewController).channelName = dataSource[indexPath.row][channelNameKey] as! String
                (channelDetailVC as! MyChannelDetailViewController).totalMediaCount = Int(dataSource[indexPath.row][totalMediaKey]! as! String)!
            }
        }
        else{
            if searchDataSource.count > indexPath.row
            {
                (channelDetailVC as! MyChannelDetailViewController).channelId = searchDataSource[indexPath.row][channelIdKey] as! String
                (channelDetailVC as! MyChannelDetailViewController).channelName = searchDataSource[indexPath.row][channelNameKey] as! String
                (channelDetailVC as! MyChannelDetailViewController).totalMediaCount = Int(searchDataSource[indexPath.row][totalMediaKey]! as! String)!
            }
        }
        channelDetailVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(channelDetailVC, animated: false)
    }
}

extension MySharedChannelsViewController : UISearchBarDelegate,UISearchDisplayDelegate{
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if self.sharedChannelsSearchBar.text != ""
        {
            searchActive = true
        }
        else{
            searchActive = false
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDataSource.removeAll()
        
        if sharedChannelsSearchBar.text!.isEmpty
        {
            searchDataSource = dataSource
            sharedChannelsSearchBar.resignFirstResponder()
            self.sharedChannelsTableView.reloadData()
        }
        else{
            if dataSource.count > 0
            {
                for element in dataSource{
                    var tmp: String =  ""
                    tmp = (element[channelNameKey] as! String).lowercased()
                    if(tmp.range(of: searchText.lowercased()) != nil)
                    {
                        searchDataSource.append(element)
                    }
                }
                
                searchActive = true
                self.sharedChannelsTableView.reloadData()
            }
        }
    }
}
