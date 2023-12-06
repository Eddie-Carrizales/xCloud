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
    var retrievedimageList = [String]()
    
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

    var urlString = ""
    
    var hasRetrievedImageList = false
    
    //----------------------- View Did Load -----------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Adds the search bar to our screen
        navigationItem.searchController = searchController
        
        
        //Fetch the data from the database to show it in the controller
        //Steps:
        //1: Fetch the imageList
        retrievedimageList = retrieveImageList()
        print("Retrieved Image Names from Database: \(retrievedimageList)")
        
        //2: if the retrievedimageList was empty, do nothing and show nothing.
        //   else, Using the retrievedimageList, we fetch the urls and imageData
        if (retrievedimageList.count == 0)
        {
            print("Image list is empty, nothing will be loaded to the collection view.")
        }
        else
        {
            retrieveImagesUrlsAndData(imageList: retrievedimageList) //This will also update global variable photosDataList
            print("Image list is not empty, urls and image data downloaded, PhotosDataList updated.")
            print("Photos Data List: \(photosDataList)")
        }
        
        //3. if the user clicks on the imagePicker, then we check last name on our image list we had already fetched, and we create a new name and we upload that name to the database (the picture we pick will also be uploaded to the database with that new name)
        //This step is done in imagePickerController function
        
        
        //4. After adding that name to the database, we want to fetch the urls and imageData again from the data and re-download because now there is a new name and a new image.
        //This step is done in imagePickerController function
        
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
    
    //Function used to retrieve the string names list of images from the database
    func retrieveImageList() -> [String]
    {
        var imageList = [String]()
        
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
                    imageList = fileContents.components(separatedBy: "\n") //imageList gets retrieved and updated by this point
                    print("Inside retrieveImageList function, retrieved imageList: \(imageList)")
                }
            }
        }
        
        hasRetrievedImageList = true
        return imageList
    } // end of function retrieveImageList
    
    //This function will parse the imageList that was retrieved so we know what name to give to the new image that we will add to the databse
    func givePickedImageName(retrievedimageList: [String]) -> [String]
    {
        var imageListTemp = [String]()
        imageListTemp = retrievedimageList //add what we already have (we have to do this because we cannot mutate retrievedimageList directly since its passed)
        
        var imageName: String?
        
        //gets the number from the last image in the imageList
        if let lastImage = imageListTemp.last
        {
            if let range = lastImage.range(of: "_")
            {
                let digitsAfterUnderscore = lastImage[range.upperBound...]
                
                // Attempt to convert the substring to an integer
                if let imageNumber = Int(digitsAfterUnderscore)
                {
                    print("Current image number: \(imageNumber)")
                    
                    // Add 1 to the extracted number
                    let newImageNumber = imageNumber + 1
                    
                    imageName = "IMAGE_" + String(newImageNumber) + ".png"
                    print("Current Photo Name: " + imageName!)
                    
                    // Append the new image name to the list
                    imageListTemp.append(imageName!)
                }
                else
                {
                    // Handle the case where the substring after underscore is not convertible to an integer
                    print("Error: Unable to extract a valid number from the image name.")
                }
            }
            else
            {
                // Handle the case where there's no underscore in the image name
                print("Error: Underscore not found in the image name.")
            }
        }
        return imageListTemp
    } // end of function givePickedImageName
    
    //This function will retreive all the imageURLS from the database using the list of image names
    func retrieveImagesUrlsAndData(imageList:[String])
    {
        
        //------------------Retrieve urls and images-----------------
        for imageName in imageList
        {
            let imageRef = self.storage.child("images/" + imageName) //name of the image we will retrieve
            
            
                // ------------------Fetch download URL for each image------------------
                imageRef.downloadURL { url, error in
                    if let error = error {
                        print("Error fetching URL for \(imageName): \(error.localizedDescription)")
                    }
                    else if let url = url
                    {
                        
                        let urlString = url.absoluteString
                        
                        // Append retrieved download URL to the array
                        self.retrievedImageURLs.append(self.urlString)
                        
                        // Check if all image URLs are retrieved
                        if self.retrievedImageURLs.count == imageList.count
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
                            if self.retrievedImages.count == imageList.count
                            {
                                // All images are retrieved, do something with retrievedImages array
                                print("All images retrieved: \(self.retrievedImages)")
                            
                            }
                            
                            //--------------Append Image, Name, and URL retrieved-----------
                            //self.imageView.image = image
                            var currentImage = ImageData(fImage: image, fName: imageName, fURL: self.urlString)
                            self.photosDataList.append(currentImage)
                        }
                    }
                } // end of download image data
        } // end of for loop
    } // end of retrieveImageUrlsAndData
    
    //This function stores the imageList as a txt file in the database
    func storeImageListAsTxt(updatedImageList: [String])
    {
        // Convert the array of strings to a single string representation
        let combinedImageNameStrings = updatedImageList.joined(separator: "\n")

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
    } // end of function storeImageListAsTxt
    
    
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
        
        //---Checking list so we know what the current image name is and adding a new image name to the list---
        var updatedImageList = [String]() // variable to store newly updated image list
        
        updatedImageList = givePickedImageName(retrievedimageList: retrievedimageList)
        print("ImagePickerController updated retrievedImageList.")
        print("New retrieved image list: \(updatedImageList) ")
        
        
        //------Putting the image chosen from the imagePickerController into the storage address-----
        //We access the last element of the updatedImageList which has the newly created name for our image
        storage.child("images/" + updatedImageList[updatedImageList.count - 1]).putData(imageAsData, metadata: nil , completion:
        { _, error in
            guard error == nil else
            {
                print("Failed to upload")
                return
            }
        }) // end of storage.child
        
        
        //------------------Retrieve new url and image and update photosDataList-----------------
        // NOTE: I WILL REDOWNLOAD EVERYTHING AGAIN (URLS and IMAGE), HOWEVER THE WAY IT SHOULD BE DONE IS TO DOWNLOAD ONLY THE NEW URL AND NEW IMAGE THAT WAS JUST UPLOADED, AND ADD THAT TO THE CORRESPONDING LISTS (URL LIST, IMAGE LIST, AND PHOTO DATA LIST)
        retrieveImagesUrlsAndData(imageList:updatedImageList)
        print("PhotosDataList updated by imagePickerController.")
        print("Updated Photos Data List: \(photosDataList)")
        
        
        //----------------We store the imageList in the database as a .txt file---------------
        storeImageListAsTxt(updatedImageList: updatedImageList)
        print("Image Picker Controller updated imageList.txt")
        
        //----------------We "retrive" the updatedImageList from our database simply by setting our retrievedImageList equal to the updatedImageList, since updatedImageList is already the most updated list.
        retrievedimageList = updatedImageList
        print("Image Picker Controller uptaded retrievedimageList")
        
        
        //Reload the view controller with the new image that was now added to the database.
        self.photosCollectionView.reloadData()
        
    } // end of function pickerController
    
    // Cancels the imagePicker if the user canceled
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

