from .postprocessing import annotate_frame, frames_to_video, summarize_attributes
from .processing import process_frame, is_professor_facing_camera
from .preprocessing import extract_frames, get_video_properties, get_video_files

from .preprocessav import extract_audio
from .processav import transcribe_audio, predict_emotion, analyze_emotions, apply_softmax
from .posprocessav import save_transcript, identify_main_speaker, save_main_speaker_transcript