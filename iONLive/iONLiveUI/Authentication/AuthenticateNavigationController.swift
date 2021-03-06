
import UIKit

class AuthenticateNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        customise()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func customise()
    {
        if #available(iOS 8.2, *) {
            UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 18, weight: UIFontWeightRegular),NSForegroundColorAttributeName: UIColor(red: 44.0/255, green: 214.0/255, blue: 229.0/255, alpha: 1.0)]
        }
        else if #available(iOS 8.1, *)
        {
            UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont(name: "HelveticaNeue-Thin", size: 18)!,NSForegroundColorAttributeName: UIColor(red: 44.0/255, green: 214.0/255, blue: 229.0/255, alpha: 1.0)]
        }
        else
        {
            UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont(name: "HelveticaNeue-Regular", size: 18)!,NSForegroundColorAttributeName: UIColor(red: 44.0/255, green: 214.0/255, blue: 229.0/255, alpha: 1.0)]
        }
        
        UINavigationBar.appearance().tintColor = UIColor(red: 44.0/255, green: 214.0/255, blue: 229.0/255, alpha: 1.0)
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        UINavigationBar.appearance().shadowImage = UIImage()
    }
}
