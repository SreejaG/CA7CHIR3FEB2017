
import UIKit
import MediaPlayer
import Foundation
import AVKit

protocol progressviewDelegate
{
    func ProgresviewUpdate (value : Float)
}

class PhotoViewerViewController: UIViewController,UIGestureRecognizerDelegate,URLSessionDelegate, URLSessionTaskDelegate,URLSessionDataDelegate,URLSessionDownloadDelegate,UIScrollViewDelegate,AVPlayerViewControllerDelegate,CAAnimationDelegate
{
    var delegate:progressviewDelegate?
    
    var lastContentOffset: CGPoint = CGPoint()
    
    @IBOutlet var TopView: UIView!
    @IBOutlet var BottomView: UIView!
    @IBOutlet var playIconInFullView: UIImageView!
    @IBOutlet weak var fullScrenImageView: UIImageView!
    @IBOutlet var fullScreenZoomView: UIImageView!
    @IBOutlet weak var fullScreenScrollView: UIScrollView!
    @IBOutlet weak var mediaTimeLabel: UILabel!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet weak var photoThumpCollectionView: UICollectionView!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var addToButton: UIButton!
    @IBOutlet var deletButton: UIButton!
    
    @IBOutlet var videoDurationLabel: UILabel!
    
    static let identifier = "PhotoViewerViewController"
    
    let imageUploadManger = ImageUpload.sharedInstance
    let requestManager = RequestManager.sharedInstance
    let channelManager = ChannelManager.sharedInstance
    
    let defaults = UserDefaults.standard
    
    var downloadTask: URLSessionDownloadTask?
    
    var operationQueueObjInMyMediaList = OperationQueue()
    var operationInMyMediaList = BlockOperation()
    
    var progressViewDownload: UIProgressView?
    var progressLabelDownload: UILabel?
    var NoDatalabelFormyMediaImageList : UILabel = UILabel()
    var loadingOverlay: UIView?
    var addToDict : [[String:Any]] = [[String:Any]]()
    var mediaSelected: NSMutableArray = NSMutableArray()
    var willEnterFlag : NSInteger = NSInteger()
    var playHandleflag : NSInteger = NSInteger()
    var selectedItem : Int = Int()
    var archiveMediaCount : Int = Int()
    var archiveChanelId : String = String()
    var mediaIdSelected : Int = 0
    var videoDownloadIntex : Int = 0
    var totalCount = 0
    var swipeFlag : Bool = false
    var downloadingFlag : Bool = false
    var dictMediaId : String = String()
    var userId : String = String()
    var accessToken: String = String()
    var deletedMediaId : NSMutableArray = NSMutableArray()
    var dictProgress : Float = Float()
    var orientationFlag: Int = Int()
    var Orgimage : UIImage? = UIImage()
    var mediaTypeSelected : String = String()
    let playerViewController = AVPlayerViewController()
    var videoThumbImage : UIImage = UIImage()
    var customView = CustomInfiniteIndicator()
    var downloadingStartedFlag : Bool = false
    
    class var sharedInstance: PhotoViewerViewController {
        struct Singleton {
            static let instance = PhotoViewerViewController()
        }
        return Singleton.instance
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        getCurrentOrientaion()
        selectedItem = 0
        self.photoThumpCollectionView.alwaysBounceHorizontal = true
        progressLabelDownload = UILabel()
        progressViewDownload?.isHidden = true
        progressLabelDownload?.isHidden = true
        self.fullScrenImageView.image = UIImage()
        self.fullScreenZoomView.image = UIImage()
        playHandleflag = 0
        videoDurationLabel.isHidden = true
        downloadingStartedFlag = false
        
        let removeActivityIndicatorMyChannel = Notification.Name("removeActivityIndicatorMyChannel")
        NotificationCenter.default.addObserver(self, selector:#selector(PhotoViewerViewController.removeActivityIndicatorMyMedia(notif:)), name: removeActivityIndicatorMyChannel, object: nil)
        
        let upload = Notification.Name("upload")
        NotificationCenter.default.addObserver(self, selector:#selector(PhotoViewerViewController.uploadMediaProgress(notif:)), name: upload, object: nil)
        
        let setFullscreenImage = Notification.Name("setFullscreenImage")
        NotificationCenter.default.addObserver(self, selector:#selector(PhotoViewerViewController.setFullscreenImage(notif:)), name: setFullscreenImage, object: nil)
        
        let tokenExpired = Notification.Name("tokenExpired")
        NotificationCenter.default.addObserver(self, selector:#selector(PhotoViewerViewController.loadInitialViewControllerTokenExpire(notif:)), name: tokenExpired, object: nil)
        
        showOverlay()
        initialise()
        
        archiveMediaCount = defaults.value(forKey: ArchiveCount) as! Int
        archiveChanelId = "\(defaults.value(forKey: archiveId) as! Int)"
        
        if((archiveMediaCount == 0) || (GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count <= 0)){
            self.removeOverlay()
            addNoDataLabel()
            self.addToButton.isHidden = true
            self.deletButton.isHidden = true
            self.fullScreenZoomView.image = UIImage()
            self.fullScrenImageView.image = UIImage()
        }
        else if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0)
        {
            var channelKeys = Array(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.keys)
            if(channelKeys.contains(archiveChanelId)){
                let filteredData = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.filter(thumbExists)
                totalCount = filteredData.count
                GlobalChannelToImageMapping.sharedInstance.setFilteredCount(count: totalCount)
            }
            channelKeys.removeAll()
            if totalCount > 0
            {
                removeOverlay()
                
                let dict = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem]
                downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: selectedItem,gestureIdentifier: 0)
                DispatchQueue.main.async {
                    self.addToButton.isHidden = false
                    self.deletButton.isHidden = false
                    self.photoThumpCollectionView.reloadData()
                }
                if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > totalCount){
                    if(totalCount < 9 && totalCount > 0){
                        DispatchQueue.main.async {
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                            self.customView = CustomInfiniteIndicator(frame: CGRect(x:(self.photoThumpCollectionView.layer.frame.width - 50), y:(self.photoThumpCollectionView.layer.frame.height/2 - 12), width:30, height:30))
                            self.photoThumpCollectionView.addSubview(self.customView)
                            self.customView.startAnimating()
                        }
                    }
                    else if(totalCount == 0){
                        DispatchQueue.main.async {
                            self.showOverlay()
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                            self.fullScrenImageView.image = UIImage()
                            self.fullScreenZoomView.image = UIImage()
                            self.deletButton.isHidden = true
                            self.addToButton.isHidden = true
                        }
                    }
                    else{
                        DispatchQueue.main.async {
                            self.removeOverlay()
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                            self.deletButton.isHidden = false
                            self.addToButton.isHidden = false
                        }
                    }
                }
            }
            else if totalCount <= 0
            {
                DispatchQueue.main.async {
                    self.addToButton.isHidden = true
                    self.deletButton.isHidden = true
                    self.mediaTimeLabel.text = ""
                    self.fullScreenZoomView.image = UIImage()
                    self.fullScrenImageView.image = UIImage()
                    self.photoThumpCollectionView.reloadData()
                }
            }
            downloadImagesFromGlobalChannelImageMapping(limit: 21)
        }
        
