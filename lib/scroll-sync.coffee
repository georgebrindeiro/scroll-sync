
dbg  = require('./utils').debug 'ssync'
StatusBarView = require './status-bar-view'

module.exports =

  activate: (state) ->
    atom.workspaceView.command "scroll-sync:toggle", => @toggle

  toggle: ->
    if @statusBarView 
      @statusBarView.destroy()
      @statusBarView = null
      @stopTracking()
      return
    
    editorView1 = atom.workspaceView.getActiveView()
    if not (editor1 = editorView1?.getEditor?()) then return
    paneView1 = editorView1.getPane()
    containerView1 = getContainer()
    
    dbg 'toggle', {editor1, editorView1, containerView1 paneView1}
    
    # paneView2 = null
    # paneViews = atom.workspaceView.getPaneViews()
    # for paneView in paneViews
    #   if paneView isnt paneView1
    #     paneView2 = paneView
    #     
    # getContainer
    # 
    # if not (tabBarView = atom.workspaceView.find('.tab-bar').view())
    #   return
    #   
    # for tabView in tabBarView.getTabs() 
    #   if tabView.title.text()[0..2] is '<- ' 
    #     tabBarView.closeTab tabView
    # EditorMgr.editorMgrs = []
    # 
    #     
    # @statusBarView = new StatusBarView @

  startTracking: (editorView1, editorView2) ->
    
    
  stopTracking: ->


  deactivate: ->
