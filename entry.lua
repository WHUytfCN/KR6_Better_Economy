-- Reachable through the game's default .\?.lua disk loader, without LUA_PATH.
local source=assert(debug.getinfo(1,'S').source):gsub('\\','/')
local root=assert(source:match('^@(.+)/entry%.lua$'),'cannot locate economy plugin directory')
package.loaded['KR6_Better_Economy.paths']={root=root}
package.path=root..'/?.lua;'..package.path
return require('src.bootstrap')
