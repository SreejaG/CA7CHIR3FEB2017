//
//  ConnectAccountViewController.swift
//  iONLive
//
//  Created by Gadgeon on 12/28/15.
//  Copyright © 2015 Gadgeon. All rights reserved.
//

import UIKit

class ConnectAccountViewController: UIViewController {
    
    static let identifier = "ConnectAccountViewController"
    @IBOutlet weak var accountOptionsTableView: UITableView!
    
    var dataSource = ["Facebook","Twitter","Instagram"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    @IBAction func didTapBackButton(sender: AnyObject)
    {
        self.navigationController?.popViewControllerAnimated(true)
    }
}

extension ConnectAccountViewController: UITableViewDelegate
{
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        return 40.0
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let  headerCell = tableView.dequeueReusableCellWithIdentifier(ConnectAccountOptionsHeaderCell.identifier) as! ConnectAccountOptionsHeaderCell
        headerCell.topBorder.hidden = false
        headerCell.bottomBorder.hidden = false
        
        switch section
        {
        case 0:
            headerCell.topBorder.hidden = true
            headerCell.headerTitle.text = ""
            break
        case 1:
            headerCell.bottomBorder.hidden = true
            headerCell.headerTitle.text = ""
            break
        default:
            break
        }
        return headerCell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return 44.0
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        return 0.01   // to avoid extra blank lines
    }
}


extension ConnectAccountViewController:UITableViewDataSource
{
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if section == 0
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
        if dataSource.count > indexPath.row
        {
            let cell = tableView.dequeueReusableCellWithIdentifier(ConnectAccountOptionsCell.identifier, forIndexPath:indexPath) as! ConnectAccountOptionsCell
            cell.accountOptionsLabel.text = dataSource[indexPath.row]
            cell.selectionStyle = .None
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
    }
}
