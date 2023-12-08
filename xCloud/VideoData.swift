//
//  VideoData.swift
//  xCloud
//
//  Created by Eddie Carrizales on 12/5/23.
//

import Foundation
import UIKit

class VideoData {
    var videoImage: UIImage
    var videoName: String
    var videoURL: String
    var videoObjects: [String]
    
    init(fImage: UIImage, fName: String, fURL: String, fObjects: [String]) {
        videoImage = fImage
        videoName = fName
        videoURL = fURL
        videoObjects = fObjects
    }
}
