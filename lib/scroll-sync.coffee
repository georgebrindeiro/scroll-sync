dbg  = require('./utils').debug 'ssync'
StatusBarView = require './status-bar-view'

module.exports =

  activate: (state) ->
    dbg 'activate'
    atom.workspaceView.command "scroll-sync:toggle", => @toggle()

  toggle: ->
    if @statusBarView
      @statusBarView.destroy()
      @statusBarView = null
      @stopTracking()
      return
    
    paneView1   = atom.workspaceView.getActivePaneView()
    editorView1 = atom.workspaceView.getActiveView()
    if not paneView1 or not editorView1 then return
    editor1 = editorView1.getEditor()
    editor1.on 'scroll-top-changed', => 
      @scrollPosChanged 1
      , editor1.bufferPositionForScreenPosition([editorView1.getFirstVisibleScreenRow(), 0]).row
      , editor1.bufferPositionForScreenPosition([editorView1.getLastVisibleScreenRow(), 0]).row
    
    paneView2 = null
    paneViews = atom.workspaceView.getPaneViews()
    for paneView in paneViews
      if paneView isnt paneView1
        paneView2 = paneView
        break
    if not paneView2 then return
    $editorView2 = paneView2.find '.editor:visible'
    if $editorView2.length is 0 then return
    editorView2 = $editorView2.view()
    editor2 = editorView2.getEditor()
    editor2.on 'scroll-top-changed', => 
      @scrollPosChanged 2
      , editor2.bufferPositionForScreenPosition([editorView2.getFirstVisibleScreenRow(), 0]).row
      , editor2.bufferPositionForScreenPosition([editorView2.getLastVisibleScreenRow(), 0]).row

    @statusBarView = new StatusBarView @

  startTracking: (editorView1, editorView2) -> 
    
    
  stopTracking: ->
    
  scrollPosChanged: (args...) -> 
    dbg 'scrollPosChanged', args

  deactivate: ->
