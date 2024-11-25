import requests
import os
import pandas as pd
import numpy as np

# Send frames to Face++ and store response
def process_frame(frame_path):
    with open(frame_path, 'rb') as f:
        img_data = f.read()

    data = {
        'api_key': API_KEY,
        'api_secret': API_SECRET,
        'return_attributes': 'age,gender,beauty,emotion'
    }

    files = {'image_file': img_data}

    response = requests.post(FACEPP_URL, data=data, files=files)
    return response.json()


# This function filters frames without emotional responses
# It was primarily written to fileter frames where the lecturer 
# is not facing the camera or that didn't catch the lecturer

# Since we choose videos always with the lecturer being the largest, 
# we don't need facial recognition

# Filter empty frames
def is_professor_facing_camera(face_data):
    # Check if emotion data is present
    # If not, no clear face facing the camera detected
    return 'emotion' in face_data['attributes']