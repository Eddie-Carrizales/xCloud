//
//  PhotosViewController.swift
//  xCloud
//
//  Created by Eddie Carrizales on 10/26/23.
//

import UIKit
import FirebaseStorage
import AVFoundation
import MobileCoreServices
import Photos


class VideosViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //-----------------------Connected Outlets-----------------------
    
    @IBOutlet weak var videosCollectionView: UICollectionView!
    
    
    //-----------------------Global Variables-----------------------
    //Firebase Storage
    private let storage = Storage.storage().reference()
    
    
    //List of type ImageData that will store the image and its name (so we can show them together on the each cell)
    var videosDataList = [VideoData]()
    
    //List that will store the image names, to determine what we have in the database
    var retrievedvideoList = [String]()
    
    // An array to store retrieved image URLs
    var retrievedVideoURLs: [String] = []
    
    // An array to store retrieved images
    var retrievedUIImagesList: [UIImage] = []
    
    var retrievedJsonObjectsList: [[String]] = []
    
    //Searching variables
    let searchController = UISearchController(searchResultsController: nil)
    var searching = false
    var searchedImage = [VideoData]()
    
    var newVideoName: String = ""

    var urlString = ""
    
    //Dictionaries
    var urlDictionary = [String: String]()
    var imageDictionary = [String: UIImage]() //STORE IMAGES OR VIDEOS?
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
        
        requestVideoPermissions()
        
        
        // Adds the search bar to our screen
        navigationItem.searchController = searchController
        
        videosCollectionView.addGestureRecognizer(longPressGesture)

        configureSearchController()
        retrieveVideosInformation()
        //Fetch the data from the database to show it in the controller
        //Steps:
        //1: Fetch the imageList, the urls and imageData
        
        // Create a Timer that fires every 15 seconds
        //let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            
            //self.retrieveJsonInformation()
        //}
        
        // To make sure the timer fires when the program starts
        //RunLoop.main.add(timer, forMode: .common)
        
        print("VIEW DID LOAD.")
        
        //2. if the user clicks on the imagePicker, then we check last name on our image list we had already fetched, and we create a new name and we upload that name to the database (the picture we pick will also be uploaded to the database with that new name)
        //This step is done in imagePickerController function
        
        
        //3. After adding that name to the database, we want to fetch the urls and imageData again from the data and re-download because now there is a new name and a new image.
        //This step is done in imagePickerController function
    }
    
    //----------------------- Action & Object Functions -----------------------
    @IBAction func didTapUpload(_ sender: UIButton)
    {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeMovie as String] // Specify media types (videos)
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    // Handle long press on collection view cell
    @objc func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let touchPoint = gesture.location(in: self.videosCollectionView)
            
            if let indexPath = videosCollectionView.indexPathForItem(at: touchPoint) {
                // Handle the long press on the cell here
                showDeleteOption(indexPath: indexPath)
            }
        }
    }
    
    // Show delete option (alert, action sheet, etc.)
    func showDeleteOption(indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Delete Image", message: "Are you sure you want to delete this video?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            // Perform deletion logic here
            self?.deleteImage(at: indexPath)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    // Delete video at specific index path
    func deleteImage(at indexPath: IndexPath) {
        let imageToDelete = videosDataList[indexPath.item] // Get the video to delete from your data source
        
        // Find the index of the item you want to remove
        if let indexToRemove = retrievedvideoList.firstIndex(of: imageToDelete.videoName) {
            // Remove the item at the found index
            retrievedvideoList.remove(at: indexToRemove)
        }
        
        // Convert the array of strings to a single string representation
        let combinedImageNameStrings = retrievedvideoList.joined(separator: "\n")

        // Convert the string to Data
        if let data = combinedImageNameStrings.data(using: .utf8) {
            // Create a reference to a file in Firebase Storage within the "index" folder
            let imageListRef = storage.child("index/videoList.txt")

            // ---------Upload the file data to Firebase Storage--------
            imageListRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    print("Error uploading: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("File uploaded successfully! Metadata: \(metadata)")
                
                // --------------Remove the image from Firebase Storage-------------------
                let storageRef = Storage.storage().reference().child("videos/\(imageToDelete.videoName)") // Adjust the reference path as per your Firebase Storage structure
                storageRef.delete { error in
                    if let error = error {
                        print("Error deleting image: \(error.localizedDescription)")
                        // Handle error condition here
                    } else {
                        // Image deleted successfully from Firebase Storage
                        // Now remove it from your local data source and collection view
                        self.videosDataList.remove(at: indexPath.item)
                        self.videosCollectionView.deleteItems(at: [indexPath])
                        
                        //------------------Retrieve imageList, new url and image and update photosDataList-----------------
                        //self.retriveNewImageInformation()
                        //print("PhotosDataList updated by imagePickerController.")
                        
                        self.videosCollectionView.reloadData()
                    }
                }

            } // end of upload file to database
        }
    } // end of delete image function
    
    //----------------------- Other Functions -----------------------
    func requestVideoPermissions() {
            // Request access to the photo library
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    print("Photo library access granted")
                    // Access to photo library granted, you can proceed
                case .denied, .restricted:
                    print("Photo library access denied")
                    // Handle denied or restricted access
                case .notDetermined:
                    print("Photo library access not determined")
                    // The user hasn't yet made a choice
                @unknown default:
                    break
                }
            }
            
            // Request access to the camera
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    print("Camera access granted")
                    // Camera access granted, you can proceed to capture videos
                } else {
                    print("Camera access denied")
                    // Handle denied access to the camera
                }
            }
        }
    
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
    func givePickedVideoName(retrievedvideoList: [String]) -> [String]
    {
        var videoListTemp = [String]()
        videoListTemp = retrievedvideoList //add what we already have (we have to do this because we cannot mutate retrievedimageList directly since its passed)
        
        var videoName: String?
        print("videoListTemp: \(videoListTemp)")
        //gets the number from the last image in the imageList
        if let lastImage = videoListTemp.last
        {
            
            let digitsAfterUnderscore = extractDigits(from: lastImage)
            // Attempt to convert the substring to an integer
            if let imageNumber = Int(digitsAfterUnderscore)
            {
                // Add 1 to the extracted number
                let newVideoNumber = imageNumber + 1
                    
                videoName = "VIDEO_" + String(newVideoNumber) + ".mp4"
                print("New Video Name: " + videoName!)
                newVideoName = videoName!
                    
                // Append the new video name to the list
                videoListTemp.append(videoName!)
            }
            else
            {
                // Handle the case where the substring after underscore is not convertible to an integer
                print("Error: Unable to extract a valid number from the video name.")
            }
        }
        return videoListTemp
    } // end of function givePickedVideoName
    
    func addToVideoDataList()
    {
        // Ensure the lists are of the same count and non-empty before processing
        print("List Counts:")
        print("retrievedvideoList count: \(self.retrievedvideoList.count)")
        print("retrievedUIImagesList count: \(self.retrievedUIImagesList.count)")
        print("retrievedVideoURLs count: \(self.retrievedVideoURLs.count)")
        
        print("URLs retrieved: \(self.retrievedVideoURLs)")
        
        if (self.retrievedvideoList.count == self.retrievedUIImagesList.count && self.retrievedvideoList.count == self.retrievedVideoURLs.count && !self.retrievedvideoList.isEmpty)
        {
            for index in 0..<self.retrievedvideoList.count
            {
                let videoName = self.retrievedvideoList[index]

                let currentVideo = VideoData(fImage: imageDictionary[videoName]!, fName: videoName, fURL: urlDictionary[videoName]!, fObjects: jsonObjectsDictionary[videoName]!)
                
                self.videosDataList.append(currentVideo)
                print("VideosDataList updated.")
                
                //Reload the view controller with the new image that was now added to the database.
                self.videosCollectionView.reloadData()
                
            }
        }
    }
    
    //This function will retreive all the video URLS from the database using the list of video names
    func retrieveVideosInformation()
    {
        
        //------------------Retrieve ImageList-------------------
        var videoList = [""]
        
        // Reference to the file in Firebase Storage
        let videoListRef = storage.child("index/videoList.txt")

        // Download the videoList file
        videoListRef.getData(maxSize: 1 * 1024 * 1024)
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
                    videoList = fileContents.components(separatedBy: "\n") //imageList gets retrieved and updated by this point
                    
                    //ADDING TO DICTIONARY
                    for name in videoList {
                        self.urlDictionary[name] = ""
                        self.imageDictionary[name] = UIImage()
                        self.jsonObjectsDictionary[name] = [""]
                    }
                    
                    //print("urlDictionary: \(self.urlDictionary)")
                    //print("imageDictionary: \(self.imageDictionary)")
                    
                    self.retrievedvideoList = videoList // update retrievedimageList
                    print("\nRetrieved all video names from videoList: \(videoList)")
                    print("Updated retrievedvideoList.")
                    print("\n")
        
                    //------------------Retrieve urls and images-----------------
                    for videoName in videoList
                    {
                        let videoRef = self.storage.child("videos/" + videoName) //name of the video we will retrieve
                        
                            // ------------------Fetch download URL for each image------------------
                            videoRef.downloadURL { url, error in
                                if let error = error {
                                    print("Error fetching URL for \(videoName): \(error.localizedDescription)")
                                }
                                else if let url = url
                                {
                                    // Append retrieved download URL to the array so we can check later if everything was downloaded
                                    self.retrievedVideoURLs.append(url.absoluteString)
                                    
                                    //Match the downloaded url to the image name
                                    if self.urlDictionary.keys.contains(videoName)
                                    {
                                        self.urlDictionary[videoName] = url.absoluteString
                                    }
                                    
                                    print("Retrieving URL and Video for: \(videoName)...")
                                    //print("Image url: \(url.absoluteString)")
                                    //print("")
                                    
                                    // Check if all image URLs are retrieved
                                    //if self.retrievedImageURLs.count == imageList.count
                                    if self.retrievedVideoURLs.count == videoList.count
                                    {
                                        // All image URLs are retrieved, do something with retrievedImageURLs array
                                        // Now you have an array of image URLs to work with
                                        // You can use these URLs to load images asynchronously
                                        print("\nAll video URLs retrieved: \(self.retrievedVideoURLs)")
                                        print("\nurlDictionary: \(self.urlDictionary)")
                                        
                                    }
                                    
                                    // ------------------ Download video thumbnail data ------------------
                                    let asset = AVAsset(url: url)
                                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                                    
                                    // Set the time of the frame you want as a thumbnail (e.g., 1 second into the video)
                                    let time = CMTime(seconds: 1, preferredTimescale: 60) // Adjust the time as needed
                                    
                                    do {
                                        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                                        let thumbnail = UIImage(cgImage: cgImage)
                                        
                                        // Append retrieved image to the array so we can check later if everything was downloaded
                                        self.retrievedUIImagesList.append(thumbnail)
                                        
                                        //Match the downloaded thumbnail to the video name
                                        if self.imageDictionary.keys.contains(videoName)
                                        {
                                            self.imageDictionary[videoName] = thumbnail
                                        }
                                        
                                        // Check if all images are retrieved
                                        if self.retrievedUIImagesList.count == videoList.count
                                        {
                                            // All images are retrieved, do something with retrievedImages array
                                            print("\nAll video thumbnails retrieved: \(self.retrievedUIImagesList)")
                                            print("\nimagesDictionary: \(self.imageDictionary)")
                                            
                                            // ------------update photosDataList---------
                                            self.addToVideoDataList()
                                            
                                            //------------------------------------------
                                        }
                                        
                                    } catch {
                                        print("Error generating thumbnail: \(error.localizedDescription)")
                                    }
                                    
                                    
                                } // end of else url
                            } //end of downloadURL
            
                    } // end of for loop
                    
                } // end of second if
            } //end of first if
        } // end of download ImageList file
        
    } // end of retrieveImageUrlsAndData
    
    
    func retrieveJsonInformation()
    {
        //------------------Retrieve VideoList-------------------
        var videoList = [""]
        
        // Reference to the file in Firebase Storage
        let videoListRef = storage.child("index/videoList.txt")

        // Download the imageList file
        videoListRef.getData(maxSize: 1 * 1024 * 1024)
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
                    videoList = fileContents.components(separatedBy: "\n") //videoList gets retrieved and updated by this point
                    
                    //------------------JSON-----------------
                    for videoName in videoList
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
                                            if let currentVideoName = key.components(separatedBy: "/").last,
                                               let objectsData = value as? [String: Any],
                                               let objects = objectsData["objects"] as? [String] {
                                                
                                                print("\nvideoName: \(videoName)")
                                                print("currentVideoName: \(currentVideoName), objects: \(objects)")
                                                
                                                if currentVideoName == videoName {
                                                    // Iterate through the videosDataList
                                                    for (index, videoData) in self.videosDataList.enumerated() {
                                                        if videoData.videoName == videoName {
                                                            print("JSON UPDATING VIDEOS DATA LIST")
                                                            print("videoName: \(videoName), Added Objects: \(objects)")
                                                            print("VideosDataList Before: \(videosDataList)")
                                                            let modifiedImageData = videoData
                                                            modifiedImageData.videoObjects = objects
                                                            self.videosDataList[index] = modifiedImageData // Update the modified data
                                                            print("VideosDataList After: \(self.videosDataList)")
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
    
    
    func retriveNewVideoInformation()
    {
        //------------------Retrieve urls and images-----------------
        print("Retrieving URL and VIDEO THUMBNAIL for: \(self.newVideoName)...")
        let videoRef = self.storage.child("videos/" + self.newVideoName) //name of the image we will retrieve
                        
        // ------------------Fetch download URL for each image------------------
        videoRef.downloadURL { url, error in
            if let error = error
            {
                print("Error fetching URL for \(self.newVideoName): \(error.localizedDescription)")
            }
            else if let newVideoUrl = url
            {
                // retrieved download URL
                print("newVideoUrl: \(newVideoUrl)")
                let newVideoUrlString = newVideoUrl.absoluteString
                
                // ------------------ Download video thumbnail data ------------------
                let asset = AVAsset(url: newVideoUrl)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                
                // Set the time of the frame you want as a thumbnail (e.g., 1 second into the video)
                let time = CMTime(seconds: 1, preferredTimescale: 60) // Adjust the time as needed
                
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    
                    // retrieved image
                    let newThumbnailImage = thumbnail
                    
                    // ------------update photosDataList---------
                    
                    let newVideoData = VideoData(fImage: newThumbnailImage, fName: self.newVideoName, fURL: newVideoUrlString, fObjects: ["No Objects Found"])
                    
                    self.videosDataList.append(newVideoData)
                    print("VideosDataList updated.")
                    
                    //Reload the view controller with the new image that was now added to the database.
                    self.videosCollectionView.reloadData()
                    //------------------------------------------
                    
                    } catch {
                        print("Error generating thumbnail: \(error.localizedDescription)")
                    }
                } //end of else
            } // end of download video url
    } // end of retriveNewImageInformation
    
    //This function stores the imageList as a txt file in the database
    func storeVideoListAsTxt(updatedVideoList: [String])
    {
        // Convert the array of strings to a single string representation
        let combinedVideoNameStrings = updatedVideoList.joined(separator: "\n")

        // Convert the string to Data
        if let data = combinedVideoNameStrings.data(using: .utf8) {
            // Create a reference to a file in Firebase Storage within the "index" folder
            let videoListRef = storage.child("index/videoList.txt")

            // Upload the data to Firebase Storage
            videoListRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    print("Error uploading: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("File uploaded successfully! Metadata: \(metadata)")
                
                //------------------Retrieve imageList, new url and image and update videosDataList-----------------
                
                self.retriveNewVideoInformation()
            }
        }
    } // end of function storeImageListAsTxt
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Video Picker Controller Was Called.")
            
            picker.dismiss(animated: true, completion: nil)
            
            if let videoURL = info[.mediaURL] as? URL {
                print("videoURL: \(videoURL)")
                print("videoURL Extension: \(videoURL.pathExtension)")
                
                retrievedvideoList = givePickedVideoName(retrievedvideoList: retrievedvideoList)
                print("ImagePickerController updated retrievedVideoList.")
                print("New retrieved video list: \(retrievedvideoList) ")
                
                do {
                    let videoData = try Data(contentsOf: videoURL)
                    let newVideoName = retrievedvideoList[retrievedvideoList.count - 1]
                    print("newVideoName: \(newVideoName)")
                    
                    let storageRef = storage.child("videos/" + newVideoName) // Adjust file name as needed
                            
                            storageRef.putData(videoData, metadata: nil) { metadata, error in
                                if let error = error {
                                    print("Error uploading video: \(error.localizedDescription)")
                                    // Handle the upload error
                                } else {
                                    print("Video uploaded successfully.")
                                    
                                    // Store the updated video list in the database as a .txt file and retrieve information
                                    self.storeVideoListAsTxt(updatedVideoList: self.retrievedvideoList)
                                }
                            }
                } catch {
                    print("Error converting video to Data: \(error.localizedDescription)")
                }
            } else {
                // Inform the user that the selected video is not an MP4
                print("Failed to upload video.")
            }
        }
    
    // Cancels the imagePicker if the user canceled
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        picker.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowNextViewController",
           let destinationViewController = segue.destination as? VideosCellViewController,
           let indexPath = sender as? IndexPath {
            
            print("IN SEGUE")
            
            let selectedImage = videosDataList[indexPath.row].videoImage
            let labelText = videosDataList[indexPath.row].videoName
            let objectsList = videosDataList[indexPath.row].videoObjects
            let urlList = videosDataList[indexPath.row].videoURL
            
            print("labelText: \(labelText)")
            
            destinationViewController.receivedImage = selectedImage
            destinationViewController.receivedLabelText = labelText
            destinationViewController.receivedObjectsList = objectsList
            destinationViewController.receivedUrl = urlList
        }
    }
    
} // end of class


extension VideosViewController: UICollectionViewDelegate, UICollectionViewDataSource, UISearchResultsUpdating, UISearchBarDelegate
{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("PERFORMING SEGUE")
        performSegue(withIdentifier: "ShowNextViewController", sender: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if searching {
            return searchedImage.count
        }
        else {
            return videosDataList.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = videosCollectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! VideosCollectionViewCell
        
        if searching
        {
            cell.imageViewCell.image = searchedImage[indexPath.row].videoImage
            //cell.labelCell.text = searchedImage[indexPath.row].photoName
        }
        else
        {
            cell.imageViewCell.image = videosDataList[indexPath.row].videoImage
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
            for video in videosDataList
            {
                if video.videoName.lowercased().contains(searchText.lowercased())
                {
                    searchedImage.append(video)
                }
                else
                {
                    //searches all objects inside photos
                    for anObject in video.videoObjects
                    {
                        if anObject.lowercased().contains(searchText.lowercased())
                        {
                            searchedImage.append(video)
                        }
                    }
                }
            }
        }
        else
        {
            searching = false
            searchedImage.removeAll()
            searchedImage = videosDataList
        }
        videosCollectionView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searching = false
        searchedImage.removeAll()
        videosCollectionView.reloadData()
    }
}

