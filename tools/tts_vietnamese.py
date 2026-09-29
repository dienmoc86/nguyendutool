"""
Vietnamese Neural Text-to-Speech Engine
Uses Microsoft Neural Voices: vi-VN-HoaiMyNeural (Female) and vi-VN-NamMinhNeural (Male).
"""

import sys
import asyncio
import argparse
from pathlib import Path
import edge_tts

async def synthesize(text: str, output_path: str, voice: str = "vi-VN-HoaiMyNeural", rate: str = "+0%", pitch: str = "+0Hz"):
    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    await communicate.save(output_path)
    print(f"[TTS] Successfully generated audio: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Vietnamese Neural TTS Generator")
    parser.add_argument("text", help="Text to speak or path to a .txt file")
    parser.add_argument("-o", "--output", default="output.mp3", help="Output audio file path (.mp3)")
    parser.add_argument("-v", "--voice", choices=["hoaimy", "namminh"], default="hoaimy", help="Voice selection")
    parser.add_argument("-r", "--rate", default="+0%", help="Speed rate, e.g. +10%% or -10%%")
    args = parser.parse_args()

    voice_map = {
        "hoaimy": "vi-VN-HoaiMyNeural",
        "namminh": "vi-VN-NamMinhNeural"
    }
    voice_name = voice_map.get(args.voice, "vi-VN-HoaiMyNeural")

    # Read from file if text argument is a valid file path
    input_text = args.text
    if Path(input_text).exists() and Path(input_text).is_file():
        with open(input_text, "r", encoding="utf-8") as f:
            input_text = f.read()

    print(f"[TTS] Synthesizing ({voice_name})...")
    asyncio.run(synthesize(input_text, args.output, voice=voice_name, rate=args.rate))

if __name__ == "__main__":
    main()
