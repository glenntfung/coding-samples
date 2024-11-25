import requests
import os
import json
import numpy as np
from pydub import AudioSegment
from transformers import AutoProcessor, AutoModelForAudioClassification, Wav2Vec2FeatureExtractor
import torch
import torch.nn.functional as F


# Transcribe audio to text
def transcribe_audio(file_path, api_key):
    # Load audio file content
    with open(file_path, "rb") as audio_file:
        audio_content = audio_file.read()

    # Define request parameters
    url = f"https://speech.googleapis.com/v1p1beta1/speech:recognize?key={api_key}"
    headers = {"Content-Type": "application/json"}
    body = {
        "config": {
            "encoding": "LINEAR16",
            "sampleRateHertz": 16000,
            "languageCode": "en-US",
            "enableWordTimeOffsets": True,
            "enableSpeakerDiarization": True,
            "diarizationConfig": {
                "enableSpeakerDiarization": True,
                "minSpeakerCount": 2,
                "maxSpeakerCount": 5,
            },
        },
        "audio": {
            "content": audio_content.decode("ISO-8859-1")  # Base64-encode audio file
        },
    }

    # Make the API request
    response = requests.post(url, headers=headers, data=json.dumps(body))
    
    if response.status_code != 200:
        raise Exception(f"API request failed: {response.text}")

    return response.json()


# Predict audio emotion
def predict_emotion(audio_file):
    sound = AudioSegment.from_file(audio_file)
    sound = sound.set_frame_rate(16000)
    sound_array = np.array(sound.get_array_of_samples())
    
    model = AutoModelForAudioClassification.from_pretrained("ehcalabres/wav2vec2-lg-xlsr-en-speech-emotion-recognition")
    feature_extractor = Wav2Vec2FeatureExtractor.from_pretrained("facebook/wav2vec2-large-xlsr-53")

    input = feature_extractor(
        raw_speech=sound_array,
        sampling_rate=16000,
        padding=True,
        return_tensors="pt"
    )

    result = model.forward(input.input_values.float())

    id2label = {
        "0": "angry",
        "1": "calm",
        "2": "disgust",
        "3": "fearful",
        "4": "happy",
        "5": "neutral",
        "6": "sad",
        "7": "surprised"
    }

    interp = dict(zip(id2label.values(), [round(float(i), 4) for i in result[0][0]]))
    return interp


# Analyze emotions for main speaker's utterances
def analyze_emotions(main_speaker_df, main_audio, base_name, output_folder):
    emotion_counts = {}

    for i, row in main_speaker_df.iterrows():
        start_time = int(row["Start_Time"] * 1000)
        end_time = int(row["End_Time"] * 1000)
        utterance_audio = main_audio[start_time:end_time]
        utterance_path = os.path.join(output_folder, f"{base_name}_utterance_{i}.wav")
        utterance_audio.export(utterance_path, format="wav")

        emotions = predict_emotion(utterance_path)
        _, max_emotion = apply_softmax(emotions)

        if max_emotion in emotion_counts:
            emotion_counts[max_emotion] += 1
        else:
            emotion_counts[max_emotion] = 1

    total_utterances = len(main_speaker_df)
    emotion_percentages = {k: (v / total_utterances) * 100 for k, v in emotion_counts.items()}
    return emotion_percentages


# Apply softmax to a dictionary of values to find dominant emotions
def apply_softmax(output_dict):
    output_values = list(output_dict.values())
    softmax_values = F.softmax(torch.tensor(output_values), dim=0)
    softmax_values = softmax_values.tolist()
    softmax_dict = dict(zip(output_dict.keys(), softmax_values))
    max_index = torch.argmax(torch.tensor(output_values))
    max_emotion = list(output_dict.keys())[max_index]
    return softmax_dict, max_emotion