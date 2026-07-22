"""Convert a contiguous RV32 binary image to $readmemh-compatible words."""

import argparse
import struct
from pathlib import Path

IRAM_SIZE = 64 * 1024


def convert_image(binary_path: Path, output_path: Path) -> int:
    image = binary_path.read_bytes()
    if not image:
        raise ValueError(f"input image is empty: {binary_path}")
    if len(image) > IRAM_SIZE:
        raise ValueError(
            f"input image is {len(image)} bytes, exceeding the {IRAM_SIZE}-byte IRAM"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="\n") as hex_file:
        for offset in range(0, len(image), 4):
            word_bytes = image[offset : offset + 4].ljust(4, b"\0")
            hex_file.write(f"{struct.unpack('<I', word_bytes)[0]:08x}\n")
    return len(image)


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", required=True, type=Path, help="input flat binary image")
    parser.add_argument(
        "--iram-out",
        type=Path,
        default=repo_root / "RTL" / "sim" / "programs" / "program.hex",
        help="output word-per-line hex image for tb_soc_program",
    )
    args = parser.parse_args()

    size = convert_image(args.bin.resolve(), args.iram_out.resolve())
    print(f"[bin2txt] wrote {args.iram_out.resolve()} ({size} bytes)")


if __name__ == "__main__":
    main()
