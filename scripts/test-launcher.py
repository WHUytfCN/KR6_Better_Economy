"""Test installed/nested source launching with fake game files; never starts a game."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import argparse
import ctypes
import os

parser = argparse.ArgumentParser()
parser.add_argument('--work-directory', type=pathlib.Path)
parser.add_argument('--lua-dll', type=pathlib.Path, help='Optional LuaJIT DLL to verify both entry paths')
args = parser.parse_args()
ROOT = pathlib.Path(__file__).resolve().parents[1]
work = args.work_directory or ROOT/'build'
work.mkdir(parents=True, exist_ok=True)
count = 0
def load_entry(game, layout):
    global count
    if not args.lua_dll:
        return
    dll = ctypes.CDLL(str(args.lua_dll.resolve()))
    dll.luaL_newstate.restype = ctypes.c_void_p
    for name, types, result in [
        ('luaL_openlibs',[ctypes.c_void_p],None),
        ('luaL_loadbuffer',[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p],ctypes.c_int),
        ('lua_pcall',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int],ctypes.c_int),
        ('lua_tolstring',[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p],ctypes.c_char_p),
        ('lua_close',[ctypes.c_void_p],None),
    ]:
        fn = getattr(dll,name);fn.argtypes,fn.restype = types,result
    source = ("package.path='./?.lua'; local p=require('"+layout+"/entry'); "
              "assert(p==custom_script); local paths=assert(package.loaded['KR6_Better_Economy.paths']); "
              "assert(require('src.config').load(paths.root..'/settings.ini').global==1); "
              "assert(require('src.core') and require('src.runtime') and require('src.ui'))").encode()
    state = dll.luaL_newstate()
    assert state
    old = pathlib.Path.cwd()
    try:
        os.chdir(game)
        dll.luaL_openlibs(state)
        status = dll.luaL_loadbuffer(state,source,len(source),b'@entry-regression')
        if not status:
            status = dll.lua_pcall(state,0,0,0)
        assert not status,dll.lua_tolstring(state,-1,None)
        count += 1
    finally:
        os.chdir(old);dll.lua_close(state)
with tempfile.TemporaryDirectory(prefix='launcher-', dir=work) as temp:
    base = pathlib.Path(temp)
    for layout in ('KR6_Better_Economy', 'KR6Economy/publish/KR6_Better_Economy'):
        game = base/('nested' if '/' in layout else 'installed')/'Game with spaces'
        plugin = game/layout
        plugin.mkdir(parents=True)
        for name in ('entry.lua','Start-Economy.ps1'):
            shutil.copyfile(ROOT/name,plugin/name)
        shutil.copytree(ROOT/'src',plugin/'src')
        fake = {'Kingdom Rush Genesis.exe':b'fixture', 'love.dll':b'engine', 'lua51.dll':b'lua'}
        for name, data in fake.items():
            (game/name).write_bytes(data)
        (plugin/'supported-build.json').write_text(json.dumps({'version':'fixture','files':{
            n:hashlib.sha256(b).hexdigest() for n,b in fake.items()}}))
        (plugin/'settings.ini').write_text('global=1\ninitial=1\nenemy=1\nsummons=false\nenabled=true\n')
        def check(good, marker=None):
            global count
            proc = subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass',
                '-File',str(plugin/'Start-Economy.ps1'),'-CheckOnly'],capture_output=True,timeout=30)
            assert (proc.returncode==0)==good,(layout,proc.stdout,proc.stderr)
            if marker:
                assert marker.encode() in proc.stdout,proc.stdout
            count += 1
        check(True, '-custom_script '+layout+'/entry')
        load_entry(game,layout)
        (plugin/'settings.ini').write_text('global=1.03')
        check(False)
        (plugin/'settings.ini').write_text('global=1')
        (game/'love.dll').write_bytes(b'updated')
        check(False)
        (game/'Kingdom Rush Genesis.exe').unlink()
        check(False)
print(f'{count}/{count} launcher checks passed; no game launched')
