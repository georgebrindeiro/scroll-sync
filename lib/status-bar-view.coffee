{View} = require 'atom-space-pen-views'

module.exports =
class StatusBarView extends View 
  @content: ->
    @a class: 'inline-block text-highlight', href:'#', 'ScrlSync'
 
  initialize: (main) ->   
    @click => main.stopTracking()
    
    do waitForStatusBar = =>
      if not (sb = atom.workspaceView.statusBar) 
        setTimeout waitForStatusBar, 100
        return
      sb.appendLeft this

  destroy: -> @detach()
