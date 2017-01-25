
import UIKit

class SettingsViewController: UIViewController, UIGestureRecognizerDelegate ,toggleCellDelegate {
    
    let optionTitle = "optionTitle"
    let optionType = "optionType"
    let accessryText = "accessryText"
    
    let toggleCell = "toggleCell"
    let normalCell = "normalCell"
    
    var cameraOptions = [[String:String]]()
    var accountOptions = [[String:String]]()
    var supportOptions = [[String:String]]()
    
    var dataSource:[[[String:String]]]?
    
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var backbutton: UIButton!
    @IBOutlet weak var settingsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraOptions = [[optionTitle:"Upload to wifi", optionType : toggleCell, accessryText:""],[optionTitle:"Vivid Mode", optionType : toggleCell, accessryText:""],[optionTitle:"Time Lapse", optionType : normalCell, accessryText:""],[optionTitle:"Media Capture Quality", optionType : normalCell, accessryText:"HD"],[optionTitle:"Camera LED", optionType : toggleCell, accessryText: ""],[optionTitle:"Program Camera Button", optionType : normalCell, accessryText: ""],
                         [optionTitle:"Software Updates", optionType : normalCell, accessryText: ""],[optionTitle:"Save to Camera Roll", optionType : toggleCell, accessryText: ""],[optionTitle:"Get Snapcam! ", optionType : normalCell, accessryText: ""],[optionTitle:"Live Stream Resolution", optionType : normalCell, accessryText:"720p"]]
        
        accountOptions = [[optionTitle:"Edit profile", optionType : normalCell, accessryText:""],[optionTitle:"Delete Archived Media", optionType : normalCell, accessryText:"Never"],[optionTitle:"Connect Accounts", optionType : normalCell, accessryText:""]]
        
        supportOptions = [[optionTitle:"Help Center ", optionType : normalCell, accessryText:""],[optionTitle:"Report a Problem", optionType : normalCell, accessryText:""], [optionTitle:"App Info ", optionType : normalCell, accessryText:""]]
        
        dataSource = [cameraOptions,accountOptions,supportOptions]
        
        if(UserDefaults.standard.value(forKey: "liveResolution") != nil)
        {
            let value = UserDefaults.standard.value(forKey: "liveResolution") as! String
            dataSource![0][9] = [optionTitle:"Live Stream Resolution", optionType : normalCell, accessryText:value]
        }
        else{
            dataSource![0][9] = [optionTitle:"Live Stream Resolution", optionType : normalCell, accessryText:"720p"]
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.settingsTableView.backgroundView = nil
        self.settingsTableView.backgroundColor = UIColor(red: 249.0/255, green: 249.0/255, blue: 249.0/255, alpha: 1)
        backbutton.isHidden = true
        reloadTableData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
    }
    
    func reloadTableData(){
        if(UserDefaults.standard.value(forKey: "archiveMediaDeletion") != nil)
        {
            let archiveConstant = UserDefaults.standard.value(forKey: "archiveMediaDeletion") as! String
            dataSource![1][1] = [optionTitle:"Delete Archived Media", optionType : normalCell, accessryText:archiveConstant]
        }
        else{
            dataSource![1][1] = [optionTitle:"Delete Archived Media", optionType : normalCell, accessryText:"Never"]
        }
        
        if(UserDefaults.standard.value(forKey: "liveResolution") != nil)
        {
            let liveResolutionConstant = UserDefaults.standard.value(forKey: "liveResolution") as! String
            dataSource![0][9] = [optionTitle:"Live Stream Resolution", optionType : normalCell, accessryText:liveResolutionConstant]
        }
        else{
            dataSource![0][9] = [optionTitle:"Live Stream Resolution", optionType : normalCell, accessryText:"720p"]
        }
        
        settingsTableView.reloadData()
    }
    
