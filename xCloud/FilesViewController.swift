//
//  PhotosViewController.swift
//  xCloud
//
//  Created by Eddie Carrizales on 10/26/23.
//

import UIKit
import FirebaseStorage
import UniformTypeIdentifiers
import MobileCoreServices


class FilesViewController: UIViewController, UIDocumentPickerDelegate, UINavigationControllerDelegate, UIDocumentInteractionControllerDelegate {
    
    //-----------------------Connected Outlets-----------------------
    @IBOutlet weak var filesCollectionView: UICollectionView!
    
    
    //-----------------------Global Variables-----------------------
    //Firebase Storage
    private let storage = Storage.storage().reference()
    
    
    //List of type ImageData that will store the image and its name (so we can show them together on the each cell)
    var filesDataList = [FileData]()
    
    //List that will store the image names, to determine what we have in the database
    var retrievedfileList = [String]()
    
    // An array to store retrieved image URLs
    var retrievedFileURLs: [String] = []
    
    // An array to store retrieved images
    var retrievedUIImagesList: [UIImage] = []
    
    //Searching variables
    let searchController = UISearchController(searchResultsController: nil)
    var searching = false
    var searchedImage = [FileData]()
    
    var newFileName: String?

    var urlString = ""
    
    //Dictionaries
    var fileUrlDictionary = [String: String]()
    var fileImageDictionary = [String: UIImage]()
    
    
    var isLongPressGesture = false // Flag to track long press
    
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
        configureSearchController()
        filesCollectionView.addGestureRecognizer(longPressGesture)
        
        //Fetch the data from the database to show it in the controller
        //Steps:
        //1: Fetch the imageList, the urls and imageData
        retrieveFilesInformation()
        print("VIEW DID LOAD.")
        
