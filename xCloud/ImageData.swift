//
//  ImageData.swift
//  xCloud
//
//  Created by Eddie Carrizales on 12/5/23.
//

import Foundation
import UIKit

class ImageData {
    var photoImage: UIImage
    var photoName: String
    
    init(fImage: UIImage, fName: String) {
        photoImage = fImage
        photoName = fName
    }
}
