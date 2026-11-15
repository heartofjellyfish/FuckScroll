import UIKit

/// Inputs to the system shield, plus the composited canvas sampled on iPhone.
enum BreakScreen {
    static let eye = "DoorEye"
    static let background = UIColor.black
    static let renderedBackground = UIColor(red: 31.0/255, green: 31.0/255, blue: 31.0/255, alpha: 1)
    static let titleInk = UIColor(red: 245.0/255, green: 239.0/255, blue: 223.0/255, alpha: 1)
    static let actionBackground = UIColor.white
    static let actionInk = UIColor.black
}
