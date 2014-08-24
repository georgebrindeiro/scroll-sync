{Subscriber} = require 'emissary'

dbg  = require('./utils').debug 'ssync'
StatusBarView = require './status-bar-view'
dmpmod        = require 'diff_match_patch'
dmp           = new dmpmod.diff_match_patch()

DIFF_EQUAL  =  0
DIFF_INSERT =  1
DIFF_DELETE = -1

paneInfo = [null, null]

class ScrlSync
  Subscriber.includeInto @
  
  activate: (state) ->
    dbg 'activate 4'
    @statusBarView = null
    atom.workspaceView.command "scroll-sync:toggle", => 
      if not @statusBarView then @startTracking()
      else                       @stopTracking()

  startTracking: -> 
    dbg 'startTracking', @statusBarView?
    paneView   = atom.workspaceView.getActivePaneView()
    editorView = atom.workspaceView.getActiveView()
    if not paneView or not editorView then stopTracking(); return
    
    editor = editorView.getEditor()
    buffer = editor.getBuffer()
    paneInfo[0] = {
      buffer, editor, editorView, paneView
      lineTop:
        editor.bufferPositionForScreenPosition( [editorView.getFirstVisibleScreenRow(), 0] ).row
      lineBot:
        editor.bufferPositionForScreenPosition( [editorView.getLastVisibleScreenRow(),  0] ).row
    }
    paneView = null
    paneViews = atom.workspaceView.getPaneViews()
    for pv in paneViews
      if pv isnt paneInfo[0].paneView
        paneView = pv
        break
    if not paneView then @stopTracking(); return
    $editorView = paneView.find '.editor:visible'
    if $editorView.length is 0 then stopTracking(); return
    editorView = $editorView.view()
    editor = editorView.getEditor()
    buffer = editor.getBuffer()
    paneInfo[1] = {
      buffer, editor, editorView
      lineTop:
        editor.bufferPositionForScreenPosition( [editorView.getFirstVisibleScreenRow(), 0] ).row
      lineBot:
        editor.bufferPositionForScreenPosition( [editorView.getLastVisibleScreenRow(),  0] ).row
    }
    
    @textChanged()
    @scrollPosChanged 0

    @statusBarView = new StatusBarView @
  
    for pane in [0..1] then do (pane) =>
      @subscribe paneInfo[pane].buffer, 'contents-modified',     @textChanged
      @subscribe paneInfo[pane].editor, 'scroll-top-changed', => @scrollPosChanged pane

  textChanged: ->
    diffs = dmp.diff_main paneInfo[0].buffer.getText(), paneInfo[1].buffer.getText()
    dmp.diff_cleanupSemantic diffs
    map0by1 = []
    map1by0 = []
    for diff in diffs
      [diffType, diffStr] = diff
      lineCount = diffStr.match(/\n/g).length
      for i in [0...lineCount]
        m0by1Len = map0by1.length
        m1by0Len = map1by0.length
        if diffType in [DIFF_EQUAL, DIFF_INSERT] then map1by0.push m0by1Len
        if diffType in [DIFF_EQUAL, DIFF_DELETE] then map0by1.push m1by0Len
    paneInfo[0].mapToOther = map1by0
    paneInfo[1].mapToOther = map0by1
    
    dbg 'textChanged', paneInfo

  scrollPosChanged: (pane) -> 
      dbg 'scrollPosChanged', pane
      thisInfo  = paneInfo[pane]
      otherInfo = paneInfo[1-pane]
      if not thisInfo or not otherInfo then return
      
      thisEditor     = thisInfo.editor
      thisEditorView = thisInfo.editorView
      thisTop = thisInfo.lineTop = \
         thisEditor.bufferPositionForScreenPosition( \
        [thisEditorView.getFirstVisibleScreenRow(), 0] ).row
      thisBot = thisInfo.lineBot = \
         thisEditor.bufferPositionForScreenPosition( \
        [thisEditorView.getLastVisibleScreenRow(),  0] ).row
        
      otherEditor     = otherInfo.editor
      othereditorView = otherInfo.editorView
      otherTop        = otherInfo.lineTop
      otherBot        = otherInfo.lineBot
      
      thisMid         = Math.floor (thisTop + thisBot) / 2
      otherPos        = [thisInfo.mapToOther[thisMid], 0]

      dbg 'scrollPosChanged', {pane, thisMid, otherMid: otherPos[0], thisInfo, otherInfo}       
      othereditorView.scrollToBufferPosition otherPos, center: yes

  stopTracking: ->
    dbg 'stopTracking', @statusBarView?
    @unsubscribe()
    paneInfo = [null, null]
    @statusBarView?.destroy()
    @statusBarView = null
  
  deactivate: -> 
    dbg 'deactivate', @statusBarView?
    @stopTracking

module.exports = new ScrlSync



    
    
