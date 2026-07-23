"""Convert RV32 images to Pango/$readmemh-compatible, word-per-line files."""

import argparse
import struct
import subprocess
import tempfile
from pathlib import Path

IRAM_SIZE = 64 * 1024
SRAM_SIZE = 32 * 1024


def write_image(image: bytes, output_path: Path, capacity: int, pad: bool) -> int:
    if not image:
        raise ValueError("input image is empty")
    if len(image) > capacity:
        raise ValueError(
            f"input image is {len(image)} bytes, exceeding the {capacity}-byte target"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="\n") as hex_file:
        output_size = capacity if pad else len(image)
        for offset in range(0, output_size, 4):
            word_bytes = image[offset : offset + 4].ljust(4, b"\0")
            hex_file.write(f"{struct.unpack('<I', word_bytes)[0]:08x}\n")
    return len(image)


def extract_section(elf_path: Path, objcopy: str, section: str) -> bytes:
    with tempfile.TemporaryDirectory() as temp_dir:
        image_path = Path(temp_dir) / f"{section[1:]}.bin"
        subprocess.run(
            [objcopy, "-O", "binary", f"--only-section={section}", str(elf_path), str(image_path)],
            check=True,
        )
        return image_path.read_bytes()


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument("--bin", type=Path, help="input flat binary image")
    input_group.add_argument("--elf", type=Path, help="linked ELF with .text and .data sections")
    parser.add_argument(
        "--iram-out",
        type=Path,
        default=repo_root / "RTL" / "sim" / "programs" / "program.hex",
        help="IRAM word-per-line output",
    )
    parser.add_argument("--sram-out", type=Path, help="SRAM output; required with --elf")
    parser.add_argument(
        "--objcopy",
        default="riscv-none-elf-objcopy",
        help="objcopy command used to extract ELF sections",
    )
    args = parser.parse_args()

    if args.bin:
        size = write_image(args.bin.resolve().read_bytes(), args.iram_out.resolve(), IRAM_SIZE, False)
        print(f"[bin2txt] wrote {args.iram_out.resolve()} ({size} bytes)")
        return

    if args.sram_out is None:
        parser.error("--sram-out is required with --elf")

    elf_path = args.elf.resolve()
    iram_size = write_image(
        extract_section(elf_path, args.objcopy, ".text"),
        args.iram_out.resolve(),
        IRAM_SIZE,
        False,
    )
    sram_size = write_image(
        extract_section(elf_path, args.objcopy, ".data"),
        args.sram_out.resolve(),
        SRAM_SIZE,
        True,
    )
    print(f"[bin2txt] wrote {args.iram_out.resolve()} (.text, {iram_size} bytes)")
    print(f"[bin2txt] wrote {args.sram_out.resolve()} (.data, {sram_size} bytes; zero-padded to {SRAM_SIZE} bytes)")


if __name__ == "__main__":
    main()
