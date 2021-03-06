
import UIKit

class MyChannelNotificationCell: UITableViewCell {
    
    static let identifier = "MyChannelNotificationCell"
    
    @IBOutlet var NotificationSenderImageView: UIImageView!
    @IBOutlet var notificationText: UILabel!
    @IBOutlet var NotificationImage: UIImageView!
    @IBOutlet var notifcationTextFullscreen: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        notificationText.numberOfLines = 0
        notificationText.lineBreakMode = .byWordWrapping
        NotificationSenderImageView.layer.cornerRadius = NotificationSenderImageView.frame.size.width/2
        NotificationSenderImageView.layer.masksToBounds = true
        notifcationTextFullscreen.numberOfLines = 0
        notifcationTextFullscreen.lineBreakMode = .byWordWrapping
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
