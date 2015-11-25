//
//  StreamsListViewController.swift
//  iON_Live
//
//  Created by Gadgeon on 11/18/15.
//  Copyright © 2015 Gadgeon. All rights reserved.
//

import UIKit

class StreamsListViewController: UIViewController,UITableViewDataSource,UITableViewDelegate{
    
    static let identifier = "StreamsListViewController"
    
    var loadingOverlay: UIView?
    
    @IBOutlet weak var liveStreamListTableView: UITableView!
    let livestreamingManager = LiveStreamingManager()
    let requestManager = RequestManager()
    
    var dataSource:[String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
         self.title = "STREAMS"
        getAllLiveStreams()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //PRAGMA MARK-: TableView dataSource and Delegates
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
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
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell : UITableViewCell?
        cell = tableView.dequeueReusableCellWithIdentifier("CELL")
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "CELL")
        }
        cell?.accessoryType = .DisclosureIndicator
        if let dataSource = dataSource
        {
            if dataSource.count > indexPath.row
            {
                cell!.textLabel!.text = dataSource[indexPath.row]
            }
        }
        return cell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("You selected cell #\(indexPath.row)!")
    }
    
    
    func getAllLiveStreams()
    {
        let userDefault = NSUserDefaults.standardUserDefaults()
        let loginId = userDefault.objectForKey(userLoginIdKey)
        let accessTocken = userDefault.objectForKey(userAccessTockenKey)
        
        if let loginId = loginId, let accessTocken = accessTocken
        {
            showOverlay()
            livestreamingManager.getAllLiveStreams(loginId:loginId as! String , accesstocken:accessTocken as! String ,success: { (response) -> () in
                
                self.removeOverlay()
                if let json = response as? [String: AnyObject]
                {
                    print("success = \(json["liveStreams"])")
                    self.dataSource = json["liveStreams"] as? [String]
                    self.liveStreamListTableView.reloadData()
                }
                else
                {
                    ErrorManager.sharedInstance.inValidResponseError()
                }
                
                }, failure: { (error, message) -> () in
                    
                    self.removeOverlay()
                    print("message = \(message)")
                    
                    if !self.requestManager.validConnection() {
                        ErrorManager.sharedInstance.noNetworkConnection()
                    } else {
                        // ErrorManager.sharedInstance.loginError()
                    }
                    return
            })
        }
        else
        {
            ErrorManager.sharedInstance.authenticationIssue()
        }
    }
    
    
    //Loading Overlay Methods
    func showOverlay()
    {
        if self.loadingOverlay != nil{
            self.loadingOverlay?.removeFromSuperview()
            self.loadingOverlay = nil
        }
        
        let loadingOverlayController:IONLLoadingView=IONLLoadingView(nibName:"IONLLoadingOverlay", bundle: nil)
        loadingOverlayController.view.frame = self.view.bounds
        loadingOverlayController.startLoading()
        self.loadingOverlay = loadingOverlayController.view
        self.navigationController?.view.addSubview(self.loadingOverlay!)
    }
    
    func removeOverlay(){
        self.loadingOverlay?.removeFromSuperview()
    }
}
