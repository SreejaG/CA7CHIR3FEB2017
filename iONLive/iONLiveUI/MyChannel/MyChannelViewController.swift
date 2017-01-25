
import UIKit
import Foundation

class MyChannelViewController: UIViewController,UIScrollViewDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var myChannelSearchBar: UISearchBar!
    @IBOutlet weak var myChannelTableView: UITableView!
    
    @IBOutlet var addChannelViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var myChannelTableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var SearchBarBottomConstraint: NSLayoutConstraint!
    @IBOutlet var tableviewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var addChannelView: UIView!
    
    @IBOutlet var channelTextField: UITextField!
    var activeField: UITextField = UITextField()
    
    @IBOutlet var channelUpdateSaveButton: UIButton!
    @IBOutlet var channelUpdateCancelButton: UIButton!
    @IBOutlet var channelAddButton: UIButton!
    @IBOutlet var backButton: UIButton!
    @IBOutlet var notifImage: UIButton!
    @IBOutlet var channelCreateButton: UIButton!
    
    static let identifier = "MyChannelViewController"
    
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    
    var NoDatalabelFormyChanelImageList : UILabel = UILabel()
    
    var gestureRecognizer = UIGestureRecognizer()
    var longPressRecognizer : UILongPressGestureRecognizer = UILongPressGestureRecognizer()
    
    let defaults = UserDefaults.standard
    
    var loadingOverlay: UIView?
    
    var searchActive : Bool = false
    var longPressFlag : Bool = false
    var searchFlagForUpdateChannel : Bool = false
    var serachBarHideDuringChannelUpdateFlag : Bool = false
    
    var longPressIndexPathRow : Int = Int()
    
    var cellChannelUpdatedNameStr = String()
    
    var searchDataSource:[[String:Any]] = [[String:Any]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        defaults.setValue("", forKey: "editedValue")
        
        channelUpdateSaveButton.isHidden = true
        channelUpdateCancelButton.isHidden = true
        searchFlagForUpdateChannel = false
        longPressIndexPathRow = -1
        
        if let notifFlag = defaults.value(forKey: "notificationArrived")
        {
            if notifFlag as! String == "0"
            {
                let image = UIImage(named: "noNotif") as UIImage?
                notifImage.setImage(image, for: .normal)
            }
        }
        else{
            let image = UIImage(named: "notif") as UIImage?
            notifImage.setImage(image, for: .normal)
        }
        
        let removeActivityIndicatorMyChannelListNotificationName = Notification.Name("removeActivityIndicatorMyChannelList")
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MyChannelViewController.removeActivityIndicator(notif:)),
                                               name: removeActivityIndicatorMyChannelListNotificationName,
                                               object: nil)
        showOverlay()
        
        if(GlobalDataChannelList.sharedInstance.globalChannelDataSource.count > 0)
        {
            removeOverlay()
            self.myChannelTableView.reloadData()
        }
        else{
            removeOverlay()
            addNoDataLabel()
        }
        
        initialise()
        hideView(constraintConstant: 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        addKeyboardObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        searchActive = false
        myChannelTableView.reloadData()
        myChannelSearchBar.resignFirstResponder()
        tableViewBottomConstraint.constant = 0
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeActivityIndicatorMyChannelList"), object: nil)
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
    
    func hideView(constraintConstant: CGFloat)
    {
        addChannelView.isHidden = true
        myChannelSearchBar.isHidden = true
        myChannelTableViewTopConstraint.constant = -120 + constraintConstant
    }
    
    func initialise()
    {
        myChannelSearchBar.delegate = self
        gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MyChannelViewController.handleTap(gestureRecognizer:)))
        myChannelTableView.addGestureRecognizer(gestureRecognizer)
        channelCreateButton.isHidden = true
    }
    
    func removeActivityIndicator(notif : NSNotification){
        DispatchQueue.main.async {
            self.removeOverlay()
        }
        self.myChannelTableView.reloadData()
    }
    
    func handleTap(gestureRecognizer: UIGestureRecognizer) {
        if(longPressFlag == false){
            let swipeLocation = gestureRecognizer.location(in: self.myChannelTableView)
            if let swipedIndexPath = self.myChannelTableView.indexPathForRow(at: swipeLocation) {
                let sharingStoryboard = UIStoryboard(name:"MyChannel", bundle: nil)
                let channelItemListVC = sharingStoryboard.instantiateViewController(withIdentifier: ChannelItemListViewController.identifier) as! ChannelItemListViewController
                if(!searchActive){
                    if GlobalDataChannelList.sharedInstance.globalChannelDataSource.count > swipedIndexPath.row
                    {
                        channelItemListVC.channelId = GlobalDataChannelList.sharedInstance.globalChannelDataSource[swipedIndexPath.row][channelIdKey] as! String
                        channelItemListVC.channelName = GlobalDataChannelList.sharedInstance.globalChannelDataSource[swipedIndexPath.row][channelNameKey] as! String
                        channelItemListVC.totalMediaCount = Int(GlobalDataChannelList.sharedInstance.globalChannelDataSource[swipedIndexPath.row][totalMediaKey]! as! String)!
                    }
                }
                else{
                    if searchDataSource.count > swipedIndexPath.row
                    {
                        channelItemListVC.channelId = searchDataSource[swipedIndexPath.row][channelIdKey] as! String
                        channelItemListVC.channelName = searchDataSource[swipedIndexPath.row][channelNameKey] as! String
                        channelItemListVC.totalMediaCount = Int(searchDataSource[swipedIndexPath.row][totalMediaKey]! as! String)!
                    }
                }
                channelItemListVC.navigationController?.isNavigationBarHidden = true
                self.navigationController?.pushViewController(channelItemListVC, animated: false)
            }
        }
    }
    
    @IBAction func didTapNotificationButton(_ sender: Any) {
        let notificationStoryboard = UIStoryboard(name:"MyChannel", bundle: nil)
        let channelItemListVC = notificationStoryboard.instantiateViewController(withIdentifier: MyChannelNotificationViewController.identifier) as! MyChannelNotificationViewController
        channelItemListVC.navigationController?.isNavigationBarHidden = true
        let animation:CATransition = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
            kCAMediaTimingFunctionEaseOut)
        animation.type = kCATransitionFade
        animation.subtype = kCATransitionFromBottom
        animation.fillMode = kCAFillModeRemoved
        animation.duration = 0.2
        self.navigationController?.view.layer.add(animation, forKey: "animation")
        self.navigationController?.pushViewController(channelItemListVC, animated: false)
    }
    
    @IBAction func didtapBackButton(_ sender: Any)
    {
        let cameraViewStoryboard = UIStoryboard(name:"PhotoViewer" , bundle: nil)
        let iPhoneCameraViewController = cameraViewStoryboard.instantiateViewController(withIdentifier: "PhotoViewerViewController") as! PhotoViewerViewController
        self.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(iPhoneCameraViewController, animated: false)
    }
    
    @IBAction func didTapAddChannelButton(_ sender: Any) {
        showviewWithNewConstraints()
        searchActive = false
    }
    
    @IBAction func didTapChanelUpdateCancel(_ sender: Any) {
        view.endEditing(true)
        self.notifImage.isHidden = false
        self.channelAddButton.isHidden = false
        self.channelUpdateCancelButton.isHidden = true
        self.channelUpdateSaveButton.isHidden = true
        self.backButton.isHidden = false
        longPressIndexPathRow = -1
        longPressFlag = false
        searchActive = false
        myChannelSearchBar.text! = ""
        searchDataSource.removeAll()
        searchFlagForUpdateChannel = false
        UserDefaults.standard.setValue("", forKey: "editedValue")
        if(serachBarHideDuringChannelUpdateFlag){
            myChannelSearchBar.isHidden = true
        }
        else{
            myChannelSearchBar.isHidden = false
        }
        self.myChannelTableView.reloadData()
    }
    
    @IBAction func didTapChannelUpdateSave(_ sender: Any) {
        view.endEditing(true)
        let indexPath = IndexPath(row: longPressIndexPathRow, section: 0)
        let cell : MyChannelCell? = self.myChannelTableView.cellForRow(at: indexPath) as! MyChannelCell?
        if((cell?.editChanelNameTextField.text)!.characters.count > 15 || (cell?.editChanelNameTextField.text)!.characters.count <= 3){
            UserDefaults.standard.setValue("", forKey: "editedValue")
            ErrorManager.sharedInstance.InvalidChannelEnteredError()
            cell?.editChanelNameTextField.text = ""
        }
        else{
            cell?.editChanelNameTextField.resignFirstResponder()
            showOverlay()
            let defaults = UserDefaults .standard
            let userId = defaults.value(forKey: userLoginIdKey) as! String
            let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
            cellChannelUpdatedNameStr = (cell?.editChanelNameTextField.text)!
            
            var chanelId : String = String()
            if(searchFlagForUpdateChannel){
                if(longPressIndexPathRow < searchDataSource.count){
                    chanelId = searchDataSource[longPressIndexPathRow][channelIdKey] as! String
                }
            }
            else{
                if(longPressIndexPathRow < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count){
                    chanelId = GlobalDataChannelList.sharedInstance.globalChannelDataSource[longPressIndexPathRow][channelIdKey] as! String
                }
            }
            if(chanelId != ""){
                channelManager.updateChannelName(userName: userId, accessToken: accessToken, channelName: cellChannelUpdatedNameStr, channelId: chanelId, success: { (response) in
                    self.authenticationSuccessHandlerUpdateChannel(response: response)
                }, failure: { (error, message) in
                    self.authenticationFailureHandlerDelete(error: error, code: message)
                    return
                })
            }
            else{
                UserDefaults.standard.setValue("", forKey: "editedValue")
            }
        }
    }
    
    func authenticationSuccessHandlerUpdateChannel(response:AnyObject?)
    {
        removeOverlay()
        longPressFlag = false
        if (response as? [String: AnyObject]) != nil
        {
            if(searchFlagForUpdateChannel){
                searchDataSource[longPressIndexPathRow][channelNameKey] = cellChannelUpdatedNameStr
                let chaId = searchDataSource[longPressIndexPathRow][channelIdKey] as! String
                for i in 0 ..< GlobalDataChannelList.sharedInstance.globalChannelDataSource.count
                {
                    if i < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count
                    {
                        if(GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelIdKey] as! String == chaId)
                        {
                            GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelNameKey] = cellChannelUpdatedNameStr
                        }
                    }
                }
            }
            else{
                GlobalDataChannelList.sharedInstance.globalChannelDataSource[self.longPressIndexPathRow][channelNameKey] = self.cellChannelUpdatedNameStr
            }
            myChannelSearchBar.text! = ""
            searchDataSource.removeAll()
            searchActive = false
            searchFlagForUpdateChannel = false
            longPressIndexPathRow = -1
            cellChannelUpdatedNameStr = ""
            if(serachBarHideDuringChannelUpdateFlag){
                myChannelSearchBar.isHidden = true
            }
            else{
                myChannelSearchBar.isHidden = false
            }
            UserDefaults.standard.setValue("", forKey: "editedValue")
            DispatchQueue.main.async {
                self.notifImage.isHidden = false
                self.channelAddButton.isHidden = false
                self.channelUpdateCancelButton.isHidden = true
                self.channelUpdateSaveButton.isHidden = true
                self.backButton.isHidden = false
                self.myChannelTableView.reloadData()
            }
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
            myChannelSearchBar.text! = ""
            searchDataSource.removeAll()
            searchActive = false
            searchFlagForUpdateChannel = false
            longPressIndexPathRow = -1
            cellChannelUpdatedNameStr = ""
            if(serachBarHideDuringChannelUpdateFlag){
                myChannelSearchBar.isHidden = true
            }
            else{
                myChannelSearchBar.isHidden = false
            }
            UserDefaults.standard.setValue("", forKey: "editedValue")
            DispatchQueue.main.async {
                self.notifImage.isHidden = false
                self.channelAddButton.isHidden = false
                self.channelUpdateCancelButton.isHidden = true
                self.channelUpdateSaveButton.isHidden = true
                self.backButton.isHidden = false
                self.myChannelTableView.reloadData()
            }
        }
    }
    
    func  showviewWithNewConstraints()
    {
        addChannelView.isHidden = false
        addChannelViewTopConstraint.constant = -40
        myChannelSearchBar.isHidden = true
        myChannelTableViewTopConstraint.constant = 0
    }
    
    @IBAction func didTapCreateButton(_ sender: Any) {
        if((channelTextField.text?.characters.count)! > 15){
            channelTextField.resignFirstResponder()
            channelTextField.text = ""
            channelCreateButton.isHidden = true
            ErrorManager.sharedInstance.InvalidChannelEnteredError()
        }
        else{
            let defaults = UserDefaults .standard
            let userId = defaults.value(forKey: userLoginIdKey) as! String
            let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
            let channelname: String = channelTextField.text!
            channelTextField.resignFirstResponder()
            channelCreateButton.isHidden = true
            addChannelViewTopConstraint.constant = 0
            myChannelTableViewTopConstraint.constant = 0
            hideView(constraintConstant: 0)
            myChannelSearchBar.text = ""
            myChannelSearchBar.resignFirstResponder()
            myChannelSearchBar.delegate = self
            
            addChannelDetails(userName: userId, token: accessToken, channelName: channelname)
        }
    }
    
    func addChannelDetails(userName: String, token: String, channelName: String)
    {
        showOverlay()
        channelManager.addChannelDetails(userName: userName, accessToken: token, channelName: channelName, success: { (response) -> () in
            self.authenticationSuccessHandlerAddChannel(response: response)
        }) { (error, message) -> () in
            self.authenticationFailureHandlerAddChannel(error: error, code: message)
            return
        }
    }
    
    func authenticationSuccessHandlerAddChannel(response:AnyObject?)
    {
        removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            channelTextField.text = ""
            let channelId = json["channelId"]?.stringValue
            let channelName = json["channelName"] as! String
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
            let localDateStr = dateFormatter.string(from: NSDate() as Date)
            
            GlobalDataChannelList.sharedInstance.globalChannelDataSource.insert([channelIdKey:channelId!, channelNameKey:channelName, totalMediaKey:"0", ChannelCreatedTimeKey: localDateStr, sharedOriginalKey:1, sharedTemporaryKey:1], at: 0)
            
            let imageData = [[String:AnyObject]]()
            GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.updateValue(imageData, forKey: channelId!)
            DispatchQueue.main.async {
                self.myChannelTableView.reloadData()
            }
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func authenticationFailureHandlerAddChannel(error: NSError?, code: String)
    {
        self.removeOverlay()
        channelTextField.text = ""
        
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
    }
    
    func deleteChannelDetails(userName: String, token: String, channelId:String, index: Int)
    {
        showOverlay()
        channelManager.deleteChannelDetails(userName: userName, accessToken: token, deleteChannelId: channelId, success: { (response) -> () in
            self.authenticationSuccessHandlerDelete(response: response,index: index)
        }) { (error, message) -> () in
            self.serachBarHideDuringChannelUpdateFlag = false
            self.authenticationFailureHandlerDelete(error: error, code: message)
            return
        }
    }
    
    func authenticationSuccessHandlerDelete(response:AnyObject?, index:Int)
    {
        removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            let status = json["status"] as! Int
            if(status == 1){
                if(searchActive){
                    let channelId = searchDataSource[index][channelIdKey] as! String
                    searchDataSource.remove(at: index)
                    
                    var deleteIndexOfI : Int = Int()
                    var deleteFlag = false
                    
                    for i in 0 ..< GlobalDataChannelList.sharedInstance.globalChannelDataSource.count
                    {
                        if i < GlobalDataChannelList.sharedInstance.globalChannelDataSource.count
                        {
                            let orgChannel = GlobalDataChannelList.sharedInstance.globalChannelDataSource[i][channelIdKey] as! String
                            if(orgChannel == channelId){
                                deleteFlag = true
                                deleteIndexOfI = i
                                break
                            }
                        }
                    }
                    if deleteFlag == true
                    {
                        GlobalDataChannelList.sharedInstance.globalChannelDataSource.remove(at: deleteIndexOfI)
                    }
                }
                else{
                    GlobalDataChannelList.sharedInstance.globalChannelDataSource.remove(at: index)
                }
                
                DispatchQueue.main.async {
                    self.myChannelTableView.reloadData()
                }
            }
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func authenticationFailureHandlerDelete(error: NSError?, code: String)
    {
        self.removeOverlay()
        myChannelSearchBar.text! = ""
        UserDefaults.standard.setValue("", forKey: "editedValue")
        searchDataSource.removeAll()
        self.notifImage.isHidden = false
        self.channelAddButton.isHidden = false
        self.channelUpdateCancelButton.isHidden = true
        self.channelUpdateSaveButton.isHidden = true
        self.backButton.isHidden = false
        self.longPressFlag = false
        self.searchFlagForUpdateChannel = false
        self.searchActive = false
        self.longPressIndexPathRow = -1
        if(serachBarHideDuringChannelUpdateFlag){
            myChannelSearchBar.isHidden = true
        }
        else{
            myChannelSearchBar.isHidden = false
        }
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
        myChannelTableView.reloadData()
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
    
    @IBAction func channelTextFieldChange(_ sender: Any) {
        
        if let text = channelTextField.text, !text.isEmpty
        {
            if(text.characters.count >= 3)
            {
                channelCreateButton.isHidden = false
            }
            else
            {
                channelCreateButton.isHidden = true
            }
        }
    }
    
    @IBAction func tapGestureRecognizer(_ sender: Any) {
        if(longPressFlag == false){
            view.endEditing(true)
            self.myChannelSearchBar.text = ""
            self.myChannelSearchBar.resignFirstResponder()
            searchActive = false
            self.myChannelTableView.reloadData()
        }
    }
    
    func showOverlay(){
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = CGRect(x:0, y:64, width:self.view.frame.width, height:self.view.frame.height - 64)
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.view.addSubview(self.loadingOverlay!)
    }
    
    func removeOverlay(){
        self.loadingOverlay?.removeFromSuperview()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        activeField = UITextField()
    }
    
    func textFieldDidChange(_ textField: UITextField)
    {
        if let text = textField.text, !text.isEmpty
        {
            if(text.characters.count >= 3)
            {
                channelCreateButton.isHidden = false
            }
            else
            {
                ErrorManager.sharedInstance.InvalidChannelEnteredError()
                channelCreateButton.isHidden = true
            }
        }
    }
    
    func addKeyboardObservers()
    {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MyChannelViewController.keyboardDidShow(notification:)),
                                               name: NSNotification.Name.UIKeyboardDidShow,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(MyChannelViewController.keyboardDidHide),
                                               name: NSNotification.Name.UIKeyboardDidHide,
                                               object: nil)
    }
    
    func keyboardDidShow(notification:NSNotification)
    {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if tableViewBottomConstraint.constant == 0
        {
            if(longPressFlag){
                myChannelTableView.contentInset =  UIEdgeInsetsMake(0, 0, keyboardFrame.size.height, 0);
                myChannelTableView.scrollToRow(at: NSIndexPath(row: activeField.tag, section: 0) as IndexPath, at: .none, animated: true)
            }
//            self.tableViewBottomConstraint.constant = self.tableViewBottomConstraint.constant + keyboardFrame.size.height
        }
    }
    
    func keyboardDidHide()
    {
        myChannelTableView.contentInset =  UIEdgeInsetsMake(0, 0, 0, 0);
        if tableViewBottomConstraint.constant != 0
        {
            self.tableViewBottomConstraint.constant = 0
        }
    }
    
    func generateWaytoSendAlert(channelId: String, indexPath: Int)
    {
        let defaults = UserDefaults .standard
        let userId = defaults.value(forKey: userLoginIdKey) as! String
        let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
        
        let alert = UIAlertController(title: "Delete!!!", message: "Do you want to delete the channel", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            self.deleteChannelDetails(userName: userId, token: accessToken, channelId: channelId, index: indexPath)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension MyChannelViewController: UITableViewDelegate, UITableViewDataSource
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75.0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(searchActive){
            return searchDataSource.count > 0 ? (searchDataSource.count) : 0
        }
        else{
            return  GlobalDataChannelList.sharedInstance.globalChannelDataSource.count > 0 ? ( GlobalDataChannelList.sharedInstance.globalChannelDataSource.count) : 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var dataSourceTmp : [[String:Any]]?
        if(searchActive){
            dataSourceTmp = searchDataSource
        }
        else{
            dataSourceTmp = GlobalDataChannelList.sharedInstance.globalChannelDataSource
        }
        
        if dataSourceTmp!.count > indexPath.row
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: MyChannelCell.identifier, for:indexPath) as! MyChannelCell
            cell.editChanelNameTextField.tag = indexPath.row
//            let channleName = dataSourceTmp![indexPath.row][channelNameKey] as? String
//            if ((channleName == "My Day") || (channleName == "Archive"))
//            {
//                cell.removeGestureRecognizer(longPressRecognizer)
//            }
//            else{
//                cell.editChanelNameTextField.delegate = self
//                longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(MyChannelViewController.handleChannelLongPress(longPressGestureRecognizer:)))
//                cell.addGestureRecognizer(longPressRecognizer)
//            }
            
//            if(indexPath.row == longPressIndexPathRow)
//            {
//                let str = UserDefaults.standard.value(forKey: "editedValue")
//                cell.editChanelNameTextField.text = str as? String
//                cell.channelNameLabel.isHidden = true
//                cell.editChanelNameTextField.isHidden = false
//                cell.editChanelNameTextField.isUserInteractionEnabled = true
//                cell.editChanelNameTextField.autocorrectionType = .no
//                cell.editChanelNameTextField.becomeFirstResponder()
//                cell.channelItemCount.text = dataSourceTmp![indexPath.row][totalMediaKey] as? String
//                if let latestImage = dataSourceTmp![indexPath.row][tImageKey]
//                {
//                    cell.channelHeadImageView.image = latestImage as? UIImage
//                }
//                else
//                {
//                    cell.channelHeadImageView.image = UIImage(named: "thumb12")
//                }
//            }
//            else{
                cell.editChanelNameTextField.text = ""
                cell.editChanelNameTextField.isHidden = true
                cell.editChanelNameTextField.isUserInteractionEnabled = false
                cell.channelNameLabel.isHidden = false
                cell.channelNameLabel.text = dataSourceTmp![indexPath.row][channelNameKey] as? String
                cell.channelItemCount.text = dataSourceTmp![indexPath.row][totalMediaKey] as? String
                if let latestImage = dataSourceTmp![indexPath.row][tImageKey]
                {
                    cell.channelHeadImageView.image = latestImage as? UIImage
                }
                else
                {
                    cell.channelHeadImageView.image = UIImage(named: "thumb12")
                }
                cell.selectionStyle = .none
//            }
            return cell
        }
        else{
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    func handleChannelLongPress(longPressGestureRecognizer: UILongPressGestureRecognizer) {
        let longPressLocation = longPressGestureRecognizer.location(in: self.myChannelTableView)
        if let longPressIndexPath = self.myChannelTableView.indexPathForRow(at: longPressLocation) {
            var chanelNameChk = String()
            if(longPressFlag == false){
                longPressFlag = true
                longPressIndexPathRow = longPressIndexPath.row
                
                if(searchFlagForUpdateChannel){
                    chanelNameChk = searchDataSource[longPressIndexPathRow][channelNameKey] as! String
                }
                else{
                    chanelNameChk = GlobalDataChannelList.sharedInstance.globalChannelDataSource[longPressIndexPathRow][channelNameKey] as! String
                }
                if(chanelNameChk == "My Day" || chanelNameChk == "Archive")
                {
                    longPressIndexPathRow = -1
                    longPressFlag = false
                    myChannelSearchBar.isHidden = false
                }
                else
                {
                    if(myChannelSearchBar.isHidden){
                        serachBarHideDuringChannelUpdateFlag = true
                    }
                    else{
                        serachBarHideDuringChannelUpdateFlag = false
                    }
                    myChannelSearchBar.isHidden = true
                    notifImage.isHidden = true
                    channelAddButton.isHidden = true
                    channelUpdateCancelButton.isHidden = false
                    channelUpdateSaveButton.isHidden = false
                    backButton.isHidden = true
                    myChannelTableView.reloadData()
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if(longPressFlag == false){
            var channelName : String = String()
            if(searchActive){
                channelName = searchDataSource[indexPath.row][channelNameKey] as! String
            }
            else{
                channelName = GlobalDataChannelList.sharedInstance.globalChannelDataSource[indexPath.row][channelNameKey] as! String
            }
            
            if ((channelName == "My Day") || (channelName == "Archive"))
            {
                return false
            }
            else
            {
                return true
            }
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            var deletedChannelId : String = String()
            if(searchActive){
                deletedChannelId = self.searchDataSource[indexPath.row][channelIdKey] as! String
            }
            else{
                deletedChannelId = GlobalDataChannelList.sharedInstance.globalChannelDataSource[indexPath.row][channelIdKey] as! String
            }
            generateWaytoSendAlert(channelId: deletedChannelId, indexPath: indexPath.row)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if(addChannelView.isHidden)
        {
            if(longPressFlag == false){
                myChannelSearchBar.isHidden = false
                addChannelView.isHidden = true
                myChannelTableViewTopConstraint.constant = -90
            }
        }
    }
}

extension MyChannelViewController: UISearchBarDelegate{
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if searchBar.text!.isEmpty
        {
            searchActive = false
            searchFlagForUpdateChannel = false
            searchDataSource.removeAll()
        }
        else{
            searchActive = true
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDataSource.removeAll()
        if myChannelSearchBar.text!.isEmpty
        {
            searchDataSource = GlobalDataChannelList.sharedInstance.globalChannelDataSource
            myChannelSearchBar.resignFirstResponder()
            self.myChannelTableView.reloadData()
        }
        else{
            if GlobalDataChannelList.sharedInstance.globalChannelDataSource.count > 0
            {
                for element in GlobalDataChannelList.sharedInstance.globalChannelDataSource{
                    let tmp: String = (element[channelNameKey] as! String).lowercased()
                    if(tmp.range(of: searchText.lowercased()) != nil)
                    {
                        searchDataSource.append(element)
                    }
                }
                searchActive = true
                searchFlagForUpdateChannel = true
                self.myChannelTableView.reloadData()
            }
        }
    }
}