        fullScreenScrollView.delegate = self
        fullScreenScrollView.minimumZoomScale = 1.0
        fullScreenScrollView.maximumZoomScale = 10.0
        fullScreenScrollView.zoomScale = 1.0
        view.addSubview(fullScreenScrollView)
        fullScreenScrollView.delaysContentTouches = false;
        
        self.view.bringSubview(toFront: fullScrenImageView)
        self.view.bringSubview(toFront: photoThumpCollectionView)
        self.view.bringSubview(toFront: playIconInFullView)
        self.view.bringSubview(toFront: TopView)
        self.view.bringSubview(toFront: BottomView)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(PhotoViewerViewController.handleDoubleTap(recognizer:)))
        doubleTap.numberOfTapsRequired = 2
        self.fullScrenImageView.addGestureRecognizer(doubleTap)
        
        let doubleTap1 = UITapGestureRecognizer(target: self, action: #selector(PhotoViewerViewController.handleDoubleTap(recognizer:)))
        doubleTap1.numberOfTapsRequired = 2
        self.fullScreenZoomView.addGestureRecognizer(doubleTap1)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action:#selector(PhotoViewerViewController.handleSwipe(gesture:)))
        swipeRight.direction = UISwipeGestureRecognizerDirection.right
        self.fullScrenImageView.addGestureRecognizer(swipeRight)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action:#selector(PhotoViewerViewController.handleSwipe(gesture:)))
        swipeLeft.direction = UISwipeGestureRecognizerDirection.left
        self.fullScrenImageView.addGestureRecognizer(swipeLeft)
        
        swipeRight.delegate = self;
        swipeLeft.delegate = self;
        
        let enlargeImageViewRecognizer = UITapGestureRecognizer(target: self, action: #selector(PhotoViewerViewController.enlargeImageView(Recognizer:)))
        enlargeImageViewRecognizer.numberOfTapsRequired = 1
        fullScrenImageView.addGestureRecognizer(enlargeImageViewRecognizer)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        if (self.mediaTypeSelected == "video")
        {
            DispatchQueue.main.async {
                self.fullScrenImageView.image = self.setOrientationForVideo()
                self.fullScreenZoomView.image = self.setOrientationForVideo()
            }
        }
        
        DispatchQueue.main.async {
            self.photoThumpCollectionView.reloadData()
        }
        
        NotificationCenter.default.addObserver(self, selector:#selector(PhotoViewerViewController.orientaionChanged(notification:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: UIDevice.current)
        
        downloadingFlag = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        operationInMyMediaList.cancel()
        customView.stopAnimationg()
        customView.removeFromSuperview()
        
        NotificationCenter.default.removeObserver(NSNotification.Name.UIDeviceOrientationDidChange)
        NotificationCenter.default.removeObserver(NSNotification.Name.AVPlayerItemDidPlayToEndTime)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("tokenExpired"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("removeActivityIndicatorMyChannel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("setFullscreenImage"), object: nil)
        
        if ((playHandleflag == 1) && (willEnterFlag == 1))
        {
        }
        else if (playHandleflag == 1)
        {
            playHandleflag = 0
            NotificationCenter.default.removeObserver(self)
        }
        if(downloadTask?.state == .running)
        {
            downloadTask?.cancel()
        }
    }
    
    func  loadInitialViewControllerTokenExpire(notif:NSNotification){
        if let tokenValid = UserDefaults.standard.value(forKey: "tokenValid")
        {
            if tokenValid as! String == "true"
            {
                operationInMyMediaList.cancel()
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
                operationInMyMediaList.cancel()
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
    
    func getCurrentOrientaion()
    {
        let device: UIDevice = UIDevice.current
        switch device.orientation {
        case .portrait,.portraitUpsideDown:
            orientationFlag = 1;
            break;
        case .landscapeLeft:
            orientationFlag = 2;
            break;
        case .landscapeRight:
            orientationFlag = 3;
            break;
        default:
            orientationFlag = 1
            break;
        }
    }
    
    func orientaionChanged(notification:NSNotification)
    {
        var orientedImage = Orgimage
        DispatchQueue.main.async {
            if(self.Orgimage != nil && self.totalCount > 0){
                let viewController: UIViewController = (self.navigationController?.visibleViewController)!
                if(viewController.restorationIdentifier == "PhotoViewerViewController"){
                    if(self.mediaTypeSelected != "video")
                    {
                        if ((self.Orgimage!.size.width > 0.0) && (self.Orgimage!.size.height > 0.0))
                        {
                            let transition : CATransition = CATransition()
                            transition.duration = 0.3;
                            transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                            transition.type = kCATransitionFade;
                            transition.delegate = self;
                            self.fullScrenImageView.layer.add(transition, forKey: nil)
                            
                            let device: UIDevice = notification.object as! UIDevice
                            switch device.orientation {
                            case .portrait,.portraitUpsideDown:
                                self.orientationFlag = 1;
                                if self.Orgimage!.size.width > self.Orgimage!.size.height
                                {
                                    self.fullScrenImageView.contentMode = .scaleAspectFit
                                }
                                else{
                                    self.fullScrenImageView.contentMode = .scaleAspectFill
                                }
                                orientedImage = self.Orgimage
                                break;
                            case .landscapeLeft:
                                self.orientationFlag = 2;
                                if self.Orgimage!.size.width > self.Orgimage!.size.height
                                {
                                    self.fullScrenImageView.contentMode = .scaleAspectFit
                                    orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                                            orientation: .right)
                                }
                                else{
                                    self.fullScrenImageView.contentMode = .scaleAspectFit
                                    orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                                            orientation: .down)
                                }
                                break;
                            case .landscapeRight:
                                self.orientationFlag = 3;
                                if self.Orgimage!.size.width > self.Orgimage!.size.height
                                {
                                    self.fullScrenImageView.contentMode = .scaleAspectFit
                                    orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                                            orientation: .left)
                                }
                                else{
                                    self.fullScrenImageView.contentMode = .scaleAspectFit
                                    orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                                            orientation: .up)
                                }
                                break;
                            default:
                                self.orientationFlag = 1
                                break;
                            }
                        }
                    }
                    else{
                        orientedImage = self.setOrientationForVideo()
                    }
                    self.fullScrenImageView.image = orientedImage! as UIImage
                    self.fullScreenZoomView.image = orientedImage! as UIImage
                }
            }
        }
    }
    
    func downloadImagesFromGlobalChannelImageMapping(limit:Int)  {
        operationInMyMediaList.cancel()
        let start = totalCount
        var end = 0
        
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId] != nil
        {
            if((totalCount + limit) <= GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count){
                end = limit
            }
            else{
                end = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count - totalCount
            }
            end = start + end
            if end <= GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count
            {
                operationInMyMediaList  = BlockOperation (block: {
                    GlobalChannelToImageMapping.sharedInstance.downloadMediaFromGCS(chanelId: self.archiveChanelId, start: start, end: end, operationObj: self.operationInMyMediaList)
                })
                self.operationQueueObjInMyMediaList.addOperation(operationInMyMediaList)
            }
        }
        GlobalChannelToImageMapping.sharedInstance.setFilteredCount(count: end)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.fullScreenZoomView
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func handleDoubleTap(recognizer: UITapGestureRecognizer) {
        if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0){
            if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0
            {
                if totalCount > 0
                {
                    let mediaType = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem][mediaTypeKey] as! String
                    
                    if mediaType != "video"
                    {
                        if (fullScreenScrollView.zoomScale > fullScreenScrollView.minimumZoomScale) {
                            fullScreenScrollView.setZoomScale(fullScreenScrollView.minimumZoomScale, animated: true)
                        } else {
                            let zoomRect = self.zoomRectForScale(scale: fullScreenScrollView.minimumZoomScale+1, center: recognizer.location(in: recognizer.view))
                            self.fullScreenScrollView.zoom(to: zoomRect, animated: true);
                            
                        }
                    }
                }
            }
        }
    }
    
    func zoomRectForScale(scale : CGFloat, center : CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        if let imageV = self.fullScreenScrollView {
            zoomRect.size.height = imageV.frame.size.height / scale;
            zoomRect.size.width  = imageV.frame.size.width  / scale;
            let newCenter = imageV.convert(center, from: self.fullScreenScrollView)
            zoomRect.origin.x = newCenter.x - ((zoomRect.size.width / 2.0));
            zoomRect.origin.y = newCenter.y - ((zoomRect.size.height / 2.0));
        }
        return zoomRect;
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with views: UIView?) {
        if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0){
            if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0
            {
                if(fullScreenZoomView.isHidden==true)
                {
                    downloadingFlag = true
                    fullScreenZoomView.isHidden = false
                    fullScrenImageView.alpha = 0.0
                    TopView.isHidden = true
                    BottomView.isHidden = true
                    photoThumpCollectionView.isHidden = true
                    playIconInFullView.isHidden = true
                    scrollView.isScrollEnabled=true;
                    fullScrenImageView.isUserInteractionEnabled = false
                    self.view.bringSubview(toFront: photoThumpCollectionView)
                    self.view.bringSubview(toFront: playIconInFullView)
                    self.view.bringSubview(toFront: TopView)
                    self.view.bringSubview(toFront: BottomView)
                }
            }
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if(scale<=1.0)
        {
            downloadingFlag = false
            fullScreenZoomView.isHidden = true
            fullScrenImageView.alpha = 1.0
            TopView.isHidden = false
            BottomView.isHidden = false
            photoThumpCollectionView.isHidden = false
            fullScreenScrollView.isScrollEnabled=false;
            self.photoThumpCollectionView.reloadData()
            fullScrenImageView.isUserInteractionEnabled = true
            fullScreenScrollView.bounds = fullScrenImageView.bounds
        }
    }
    
    func enlargeImageView(Recognizer:UITapGestureRecognizer){
        if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0){
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0){
                if(totalCount > 0){
                    if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem][mediaTypeKey] != nil
                    {
                        let mediaType = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem][mediaTypeKey] as! String
                        if mediaType == "video"
                        {
                            downloadVideo(index: selectedItem)
                        }
                    }
                }
            }
        }
    }
    
    func addNoDataLabel()
    {
        self.NoDatalabelFormyMediaImageList = UILabel(frame: CGRect(x:((self.view.frame.width/2) - 100),y:((self.view.frame.height/2) - 35), width:200, height:70))
        self.NoDatalabelFormyMediaImageList.textAlignment = NSTextAlignment.center
        self.NoDatalabelFormyMediaImageList.text = "No Media Available"
        self.view.addSubview(self.NoDatalabelFormyMediaImageList)
        DispatchQueue.main.async {
            self.mediaTimeLabel.text = ""
        }
    }
    
    func removeActivityIndicatorMyMedia(notif : NSNotification){
        operationInMyMediaList.cancel()
        let filteredData = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.filter(thumbExists)
        totalCount = filteredData.count
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0
        {
            let dict =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![0]
            self.downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: selectedItem,gestureIdentifier:0)
        }
        else{
            DispatchQueue.main.async {
                self.removeOverlay()
                self.customView.stopAnimationg()
                self.customView.removeFromSuperview()
                self.addToButton.isHidden = false
                self.deletButton.isHidden = false
            }
            addNoDataLabel()
        }
        
        DispatchQueue.main.async {
            self.removeOverlay()
            self.customView.stopAnimationg()
            self.customView.removeFromSuperview()
            self.addToButton.isHidden = false
            self.deletButton.isHidden = false
            self.photoThumpCollectionView.reloadData()
        }
        
        if downloadingFlag == true
        {
            downloadingFlag = false
        }
    }
    
    func thumbExists (item: [String : Any]) -> Bool {
        return item[tImageKey] != nil
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        self.lastContentOffset = scrollView.contentOffset
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if (self.lastContentOffset.x > scrollView.contentOffset.x) {
            if totalCount > 0
            {
                if(totalCount < GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count)
                {
                    if self.downloadingFlag == false
                    {
                        if totalCount > 9
                        {
                            DispatchQueue.main.async {
                                let attributes: UICollectionViewLayoutAttributes = self.photoThumpCollectionView.layoutAttributesForItem(at: IndexPath(row: self.totalCount - 1, section: 0))!
                                self.customView.stopAnimationg()
                                self.customView.removeFromSuperview()
                                self.customView = CustomInfiniteIndicator(frame: CGRect(x:(attributes.frame.origin.x + 50), y:(self.photoThumpCollectionView.layer.frame.height/2 - 12), width:30, height:30))
                                self.photoThumpCollectionView.addSubview(self.customView)
                                self.customView.startAnimating()
                            }
                        }
                        self.downloadingFlag = true
                        downloadImagesFromGlobalChannelImageMapping(limit: 12)
                    }
                }
            }
        }
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
                    let failedString = String(data: imageData as Data, encoding: String.Encoding.utf8)
                    let fullString  = failedString?.components(separatedBy: ",")
                    let errorString = fullString?[1].components(separatedBy: ":")
                    var orgString = errorString?[1]
                    orgString = orgString?.trimmingCharacters(in: NSCharacterSet.alphanumerics.inverted)
                    if((orgString == "USER004") || (orgString == "USER005") || (orgString == "USER006")){
                        loadInitialViewController(code: orgString!)
                    }
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
    
    func handleSwipe(gesture: UIGestureRecognizer)
    {
        if (GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0)
        {
            if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count == 0
            {
            }
            else
            {
                if totalCount > 0
                {
                    swipeFlag = true
                    self.removeOverlay()
                    fullScrenImageView.isUserInteractionEnabled = true
                    
                    if let swipeGesture = gesture as? UISwipeGestureRecognizer
                    {
                        switch swipeGesture.direction
                        {
                        case UISwipeGestureRecognizerDirection.left:
                            if(selectedItem < totalCount - 1)
                            {
                                downloadingStartedFlag = false
                                
                                if (playHandleflag == 1)
                                {
                                    playHandleflag = 0
                                    playIconInFullView.isHidden = false
                                    self.view.isUserInteractionEnabled = true
                                }
                                downloadTask?.cancel()
                                fullScrenImageView.alpha = 1.0
                                videoDurationLabel?.textColor = UIColor.white
                                
                                progressLabelDownload?.text = " ";
                                progressLabelDownload?.removeFromSuperview()
                                progressViewDownload?.removeFromSuperview()
                                
                                progressViewDownload?.isHidden=true;
                                progressLabelDownload?.isHidden=true;
                                
                                let backgroundQueue = DispatchQueue(label: "com.app.queue",
                                                                    qos: .background,
                                                                    target: nil)
                                backgroundQueue.async {
                                    self.selectedItem = self.selectedItem+1
                                    let dict = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![self.selectedItem]
                                    self.downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: self.selectedItem,gestureIdentifier:1)
                                    DispatchQueue.main.async {
                                        self.removeOverlay()
                                        self.photoThumpCollectionView.reloadData()
                                    }
                                }
                            }
                            else if(selectedItem == totalCount - 1)
                            {
                                swipeFlag = false
                                self.removeOverlay()
                            }
                            
                        case UISwipeGestureRecognizerDirection.right:
                            if(selectedItem != 0)
                            {
                                downloadingStartedFlag = false
                                
                                if (playHandleflag == 1)
                                {
                                    playHandleflag = 0
                                    playIconInFullView.isHidden = false
                                    self.view.isUserInteractionEnabled = true
                                }
                                downloadTask?.cancel()
                                fullScrenImageView.alpha = 1.0
                                videoDurationLabel?.textColor = UIColor.white
                                
                                progressLabelDownload?.text = " ";
                                progressLabelDownload?.removeFromSuperview()
                                progressViewDownload?.removeFromSuperview()
                                
                                progressViewDownload?.isHidden=true;
                                progressLabelDownload?.isHidden=true;
                                
                                let backgroundQueue = DispatchQueue(label: "com.app.queue",
                                                                    qos: .background,
                                                                    target: nil)
                                backgroundQueue.async {
                                    self.selectedItem = self.selectedItem - 1
                                    let dict = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![self.selectedItem]
                                    self.downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: self.selectedItem,gestureIdentifier: 2)
                                    DispatchQueue.main.async {
                                        self.removeOverlay()
                                        self.photoThumpCollectionView.reloadData()
                                    }
                                }
                            }
                            else if(self.selectedItem == 0)
                            {
                                swipeFlag = false
                                self.removeOverlay()
                            }
                            
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
    
    func doneButtonClickedToExit(notif2:NSNotification)
    {
        willEnterFlag = 0
        let fullScreenController = notif2.object as! MPMoviePlayerController
        
        DispatchQueue.main.async {
            fullScreenController.scalingMode = MPMovieScalingMode.aspectFit
        }
    }
    
    func initialise()
    {
        fullScreenZoomView.isUserInteractionEnabled = true
        fullScreenZoomView.isHidden = true
        fullScrenImageView.isUserInteractionEnabled = true
        playIconInFullView.isHidden = true;
        addToButton.isHidden = true
        deletButton.isHidden = true
        mediaIdSelected = 0
        
        userId = defaults.value(forKey: userLoginIdKey) as! String
        accessToken = defaults.value(forKey: userAccessTockenKey) as! String
    }
    
    @IBAction func deleteButtonAction(_ sender: Any) {
        
        if(downloadTask?.state == .running)
        {
            downloadTask?.cancel()
            downloadTask = nil
        }
        
        if (playHandleflag == 1)
        {
            playHandleflag = 0
        }
        progressLabelDownload?.text = " "
        progressLabelDownload?.removeFromSuperview()
        progressViewDownload?.removeFromSuperview()
        videoDurationLabel.textColor = UIColor.white
        fullScrenImageView.alpha = 1.0
        let alert = UIAlertController(title: "", message: "Are you sure you want to permanently delete this picture from all your channels?", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: {(
            action:UIAlertAction!) in
            self.deletedMediaId.removeAllObjects()
            self.mediaSelected.removeAllObjects()
            
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![self.selectedItem][mediaIdKey] as! String == "video"){
                self.playIconInFullView.isHidden = false
            }
            else{
                self.playIconInFullView.isHidden = true
            }
            let mediaIdChecked : String = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![self.selectedItem][mediaIdKey] as! String
            
            self.mediaIdSelected = Int(mediaIdChecked)!
            self.deletedMediaId.add(mediaIdChecked)
            self.mediaSelected.add(self.mediaIdSelected)
            
            if(self.mediaSelected.count > 0)
            {
                var channelIds : [Int] = [Int]()
                if let channel = UserDefaults.standard.value(forKey: archiveId)
                {
                    let channelIdForApi = channel as! Int
                    channelIds.append(channelIdForApi)
                    
                    let defaults = UserDefaults .standard
                    let userId = defaults.value(forKey: userLoginIdKey) as! String
                    let accessToken = defaults.value(forKey: userAccessTockenKey) as! String
                    self.showOverlay()
                    
                    self.imageUploadManger.deleteMediasByChannel(userName: userId, accessToken: accessToken, mediaIds: self.mediaSelected, channelId: channelIds as NSArray, success: { (response) -> () in
                        self.authenticationSuccessHandlerDelete(response: response)
                    }, failure: { (error, message) -> () in
                        self.authenticationFailureHandlerDelete(error: error, code: message)
                    })
                }
                else{
                    ErrorManager.sharedInstance.NoArchiveId()
                }
                channelIds.removeAll()
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: {
            (action:UIAlertAction!) in
            self.fullScrenImageView.alpha = 1.0
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![self.selectedItem][mediaTypeKey] as! String == "video"){
                self.playIconInFullView.isHidden = false
            }
            else{
                self.playIconInFullView.isHidden = true
            }
            self.progressLabelDownload?.text = " "
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func authenticationSuccessHandlerDelete(response:AnyObject?)
    {
        removeOverlay()
        self.fullScrenImageView.alpha = 1.0
        if let _ = response as? [String: AnyObject]
        {
            mediaIdSelected = 0
            mediaSelected.removeAllObjects()
            GlobalChannelToImageMapping.sharedInstance.deleteMediasFromChannel(channelId: archiveChanelId, mediaIdChkS: deletedMediaId)
            totalCount = totalCount - 1
            archiveMediaCount = archiveMediaCount - 1
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > totalCount){
                if(totalCount < 10){
                    DispatchQueue.main.async {
                        self.customView.stopAnimationg()
                        self.customView.removeFromSuperview()
                        self.customView = CustomInfiniteIndicator(frame: CGRect(x:(self.photoThumpCollectionView.layer.frame.width - 50), y:(self.photoThumpCollectionView.layer.frame.height/2 - 12), width:30, height:30))
                        self.photoThumpCollectionView.addSubview(self.customView)
                        self.customView.startAnimating()
                    }
                    downloadImagesFromGlobalChannelImageMapping(limit: 9)
                }
                else{
                    downloadImagesFromGlobalChannelImageMapping(limit: 1)
                }
            }
            
            if(selectedItem - 1 <= 0){
                selectedItem = 0
            }
            else{
                selectedItem = selectedItem - 1
            }
            
            if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0){
                if(totalCount > 0){
                    mediaIdSelected = Int( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem][mediaIdKey] as! String)!
                    deletButton.isHidden = false
                    addToButton.isHidden = false
                    let dict = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem]
                    downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: selectedItem,gestureIdentifier: 0)
                }
                else{
                    if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count <= 0){
                        mediaIdSelected = 0
                        removeOverlay()
                        addNoDataLabel()
                    }
                    else{
                        DispatchQueue.main.async {
                            self.showOverlay()
                            self.customView.stopAnimationg()
                            self.customView.removeFromSuperview()
                        }
                    }
                    DispatchQueue.main.async {
                        self.fullScrenImageView.image = UIImage()
                        self.fullScreenZoomView.image = UIImage()
                        self.deletButton.isHidden = true
                        self.addToButton.isHidden = true
                    }
                }
            }
            else{
                if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count <= 0){
                    removeOverlay()
                    addNoDataLabel()
                }
                else{
                    showOverlay()
                }
                DispatchQueue.main.async {
                    self.fullScrenImageView.image = UIImage()
                    self.fullScreenZoomView.image = UIImage()
                    self.deletButton.isHidden = true
                    self.addToButton.isHidden = true
                }
            }
            photoThumpCollectionView.reloadData()
        }
    }
    
    func authenticationFailureHandlerDelete(error: NSError?, code: String)
    {
        self.removeOverlay()
        self.fullScrenImageView.alpha = 1.0
        
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
    
    func setLabelValue(index: NSInteger)
    {
        if( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0)
        {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone!
            let fromdate = dateFormatter.date(from: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![index][mediaCreatedTimeKey] as! String)
            var dateForDisplay : String
            if(fromdate != nil){
                let dateStr = dateFormatter.string(from: NSDate() as Date)
                let currentDate = dateFormatter.date(from: dateStr)
                let sdifferentString = offset(fromDate: fromdate!, toDate: currentDate!)
                switch(sdifferentString)
                {
                case "TODAY" :
                    dateForDisplay = "   TODAY"
                    break;
                case "1d" : dateForDisplay = "  YESTERDAY"
                break;
                default :
                    let dateFormatterDisplay = DateFormatter()
                    dateFormatterDisplay.dateFormat = "   MMM d, yyyy"
                    let dateString = dateFormatterDisplay.string(from: fromdate!)
                    dateForDisplay = "  \(dateString)"
                    break;
                }
            }
            else{
                dateForDisplay = "   TODAY"
            }
            
            DispatchQueue.main.async {
                self.mediaTimeLabel.text = dateForDisplay
            }
        }
    }
    
    func years(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: fromDate, to: toDate).year ?? 0
    }
    
    func months(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.month], from: fromDate, to: toDate).month ?? 0
    }
    
    func weeks(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.weekOfYear], from: fromDate, to: fromDate).weekOfYear ?? 0
    }
    
    func days(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
    }
    
    func hours(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: fromDate, to: toDate).hour ?? 0
    }
    
    func minutes(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: fromDate, to: toDate).minute ?? 0
    }
    
    func seconds(fromDate: Date, toDate: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: fromDate, to: toDate).second ?? 0
    }
    
    func offset(fromDate: Date, toDate: Date ) -> String {
        if years(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(years(fromDate: fromDate, toDate: toDate))y"
        }
        if months(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(months(fromDate: fromDate, toDate: toDate))M"
        }
        if weeks(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(weeks(fromDate: fromDate, toDate: toDate))w"
        }
        if days(fromDate: fromDate, toDate: toDate) > 0
        {
            return "\(days(fromDate: fromDate, toDate: toDate))d"
        }
        if hours(fromDate: fromDate, toDate: toDate) > 0
        {
            return "TODAY"
        }
        if minutes(fromDate: fromDate, toDate: toDate) > 0
        {
            return "TODAY"
        }
        if seconds(fromDate: fromDate, toDate: toDate) >= 0
        {
            return "TODAY"
        }
        return ""
    }
    
    func downloadVideo(index : Int)
    {
        videoDownloadIntex = index
        
        let mediaIdForFilePath = "\( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![index][mediaIdKey]!)"
        
        let videoUrl = UrlManager.sharedInstance.getFullImageForMedia(mediaId: mediaIdForFilePath, userName: userId, accessToken: accessToken)
        let videoDownloadUrl = convertStringtoURL(url: videoUrl)
        
        let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
        let savingPath = parentPath! + "/" + mediaIdForFilePath + "video.mov"
        
        let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: savingPath)
        if fileExistFlag == true
        {
            progressViewDownload?.isHidden = true
            progressLabelDownload?.isHidden = true
            let url1 = NSURL(fileURLWithPath: savingPath)
            DispatchQueue.main.async {
                self.view.isUserInteractionEnabled = true
                self.fullScrenImageView.isUserInteractionEnabled = true
                self.playHandleflag = 1
                let player1 = AVPlayer(url: url1 as URL)
                if #available(iOS 9.0, *) {
                    self.playerViewController.delegate = self
                } else {
                }
                self.playerViewController.view.frame = CGRect(x:0, y:64, width:320, height:420)
                self.playerViewController.showsPlaybackControls = true
                player1.actionAtItemEnd = .none
                
                if #available(iOS 9.0, *) {
                    self.playerViewController.allowsPictureInPicturePlayback = true
                } else {
                }
                self.playerViewController.videoGravity = AVLayerVideoGravityResizeAspect;
                self.playerViewController.player = player1
                self.present(self.playerViewController, animated: true, completion: {
                    self.playerViewController.player!.play()
                    NotificationCenter.default.addObserver(self,
                                                           selector:#selector(PhotoViewerViewController.playerDidFinishPlaying(notif:)),
                                                           name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                           object: player1.currentItem)
                    
                })
            }
            
        }
        else{
            if downloadingStartedFlag == false
            {
                downloadingStartedFlag = true
                
                let bounds = UIScreen.main.bounds
                let widths = bounds.size.width
                let heights = bounds.size.height
                
                let downloadRequest = URLRequest(url: videoDownloadUrl as URL)
                let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
                downloadTask = session.downloadTask(with: downloadRequest)
                
                progressViewDownload?.removeFromSuperview()
                progressLabelDownload?.removeFromSuperview()
                
                progressLabelDownload?.isHidden = false
                
                videoDurationLabel?.textColor = UIColor.black
                
                progressViewDownload = UIProgressView(progressViewStyle: UIProgressViewStyle.default)
                let frame1 = CGRect(x:0, y:(heights - (BottomView.frame.size.height + photoThumpCollectionView.frame.size.height + 4)), width:widths, height:3)
                progressViewDownload?.frame = frame1
                progressViewDownload?.transform =  CGAffineTransform(scaleX: 1.0, y: 3.0)
                
                view.addSubview(progressViewDownload!)
                progressViewDownload?.isHidden = true
                
                self.playIconInFullView.isHidden = true
                
                let frame = CGRect(x:(fullScrenImageView.center.x - 100), y:(fullScrenImageView.center.y - 30), width:200, height:20)
                progressLabelDownload?.frame = frame
                view.addSubview(progressLabelDownload!)
                progressLabelDownload?.text = "Downloading ..."
                progressLabelDownload!.textAlignment = NSTextAlignment.center
                fullScrenImageView.alpha = 0.2
                downloadTask!.resume()
            }
        }
    }
    
    func playerDidFinishPlaying(notif: NSNotification) {
        self.playerViewController.removeFromParentViewController()
        self.playerViewController.dismiss(animated: true, completion: nil)
        self.fullScrenImageView.isUserInteractionEnabled = true
        self.fullScrenImageView.image = self.setOrientationForVideo()
        self.fullScreenZoomView.image = self.setOrientationForVideo()
    }
    
    func playbackStateChange(notif:NSNotification)
    {
        let moviePlayerController = notif.object as! MPMoviePlayerController
        
        switch moviePlayerController.playbackState {
        case .stopped: break
        case .playing:
            playHandleflag = 1
        case .paused:
            playHandleflag = 1
        case .interrupted: break
        case .seekingForward: break
        case .seekingBackward: break
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progressViewDownload?.isHidden = false
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        let y = Int(round(progress*100))
        videoDurationLabel?.textColor = UIColor.black
        progressLabelDownload?.text = "Downloading  \(y) %"
        progressLabelDownload!.textAlignment = NSTextAlignment.center
        progressViewDownload!.progress = progress
        if progress == 1.0
        {
            fullScrenImageView.alpha = 1.0
            self.playIconInFullView.isHidden = false
            videoDurationLabel?.textColor = UIColor.white
            progressLabelDownload?.text = " "
            progressLabelDownload?.removeFromSuperview()
            progressViewDownload?.removeFromSuperview()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let data = NSData(contentsOf: location as URL)
        if let imageData = data as NSData? {
            let failedString = String(data: imageData as Data, encoding: String.Encoding.utf8)
            if(failedString != nil)
            {
                let fullString = failedString?.components(separatedBy: ",")
                let errorString = fullString?[1].components(separatedBy: ":")
                var orgString = errorString?[1]
                orgString = orgString?.trimmingCharacters(in: NSCharacterSet.alphanumerics.inverted)
                if((orgString == "USER004") || (orgString == "USER005") || (orgString == "USER006")){
                    loadInitialViewController(code: orgString!)
                }
            }
            else{
                let mediaIdForFilePath = "\( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![videoDownloadIntex][mediaIdKey]!)"
                let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                let savingPath = parentPath! + "/" + mediaIdForFilePath + "video.mov"
                let url = NSURL(fileURLWithPath: savingPath)
                let writeFlag = imageData.write(to: url as URL, atomically: true)
                if(writeFlag){
                    videoDownloadIntex = 0
                    DispatchQueue.main.async {
                        self.downloadingStartedFlag = false
                        self.view.isUserInteractionEnabled = true
                        self.fullScrenImageView.isUserInteractionEnabled = true
                        self.playHandleflag = 1
                        self.view.isUserInteractionEnabled = true
                        self.fullScrenImageView.isUserInteractionEnabled = true
                        self.playHandleflag = 1
                        self.playerViewController.removeFromParentViewController()
                        self.playerViewController.dismiss(animated: false, completion: nil)
                        
                        let player1 = AVPlayer(url: url as URL)
                        if #available(iOS 9.0, *) {
                            self.playerViewController.delegate = self
                        } else {
                        }
                        self.playerViewController.view.frame = CGRect(x:0, y:64, width:320, height:420)
                        self.playerViewController.showsPlaybackControls = true
                        player1.actionAtItemEnd = .none
                        
                        if #available(iOS 9.0, *) {
                            self.playerViewController.allowsPictureInPicturePlayback = true
                        } else {
                        }
                        self.playerViewController.videoGravity = AVLayerVideoGravityResizeAspect;
                        self.playerViewController.player = player1
                        self.present(self.playerViewController, animated: true, completion: {
                            self.playerViewController.player!.play()
                            NotificationCenter.default.addObserver(self,
                                                                   selector:#selector(PhotoViewerViewController.playerDidFinishPlaying(notif:)),
                                                                   name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                                   object: player1.currentItem)
                        })
                    }
                }
            }
        }
    }
    
    func playerDidFinish(notif:NSNotification)
    {
        playIconInFullView.isHidden = false
        self.view.isUserInteractionEnabled = true
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    }
    
    func uploadMediaProgress(notif:NSNotification)
    {
        archiveChanelId = "\(defaults.value(forKey: archiveId) as! Int)"
        let dict = notif.object as! [String:Any]
        dictMediaId = dict[mediaIdKey] as! String
        dictProgress = dict[progressKey] as! Float
        if(GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0){
            for i in 0 ..<  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count
            {
                if(i < GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count){
                    let mediaIdFromData =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![i][mediaIdKey] as! String
                    
                    if(mediaIdFromData == dictMediaId){
                        GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![i][progressKey] = dictProgress
                    }
                    DispatchQueue.main.async {
                        self.photoThumpCollectionView.reloadData()
                    }
                }
            }
        }
    }
    
    func setFullscreenImage(notif:NSNotification)
    {
        archiveChanelId = "\(defaults.value(forKey: archiveId) as! Int)"
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict.count > 0
        {
            DispatchQueue.main.async {
                self.archiveMediaCount = self.defaults.value(forKey: ArchiveCount) as! Int
                let filteredData =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]!.filter(self.thumbExists)
                self.totalCount = filteredData.count
                self.addToButton.isHidden = false
                self.deletButton.isHidden = false
                
                let dict =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![0]
                self.downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: 0,gestureIdentifier:0)
                self.photoThumpCollectionView.reloadData()
            }
        }
    }
    
    @IBAction func didTapAddChannelButton(_ sender: Any) {
        if(downloadTask?.state == .running)
        {
            downloadTask?.cancel()
        }
        
        if (playHandleflag == 1)
        {
            playHandleflag = 0
        }
        
        progressLabelDownload?.text = " "
        progressLabelDownload?.removeFromSuperview()
        progressViewDownload?.removeFromSuperview()
        
        mediaSelected.removeAllObjects()
        addToDict.removeAll()
        if mediaIdSelected == 0
        {
            mediaIdSelected = Int( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![0][mediaIdKey] as! String)!
            addToDict.append( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![0])
        }
        else{
            addToDict.append( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![selectedItem])
        }
        
        mediaSelected.add(mediaIdSelected)
        
        mediaIdSelected = 0
        
        if let channel = UserDefaults.standard.value(forKey: "archiveId")
        {
            if(mediaSelected.count > 0)
            {
                let channelStoryboard = UIStoryboard(name:"MyChannel", bundle: nil)
                let addChannelVC = channelStoryboard.instantiateViewController(withIdentifier: AddChannelViewController.identifier) as! AddChannelViewController
                addChannelVC.mediaDetailSelected = mediaSelected
                addChannelVC.selectedChannelId = String(channel as! Int)
                addChannelVC.localMediaDict = addToDict
                addChannelVC.navigationController?.isNavigationBarHidden = true
                self.navigationController?.pushViewController(addChannelVC, animated: false)
            }
        }
        else{
            ErrorManager.sharedInstance.NoArchiveId()
        }
    }
    
    @IBAction func channelButtonClicked(_ sender: Any)
    {
        let myChannelStoryboard = UIStoryboard(name:"MyChannel" , bundle: nil)
        let myChannelVC = myChannelStoryboard.instantiateViewController(withIdentifier: MyChannelViewController.identifier)
        myChannelVC.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(myChannelVC, animated: false)
    }
    
    @IBAction func donebuttonClicked(_ sender: Any)
    {
        if(playHandleflag == 0)
        {
            let cameraViewStoryboard = UIStoryboard(name:"IPhoneCameraView" , bundle: nil)
            let iPhoneCameraViewController = cameraViewStoryboard.instantiateViewController(withIdentifier: "IPhoneCameraViewController") as! IPhoneCameraViewController
            self.navigationController?.isNavigationBarHidden = true
            self.navigationController?.pushViewController(iPhoneCameraViewController, animated: false)
        }
        else if(playHandleflag == 1)
        {
            playHandleflag = 0;
            playIconInFullView.isHidden = false
            self.view.isUserInteractionEnabled = true
        }
    }
    
    func setOrientationForVideo() -> UIImage
    {
        getCurrentOrientaion()
        var orientedImage : UIImage = UIImage()
        switch self.orientationFlag {
        case 1:
            self.fullScrenImageView.contentMode = .scaleAspectFill
            orientedImage = self.videoThumbImage;
            self.playIconInFullView.image = UIImage(named: "Circled Play")
            break;
        case 2:
            self.fullScrenImageView.contentMode = .scaleAspectFit
            orientedImage = UIImage(cgImage: self.videoThumbImage.cgImage!, scale: CGFloat(1.0),
                                    orientation: .right)
            self.playIconInFullView.image = UIImage(cgImage:  UIImage(named: "Circled Play")!.cgImage!, scale: CGFloat(1.0), orientation: .right)
            
            break;
        case 3:
            self.fullScrenImageView.contentMode = .scaleAspectFit
            orientedImage = UIImage(cgImage: self.videoThumbImage.cgImage!, scale: CGFloat(1.0),
                                    orientation: .left)
            self.playIconInFullView.image =   UIImage(cgImage:  UIImage(named: "Circled Play")!.cgImage!, scale: CGFloat(1.0), orientation: .left)
            
            break;
        default:
            break;
        }
        self.Orgimage = orientedImage
        return orientedImage
    }
    
    func downloadFullImageWhenTapThumb(imageDict: [String:Any], indexpaths : Int ,gestureIdentifier:Int) {
        DispatchQueue.main.async {
            self.removeOverlay()
        }
        var imageForMedia : UIImage = UIImage()
        if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0
        {
            mediaTypeSelected = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexpaths][mediaTypeKey] as! String
            if let fullImage = imageDict[tImageKey]
            {
                DispatchQueue.main.async {
                    self.setLabelValue(index: self.selectedItem)
                }
                if  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexpaths][mediaTypeKey] as! String == "video"
                {
                    DispatchQueue.main.async {
                        self.photoThumpCollectionView.alpha = 1.0
                        self.removeOverlay()
                        self.videoDurationLabel.isHidden = true
                        self.view.bringSubview(toFront: self.videoDurationLabel)
                        self.videoDurationLabel.text = ""
                        if let vDuration =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[self.archiveChanelId]![indexpaths][videoDurationKey]
                        {
                            self.videoDurationLabel.text = vDuration as? String
                        }
                        self.playIconInFullView.isHidden = false;
                        self.fullScrenImageView.contentMode = .scaleAspectFill
                        if(gestureIdentifier==1||gestureIdentifier==2)
                        {
                            let animation = CATransition()
                            animation.duration = 0.2;
                            animation.type = kCATransitionMoveIn;
                            if(gestureIdentifier==1)
                            {
                                animation.subtype = kCATransitionFromRight;
                            }else{
                                animation.subtype = kCATransitionFromLeft;
                            }
                            self.fullScrenImageView.layer.add(animation, forKey: "imageTransition")
                        }
                        self.videoThumbImage = fullImage as! UIImage
                        
                        self.fullScrenImageView.image = (self.setOrientationForVideo())
                        self.fullScreenZoomView.image = (self.setOrientationForVideo())
                        
                        self.fullScreenScrollView.isHidden=true;
                    }
                }
                else
                {
                    let mediaIdStr =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexpaths][mediaIdKey] as! String
                    let mediaIdForFilePath = mediaIdStr + "full"
                    let parentPath = FileManagerViewController.sharedInstance.getParentDirectoryPath().absoluteString
                    let savingPath = parentPath! + "/" + mediaIdForFilePath
                    let fileExistFlag = FileManagerViewController.sharedInstance.fileExist(mediaPath: savingPath)
                    if fileExistFlag == true{
                        let mediaImageFromFile = FileManagerViewController.sharedInstance.getImageFromFilePath(mediaPath: savingPath)
                        imageForMedia = mediaImageFromFile!
                    }
                    else{
                        DispatchQueue.main.async {
                            self.showOverlay()
                        }
                        let mediaUrl =  UrlManager.sharedInstance.getFullImageForMedia(mediaId: mediaIdStr, userName: userId, accessToken: accessToken)
                        if(mediaUrl != ""){
                            let url: NSURL = convertStringtoURL(url: mediaUrl)
                            downloadMedia(downloadURL: url, key: "ThumbImage", completion: { (result) -> Void in
                                if(result != UIImage()){
                                    let imageDataFromresult = UIImageJPEGRepresentation(result, 0.5)
                                    if imageDataFromresult != nil{
                                        let imageDataFromresultAsNsdata = (imageDataFromresult as NSData?)!
                                        let imageDataFromDefault = UIImageJPEGRepresentation(UIImage(named: "thumb12")!, 0.5)
                                        let imageDataFromDefaultAsNsdata = (imageDataFromDefault as NSData?)!
                                        if(imageDataFromresultAsNsdata.isEqual(imageDataFromDefaultAsNsdata)){
                                        }
                                        else{
                                            _ = FileManagerViewController.sharedInstance.saveImageToFilePath(mediaName: mediaIdForFilePath, mediaImage: result)
                                        }
                                        imageForMedia = result
                                    }
                                    else{
                                        imageForMedia = UIImage(named: "thumb12")!
                                    }
                                }
                                else{
                                    imageForMedia = UIImage(named: "thumb12")!
                                }
                            })
                        }
                    }
                    DispatchQueue.main.async {
                        var orientedImage = UIImage()
                        orientedImage = self.setGuiBasedOnOrientation(image: imageForMedia)
                        self.fullScrenImageView.image = orientedImage as UIImage
                        self.fullScreenZoomView.image = orientedImage as UIImage
                        self.photoThumpCollectionView.alpha = 1.0
                        self.removeOverlay()
                        if(gestureIdentifier==1||gestureIdentifier==2)
                        {
                            let animation = CATransition()
                            animation.duration = 0.2;
                            animation.type = kCATransitionMoveIn;
                            if(gestureIdentifier==1)
                            {
                                animation.subtype = kCATransitionFromRight;
                            }else{
                                animation.subtype = kCATransitionFromLeft;
                            }
                            self.fullScrenImageView.layer.add(animation, forKey: "imageTransition")
                        }
                        self.playIconInFullView.isHidden = true;
                        self.fullScreenScrollView.isHidden=false;
                        self.videoDurationLabel.isHidden = true
                    }
                }
            }
            DispatchQueue.main.async {
                self.view.bringSubview(toFront: self.photoThumpCollectionView)
                self.view.bringSubview(toFront: self.playIconInFullView)
                self.view.bringSubview(toFront: self.TopView)
                self.view.bringSubview(toFront: self.BottomView)
            }
        }
    }
    
    func setGuiBasedOnOrientation(image : UIImage) -> UIImage
    {
        self.getCurrentOrientaion()
        self.Orgimage = image
        var orientedImage = UIImage()
        
        switch self.orientationFlag
        {
        case 1:
            //portrait
            if self.Orgimage!.size.width > self.Orgimage!.size.height
            {
                self.fullScrenImageView.contentMode = .scaleAspectFit
            }
            else{
                self.fullScrenImageView.contentMode = .scaleAspectFill
            }
            orientedImage = self.Orgimage!
            break
            
        case 2:
            //landscape left
            if self.Orgimage!.size.width > self.Orgimage!.size.height
            {
                self.fullScrenImageView.contentMode = .scaleAspectFit
                self.fullScrenImageView.startAnimating()
                orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                        orientation: .right)
            }
            else{
                self.fullScrenImageView.contentMode = .scaleAspectFit
                orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                        orientation: .down)
            }
            break
        case 3:
            //landscape right
            if self.Orgimage!.size.width > self.Orgimage!.size.height
            {
                self.fullScrenImageView.contentMode = .scaleAspectFit
                orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                        orientation: .left)
            }
            else{
                self.fullScrenImageView.contentMode = .scaleAspectFit
                orientedImage = UIImage(cgImage: self.Orgimage!.cgImage!, scale: CGFloat(1.0),
                                        orientation: .up)
            }
            break
        default:
            break
        }
        return orientedImage
    }
}

