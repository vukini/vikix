"""Run the comparison in a disposable base image, never the user's live image."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def prepare(root, folder, endpoint):
    base = Path(os.environ.get('VIKIX_CUIS_OPT', str(Path.home() / '.local/opt/cuis'))) / 'base'
    vm = base / 'CuisVM.app/Contents/Linux-x86_64/squeak'
    image = base / 'CuisImage/Cuis7.7-7976.image'
    if not vm.is_file() or not image.is_file():
        raise ValueError('Cuis is missing; vikix add cuis installs it')
    shutil.copyfile(image, folder / 'music.image')
    shutil.copyfile(image.with_suffix('.changes'), folder / 'music.changes')
    for name in ('Packages', 'CoreUpdates', 'TrueTypeFonts'):
        (folder / name).symlink_to(base / name)
    for path in (base / 'CuisImage').glob('*.sources'):
        (folder / path.name).symlink_to(path)
    (folder / 'UnicodeData.txt').symlink_to(base / 'CuisImage/UnicodeData.txt')
    script = folder / 'open.st'
    script.write_text("\n".join([
        "[ | window |",
        "Feature require: 'Network-Kernel'.",
        "Feature require: 'JSON'.",
        f"Feature require: {quote(root / 'lib/music/VikixMusic.pck.st')}.",

        f"window := (Smalltalk at: #VikixMusic) openFrom: {quote(endpoint)}.",
        "UISupervisor whenUIinSafeState: [ UISupervisor ui submorphs copy do: [ :m | (m isKindOf: TranscriptWindow) ifTrue: [ m delete ] ] ].",
        "[ [ window owner notNil ] whileTrue: [ (Delay forMilliseconds: 300) wait ]. Smalltalk quit ] fork.",
        "] on: Error do: [ :ex | StdIOWriteStream stdout nextPutAll: ex description; newLine; flush. Smalltalk quit ].",
    ]))
    return [str(vm), '-vm-sound-null', str(folder / 'music.image'), '-ud', str(folder), '-s', str(script)]


def launch(root, endpoint):
    with tempfile.TemporaryDirectory(prefix='vikix-music-cuis-') as temp:
        folder = Path(temp) / 'image'
        folder.mkdir()
        env = dict(os.environ, SQUEAK_DISPLAY_PER_MONITOR_SCALE='1')
        child = subprocess.Popen(prepare(root, folder, endpoint), cwd=folder, env=env)
        try:
            return child.wait()
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
