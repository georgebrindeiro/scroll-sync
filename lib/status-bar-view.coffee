{View} = require 'atom'
dbg    = require('./utils').debug 'sbvw'

module.exports =
class StatusBarView extends View 
  @content: ->
    @a class: 'inline-block text-highlight', href:'#', 'Scroll Locked'
 
  initialize: ->   
    do waitForStatusBar = =>
      if not (sb = atom.workspaceView.statusBar) 
        setTimeout waitForStatusBar, 100
        return
      sb.appendLeft this

  destroy: -> @detach()