//PRAGMA MARK:- Collection View Delegates
extension PhotoViewerViewController:UICollectionViewDelegate,UICollectionViewDelegateFlowLayout, UICollectionViewDataSource
{
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return totalCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoThumbCollectionViewCell", for: indexPath as IndexPath) as! PhotoThumbCollectionViewCell
        
        videoDurationLabel?.textColor = UIColor.white
        
        cell.layer.shouldRasterize = true
        cell.layer.rasterizationScale = UIScreen.main.scale
        
        if(( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > indexPath.row) && ( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > 0))
        {
            if(indexPath.row == selectedItem){
                if(swipeFlag){
                    photoThumpCollectionView.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.centeredHorizontally, animated: false)
                }
                cell.layer.borderWidth = 2;
                cell.layer.borderColor = UIColor(red: 44.0/255.0, green: 214.0/255.0, blue: 229.0/255.0, alpha: 0.7).cgColor
            }
            else{
                cell.layer.borderWidth = 0;
                cell.layer.borderColor = UIColor.clear.cgColor;
            }
            var dict =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row]
            
            if let thumpImage = dict[tImageKey]
            {
                
                if  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row][mediaTypeKey] as! String == "video"
                {
                    cell.playIcon.isHidden = false
                }
                else
                {
                    cell.playIcon.isHidden = true
                }
                cell.progressView.isHidden = true
                
                cell.thumbImageView.image = (thumpImage as! UIImage)
                
                let progress = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row][progressKey] as! Float
                if(progress == 3.0 || progress == 3)
                {
                    cell.progressView.isHidden = true
                    cell.cloudIcon.isHidden = false
                    cell.reloadMedia.isHidden = true
                }
                else if(progress == 2.0 || progress == 2 || progress == 4.0 || progress == 4){
                    cell.progressView.isHidden = true
                    cell.cloudIcon.isHidden = true
                    cell.reloadMedia.isHidden = true
                }
                else{
                    cell.progressView.progress = Float(progress)
                    cell.progressView.isHidden = false
                    cell.cloudIcon.isHidden = true
                    cell.reloadMedia.isHidden = true
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoThumbCollectionViewCell", for: indexPath as IndexPath) as! PhotoThumbCollectionViewCell
        cell.rotate360Degrees(duration: 2.0)
        
        if(self.selectedItem != indexPath.row){
            swipeFlag = false
            downloadingStartedFlag = false
            self.selectedItem = indexPath.row
            if (playHandleflag == 1)
            {
                playHandleflag = 0
            }
            progressLabelDownload?.text = " "
            progressLabelDownload?.removeFromSuperview()
            progressViewDownload?.removeFromSuperview()
            
            self.photoThumpCollectionView.reloadData()
            
            if GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > indexPath.row
            {
                if(downloadTask?.state == .running)
                {
                    downloadTask?.cancel()
                    fullScrenImageView.alpha = 1.0
                    videoDurationLabel?.textColor = UIColor.white
                    progressLabelDownload?.text = " "
                    progressLabelDownload?.removeFromSuperview()
                    progressViewDownload?.removeFromSuperview()
                    
                }
                
                let dict =  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row]
                
                let backgroundQueue = DispatchQueue(label: "com.app.queue",
                                                    qos: .background,
                                                    target: nil)
                backgroundQueue.async {
                    self.downloadFullImageWhenTapThumb(imageDict: dict, indexpaths: indexPath.row ,gestureIdentifier:0)
                }
                
            }
            
            self.fullScrenImageView.alpha = 1.0
        }
        
