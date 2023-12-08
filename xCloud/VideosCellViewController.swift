//
//  PhotosCellViewController.swift
//  xCloud
//
//  Created by Eddie Carrizales on 12/7/23.
//

import UIKit
import AVFoundation

class VideosCellViewController: UIViewController {

    //Outlets declarations
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var contentNameLabel: UILabel!
    @IBOutlet weak var contentObjectsLabel: UILabel!
    @IBOutlet weak var videoPlayerView: UIView!
    
    var player: AVPlayer?
    
    //variable declarations
    var receivedImage: UIImage?
    var receivedLabelText: String?
    var receivedUrl: String?
    var receivedObjectsList: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("IN CELL VIEW CONTROLLER")
        print("receivedLabelText: \(String(describing: receivedLabelText))")
        print("receivedLabelText: \(String(describing: receivedObjectsList))")
        
        //set content video from the received url
        // Load the video from a URL
        if let videoURL = URL(string: receivedUrl!) {
            let playerItem = AVPlayerItem(url: videoURL)
            player = AVPlayer(playerItem: playerItem)

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill // or .resizeAspect
            playerLayer.frame = videoPlayerView.bounds

            videoPlayerView.layer.addSublayer(playerLayer)
            player?.play()
        }
        
        
        if let labelText = receivedLabelText {
            contentNameLabel.text = labelText
        }
        
            
        if let labelText = self.receivedLabelText {
            self.contentNameLabel.text = labelText
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
