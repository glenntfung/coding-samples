import os


# Save transcript as csv
def save_transcript(df, base_name, output_folder):
    df_path = os.path.join(output_folder, f"{base_name}_transcript.csv")
    df.to_csv(df_path, index=False)


# Identify the main speaker with the longest speaking duration
# An effective sample should have the lecturer as the longest speaker
def identify_main_speaker(df):
    df['Duration'] = df['End_Time'] - df['Start_Time']
    speaker_durations = df.groupby('Speaker')['Duration'].sum()
    return speaker_durations.idxmax()


# Save main speaker's transcript to txt
def save_main_speaker_transcript(df, main_speaker, base_name, output_folder):
    main_speaker_df = df[df['Speaker'] == main_speaker]
    main_speaker_transcript = " ".join(main_speaker_df['Word'].tolist())
    transcript_path = os.path.join(output_folder, f"{base_name}_main_speaker.txt")
    with open(transcript_path, "w") as file:
        file.write(main_speaker_transcript)
    return main_speaker_df