//        if  GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]!.count > indexPath.row
//        {
//            self.mediaIdSelected = Int( GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row][mediaIdKey] as! String)!
//            
//            let progres = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row][progressKey] as! Float
//            if(progres == 2.0 || progres == 2){
//                uploadFailedImagesOnClick(mediaIDClick: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row][mediaIdKey] as! String)
//            }
//            else if(progres == 4.0 || progres == 4){
//                MappingFailedImagesOnClick(mediaIDClick: GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[archiveChanelId]![indexPath.row][mediaIdKey] as! String)
//            }
//            
//            
//        }
    }
    
    func uploadFailedImagesOnClick(mediaIDClick: String)
    {
        if(GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict.count > 0){
            for j in 0 ..< GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict.count
            {
                if j < GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict.count
                {
                    let mediaIdChk = GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict[j][mediaIdKey] as! String
                    if mediaIdChk == mediaIDClick
                    {
                        let thumbToUpload = GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict[j][tImageURLKey] as! String
                        let fullToUpload = GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict[j][fImageURLKey] as! String
                        let mediaTypeToUpload = GlobalChannelToImageMapping.sharedInstance.mediaUploadFailedDict[j][mediaTypeKey] as! String
                        let uploadMediaObj = uploadMediaToGCS()
                        uploadMediaObj.setGlobalValuesForUploading(MediaIDGlob: mediaIdChk, thumbURL: thumbToUpload, fullURL: fullToUpload, mediaType: mediaTypeToUpload)
                    }
                }
            }
        }
    }
    
    func MappingFailedImagesOnClick(mediaIDClick: String)
    {
        let uploadMediaObj = uploadMediaToGCS()
        uploadMediaObj.setGlobalValuesForMapping(MediaIDGlob: mediaIDClick)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(1, 1, 1, 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath as IndexPath)
        if cell?.isSelected == false{
            cell?.layer.borderColor = UIColor.clear.cgColor
        }
    }
}
