import os
from moviepy.editor import VideoFileClip

# Extract audio
def extract_audio(video_path, output_folder):
    video = VideoFileClip(video_path)
    base_name = os.path.splitext(os.path.basename(video_path))[0]
    audio_path = os.path.join(output_folder, f"{base_name}.wav")
    video.audio.write_audiofile(audio_path)
    return audio_path

