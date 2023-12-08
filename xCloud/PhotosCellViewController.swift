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
    var receivedObjectsList: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("IN CELL VIEW CONTROLLER")
        print("receivedLabelText: \(String(describing: receivedLabelText))")
        print("receivedLabelText: \(String(describing: receivedObjectsList))")
        
        //set content image to the received image
        if let image = receivedImage {
            contentImageView.image = image
        }
        
        
        if let labelText = receivedLabelText {
            contentNameLabel.text = labelText
        }
        
        if receivedObjectsList.count == 0 || receivedObjectsList == [""]
        {
            contentObjectsLabel.text = "[No objects found]"
        }
        else
        {
            let objectsListAsString = stringifyList(receivedObjectsList)
            contentObjectsLabel.text = objectsListAsString
        }

    } // end of view did load
    
    func stringifyList(_ list: [String]) -> String {
        let elementsAsString = list.map { "\($0)" }.joined(separator: ", ")
        return "[\(elementsAsString)]"
    }

} // end of photos cell view controller
