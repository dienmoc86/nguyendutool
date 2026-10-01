import argparse
import asyncio
import os
import sys
import edge_tts

async def run(args):
    if not os.path.exists(args.input):
        print(f"ERROR: Input file does not exist: {args.input}", file=sys.stderr)
        sys.exit(1)
        
    with open(args.input, "r", encoding="utf-8") as f:
        text = f.read().strip()
        
    if not text:
        print("ERROR: Input text is empty", file=sys.stderr)
        sys.exit(1)
        
    voice = args.voice or "vi-VN-HoaiMyNeural"
    rate = args.rate or "+0%"
    pitch = args.pitch or "+0Hz"
    
    # Ensure parent output directory exists
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    
    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    await communicate.save(args.output)
    
    if os.path.exists(args.output) and os.path.getsize(args.output) > 0:
        size = os.path.getsize(args.output)
        print(f"OK {args.output} {size}")
    else:
        print("ERROR: Output file was not created or empty", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Standalone Edge TTS CLI for NguyenDu Tool")
    parser.add_argument("--input", "-i", required=True, help="Path to input UTF-8 text file")
    parser.add_argument("--output", "-o", required=True, help="Path to output MP3 file")
    parser.add_argument("--voice", "-v", default="vi-VN-HoaiMyNeural", help="Voice identifier")
    parser.add_argument("--rate", "-r", default="+0%", help="Rate modifier (e.g. +20%%, -10%%)")
    parser.add_argument("--pitch", "-p", default="+0Hz", help="Pitch modifier (e.g. +0Hz)")
    
    args = parser.parse_args()
    asyncio.run(run(args))

if __name__ == "__main__":
    main()