        //2. if the user clicks on the imagePicker, then we check last name on our image list we had already fetched, and we create a new name and we upload that name to the database (the picture we pick will also be uploaded to the database with that new name)
        //This step is done in imagePickerController function
        
        
        //3. After adding that name to the database, we want to fetch the urls and imageData again from the data and re-download because now there is a new name and a new image.
        //This step is done in imagePickerController function
    }
    
    //----------------------- Action && Objc Functions -----------------------
    @IBAction func didTapUpload(_ sender: UIButton)
    {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [String(kUTTypePDF), String(kUTTypeText)], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    // Handle long press on collection view cell
    @objc func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            isLongPressGesture = true
            let touchPoint = gesture.location(in: self.filesCollectionView)
            
            if let indexPath = filesCollectionView.indexPathForItem(at: touchPoint) {
                // Handle the long press on the cell here
                showDeleteOption(indexPath: indexPath)
            }
        }
    }
    
    // Show delete option (alert, action sheet, etc.)
    func showDeleteOption(indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Delete File", message: "Are you sure you want to delete this file?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            // Perform deletion logic here
            self?.deleteFile(at: indexPath)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Delete image at specific index path
    func deleteFile(at indexPath: IndexPath) {
        let fileToDelete = filesDataList[indexPath.item] // Get the image to delete from your data source
        
        // Find the index of the item you want to remove
        if let indexToRemove = retrievedfileList.firstIndex(of: fileToDelete.fileName) {
            // Remove the item at the found index
            retrievedfileList.remove(at: indexToRemove)
        }
        
        // Convert the array of strings to a single string representation
        let combinedImageNameStrings = retrievedfileList.joined(separator: "\n")

        // Convert the string to Data
        if let data = combinedImageNameStrings.data(using: .utf8) {
            // Create a reference to a file in Firebase Storage within the "index" folder
            let imageListRef = storage.child("index/fileList.txt")

            // ---------Upload the file data to Firebase Storage--------
            imageListRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    print("Error uploading: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("File uploaded successfully! Metadata: \(metadata)")
                
                // --------------Remove the image from Firebase Storage-------------------
                let storageRef = Storage.storage().reference().child("files/\(fileToDelete.fileName)") // Adjust the reference path as per your Firebase Storage structure
                storageRef.delete { error in
                    if let error = error {
                        print("Error deleting image: \(error.localizedDescription)")
                        // Handle error condition here
                    } else {
                        // Image deleted successfully from Firebase Storage
                        // Now remove it from your local data source and collection view
                        self.filesDataList.remove(at: indexPath.item)
                        self.filesCollectionView.deleteItems(at: [indexPath])
                        
                        //------------------Retrieve imageList, new url and image and update photosDataList-----------------
                        //self.retriveNewImageInformation()
                        //print("PhotosDataList updated by imagePickerController.")
                        
                        self.filesCollectionView.reloadData()
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
        searchController.searchBar.placeholder = "Search by file name"
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
    
    func addToFileDataList()
    {
        // Ensure the lists are of the same count and non-empty before processing
        print("List Counts:")
        print("retrievedfileList count: \(self.retrievedfileList.count)")
        print("retrievedUIImagesList count: \(self.retrievedUIImagesList.count)")
        print("retrievedFileURLs count: \(self.retrievedFileURLs.count)")
        
        print("URLs retrieved: \(self.retrievedFileURLs)")
        
        if (self.retrievedfileList.count == self.retrievedUIImagesList.count && self.retrievedfileList.count == self.retrievedFileURLs.count && !self.retrievedfileList.isEmpty)
        {
            for index in 0..<self.retrievedfileList.count
            {
                let fileName = self.retrievedfileList[index]

                let currentFile = FileData(fImage: fileImageDictionary[fileName]!, fName: fileName, fURL: fileUrlDictionary[fileName]!)
                
                self.filesDataList.append(currentFile)
                print("FilesDataList updated.")
                
                //Reload the view controller with the new file that was now added to the database.
                self.filesCollectionView.reloadData()
                
            }
        }
    }
    
    //This function will retreive all the imageURLS from the database using the list of image names
    func retrieveFilesInformation()
    {
        
        //------------------Retrieve ImageList-------------------
        var fileList = [String]()
        
        // Reference to the file in Firebase Storage
        let fileListRef = storage.child("index/fileList.txt")

        // Download the imageList file
        fileListRef.getData(maxSize: 1 * 1024 * 1024)
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
                    fileList = fileContents.components(separatedBy: "\n") //imageList gets retrieved and updated by this point
                    
                    //ADDING TO DICTIONARY
                    for name in fileList {
                        self.fileUrlDictionary[name] = ""
                        self.fileImageDictionary[name] = UIImage()
                    }
                    
                    //print("urlDictionary: \(self.urlDictionary)")
                    //print("imageDictionary: \(self.imageDictionary)")
                    
                    self.retrievedfileList = fileList // update retrievedimageList
                    print("Retrieved all file names from fileList: \(self.retrievedfileList)")
                    print("Updated retrievedfileList.")
        
                    //------------------Retrieve urls and images-----------------
                    for fileName in fileList
                    {
                        let fileRef = self.storage.child("files/" + fileName) //name of the image we will retrieve
                        
                            // ------------------Fetch download URL for each image------------------
                            fileRef.downloadURL { url, error in
                                if let error = error {
                                    print("Error fetching URL for \(fileName): \(error.localizedDescription)")
                                }
                                else if let url = url
                                {
                                    print("Retrieving URL and IMAGE for: \(fileName)...")
                                    //print("Image url: \(url.absoluteString)")
                                    //print("")
                                    
                                    // Append retrieved download URL to the array so we can check later if everything was downloaded
                                    
                                    let retrievedURL = url.absoluteString
                                    
                                    self.retrievedFileURLs.append(retrievedURL)
                                    
                                    //Match the downloaded url to the file name
                                    if self.fileUrlDictionary.keys.contains(fileName)
                                    {
                                        self.fileUrlDictionary[fileName] = retrievedURL
                                    }
                                    
                                    // retrieved download URL
                                    //let retrievedDocumentName = retrievedURL
                                    let retrievedDocumentExtension = url.pathExtension
                                    
                                    print("retrievedDocumentExtension: \(retrievedDocumentExtension)")
                                    
                                    //Pick image from assets
                                    var fileImageType = UIImage(named: "txt")
                                    
                                    if retrievedDocumentExtension == "pdf"
                                    {
                                        fileImageType = UIImage(named: "pdf")
                                    }
                                    else if retrievedDocumentExtension == "docx"
                                    {
                                        fileImageType = UIImage(named: "docx")
                                    }
                                    else if retrievedDocumentExtension == "mp3"
                                    {
                                        fileImageType = UIImage(named: "mp3")
                                    }
                                    else if retrievedDocumentExtension == "csv"
                                    {
                                        fileImageType = UIImage(named: "csv")
                                    }
                                    
                                    if let fileImageTypeAsData = fileImageType!.pngData() {
                                        // Now you have the image data, you can use it to create a new UIImage
                                        let fileImage = UIImage(data: fileImageTypeAsData)
                                        
                                        // Append retrieved image to the array so we can check later if everything was downloaded
                                        self.retrievedUIImagesList.append(fileImage!)
                                        
                                        // Use the newImage as needed
                                        //Match the downloaded url to the file name
                                        if self.fileUrlDictionary.keys.contains(fileName)
                                        {
                                            self.fileImageDictionary[fileName] = fileImage
                                        }
                                    }
                                    
                                    // Check if all image URLs are retrieved
                                    //if self.retrievedImageURLs.count == imageList.count
                                    if self.retrievedFileURLs.count == fileList.count
                                    {
                                        // All image URLs are retrieved, do something with retrievedImageURLs array
                                        // Now you have an array of image URLs to work with
                                        // You can use these URLs to load images asynchronously
                                        print("All file URLs retrieved: \(self.retrievedFileURLs)")
                                        print("urlDictionary: \(self.fileUrlDictionary)")
                                        
                                        
                                        self.addToFileDataList()
                                        
                                    }
                                    
                                }
                            } //end of downloadURL
            
                    } // end of for loop
                    
                } // end of second if
            } //end of first if
        } // end of download ImageList file
        
    } // end of retrieveImageUrlsAndData
    
    func retriveNewFileInformation()
    {
        //------------------Retrieve urls and images-----------------
        print("Retrieving URL and IMAGE for: \(String(describing: self.newFileName))...")
        let imageRef = self.storage.child("files/" + self.newFileName!) //name of the files we will retrieve
                        
        // ------------------Fetch download URL for each file------------------
        imageRef.downloadURL
        { url, error in
            if let error = error
            {
                print("Error fetching URL for \(String(describing: self.newFileName)): \(error.localizedDescription)")
            }
            else if let url = url
            {
                // retrieved download URL
                                    
                let newImageUrl = url.absoluteString
                
                // retrieved download URL
                //let retrievedNewDocumentName = newImageUrl
                let retrievedNewDocumentExtension = url.pathExtension
                print("retrievedNewDocumentExtension: \(retrievedNewDocumentExtension)")
                
                //Pick image from assets
                var fileImageType = UIImage(named: "txt")
                
                if retrievedNewDocumentExtension == "pdf"
                {
                    fileImageType = UIImage(named: "pdf")
                }
                else if retrievedNewDocumentExtension == "docx"
                {
                    fileImageType = UIImage(named: "docx")
                }
                else if retrievedNewDocumentExtension == "mp3"
                {
                    fileImageType = UIImage(named: "mp3")
                }
                else if retrievedNewDocumentExtension == "csv"
                {
                    fileImageType = UIImage(named: "csv")
                }
                
                if let fileImageTypeAsData = fileImageType!.pngData() {
                    // Now you have the image data, you can use it to create a new UIImage
                    let newfileImage = UIImage(data: fileImageTypeAsData)
                    
                    // Use the newImage as needed
                    // update fileDataList
                    let newFileData = FileData(fImage: newfileImage!, fName: self.newFileName!, fURL: newImageUrl)
                    self.filesDataList.append(newFileData)
                    print("FilesDataList updated.")
                    
                    //Reload the view controller with the new image that was now added to the database.
                    self.filesCollectionView.reloadData()
                }
                
            } //end of first if
        } // end of download ImageList file
        
    } // end of retriveNewImageInformation
    
    //This function stores the imageList as a txt file in the database
    func storeFileListAsTxt(updatedFileList: [String])
    {
        // Convert the array of strings to a single string representation
        let combinedFileNameStrings = updatedFileList.joined(separator: "\n")

        // Convert the string to Data
        if let data = combinedFileNameStrings.data(using: .utf8) {
            // Create a reference to a file in Firebase Storage within the "index" folder
            let fileListRef = storage.child("index/fileList.txt")

            // Upload the data to Firebase Storage
            fileListRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    print("Error uploading: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("File uploaded successfully! Metadata: \(metadata)")
                
                //------------------Retrieve imageList, new url and image and update photosDataList-----------------
                self.retriveNewFileInformation()
                print("FilesDataList updated by documentPickerController.")
            }
        }
    } // end of function storeImageListAsTxt
    
    
    //Function that will call the imagePickerController allowing a user to pick an image
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
         guard let selectedURL = urls.first else {
             return
         }
        
        print("Document Picker Controller Was Called.")
        controller.dismiss(animated: true, completion: nil)
        
        
        //download file data from the selected url
        let fileData: Data
        do {
            fileData = try Data(contentsOf: selectedURL)
        } catch {
            print("Error reading file data: \(error)")
            return
        }
        
        //-----------------------------ADDING NEW FILE NAME WITH EXTENSION------------------------
        //---Checking list so we know what the current file name is and adding a new file name to the list---
        
        let pickedDocumentName = selectedURL.lastPathComponent
        newFileName = pickedDocumentName // set it to newFileName so we can use it in retriveNewFileInformation function

        
        // Append the new file name to the list
        retrievedfileList.append(pickedDocumentName)
        
        print("DocumentPickerController updated retrievedFileList.")
        print("New retrieved file list: \(retrievedfileList) ")
        
        
        //------Putting the file chosen from the filePickerController into the storage address-----
        //We access the last element of the updatedFileList which has the newly created name for our file
        storage.child("files/" + retrievedfileList[retrievedfileList.count - 1]).putData(fileData, metadata: nil , completion:
        { _, error in
            guard error == nil else
            {
                print("Failed to upload")
                return
            }
        }) // end of storage.child
        print("File Picker Uploaded the picked file.")
        
        
        
        //----------------We store the fileList in the database as a .txt file and Retrieve information---------------
        storeFileListAsTxt(updatedFileList: retrievedfileList) // This stores imageList and retrieves
        //print("Image Picker Controller updated imageList.txt")
        
    } // end of function pickerController
    
    // Cancels the imagePicker if the user canceled
    func documentPickerControllerDidCancel(_ controller: UIDocumentPickerViewController) {
        print("Document picker was cancelled")
    }
} // end of class


extension FilesViewController: UICollectionViewDelegate, UICollectionViewDataSource, UISearchResultsUpdating, UISearchBarDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !isLongPressGesture {
            print("FILE CLICKED: \(indexPath.row)")
            
            let url = URL(string: filesDataList[indexPath.row].fileURL)
            
            UIApplication.shared.open(url!) // opens in safari
            
            //Opens to use other apps (such as pages)
            //let documentController = UIDocumentInteractionController(url: url!)
            //documentController.delegate = self // Set the delegate
            //documentController.presentPreview(animated: true)
        }
        isLongPressGesture = false // Reset the flag after handling selection or long press
    } //end of function
    
    // Implement the delegate method
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self // Return the view controller to present the preview
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if searching {
            return searchedImage.count
        }
        else {
            return filesDataList.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = filesCollectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! FilesCollectionViewCell
        
        if searching
        {
            cell.fileViewCell.image = searchedImage[indexPath.row].fileImage
            cell.labelCell.text = searchedImage[indexPath.row].fileName
        }
        else
        {
            cell.fileViewCell.image = filesDataList[indexPath.row].fileImage
            cell.labelCell.text = filesDataList[indexPath.row].fileName
        }
        
        return cell
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text!
        
        if !searchText.isEmpty
        {
            searching = true
            searchedImage.removeAll()
            
            for photo in filesDataList
            {
                if photo.fileName.lowercased().contains(searchText.lowercased())
                {
                    searchedImage.append(photo)
                }
            }
        }
        else
        {
            searching = false
            searchedImage.removeAll()
            searchedImage = filesDataList
        }
        filesCollectionView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searching = false
        searchedImage.removeAll()
        filesCollectionView.reloadData()
    }
}

