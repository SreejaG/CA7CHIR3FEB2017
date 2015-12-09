//
//  StreamsListViewController.swift
//  iON_Live
//
//  Created by Gadgeon on 11/18/15.
//  Copyright © 2015 Gadgeon. All rights reserved.
//

import UIKit

class StreamsListViewController: UIViewController{
    
    let streamTockenKey = "streamToken"
    let imageKey = "image"
    let typeKey = "type"
    let imageType = "imageType"
    static let identifier = "StreamsListViewController"
    
    
    //var loadingOverlay: UIView?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    let livestreamingManager = LiveStreamingManager()
    let requestManager = RequestManager()
    var dataSource:[[String:String]]?
    
    //for temp image along with streams and stream thumbanes
    var dummyImagesArray:[String] = ["thumb1","thumb2","thumb3","thumb4","thumb5","thumb6" , "thumb7","thumb8","thumb9","thumb10","thumb11","thumb12"]
    
    @IBOutlet weak var streamListCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.bringSubviewToFront(activityIndicator)
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true)
        self.navigationController?.navigationBarHidden = true
        activityIndicator.hidden = true
        let dummyImageListingDataSource = [[imageKey:dummyImagesArray[0],typeKey:imageType],[imageKey:dummyImagesArray[1],typeKey:imageType],[imageKey:dummyImagesArray[2],typeKey:imageType],[imageKey:dummyImagesArray[3],typeKey:imageType],[imageKey:dummyImagesArray[4],typeKey:imageType],[imageKey:dummyImagesArray[5],typeKey:imageType],[imageKey:dummyImagesArray[6],typeKey:imageType],[imageKey:dummyImagesArray[7],typeKey:imageType],[imageKey:dummyImagesArray[8],typeKey:imageType],[imageKey:dummyImagesArray[9],typeKey:imageType],[imageKey:dummyImagesArray[10],typeKey:imageType],[imageKey:dummyImagesArray[11],typeKey:imageType]]
        
        self.tabBarItem.selectedImage = UIImage(named:"all_media_blue")?.imageWithRenderingMode(.AlwaysOriginal)
        
        self.dataSource = dummyImageListingDataSource
        getAllLiveStreams()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //    override func viewWillDisappear(animated: Bool) {
    //
    //        if let viewControllers = self.navigationController?.viewControllers as [UIViewController]! {
    //
    //            if viewControllers.contains(self) == false{
    //
    //                let vc:MovieViewController = self.navigationController?.topViewController as! MovieViewController
    //
    //                vc.initialiseDecoder()
    //            }
    //        }
    //    }
    func loadLiveStreamView(streamTocken:String)
    {
        let vc = MovieViewController.movieViewControllerWithContentPath("rtsp://104.197.159.157:1935/live/\(streamTocken)", parameters: nil , liveVideo: false) as! UIViewController
        
        self.presentViewController(vc, animated: true) { () -> Void in
            
        }
    }
    
    //PRAGMA MARK:- API Handlers
    func getAllLiveStreams()
    {
        let userDefault = NSUserDefaults.standardUserDefaults()
        let loginId = userDefault.objectForKey(userLoginIdKey)
        let accessTocken = userDefault.objectForKey(userAccessTockenKey)
        
        if let loginId = loginId, let accessTocken = accessTocken
        {
            activityIndicator.hidden = false
            //showOverlay()
            livestreamingManager.getAllLiveStreams(loginId:loginId as! String , accesstocken:accessTocken as! String ,success: { (response) -> () in
                self.getAllStreamSuccessHandler(response)
                }, failure: { (error, message) -> () in
                    self.getAllStreamFailureHandler(error, message: message)
                    return
            })
        }
        else
        {
            ErrorManager.sharedInstance.authenticationIssue()
        }
    }
    
    
    func getAllStreamSuccessHandler(response:AnyObject?)
    {
        activityIndicator.hidden = true
        //self.removeOverlay()
        if let json = response as? [String: AnyObject]
        {
            print("success = \(json["liveStreams"])")
            let liveStreamDataSource = json["liveStreams"] as? [[String:String]]
//            if liveStreamDataSource?.count == 0
//            {
//                ErrorManager.sharedInstance.alert("No Live Streams", message: "Sorry! you don't have any live streams")
//            }
            
            self.createDataSource(liveStreamDataSource)
            self.streamListCollectionView.reloadData()
        }
        else
        {
            ErrorManager.sharedInstance.inValidResponseError()
        }
    }
    
    func getAllStreamFailureHandler(error: NSError?, message: String)
    {
        activityIndicator.hidden = true
        //self.removeOverlay()
        print("message = \(message)")
        
        if !self.requestManager.validConnection() {
            ErrorManager.sharedInstance.noNetworkConnection()
        }
        else if message.isEmpty == false {
            ErrorManager.sharedInstance.mapErorMessageToErrorCode(message)
        }
        else{
            ErrorManager.sharedInstance.liveStreamFetchingError()
        }
    }
    
    
    //Loading Overlay Methods
