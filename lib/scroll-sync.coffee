
SubAtom = require 'sub-atom'
dmpmod  = require 'diff_match_patch'
dmp     = new dmpmod.diff_match_patch()

DIFF_EQUAL  =  0
DIFF_INSERT =  1
DIFF_DELETE = -1

paneInfo = [null, null]

class ScrlSync
  activate: (state) ->
    console.log 'activate scrlsync'
    @subs = new SubAtom
    @tracking = no
    @statusBarEle = document.createElement 'a'
    @subToggle = new SubAtom
    @subToggle.add atom.commands.add 'atom-workspace', 'scroll-sync:toggle': =>
      if not @tracking then @startTracking() else @stopTracking()

  consumeStatusBar: (statusBar) ->
    console.log 'consumeStatusBar'
    @statusBarEle.classList.add 'inline-block'
    @statusBarEle.classList.add 'text-highlight'
    @statusBarEle.setAttribute 'href', '#'
    @statusBarEle.textContent = 'ScrlSync'
    @statusBarEle.style.display = if @tracking then 'inline-block' else 'none'
    @statusBarEle.addEventListener 'click', => @stopTracking()
    @statusBarTile = statusBar.addLeftTile item: @statusBarEle, priority: 100

  startTracking: -> 
    @tracking = yes
    @statusBarEle.style.display = 'inline-block'
    pane   = atom.workspace.getActivePane()
    editor = atom.workspace.getActiveTextEditor()
    editorEle = atom.views.getView editor
    if not pane or not editor then @stopTracking(); return
    
    buffer = editor.getBuffer()
    @subs.add buffer, "destroyed", => @stopTracking()
    paneInfo[0] = {
      buffer, editor, editor, pane
      lineTop:
        editor.bufferPositionForScreenPosition( [editorEle.getFirstVisibleScreenRow(), 0] ).row
      lineBot:
        editor.bufferPositionForScreenPosition( [editorEle.getLastVisibleScreenRow(),  0] ).row
    }
    pane = null
    panes = atom.workspace.getPanes()
    for pv in panes
        pane = pv
        break
    if not pane then @stopTracking(); return
    
    editor = pane.getActiveEditor()
    if not editor then @stopTracking(); return
    editorEle = atom.views.getView editor
    
    buffer = editor.getBuffer()
    @subs.add buffer, "destroyed", => @stopTracking?()
    paneInfo[1] = {
      buffer, editor, editor
      lineTop:
        editor.bufferPositionForScreenPosition( [editorEle.getFirstVisibleScreenRow(), 0] ).row
      lineBot:
        editor.bufferPositionForScreenPosition( [editorEle.getLastVisibleScreenRow(),  0] ).row
    }
    
    @textChanged()
    @scrollPosChanged 0

    for pane in [0..1] then do (pane) =>
      @subs.add paneInfo[pane].buffer, 'contents-modified',   @textChanged
      @subs.add paneInfo[pane].editor.onDidChangeScrollTop => @scrollPosChanged pane

  textChanged: ->
    diffs = dmp.diff_main paneInfo[0].buffer.getText(), paneInfo[1].buffer.getText()
    dmp.diff_cleanupSemantic diffs
    map0by1 = []
    map1by0 = []
    for diff in diffs
      [diffType, diffStr] = diff
      lineCount = diffStr.match(/\n/g)?.length ? 0
      for i in [0...lineCount]
        m0by1Len = map0by1.length
        m1by0Len = map1by0.length
        if diffType in [DIFF_EQUAL, DIFF_INSERT] then map1by0.push m0by1Len
        if diffType in [DIFF_EQUAL, DIFF_DELETE] then map0by1.push m1by0Len
    paneInfo[0].mapToOther = map0by1
    paneInfo[1].mapToOther = map1by0

  scrollPosChanged: (pane) -> 
      thisInfo  = paneInfo[pane]
      otherInfo = paneInfo[1-pane]
      if not thisInfo or not otherInfo or thisInfo.scrolling then return
      
      thisEditor = thisInfo.editor
      thisEditorEle = atom.views.getView thisEditor
        
      thisTop = thisInfo.lineTop = \
         thisEditor.bufferPositionForScreenPosition( \
        [thisEditorEle.getFirstVisibleScreenRow(), 0] ).row
      thisBot = thisInfo.lineBot = \
         thisEditor.bufferPositionForScreenPosition( \
        [thisEditorEle.getLastVisibleScreenRow(),  0] ).row
      thisMid = Math.min thisInfo.mapToOther.length-1, Math.floor (thisTop + thisBot) / 2
      
      otherEditor = otherInfo.editor
      otherEditorEle = atom.views.getView otherEditor
      otherMid = Math.min otherInfo.mapToOther.length-1, thisInfo.mapToOther[thisMid] 
      otherPos = [otherMid, 0]
      
      otherInfo.scrolling = yes
      otherEditor.scrollToBufferPosition otherPos, center: true
      otherInfo.scrolling = no

  stopTracking: ->
    @tracking = no
    @subs.dispose()
    @subs.clear()
    @statusBarEle.style.display = 'none'
    paneInfo = [null, null]
  
  deactivate: -> 
    @subToggle.dispose()
    @stopTracking()
    @statusBarTile?.destroy()
    @statusBarTile = null
    
module.exports = new ScrlSync
