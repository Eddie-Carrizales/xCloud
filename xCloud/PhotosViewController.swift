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
    
    
    //List of type ImageData that will store the image and its name (so we can show them together on the each cell)
    var photosDataList = [ImageData]()
    
    //List that will store the image names, to determine what we have in the database
    var retrievedimageList = [String]()
    
    // An array to store retrieved image URLs
    var retrievedImageURLs: [String] = []
    
    // An array to store retrieved images
    var retrievedUIImagesList: [UIImage] = []
    
    var retrievedJsonObjectsList: [[String]] = []
    
    //Searching variables
    let searchController = UISearchController(searchResultsController: nil)
    var searching = false
    var searchedImage = [ImageData]()
    
    var newImageName: String?

    var urlString = ""
    
    //Dictionaries
    var urlDictionary = [String: String]()
    var imageDictionary = [String: UIImage]()
    var jsonObjectsDictionary = [String: [String]]()
    
    // Long press gesture recognizer setup
    lazy var longPressGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
        gesture.minimumPressDuration = 0.5 // Adjust as needed
        return gesture
    }()
    
    //----------------------- View Did Load -----------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Adds the search bar to our screen
        navigationItem.searchController = searchController
        
        photosCollectionView.addGestureRecognizer(longPressGesture)

        configureSearchController()
        retrieveImagesInformation()
        
        
        //Fetch the data from the database to show it in the controller
        //Steps:
        //1: Fetch the imageList, the urls and imageData
        
        // Create a Timer that fires every 15 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            
            self.retrieveJsonInformation()
        }
        
        // To make sure the timer fires when the program starts
        RunLoop.main.add(timer, forMode: .common)
        
        print("VIEW DID LOAD.")
        
        //2. if the user clicks on the imagePicker, then we check last name on our image list we had already fetched, and we create a new name and we upload that name to the database (the picture we pick will also be uploaded to the database with that new name)
        //This step is done in imagePickerController function
        
        
        //3. After adding that name to the database, we want to fetch the urls and imageData again from the data and re-download because now there is a new name and a new image.
        //This step is done in imagePickerController function
    }
    
    //----------------------- Action & Object Functions -----------------------
    @IBAction func didTapUpload(_ sender: UIButton)
    {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    // Handle long press on collection view cell
    @objc func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let touchPoint = gesture.location(in: self.photosCollectionView)
            
            if let indexPath = photosCollectionView.indexPathForItem(at: touchPoint) {
                // Handle the long press on the cell here
                showDeleteOption(indexPath: indexPath)
            }
        }
    }
    
    // Show delete option (alert, action sheet, etc.)
    func showDeleteOption(indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Delete Image", message: "Are you sure you want to delete this image?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            // Perform deletion logic here
            self?.deleteImage(at: indexPath)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Delete image at specific index path
    func deleteImage(at indexPath: IndexPath) {
        let imageToDelete = photosDataList[indexPath.item] // Get the image to delete from your data source
        
        // Find the index of the item you want to remove
        if let indexToRemove = retrievedimageList.firstIndex(of: imageToDelete.photoName) {
            // Remove the item at the found index
            retrievedimageList.remove(at: indexToRemove)
        }
        
        // Convert the array of strings to a single string representation
        let combinedImageNameStrings = retrievedimageList.joined(separator: "\n")

        // Convert the string to Data
        if let data = combinedImageNameStrings.data(using: .utf8) {
            // Create a reference to a file in Firebase Storage within the "index" folder
            let imageListRef = storage.child("index/imageList.txt")

            // Upload the file data to Firebase Storage
            imageListRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    print("Error uploading: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("File uploaded successfully! Metadata: \(metadata)")
                
                // --------------Remove the image from Firebase Storage-------------------
                let storageRef = Storage.storage().reference().child("images/\(imageToDelete.photoName)") // Adjust the reference path as per your Firebase Storage structure
                storageRef.delete { error in
                    if let error = error {
                        print("Error deleting image: \(error.localizedDescription)")
                        // Handle error condition here
                    } else {
                        // Image deleted successfully from Firebase Storage
                        // Now remove it from your local data source and collection view
                        self.photosDataList.remove(at: indexPath.item)
                        self.photosCollectionView.deleteItems(at: [indexPath])
                        
                        //------------------Retrieve imageList, new url and image and update photosDataList-----------------
                        self.retriveNewImageInformation()
                        print("PhotosDataList updated by imagePickerController.")
                        
                        self.photosCollectionView.reloadData()
                    }
                }

            } // end of upload file to database
        }
    } // end of delete image function
    
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
    
    func extractDigits(from input: String) -> String {
        let pattern = #"_([0-9]+)\."#

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            if let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)) {
                let range = Range(match.range(at: 1), in: input)!
                let digits = String(input[range])
                return digits
            }
        }

        return ""
    }
    
    //This function will parse the imageList that was retrieved so we know what name to give to the new image that we will add to the databse
    func givePickedImageName(retrievedimageList: [String]) -> [String]
    {
        var imageListTemp = [String]()
        imageListTemp = retrievedimageList //add what we already have (we have to do this because we cannot mutate retrievedimageList directly since its passed)
        
        var imageName: String?
        print("imageListTemp: \(imageListTemp)")
        //gets the number from the last image in the imageList
        if let lastImage = imageListTemp.last
        {
            
            let digitsAfterUnderscore = extractDigits(from: lastImage)
            // Attempt to convert the substring to an integer
            if let imageNumber = Int(digitsAfterUnderscore)
            {
                // Add 1 to the extracted number
                let newImageNumber = imageNumber + 1
                    
                imageName = "IMAGE_" + String(newImageNumber) + ".png"
                print("New Photo Name: " + imageName!)
                newImageName = imageName
                    
                // Append the new image name to the list
                imageListTemp.append(imageName!)
            }
            else
            {
                // Handle the case where the substring after underscore is not convertible to an integer
                print("Error: Unable to extract a valid number from the image name.")
            }
        }
        return imageListTemp
    } // end of function givePickedImageName
    
    func addToPhotoDataList()
    {
        // Ensure the lists are of the same count and non-empty before processing
        print("List Counts:")
        print("retrievedimageList count: \(self.retrievedimageList.count)")
        print("retrievedUIImagesList count: \(self.retrievedUIImagesList.count)")
        print("retrievedImageURLs count: \(self.retrievedImageURLs.count)")
        
        print("URLs retrieved: \(self.retrievedImageURLs)")
        
        if (self.retrievedimageList.count == self.retrievedUIImagesList.count && self.retrievedimageList.count == self.retrievedImageURLs.count && !self.retrievedimageList.isEmpty)
        {
            for index in 0..<self.retrievedimageList.count
            {
                let imageName = self.retrievedimageList[index]

                let currentImage = ImageData(fImage: imageDictionary[imageName]!, fName: imageName, fURL: urlDictionary[imageName]!, fObjects: jsonObjectsDictionary[imageName]!)
                
                self.photosDataList.append(currentImage)
                print("PhotosDataList updated.")
                
                //Reload the view controller with the new image that was now added to the database.
                self.photosCollectionView.reloadData()
                
            }
        }
    }
    
    //This function will retreive all the imageURLS from the database using the list of image names
    func retrieveImagesInformation()
    {
        
        //------------------Retrieve ImageList-------------------
        var imageList = [""]
        
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
                    
                    //ADDING TO DICTIONARY
                    for name in imageList {
                        self.urlDictionary[name] = ""
                        self.imageDictionary[name] = UIImage()
                        self.jsonObjectsDictionary[name] = [""]
                    }
                    
                    //print("urlDictionary: \(self.urlDictionary)")
                    //print("imageDictionary: \(self.imageDictionary)")
                    
                    self.retrievedimageList = imageList // update retrievedimageList
                    print("\nRetrieved all image names from imageList: \(imageList)")
                    print("Updated retrievedimageList.")
                    print("\n")
        
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
                                    // Append retrieved download URL to the array so we can check later if everything was downloaded
                                    self.retrievedImageURLs.append(url.absoluteString)
                                    
                                    //Match the downloaded url to the image name
                                    if self.urlDictionary.keys.contains(imageName)
                                    {
                                        self.urlDictionary[imageName] = url.absoluteString
                                    }
                                    
                                    print("Retrieving URL and IMAGE for: \(imageName)...")
                                    //print("Image url: \(url.absoluteString)")
                                    //print("")
                                    
                                    // Check if all image URLs are retrieved
                                    //if self.retrievedImageURLs.count == imageList.count
                                    if self.retrievedImageURLs.count == imageList.count
                                    {
                                        // All image URLs are retrieved, do something with retrievedImageURLs array
                                        // Now you have an array of image URLs to work with
                                        // You can use these URLs to load images asynchronously
                                        print("\nAll image URLs retrieved: \(self.retrievedImageURLs)")
                                        print("\nurlDictionary: \(self.urlDictionary)")
                                        
                                    }
                                    
                                // ------------------ Download image data ------------------
                                imageRef.getData(maxSize: 10 * 1024 * 1024)
                                    { data, error in
                                        if let error = error {
                                            print("Error downloading \(imageName): \(error.localizedDescription)")
                                        }
                                        else
                                        {
                                            if let imageData = data, let image = UIImage(data: imageData)
                                            {
                                                // Append retrieved image to the array so we can check later if everything was downloaded
                                                self.retrievedUIImagesList.append(image)
                                                
                                                //Match the downloaded image to the image name
                                                if self.imageDictionary.keys.contains(imageName)
                                                {
                                                    self.imageDictionary[imageName] = image
                                                }
                                                
                                                // Check if all images are retrieved
                                                if self.retrievedUIImagesList.count == imageList.count
                                                {
                                                    // All images are retrieved, do something with retrievedImages array
                                                    print("\nAll images retrieved: \(self.retrievedUIImagesList)")
                                                    print("\nimagesDictionary: \(self.imageDictionary)")
                                                    
                                                    // ------------update photosDataList---------
                                                    self.addToPhotoDataList()
                                                    
                                                    //------------------------------------------
                                                }
                                                    
                                            }
                                                
                                        }
                                    } // end of download image data
                                }
                            } //end of downloadURL
            
                    } // end of for loop
                    
                } // end of second if
            } //end of first if
        } // end of download ImageList file
        
    } // end of retrieveImageUrlsAndData
    
    
    func retrieveJsonInformation()
    {
        //------------------Retrieve ImageList-------------------
        var imageList = [""]
        
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
                    
                    //------------------JSON-----------------
                    for imageName in imageList
                    {
                        
                        // Assuming self.storage is an instance of StorageReference
                        let jsonRef = self.storage.child("index/ml_status.json") // Name of the JSON file
                        
                        jsonRef.getData(maxSize: 5 * 1024 * 1024) { [self] result in
                            switch result {
                            case .success(let data):
                                // Parse the downloaded JSON data
                                do {
                                    if let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                        let fileNames = jsonDict.keys.map { $0.components(separatedBy: "/").last ?? "" }
                                        print("\nNames in JSON file:", fileNames)
                                        
                                        print("\njsonDict: \(jsonDict)")
                                        print("\n")
                                        
                                        // Iterate through each key-value pair
                                        for (key, value) in jsonDict {
                                            if let currentImageName = key.components(separatedBy: "/").last,
                                               let objectsData = value as? [String: Any],
                                               let objects = objectsData["objects"] as? [String] {
                                                
                                                print("\nimageName: \(imageName)")
                                                print("currentImageName: \(currentImageName), objects: \(objects)")
                                                
                                                if currentImageName == imageName {
                                                    // Iterate through the photosDataList
                                                    for (index, imageData) in self.photosDataList.enumerated() {
                                                        if imageData.photoName == imageName {
                                                            print("JASON UPDATING PHOTOS DATA LIST")
                                                            print("imageName: \(imageName), Added Objects: \(objects)")
                                                            print("PhotosDataList Before: \(photosDataList)")
                                                            let modifiedImageData = imageData
                                                            modifiedImageData.photoObjects = objects
                                                            self.photosDataList[index] = modifiedImageData // Update the modified data
                                                            print("PhotosDataList After: \(self.photosDataList)")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } catch {
                                    print("Error parsing JSON: \(error.localizedDescription)")
                                }
                            case .failure(let error):
                                print("Error downloading JSON file: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        
    } //end of retrieveJasonInfo
    
    
    func retriveNewImageInformation()
    {
        //------------------Retrieve urls and images-----------------
        print("Retrieving URL and IMAGE for: \(String(describing: self.newImageName))...")
        let imageRef = self.storage.child("images/" + self.newImageName!) //name of the image we will retrieve
                        
        // ------------------Fetch download URL for each image------------------
        imageRef.downloadURL
        { url, error in
            if let error = error
            {
                print("Error fetching URL for \(String(describing: self.newImageName)): \(error.localizedDescription)")
            }
            else if let url = url
            {
                // retrieved download URL
                                    
                let newImageUrl = url.absoluteString
                                    
                                    
                // ------------------ Download image data ------------------
                imageRef.getData(maxSize: 10 * 1024 * 1024)
                { data, error in
                    if let error = error
                    {
                        print("Error downloading \(String(describing: self.newImageName)): \(error.localizedDescription)")
                    }
                    else
                    {
                        if let imageData = data, let image = UIImage(data: imageData)
                        {
                            // retrieved image
                            let newImage = image
                                            
                            // ------------update photosDataList---------
                            let newImageData = ImageData(fImage: newImage, fName: self.newImageName!, fURL: newImageUrl, fObjects: ["No Objects Found"])
                            self.photosDataList.append(newImageData)
                            print("PhotosDataList updated.")
                            
                            //Reload the view controller with the new image that was now added to the database.
                            self.photosCollectionView.reloadData()
                            //------------------------------------------
                                                
                        } // end of if
                    }
                }
            } //end of first if
        } // end of download ImageList file
        
    } // end of retriveNewImageInformation
    
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
                
                //------------------Retrieve imageList, new url and image and update photosDataList-----------------
                self.retriveNewImageInformation()
                print("PhotosDataList updated by imagePickerController.")
            }
        }
    } // end of function storeImageListAsTxt
    
    
    //Function that will call the imagePickerController allowing a user to pick an image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
    {
        print("Image Picker Controller Was Called.")
        
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
        //var updatedImageList = [String]() // variable to store newly updated image list
        
        retrievedimageList = givePickedImageName(retrievedimageList: retrievedimageList)
        print("ImagePickerController updated retrievedImageList.")
        print("New retrieved image list: \(retrievedimageList) ")
        
        
        //------Putting the image chosen from the imagePickerController into the storage address-----
        //We access the last element of the updatedImageList which has the newly created name for our image
        storage.child("images/" + retrievedimageList[retrievedimageList.count - 1]).putData(imageAsData, metadata: nil , completion:
        { _, error in
            guard error == nil else
            {
                print("Failed to upload")
                return
            }
        }) // end of storage.child
        print("Image Picker Uploaded the picked image.")
        
        
        //----------------We store the imageList in the database as a .txt file and Retrieve information---------------
        storeImageListAsTxt(updatedImageList: retrievedimageList) // This stores imageList and retrieves
        //print("Image Picker Controller updated imageList.txt")
        
    } // end of function pickerController
    
    // Cancels the imagePicker if the user canceled
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        picker.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAnotherViewController",
           let destinationViewController = segue.destination as? PhotosCellViewController,
           let indexPath = sender as? IndexPath {
            
            print("IN SEGUE")
            
            let selectedImage = photosDataList[indexPath.row].photoImage
            let labelText = photosDataList[indexPath.row].photoName
            let objectsList = photosDataList[indexPath.row].photoObjects
            
            print("labelText: \(labelText)")
            
            destinationViewController.receivedImage = selectedImage
            destinationViewController.receivedLabelText = labelText
            destinationViewController.receivedObjectsList = objectsList
        }
    }
    
} // end of class


extension PhotosViewController: UICollectionViewDelegate, UICollectionViewDataSource, UISearchResultsUpdating, UISearchBarDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("PERFORMING SEGUE")
        performSegue(withIdentifier: "ShowAnotherViewController", sender: indexPath)
    }
    
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
            //cell.labelCell.text = searchedImage[indexPath.row].photoName
        }
        else
        {
            cell.imageViewCell.image = photosDataList[indexPath.row].photoImage
            //cell.labelCell.text = photosDataList[indexPath.row].photoName
        }
        
        return cell
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text!
        
        if !searchText.isEmpty
        {
            searching = true
            searchedImage.removeAll()
            
            //ADD CONDITIONS INSIDE THIS LOOP FOR SEARCH BAR
            for photo in photosDataList
            {
                if photo.photoName.lowercased().contains(searchText.lowercased())
                {
                    searchedImage.append(photo)
                }
                else
                {
                    //searches all objects inside photos
                    for anObject in photo.photoObjects
                    {
                        if anObject.lowercased().contains(searchText.lowercased())
                        {
                            searchedImage.append(photo)
                        }
                    }
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

