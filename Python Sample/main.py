# Functions 
from utils import annotate_frame, summarize_attributes, process_frame, extract_frames, get_video_files # visual analysis
# from utils import frames_to_video, get_video_properties, is_professor_facing_camera # visual not used
from utils import extract_audio, transcribe_audio, predict_emotion, analyze_emotions, apply_softmax, save_transcript, identify_main_speaker, save_main_speaker_transcript # audio and verbal

# Config variables
from config import FPPAPI_KEY, API_SECRET, FACEPP_URL, GOOGLEAPI_KEY

# Packages 
import os
import csv
import pandas

# Variables
frame_rate = 0.1
input_folder = 'videos'  
output_csv = 'video_analysis_results.csv'
output_folder = "analysis_results"


# Function to analyze visually for videos in input folder
def process_videos_in_folder(input_folder, output_csv):

    # Get videos
    video_list = get_video_files(input_folder)

    if not video_list:
        print("No video files found in the specified folder.")
        return

    # Prepare the output CSV file
    print(f"Creating output CSV file: {output_csv}")
    with open(output_csv, 'w', newline='') as csvfile:
        csv_writer = csv.writer(csvfile)
        csv_writer.writerow(['Video', 'Dominant Gender', 'Average Age', 
                             'Emotion Proportions', 'Average Beauty Score'])

        for video_path in video_list:
            video_name = os.path.basename(video_path).split('.')[0]
            print(f"\nProcessing video: {video_path} (name: {video_name})")

            frames_folder = f'frames_{video_name}'
            annotated_frames_folder = f'annotated_frames_{video_name}'

            # Create folders if they don't exist
            if not os.path.exists(frames_folder):
                os.makedirs(frames_folder)
                print(f"Created folder for frames: {frames_folder}")
            if not os.path.exists(annotated_frames_folder):
                os.makedirs(annotated_frames_folder)
                print(f"Created folder for annotated frames: {annotated_frames_folder}")

            # Extract frames
            print(f"Extracting frames from video: {video_path}")
            try:
                extract_frames(video_path, frames_folder, frame_rate)
                print(f"Frames extracted successfully to: {frames_folder}")
            except Exception as e:
                print(f"Error extracting frames from video {video_path}: {e}")
                continue

            # Process frames and annotate
            print("Processing and annotating frames...")
            results = []
            for frame_file in sorted(os.listdir(frames_folder)):
                frame_path = os.path.join(frames_folder, frame_file)
                try:
                    result = process_frame(frame_path)
                    if result['faces']:
                        annotate_frame(
                            frame_path,
                            result,
                            os.path.join(annotated_frames_folder, frame_file)
                        )
                        results.append(result)
                    else:
                        print(f"No faces detected in frame: {frame_path}") # Comment this if expecting too many
                except Exception as e:
                    print(f"Error processing frame {frame_path}: {e}")
                    continue

            # Summarize attributes
            print(f"Summarizing attributes for video: {video_name}")
            try:
                summary = summarize_attributes(results)
                print(f"Summary for {video_name}: {summary}")
            except Exception as e:
                print(f"Error summarizing attributes for video {video_name}: {e}")
                continue

            # Write results to CSV
            print(f"Writing summary to CSV for video: {video_name}")
            try:
                csv_writer.writerow([
                    video_name,
                    summary.get('dominant_gender', 'N/A'),
                    summary.get('average_age', 'N/A'),
                    summary.get('emotion_proportions', 'N/A'),
                    summary.get('average_beauty_score', 'N/A')
                ])
            except Exception as e:
                print(f"Error writing results to CSV for video {video_name}: {e}")
                continue

            print(f"Finished processing video: {video_name}")


            # Clean up the folders if necessary
            # shutil.rmtree(frames_folder)
            # shutil.rmtree(annotated_frames_folder)


# Function to analyze audio and verbal part
# Combined because verbal analysis uses audio results
def process_folder(input_folder, output_folder="output"):
    # Check if input folder exists
    if not os.path.exists(input_folder):
        print(f"Error: Input folder '{input_folder}' does not exist.")
        return

    # Create output folder if it doesn't exist
    if not os.path.exists(output_folder):
        print(f"Output folder '{output_folder}' does not exist. Creating it...")
        os.makedirs(output_folder)

    # Initialize a list to store emotion percentages
    emotion_data = []

    # Process each video file in the input folder
    for video_file in os.listdir(input_folder):
        if video_file.endswith((".mp4", ".mkv", ".avi", ".mov")):
            try:
                print(f"Processing video file: {video_file}")
                video_path = os.path.join(input_folder, video_file)
                base_name = os.path.splitext(video_file)[0]

                # Extract audio
                print(f"Extracting audio from {video_file}...")
                audio_path = extract_audio(video_path, output_folder)
                print(f"Audio extracted to {audio_path}")

                # Transcribe and save
                print(f"Transcribing audio for {video_file}...")
                df = transcribe_audio(audio_path, GOOGLEAPI_KEY)
                save_transcript(df, base_name, output_folder)
                print(f"Transcription saved for {video_file}")

                # Identify main speaker and save transcript
                print(f"Identifying main speaker for {video_file}...")
                main_speaker = identify_main_speaker(df)
                main_speaker_df = save_main_speaker_transcript(df, main_speaker, base_name, output_folder)
                print(f"Main speaker transcript saved for {video_file}")

                # Emotion analysis
                print(f"Performing emotion analysis for {video_file}...")
                main_audio = AudioSegment.from_file(audio_path)
                emotion_percentages = analyze_emotions(main_speaker_df, main_audio, base_name, output_folder)
                print(f"Emotion Percentages for {base_name}: {emotion_percentages}") # Comment if there are too many

                # Add emotion percentages to the list
                emotion_data.append({"Video": base_name, **emotion_percentages})

            except Exception as e:
                print(f"Error processing {video_file}: {e}")
        else:
            print(f"Skipping non-video file: {video_file}")

    # Save emotion data to a CSV
    if emotion_data:
        emotion_df = pd.DataFrame(emotion_data)
        output_csv_path = os.path.join(output_folder, "emotion_percentages.csv")
        emotion_df.to_csv(output_csv_path, index=False)
        print(f"Emotion percentages saved to {output_csv_path}")




if __name__ == "__main__":
    
    print(f"Starting visual analysis for folder: {input_folder}")
    process_videos_in_folder(input_folder, output_csv)
    print(f"Visual analysis completed. Results saved in {output_csv}.")
    
    print(f"Starting audio and verbal analysis for folder: {input_folder}")
    process_folder(input_folder, output_folder)
    print(f"Audio and verbal analysis completed. Results saved in {output_folder}.")