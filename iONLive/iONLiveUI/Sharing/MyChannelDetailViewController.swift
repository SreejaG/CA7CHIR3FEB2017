
import UIKit

class MyChannelDetailViewController: UITabBarController {
    
    static let identifier = "MyChannelDetailViewController"
    
    var totalMediaCount: Int = Int()
    var channelId:String!
    var channelName:String!
    
    var allItemTitleText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let index =  UserDefaults.standard.value(forKey: "tabToAppear")
        self.selectedIndex = index as! Int
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
    }
}
