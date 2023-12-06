//
//  PhotosViewController.swift
//  xCloud
//
//  Created by Eddie Carrizales on 10/26/23.
//

import UIKit
import FirebaseStorage


class PhotosViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //-----------------------Connected Outlets-----------------------
    @IBOutlet weak var photosCollectionView: UICollectionView!
    
    
    //-----------------------Global Variables-----------------------
    //Firebase Storage
    private let storage = Storage.storage().reference()
    
    //List that will store the image names, to determine what we have in the database
    var imageList = [String]()
    
    //List of type ImageData that will store the image and its name (so we can show them together on the each cell)
    var photosAndNamesList = [ImageData]()
    
    // An array to store retrieved image URLs
    var retrievedImageURLs: [String] = []
    
    let searchController = UISearchController(searchResultsController: nil)
    
    //----------------------- View Did Load -----------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Adds the search bar to our screen
        navigationItem.searchController = searchController
        
        //Uses the url to download the each image and sets the imageViewCell to that image
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
                //imageViewCell.image = image
            }
        })
        task.resume()
    }
    
    //----------------------- Action Functions -----------------------
    @IBAction func didTapUpload(_ sender: UIButton)
    {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    //----------------------- Other Functions -----------------------
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

        
        //------------------We retrieve the list of images from the database here----------
        //Retrieve list of image strings from the database
        
        // Reference to the file in Firebase Storage
        let imageListRef = storage.child("index/imageList.txt")

        // Download the imageList file
        imageListRef.getData(maxSize: 1 * 1024 * 1024)
        { data, error in
            if let error = error
            {
                print("Error downloading: \(error.localizedDescription)")
                return
            }

            if let data = data
            {
                // Convert the Data to a String
                if let fileContents = String(data: data, encoding: .utf8)
                {
                    // Split the retrieved string into an array of strings
                    self.imageList = fileContents.components(separatedBy: "\n") //imageList gets retrieved and updated by this point
                    print("Retrieved strings: \(self.imageList)")
                }
            }
        }
        
        
        //--------------Parsing List so we know what is current image number and setting image name-------
        //local variable declarations
        var imageNumber = 0
        
        //gets the number from the last image in the imageList
        if let lastImage = imageList.last
        {
            // Find the range of the underscore character
            if let range = lastImage.range(of: "_")
            {
                // Extract substring after the underscore
                let digitsAfterUnderscore = lastImage[range.upperBound...]
                
                // Convert the substring to an integer
                imageNumber = Int(digitsAfterUnderscore)!
                print("Current image number: \(imageNumber)")
                
                //Add 1 to whatever number is latest
                imageNumber = imageNumber + 1
            }
        }

        var imageName = "IMAGE_" + String(imageNumber) + ".png"
        imageList.append(imageName)
        
        //everytime you upload an image you add it to the list and upload list as well, every time you remove an image, you remove it from the list and upload it as well
        //------------------------------------------------------------------------------
        
        //------Putting the image chosen from the imagePickerController into the storage address-----
        storage.child("images/" + imageName).putData(imageData, metadata: nil , completion:
        { _, error in
            guard error == nil else
            {
                print("Failed to upload")
                return
            }
            
            //------------------Retrieve all of the images in the Database-----------------
            for imageName in self.imageList
            {
                let imageRef = self.storage.child("images/\(imageName)")

                    // Fetch download URL for each image
                    imageRef.downloadURL { url, error in
                        if let error = error {
                            print("Error fetching URL for \(imageName): \(error.localizedDescription)")
                        }
                        else if let url = url
                        {
                            // Append retrieved download URL to the array
                            let urlString = url.absoluteString //This may not be needed I just added it
                            self.retrievedImageURLs.append(url.absoluteString)
                            
                            // Check if all image URLs are retrieved
                            if self.retrievedImageURLs.count == self.imageList.count
                            {
                                // All image URLs are retrieved, do something with retrievedImageURLs array
                                print("All image URLs retrieved: \(self.retrievedImageURLs)")
                                
                                // Now you have an array of image URLs to work with
                                // You can use these URLs to load images asynchronously
                                DispatchQueue.main.async
                                {
                                    //self.imageView.image = image
                                    let currentImage = ImageData(fImage: image, fName: imageName)
                                    self.photosAndNamesList.append(currentImage)
                                }
                                
                                //Save a url to a users device (we have to save the whole list)
                                //UserDefaults.standard.set(urlString, forKey: "url")
                            }
                        }
                    } //end of downloadURL
                
                } // end of for loop
        }) // end of storage.child
        
        
        //----------------We store the imageList in the database as a .txt file---------------
        // Convert the array of strings to a single string representation
        let combinedImageNameStrings = imageList.joined(separator: "\n")

        // Convert the string to Data
        if let data = combinedImageNameStrings.data(using: .utf8) {
            // Create a reference to a file in Firebase Storage within the "index" folder
            let imageListRef = storage.child("index/imageList.txt")

            // Upload the data to Firebase Storage
            imageListRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    print("Error uploading: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("File uploaded successfully! Metadata: \(metadata)")
            }
        }
        //--------------------------------------------------------------------------------------
        
        
        
    } // end of function pickerController
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        picker.dismiss(animated: true, completion: nil)
    }
    
    
    
} // end of class


