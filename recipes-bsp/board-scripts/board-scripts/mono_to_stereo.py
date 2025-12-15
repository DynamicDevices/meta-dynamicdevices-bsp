#!/usr/bin/env python3
"""
Convert a mono WAV file to stereo by duplicating the channel.
Usage: mono_to_stereo.py <input.wav> <output.wav>
"""
import sys
import wave

if len(sys.argv) != 3:
    print("Usage: mono_to_stereo.py <input.wav> <output.wav>", file=sys.stderr)
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

try:
    with wave.open(input_file, 'rb') as wav_in:
        params = wav_in.getparams()
        
        if params.nchannels != 1:
            print(f"Error: input file must be mono (has {params.nchannels} channels)", file=sys.stderr)
            sys.exit(1)
        
        frames = wav_in.readframes(params.nframes)
        
        # Duplicate mono samples to create stereo [L, R, L, R, ...]
        stereo_frames = bytearray()
        for i in range(0, len(frames), params.sampwidth):
            sample = frames[i:i+params.sampwidth]
            # Duplicate sample for both channels
            stereo_frames.extend(sample)  # Left channel
            stereo_frames.extend(sample)  # Right channel
        
        # Write stereo output
        with wave.open(output_file, 'wb') as wav_out:
            wav_out.setparams((2, params.sampwidth, params.framerate, len(stereo_frames) // (params.sampwidth * 2), params.comptype, params.compname))
            wav_out.writeframes(bytes(stereo_frames))
            
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)

