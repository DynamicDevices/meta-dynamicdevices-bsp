#!/usr/bin/env python3
"""
Extract a single channel from a stereo WAV file.
Usage: extract_channel.py <input.wav> <output.wav> <channel>
  channel: 0 for left (CH0), 1 for right (CH1)
"""
import sys
import wave

if len(sys.argv) != 4:
    print("Usage: extract_channel.py <input.wav> <output.wav> <channel>", file=sys.stderr)
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]
channel = int(sys.argv[3])

if channel not in [0, 1]:
    print("Error: channel must be 0 (left) or 1 (right)", file=sys.stderr)
    sys.exit(1)

try:
    with wave.open(input_file, 'rb') as wav_in:
        params = wav_in.getparams()
        
        if params.nchannels != 2:
            print(f"Error: input file must be stereo (has {params.nchannels} channels)", file=sys.stderr)
            sys.exit(1)
        
        frames = wav_in.readframes(params.nframes)
        
        # Extract samples for the specified channel
        # WAV format: interleaved samples [L, R, L, R, ...]
        # Each sample is 2 bytes (16-bit)
        samples = []
        for i in range(0, len(frames), 4):  # 4 bytes per stereo sample pair
            if channel == 0:
                # Left channel: first 2 bytes
                samples.append(frames[i:i+2])
            else:
                # Right channel: second 2 bytes
                samples.append(frames[i+2:i+4])
        
        # Write mono output
        with wave.open(output_file, 'wb') as wav_out:
            wav_out.setparams((1, params.sampwidth, params.framerate, len(samples), params.comptype, params.compname))
            wav_out.writeframes(b''.join(samples))
            
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)




