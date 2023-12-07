//
//  FileData.swift
//  xCloud
//
//  Created by Eddie Carrizales on 12/7/23.
//

import Foundation
import UIKit

class FileData {
    var fileImage: UIImage
    var fileName: String
    var fileURL: String
    
    init(fImage: UIImage, fName: String, fURL: String) {
        fileImage = fImage
        fileName = fName
        fileURL = fURL
    }
}
