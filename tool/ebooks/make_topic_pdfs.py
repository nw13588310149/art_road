"""Build the bundled small-lesson PDFs from the existing illustrated book pages."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "demo" / "ebooks"
BOOKS = {"eb-sketch-still": 12, "eb-color-warmcool": 10, "eb-speed-figure": 10}


def main():
    for book_id, count in BOOKS.items():
        pages = []
        try:
            for number in range(1, count + 1):
                with Image.open(ASSETS / f"{book_id}-p{number:02d}.jpg") as source:
                    pages.append(source.convert("RGB"))
            pages[0].save(
                ASSETS / f"{book_id}.pdf",
                "PDF",
                save_all=True,
                append_images=pages[1:],
                resolution=110,
                title=book_id,
                author="美育集 · 阅读示例",
            )
            print(f"{book_id}: {count} pages")
        finally:
            for page in pages:
                page.close()


if __name__ == "__main__":
    main()
