# Pass a directory (or list of directories) that were outputted by
# run_marker.sh.
import logging
import shutil
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

logging.basicConfig(
    level=logging.INFO,
    format="{asctime} | {levelname:8} | {name}:{lineno} | {message}",
    datefmt="%Y-%m-%d %H:%M:%S",
    style="{",
)

logger = logging.getLogger(__name__)


def check_if_safe(d: Path) -> bool:
    for p in d.glob("*"):
        if p.suffix not in [".jpeg", ".md", ".json"]:
            return False
    return True


def process_dir(d: str) -> None:
    d = Path(d)
    logger.info(f"processing {d}")
    try:
        pdf_name = next(d.glob("*.md")).stem
    except StopIteration:
        logger.warning("pdf conversion may have been interrupted; skipping")
        return

    for subdir in d.glob("chunks/*/*"):
        if not check_if_safe(subdir):
            logger.warning(f"subdir {subdir} contains unexpected files; skipping")
            return

    archive_path = d / f"{pdf_name}.zip"
    if archive_path.exists():
        logger.warning(f"archive {archive_path} exists; skipping")
        return

    logger.info(f"writing to archive {archive_path}")
    images = d.glob("chunks/*/*/*.jpeg")
    with ZipFile(archive_path, "w", compression=ZIP_DEFLATED) as archive:
        for i in images:
            archive.write(i, arcname=i.name)

    logger.info(f"removing dir {d / 'chunks'}")
    shutil.rmtree(d / "chunks")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        dirs = sys.argv[1:]
    else:
        dirs = input().split()

    for d in dirs:
        process_dir(d)
