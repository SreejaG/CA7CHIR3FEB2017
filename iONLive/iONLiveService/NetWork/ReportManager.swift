
import UIKit
import Foundation

class ReportManager: NSObject {
    
    class var sharedInstance: ReportManager
    {
        struct Singleton
        {
            static let instance = ReportManager()
        }
        return Singleton.instance
    }
    
    //Method to report a probelm, success and failure block
    func reportAProblem(userName: String, accessToken: String,problemTitle: String, probelmDesc: String, success: ((_ response: AnyObject?)->())?, failure: ((_ error: NSError?, _ code: String)->())?)
    {
        let requestManager = RequestManager.sharedInstance
        requestManager.httpManager().post(UrlManager.sharedInstance.reportProblemAPIUrl(), parameters: ["userName": userName, "access_token": accessToken, "problemTitle": problemTitle, "problemDetail": probelmDesc], success: { (operation, response) -> Void in
            
            if let responseObject = response as? [String:AnyObject]
            {
                success?(responseObject as AnyObject?)
            }
            else
            {
                //The response did not match the form we expected, error/fail
                failure?(NSError(domain: "Response error", code: 1, userInfo: nil), "ResponseInvalid")
            }
            
        }, failure: { (operation, error) -> Void in
            
            var failureErrorCode:String = ""
            //get the error code from API if any
            if let errorCode = requestManager.getFailureErrorCodeFromResponse(error: error as NSError?)
            {
                failureErrorCode = errorCode
            }
            //The credentials were wrong or the network call failed
            failure?(error as NSError?, failureErrorCode)
        })
    }
}
