
import UIKit
class ChannelSharedCell: UITableViewCell {
    
    static let identifier = "ChannelSharedCell"
    @IBOutlet weak var channelNameLabel: UILabel!
    
    @IBOutlet weak var channelProfileImage: UIImageView!
    
    @IBOutlet weak var detailLabel: UILabel!
    
    @IBOutlet weak var latestImage: UIImageView!
    
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var currentUpdationImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        countLabel.layer.cornerRadius = 5
        countLabel.layer.masksToBounds = true
        channelProfileImage.layer.cornerRadius = channelProfileImage.frame.size.width/2
        channelProfileImage.layer.masksToBounds = true
    }
}
