//
//  PhotosCellViewController.swift
//  xCloud
//
//  Created by Eddie Carrizales on 12/7/23.
//

import UIKit

class PhotosCellViewController: UIViewController {

    //Outlets declarations
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var contentNameLabel: UILabel!
    @IBOutlet weak var contentObjectsLabel: UILabel!
    
    //variable declarations
    var receivedImage: UIImage?
    var receivedLabelText: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("IN CELL VIEW CONTROLLER")
        print("receivedLabelText: \(String(describing: receivedLabelText))")
        
        //set content image to the received image
        if let image = receivedImage {
            contentImageView.image = image
        }
        
        
        if let labelText = receivedLabelText {
            contentNameLabel.text = labelText
        }

    } // end of view did load

} // end of photos cell view controller
