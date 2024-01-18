#from firebase import Firebase

import firebase_admin
from firebase_admin import credentials, storage
from ultralytics import YOLO
import json
import time
# import torch



# YOLO Model
model = YOLO("yolov8x.pt")
names = model.names
# model = torch.hub.load("ultralytics/yolov5", "yolov5x6")


# Download the JSON file from Firebase Storage
def download_json_from_storage(file_path):
      blob = storage.bucket().get_blob(file_path)
      if blob:
            json_data = blob.download_as_text()
            return json.loads(json_data)
      else:
            print(f"File {file_path} not found.")
            return None
      
# Upload the modified JSON data back to Firebase Storage
def upload_json_to_storage(file_path, json_data):
      blob = storage.bucket().blob(file_path)
      blob.upload_from_string(json.dumps(json_data), content_type='application/json')

def process_image(bucket, img_file, ml_status, ml_status_path):

      #for img_file in image_blobs:

      if ml_status.get(img_file.name)==None or not ml_status[img_file.name]['analyzed']:

            print('\nAnalyzing '+img_file.name)

            if ml_status.get(img_file.name)==None:
                  ml_status[img_file.name] = dict()
                  ml_status[img_file.name]['analyzed'] = False

            img_file_ext = '.'+img_file.name.split('.')[-1]
            processing_file_name = 'downloaded_file'+img_file_ext
            # processing_file_name = img_file.name.split('/')[1]

            bucket.blob(img_file.name).download_to_filename(processing_file_name)

            result = model(processing_file_name, verbose = False)[0]
            # result = model(processing_file_name)

            class_list = list(set([names[int(cls)] for cls in result.boxes.cls]))

            print(class_list)

            ml_status[img_file.name]['analyzed'] = True
            ml_status[img_file.name]['objects'] = class_list

            upload_json_to_storage(ml_status_path, ml_status)

            #return class_list

def process_video(bucket, vid_file, ml_status, ml_status_path):
      if ml_status.get(vid_file.name)==None or not ml_status[vid_file.name]['analyzed']:

            print('\nAnalyzing '+vid_file.name)

            if ml_status.get(vid_file.name)==None:
                  ml_status[vid_file.name] = dict()
                  ml_status[vid_file.name]['analyzed'] = False

            img_file_ext = '.'+vid_file.name.split('.')[-1]
            processing_file_name = 'downloaded_file'+img_file_ext
            # processing_file_name = img_file.name.split('/')[1]

            bucket.blob(vid_file.name).download_to_filename(processing_file_name)

            results = model(processing_file_name, stream = True, verbose = False)
            # result = model(processing_file_name)

            class_list = set()

            for result in results:

                  class_list.update(list(set([names[int(cls)] for cls in result.boxes.cls])))

            print(class_list)

            ml_status[vid_file.name]['analyzed'] = True
            ml_status[vid_file.name]['objects'] = class_list

            upload_json_to_storage(ml_status_path, ml_status)

# Save the JSON data to a local file for testing
def save_json_locally(json_data):
      file_path = 'downloaded_ml_status.json'
      with open(file_path, 'w') as file:
            json.dump(json_data, file, indent=2)

def core(ml_status, ml_status_path):
      bucket = storage.bucket()

      while True:
            file_blobs = list(bucket.list_blobs())[1:]

            for blob in file_blobs:
                  blob_name = blob.name
                  blob_type = blob_name.split('/')[0]
                  if blob_type == "images" and len(blob_name)>7: 
                        process_image(bucket, blob, ml_status, ml_status_path)
                  elif blob_type == "videos" and len(blob_name)>7:
                        process_video(bucket, blob, ml_status, ml_status_path)
                  else:
                        continue

            # To view updated json locally
            save_json_locally(ml_status)

            time.sleep(10)


if __name__=="__main__":
      # Initialize credentials
      cred = credentials.Certificate("./xcloud-6899f.json")
      firebase_admin.initialize_app(cred,{'storageBucket': 'xcloud-6899f.appspot.com'})

      # Set variables
      # img_file = 'images/IMAGE_1.png'
      # img_file_ext = img_file.split('.')[-1]
      # processing_file_name = 'downloaded_file.'+img_file_ext
      ml_status_path = "index/ml_status.json"

      # Get classification status JSON file
      ml_status = download_json_from_storage(ml_status_path)

      # print(type(ml_status['images/IMAGE_0.png']))

      # ml_status['images/IMAGE_0']['analyzed'] = False

      # print(ml_status)

      # upload_json_to_storage(ml_status_path, ml_status)

      core(ml_status, ml_status_path)

      


# config = {
#   "apiKey": "AIzaSyC5sRRQyyMW6HXPCtLT5XykEhpbGTazV4g",
#   "authDomain": "xcloud-6899f.firebaseapp.com", #"projectId.firebaseapp.com",
#   "projectId": "xcloud-6899f", 
#   #"databaseURL": "xcloud-6899f.appspot.com/images",
#   "storageBucket": "xcloud-6899f.appspot.com"
# }

# firebase = Firebase(config)