//
//  PhotosCollectionViewCell.swift
//  xCloud
//
//  Created by Eddie Carrizales on 12/5/23.
//

import UIKit
import FirebaseStorage

class PhotosCollectionViewCell: UICollectionViewCell, UIImagePickerControllerDelegate {
    
    //-----------------------Connected Outlets-----------------------
    @IBOutlet weak var imageViewCell: UIImageView!
    @IBOutlet weak var labelCell: UILabel!
    
    //-----------------------Global Variables-----------------------
    //Firebase Storage
    private let storage = Storage.storage().reference()
    
    //List that will store the image names, to determine what we have in the database
    var imageList = [String]()
    
    
}