//    func showOverlay()
//    {
//        if self.loadingOverlay != nil{
//            self.loadingOverlay?.removeFromSuperview()
//            self.loadingOverlay = nil
//        }
//        
//        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
//        loadingOverlayController.view.frame = self.view.bounds
//        loadingOverlayController.startLoading()
//        self.loadingOverlay = loadingOverlayController.view
//        self.navigationController?.view.addSubview(self.loadingOverlay!)
//    }
//    
//    func removeOverlay(){
//        self.loadingOverlay?.removeFromSuperview()
//    }
    
    @IBAction func customBackButtonClicked(sender: AnyObject)
    {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent;
    }
    
    //PRAGMA MARK:- dummy image helper functions
    
    func createDataSource(liveStreamDataSource:[[String:String]]?)
    {
        if let liveStreams = liveStreamDataSource
        {
            for eachLiveStream in liveStreams
            {
                dataSource?.insert(eachLiveStream, atIndex:0)
            }
        }
    }
}

    
extension StreamsListViewController:UICollectionViewDataSource,UICollectionViewDelegateFlowLayout
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        if let dataSource = dataSource
        {
            return dataSource.count
        }
        else
        {
            return 0
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("StreamListCollectionViewCell", forIndexPath: indexPath) as! StreamListCollectionViewCell
        
        //cell for live streams
        
        if let dataSource = dataSource
        {
            if dataSource.count > indexPath.row
            {
                //image stream cell
                var dict = dataSource[indexPath.row]
                if let streamType = dict[typeKey]
                {
                    if streamType == imageType
                    {
                        cell.liveStatusLabel.hidden = true
                        cell.liveNowIcon.hidden = true
                        if let imageName = dict[imageKey]
                        {
                            cell.streamThumbnaleImageView.image = UIImage(named: imageName)
                        }
                    }
                }
                else   //live stream cell
                {
                    cell.liveStatusLabel.hidden = false
                    cell.liveNowIcon.hidden = false
                    
                    var imageIndexPath = 0
                    if dummyImagesArray.count > indexPath.row
                    {
                        imageIndexPath = indexPath.row
                    }
                    cell.streamThumbnaleImageView.image = UIImage(named: dummyImagesArray[imageIndexPath])
                }
            }
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        if let dataSource = dataSource
        {
            if dataSource.count > indexPath.row
            {
                var dict = dataSource[indexPath.row]
                if let _ = dict[typeKey]
                {
                    //not clickable as of now
                }
                else
                {
                    //live stream click
                    if let streamTocken = dict[streamTockenKey]
                    {
                        self.loadLiveStreamView(streamTocken)
                    }
                    else
                    {
                        ErrorManager.sharedInstance.alert("Streaming error", message: "Not a valid stream tocken")
                    }
                }
            }
        }
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(1, 1, 0, 1)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
         return CGSizeMake((UIScreen.mainScreen().bounds.width/3)-2, 100)
    }
}

