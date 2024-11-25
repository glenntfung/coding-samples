import os
import pandas as pd
import numpy as np
import cv2


# Get a list of all video files in the specified folder with given extensions
def get_video_files(folder, extensions=('mp4', 'avi', 'mov')):
    return [
        os.path.join(folder, file)
        for file in os.listdir(folder)
        if file.lower().endswith(extensions)
    ]


# Get video properties
def get_video_properties(video_path):
    
    cap = cv2.VideoCapture(video_path)
    
    # Exception
    if not cap.isOpened():
        print("Error: Could not open video.")
        return

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = frame_count / fps

    print(f"Width: {width}px")
    print(f"Height: {height}px")
    print(f"FPS: {fps}")
    print(f"Duration: {duration:.2f} seconds")

    cap.release()
    

# Sample frames, default rate at one frame per 0.1 seconds
# Theoretically, one frame per 0.25 seconds is already sufficient
def extract_frames(video_path, output_folder, sample_rate=0.1):
    
    cap = cv2.VideoCapture(video_path)
    
    # Exception
    if not cap.isOpened():
        print("Error opening video file")
        return

    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps

    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    current_time = 0.0
    saved_count = 0

    while current_time <= duration:
        # Set the video position to the current timestamp in milliseconds
        cap.set(cv2.CAP_PROP_POS_MSEC, current_time * 1000)
        ret, frame = cap.read()
        if not ret:
            break

        cv2.imwrite(os.path.join(output_folder, f"frame_{saved_count}.jpg"), frame)
        saved_count += 1
        # Forcing time with steps at sample rate
        current_time += sample_rate

    cap.release()
    cv2.destroyAllWindows()