    @IBAction func doneClicked(_ sender: Any) {
        let cameraViewStoryboard = UIStoryboard(name:"IPhoneCameraView" , bundle: nil)
        let iPhoneCameraViewController = cameraViewStoryboard.instantiateViewController(withIdentifier: "IPhoneCameraViewController") as! IPhoneCameraViewController
        self.navigationController?.isNavigationBarHidden = true
        self.navigationController?.pushViewController(iPhoneCameraViewController, animated: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        doneButton.isHidden = false
        backbutton.isHidden = true
        settingsTableView.reloadData()
        self.settingsTableView.isUserInteractionEnabled = true
    }
    
    // #pragma mark - toggleCellDelegate
    func didChangeSwitchState(toggleCell:SettingsToggleTableViewCell , isOn: Bool) {
        let indexPath = self.settingsTableView.indexPath(for: toggleCell)
        
        switch indexPath!.row {
        case 7:
            if isOn
            {
                UserDefaults.standard.set(1, forKey: "SaveToCameraRoll")
            }
            else{
                UserDefaults.standard.set(0, forKey: "SaveToCameraRoll")
            }
            break;
        case 4:
            if isOn
            {
                UserDefaults.standard.set(1, forKey: "flashMode")
            }
            else{
                UserDefaults.standard.set(0, forKey: "flashMode")
            }
            break;
        default:
            break;
        }
    }
}

extension SettingsViewController:UITableViewDelegate,UITableViewDataSource
{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 45.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let  headerCell = tableView.dequeueReusableCell(withIdentifier: "SettingsHeaderTableViewCell") as! SettingsHeaderTableViewCell
        headerCell.isUserInteractionEnabled = false
        switch (section) {
        case 0:
            headerCell.headerTitle.text = "CAMERA"
        case 1:
            headerCell.headerTitle.text = "ACCOUNT"
        case 2:
            headerCell.headerTitle.text = "SUPPORT"
        default:
            headerCell.headerTitle.text = ""
        }
        return headerCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch section
        {
        case 0:
            return dataSource != nil ? (dataSource?[0].count)! :0
            
        case 1:
            return dataSource != nil ? (dataSource?[1].count)! :0
            
        case 2:
            return dataSource != nil ? (dataSource?[2].count)! :0
            
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        var cellDataSource:[String:String]?
        if let dataSource = dataSource
        {
            if dataSource.count > indexPath.section
            {
                if dataSource[indexPath.section].count > indexPath.row
                {
                    cellDataSource = dataSource[indexPath.section][indexPath.row]
                }
            }
        }
        
        if let cellDataSource = cellDataSource
        {
            if cellDataSource[optionType] == toggleCell
            {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsToggleTableViewCell", for:indexPath) as! SettingsToggleTableViewCell
                cell.titlelabel.text = cellDataSource[optionTitle]
                cell.backgroundColor = UIColor.clear
                cell.isUserInteractionEnabled = true
                cell.selectionStyle = .none
//                if indexPath.row == 4 || indexPath.row == 7
//                {
//                    cell.isUserInteractionEnabled = true
//                    cell.backgroundColor = UIColor.clear
//                    cell.titlelabel.textColor = UIColor.black
//                    cell.titlelabel.alpha = 0.6
//                    var switchStatus : Int = Int()
//                    if indexPath.row == 4
//                    {
//                        switchStatus = UserDefaults.standard.integer(forKey: "flashMode")
//                    }
//                    else if indexPath.row == 7{
//                        switchStatus =  UserDefaults.standard.integer(forKey: "SaveToCameraRoll")
//                    }
//                    if switchStatus == 0
//                    {
//                        cell.toggleCellSwitch.setOn(false, animated: false)
//                    }
//                    else{
//                        cell.toggleCellSwitch.setOn(true, animated: false)
//                    }
//                }
//                else{
                    cell.isUserInteractionEnabled = false
                    cell.titlelabel.textColor = UIColor.lightGray
                    cell.titlelabel.alpha = 1.0
//                }
                cell.cellDelegate = self
                return cell
            }
            else
            {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell", for:indexPath) as! SettingsTableViewCell
                cell.titleLabel.text = cellDataSource[optionTitle]
                cell.accessryLabel.text = cellDataSource[accessryText]
                cell.backgroundColor = UIColor.clear
                
                if(((indexPath.section == 1) && (indexPath.row == 0)) || ((indexPath.section == 0) && (indexPath.row == 9)) /*|| ((indexPath.section == 2) && (indexPath.row == 1))  || ((indexPath.section == 1) && (indexPath.row == 1))  || ((indexPath.section == 2) && (indexPath.row == 2)) */)
                {
                    cell.titleLabel.textColor = UIColor.black
                    cell.accessryLabel.textColor = UIColor.black
                    cell.titleLabel.alpha = 0.6
                    cell.accessryLabel.alpha = 0.6
                    cell.isUserInteractionEnabled = true
                }
                else{
                    cell.isUserInteractionEnabled = false
                    cell.titleLabel.textColor = UIColor.lightGray
                    cell.accessryLabel.textColor = UIColor.lightGray
                    cell.titleLabel.alpha = 1.0
                    cell.accessryLabel.alpha = 1.0
                }
                return cell
            }
        }
        else
        {
            return UITableViewCell()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if let dataSource = dataSource
        {
            return dataSource.count
        }
        else
        {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: false)
        switch indexPath.section
        {
        case 0:
            switch indexPath.row
            {
            case 2:
                //   loadTimeLapseOptionsView()
                break
            case 5:
                //    loadProgramCameraButtonView()
                break
            case 9:
                loadLiveStreamView()
                break
            default:
                break
            }
        case 1:
            switch indexPath.row
            {
            case 0:
                loadEditProfileView()
                break
            case 1:
//                loadDeleteMediaOptionsView()
                break
            case 2:
                //   loadConnectAccountView()
                break
            default:
                break
            }
        case 2:
            switch indexPath.row
            {
            case 0:
                break
            case 1:
//                loadReportProblemView()
                break
            case 2:
//                loadAppInfoView()
                break
            default:
                break
            }
            
        default:
            break
        }
    }
    func updateSwitchAtIndexPath(toggleSwitch: UISwitch)
    {
    }
    
    func loadReportProblemView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let reportVC = storyBoard.instantiateViewController(withIdentifier: ReportAProblemViewController.identifier) as! ReportAProblemViewController
        self.navigationController?.pushViewController(reportVC, animated: true)
    }
    
