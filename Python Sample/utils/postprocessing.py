import os
import pandas as pd
import numpy as np
import cv2


# Annotate Frames
# Here we just want the largest frame since we just want to analyze the lecturer (acceptably with minor errors)
def annotate_frame(frame_path, face_data, output_path):

    image = cv2.imread(frame_path)

    # Find the largest face
    largest_face = max(face_data['faces'], key=lambda face: face['face_rectangle']['width'] * face['face_rectangle']['height'])
    rect = largest_face['face_rectangle']
    emotions = largest_face['attributes']['emotion']
    dominant_emotion = max(emotions, key=emotions.get)

    # Get rectangle coordinates
    left = rect['left']
    top = rect['top']
    width = rect['width']
    height = rect['height']

    # Draw bounding box with OpenCV (BGR for color)
    cv2.rectangle(image, (left, top), (left + width, top + height), color=(0, 0, 255), thickness=2)

    # Set font 
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 1.0  
    font_color = (0, 0, 255)  # Red 
    font_thickness = 2

    # Annotate the emotion above the rectangle
    cv2.putText(image, dominant_emotion, (left, top - 10), font, font_scale, font_color, font_thickness)

    # Save the annotated image to the output path
    cv2.imwrite(output_path, image)
    

# Reassemble Frames into a Video
# Note that if frames were not sampled at FPS, 
# this is NOT going to produce the annotated verion of the original video, 
# but would be a sampled version
def frames_to_video(frames_folder, output_video, fps=10):
    
    images = [img for img in os.listdir(frames_folder) if img.endswith(".jpg")]
    images.sort(key=lambda x: int(x.split('_')[1].split('.jpg')[0]))

    frame = cv2.imread(os.path.join(frames_folder, images[0]))
    height, width, layers = frame.shape

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    video = cv2.VideoWriter(output_video, fourcc, fps, (width, height))

    for image in images:
        video.write(cv2.imread(os.path.join(frames_folder, image)))

    cv2.destroyAllWindows()
    video.release()
    
    
# Summarize Attributes
def summarize_attributes(results):
    emotions_list = []
    ages = []
    genders = []
    beauty_scores = []

    for result in results:
        if result['faces']:
            largest_face = max(result['faces'], key=lambda face: face['face_rectangle']['width'] * face['face_rectangle']['height'])
            attributes = largest_face['attributes']

            # Age
            ages.append(attributes['age']['value'])

            # Gender
            genders.append(attributes['gender']['value'])

            # Emotions
            emotions = attributes['emotion']
            emotions_list.append(emotions)

            # Beauty Score
            gender = attributes['gender']['value']
            # In Face++ output, beauty score is splitted into genders
            beauty_score = attributes['beauty']['male_score'] if gender == 'Male' else attributes['beauty']['female_score']
            beauty_scores.append(beauty_score)

    # Create DataFrames
    df_emotions = pd.DataFrame(emotions_list)
    df_ages = pd.Series(ages, name='age')
    df_genders = pd.Series(genders, name='gender')
    df_beauty = pd.Series(beauty_scores, name='beauty_score')

    # Calculate summaries
    emotion_proportions = df_emotions.mean() / df_emotions.mean().sum()
    average_age = df_ages.mean()
    dominant_gender = df_genders.mode()[0]
    average_beauty_score = df_beauty.mean()

    # Prepare the summary
    summary = {
        'dominant_gender': dominant_gender,
        'average_age': average_age,
        'emotion_proportions': emotion_proportions.to_dict(),
        'average_beauty_score': average_beauty_score
    }

    return summary