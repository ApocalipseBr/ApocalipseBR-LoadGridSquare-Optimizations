"""Provision an isolated copy of Valve SteamCMD for Windows builds."""
import os
import shutil
from contextlib import contextmanager
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.request import urlopen
from zipfile import BadZipFile, ZipFile

STEAMCMD_URL = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"


@contextmanager
def bundled_steamcmd():
    if os.name != "nt":
        raise ValueError("Install SteamCMD on PATH, set STEAMCMD, or pass --workshop-root")

    local_app_data = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData/Local")
    cache = local_app_data / "ApocalipseBR/LoadGridSquare"
    cache.mkdir(parents=True, exist_ok=True)
    lock = cache / "steamcmd.lock"
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError(f"The automatic SteamCMD cache is locked at {lock}") from None

    try:
        install = cache / "steamcmd"
        executable = install / "steamcmd.exe"
        if not executable.is_file():
            print(f"Installing SteamCMD in {install}", flush=True)
            with TemporaryDirectory(prefix="steamcmd-install-", dir=cache) as temporary:
                archive = Path(temporary) / "steamcmd.zip"
                unpacked = Path(temporary) / "steamcmd"
                try:
                    with urlopen(STEAMCMD_URL, timeout=60) as response, archive.open("wb") as target:
                        shutil.copyfileobj(response, target)
                    with ZipFile(archive) as files:
                        files.extractall(unpacked)
                except (OSError, BadZipFile) as error:
                    raise ValueError(f"Could not install SteamCMD from Valve: {error}") from error
                if not (unpacked / "steamcmd.exe").is_file():
                    raise ValueError("Valve's SteamCMD archive did not contain steamcmd.exe")
                if install.exists():
                    shutil.copytree(unpacked, install, dirs_exist_ok=True)
                else:
                    unpacked.rename(install)
        yield executable
    finally:
        lock.rmdir()