    func loadAppInfoView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let reportVC = storyBoard.instantiateViewController(withIdentifier: AppInfoViewController.identifier) as! AppInfoViewController
        self.navigationController?.pushViewController(reportVC, animated: true)
    }
    
    func loadEditProfileView()
    {
        let storyBoard = UIStoryboard.init(name:"EditProfile", bundle: nil)
        let editProfileVC = storyBoard.instantiateViewController(withIdentifier: EditProfileViewController.identifier) as! EditProfileViewController
        self.navigationController?.pushViewController(editProfileVC, animated: true)
    }
    
    func loadTimeLapseOptionsView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let timeLapseVC = storyBoard.instantiateViewController(withIdentifier: TimeLapseSettingsViewController.identifier) as! TimeLapseSettingsViewController
        self.navigationController?.pushViewController(timeLapseVC, animated: true)
    }
    
    func loadDeleteMediaOptionsView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let deleteMediaOptionsVC = storyBoard.instantiateViewController(withIdentifier: DeleteMediaSettingsViewController.identifier) as! DeleteMediaSettingsViewController
        self.navigationController?.pushViewController(deleteMediaOptionsVC, animated: true)
    }
    
    func loadConnectAccountView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let connectAccountVC = storyBoard.instantiateViewController(withIdentifier: ConnectAccountViewController.identifier) as! ConnectAccountViewController
        self.navigationController?.pushViewController(connectAccountVC, animated: true)
    }
    
    func loadProgramCameraButtonView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let connectAccountVC = storyBoard.instantiateViewController(withIdentifier: ProgramCameraButtonViewController.identifier) as! ProgramCameraButtonViewController
        self.navigationController?.pushViewController(connectAccountVC, animated: true)
    }
    
    func loadLiveStreamView()
    {
        let storyBoard = UIStoryboard.init(name:"Settings", bundle: nil)
        let LiveStreamVC = storyBoard.instantiateViewController(withIdentifier: ResolutionSelectionViewController.identifier) as! ResolutionSelectionViewController
        self.navigationController?.pushViewController(LiveStreamVC, animated: true)
    }
}

