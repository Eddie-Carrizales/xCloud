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
    var photosDataList = [ImageData]()
    
    // An array to store retrieved image URLs
    var retrievedImageURLs: [String] = []
    
    // An array to store retrieved images
    var retrievedImages: [UIImage] = []
    
    //Searching variables
    let searchController = UISearchController(searchResultsController: nil)
    var searching = false
    var searchedImage = [ImageData]()
    
    var imageNumber = 0
    var urlString = ""

    
    
    //----------------------- View Did Load -----------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Adds the search bar to our screen
        navigationItem.searchController = searchController
        
        //Uses the url to download the each image and sets the imageViewCell to that image
//        guard let urlString = UserDefaults.standard.value(forKey: "url") as? String,
//              let url = URL(string:urlString) else
//        {
//            return
//        }
//
//        let task = URLSession.shared.dataTask(with: url, completionHandler: {data, _, error in
//            guard let data = data, error == nil else
//            {
//                return
//            }
//            DispatchQueue.main.async
//            {
//                //Shows the image on the image view screen and updates image in real time
//                let image = UIImage(data: data)
//                imageViewCell.image = image
//            }
//        })
//        task.resume()
        photosCollectionView.reloadData()
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
    func configureSearchController()
    {
        searchController.loadViewIfNeeded()
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.enablesReturnKeyAutomatically = false
        searchController.searchBar.returnKeyType = UIReturnKeyType.done
        self.navigationItem.searchController = searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        searchController.searchBar.placeholder = "Search content in photos or by name"
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
        guard let imageAsData = image.pngData() else
        {
            return
        }

        
        //------------------We retrieve the String list of images from the database here----------
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
                    print("Retrieved Image Names from Database: \(self.imageList)")
                }
            }
        }
        
        
        //--------------Parsing List so we know what is current image number and setting image name-------
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

        let imageName = "IMAGE_" + String(imageNumber) + ".png"
        print("Current Photo Name: " + imageName)
        imageList.append(imageName)
        
        //------------------------------------------------------------------------------
        //everytime you upload an image you add it to the list and upload list as well, every time you remove an image, you remove it from the list and upload it as well
        //------------------------------------------------------------------------------
        
        //------Putting the image chosen from the imagePickerController into the storage address-----
        storage.child("images/" + imageName).putData(imageAsData, metadata: nil , completion:
        { _, error in
            guard error == nil else
            {
                print("Failed to upload")
                return
            }
            
            //------------------Retrieve urls and images-----------------
            for imageName in self.imageList
            {
                let imageRef = self.storage.child("images/" + imageName) //name of the image we will retrieve
                
                
                    // ------------------Fetch download URL for each image------------------
                    imageRef.downloadURL { url, error in
                        if let error = error {
                            print("Error fetching URL for \(imageName): \(error.localizedDescription)")
                        }
                        else if let url = url
                        {
                            
                            self.urlString = url.absoluteString
                            
                            // Append retrieved download URL to the array
                            self.retrievedImageURLs.append(self.urlString)
                            
                            // Check if all image URLs are retrieved
                            if self.retrievedImageURLs.count == self.imageList.count
                            {
                                // All image URLs are retrieved, do something with retrievedImageURLs array
                                // Now you have an array of image URLs to work with
                                // You can use these URLs to load images asynchronously
                                print("All image URLs retrieved: \(self.retrievedImageURLs)")
                            }
                        }
                    } //end of downloadURL
                
                    // ------------------ Download image data ------------------
                    imageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                        if let error = error {
                            print("Error downloading \(imageName): \(error.localizedDescription)")
                        }
                        else
                        {
                            if let imageData = data, let image = UIImage(data: imageData)
                            {
                                
                                // Append retrieved image to the array
                                self.retrievedImages.append(image)
                            
                                // Check if all images are retrieved
                                if self.retrievedImages.count == self.imageList.count
                                {
                                    // All images are retrieved, do something with retrievedImages array
                                    print("All images retrieved: \(self.retrievedImages)")
                                
                                }
                                
                                //--------------Append Image, Name, and URL retrieved-----------
                                //self.imageView.image = image
                                var currentImage = ImageData(fImage: image, fName: imageName, fURL: self.urlString)
                                self.photosDataList.append(currentImage)
                                self.photosCollectionView.reloadData()
                                
                            }
                        }
                    } // end of download image data
                    
                
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
extension PhotosViewController: UICollectionViewDelegate, UICollectionViewDataSource, UISearchResultsUpdating, UISearchBarDelegate
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if searching {
            return searchedImage.count
        }
        else {
            return photosDataList.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = photosCollectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PhotosCollectionViewCell
        
        if searching
        {
            cell.imageViewCell.image = searchedImage[indexPath.row].photoImage
            cell.labelCell.text = searchedImage[indexPath.row].photoName
        }
        else
        {
            cell.imageViewCell.image = photosDataList[indexPath.row].photoImage
            cell.labelCell.text = photosDataList[indexPath.row].photoName
        }
        
        return cell
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text!
        
        if !searchText.isEmpty
        {
            searching = true
            searchedImage.removeAll()
            
            for photo in photosDataList
            {
                if photo.photoName.lowercased().contains(searchText.lowercased())
                {
                    searchedImage.append(photo)
                }
            }
        }
        else
        {
            searching = false
            searchedImage.removeAll()
            searchedImage = photosDataList
        }
        photosCollectionView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searching = false
        searchedImage.removeAll()
        photosCollectionView.reloadData()
    }
}

