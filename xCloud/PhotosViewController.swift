//
//  PhotosViewController.swift
//  xCloud
//
//  Created by Eddie Carrizales on 10/26/23.
//

import UIKit
import FirebaseStorage


class PhotosViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    //List that will store the image names, to determine what we have in the database
    var imageList = [String]()
    
    
    @IBOutlet weak var imageView: UIImageView!
    
    //Firebase Storage
    private let storage = Storage.storage().reference()
    
    let searchController = UISearchController()
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Adds the search bar to our screen
        navigationItem.searchController = searchController
        
        guard let urlString = UserDefaults.standard.value(forKey: "url") as? String,
              let url = URL(string:urlString) else
        {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: {data, _, error in
            guard let data = data, error == nil else
            {
                return
            }
            DispatchQueue.main.async
            {
                //Shows the image on the image view screen and updates image in real time
                let image = UIImage(data: data)
                self.imageView.image = image
            }
        })
        task.resume()
    }
    
    @IBAction func didTapUpload(_ sender: UIButton)
    {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    //Function that will call the imagePickerController allowing a user to pick an image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
    {
        picker.dismiss(animated: true, completion: nil)
        //Create a variable type image that will be chosen from the image picker controller
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else
        {
            return
        }
        //creates variable imageData and sets its type
        guard let imageData = image.pngData() else
        {
            return
        }
        
        //------------------We could retrieve the list of images from the databse here----------
        //Retrieve list of files from the database
        let imageNumber = imageList.count
        var imageName = "IMAGE_" + String(imageNumber) + ".png"
        imageList.append(imageName)
        
        //everytime you upload an image you add it to the list and upload list as well, every time you remove an image, you remove it from the list and upload it as well
        //------------------------------------------------------------------------------
        
        //Putting the image chosen from the imagePickerController into the storage address
        storage.child("images/" + imageName).putData(imageData, metadata: nil , completion:
        { _, error in
            guard error == nil else
            {
                print("Failed to upload")
                return
            }
            
            //Fetch the image called images/IMAGE_1.png from the download URL
            // NOTE: Currently, this only will retrieve one file, you have to make a loop that will go through all of the names in the imageList and retrieve every single image and put it in a special list that will store images, then you will pass that list to your collection controller so it can show all those images that you have in your database.
            self.storage.child("images/file.png").downloadURL(completion:
            {url, error in
                guard let url = url, error == nil else
                {
                    return
                }
                
                let urlString = url.absoluteString
                
                //Refresh image only once, after uploading
                DispatchQueue.main.async
                {
                    self.imageView.image = image
                }
                
                print("Download URL: \(urlString)")
                UserDefaults.standard.set(urlString, forKey: "url")
            })
        })
        
        //upload image data
        
        //get download url
        
        //save download url to userdata
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        picker.dismiss(animated: true, completion: nil)
    }
    
    
    
} // end of class


