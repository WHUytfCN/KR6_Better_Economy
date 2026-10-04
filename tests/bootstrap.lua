local path='src/bootstrap.lua'
assert(io.open(path,'rb'),'bootstrap must be implemented')
-- No writes to a real save; this test uses a fake module boundary and unsupported build.
version={string='unsupported-build'}
assert(loadfile(path))()
assert(type(custom_script)=='table' and type(custom_script.init)=='function')
custom_script:init()
assert(not custom_script.active,'unsupported version must refuse hooks')
local old=custom_script
assert(loadfile(path))();assert(custom_script==old,'bootstrap must be idempotent')
print('bootstrap: unknown version refused, repeated load harmless')
