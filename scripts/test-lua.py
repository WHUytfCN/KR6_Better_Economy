"""Run authored Lua tests using a user-supplied Lua 5.1/LuaJIT DLL; no game code included."""
import argparse
import ctypes
import os
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument('--lua-dll', required=True, type=pathlib.Path)
args = parser.parse_args()
dll = ctypes.CDLL(str(args.lua_dll.resolve()))
dll.luaL_newstate.restype = ctypes.c_void_p
for name, types, result in [
    ('luaL_openlibs', [ctypes.c_void_p], None),
    ('luaL_loadbuffer', [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p], ctypes.c_int),
    ('lua_pcall', [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int], ctypes.c_int),
    ('lua_tolstring', [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p], ctypes.c_char_p),
    ('lua_close', [ctypes.c_void_p], None),
]:
    fn = getattr(dll, name)
    fn.argtypes, fn.restype = types, result
root = pathlib.Path(__file__).resolve().parents[1]
os.chdir(root)
failures = 0
tests = sorted((root/'tests').glob('*.lua'))
for test in tests:
    state = dll.luaL_newstate()
    if not state:
        raise MemoryError('Lua allocation failed')
    try:
        dll.luaL_openlibs(state)
        source = test.read_bytes()
        status = dll.luaL_loadbuffer(state, source, len(source), b'@authored-test')
        if not status:
            status = dll.lua_pcall(state, 0, 0, 0)
        if status:
            failures += 1
            print('FAIL', test.name, dll.lua_tolstring(state, -1, None).decode('utf-8', 'replace'))
        else:
            print('PASS', test.name)
    finally:
        dll.lua_close(state)
print(f'{len(tests)-failures}/{len(tests)} Lua test groups passed')
raise SystemExit(bool(failures))
