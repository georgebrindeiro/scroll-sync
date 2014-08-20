
util = exports

util.debug = (mod) ->
  mod = mod[0..4]
  mod += ':'
  while mod.length < 5 then mod += ' '
  (args...) -> console.log mod, args...
  
    
# @enbld = no
# Object.defineProperties @, 
#   enabled:
#     get: -> 
#       console.log 'get enabled', @enbld, '       ' + @filePath
#       @enbld
#     set: (val) -> 
#       console.log 'set enabled', @enbld, val, '       ' + @filePath
#       if val is no then debugger
#       @enbld = val

