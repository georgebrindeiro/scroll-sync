# coffeelint: disable=max_line_length
{CompositeDisposable} = require 'atom'
# dmpmod  = require 'diff_match_patch'
# dmp     = new dmpmod.diff_match_patch()
#
# DIFF_EQUAL  =  0
# DIFF_INSERT =  1
# DIFF_DELETE = -1


class ScrlSync

  activate: (state) ->
    @tracking = no
    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add 'atom-workspace', 'scroll-sync:toggle': =>
      @toggleTracking()

    @disposables.add atom.workspace.getCenter().onDidAddPane =>
      @checkPaneCount()

    @disposables.add atom.workspace.getCenter().onDidDestroyPane =>
      @checkPaneCount()

    @checkPaneCount()


  consumeStatusBar: (statusBar) ->
    @statusBarEle = document.createElement 'div'
    @statusBarEle.classList.add 'inline-block'
    @statusBarEle.classList.add 'scroll-sync-status-bar'
    @statusBarTooltip?.dispose()
    @statusBarTooltip = atom.tooltips.add @statusBarEle, title: 'Scroll Sync: Off'
    @statusBarEle.addEventListener 'click', => @toggleTracking()
    @checkPaneCount()
    @statusBarTile = statusBar.addLeftTile item: @statusBarEle, priority: 100

  checkPaneCount: ->
    paneCount = atom.workspace.getCenter().getPanes().length
    @statusBarEle?.classList.toggle 'two-panes', paneCount is 2

  toggleTracking: ->
    if @tracking
      @stopTracking()
    else
      @startTracking()

  startTracking: ->
    # Update our internal variable
    @tracking = yes

    # Update statusbar
    if @statusBarEle?
      @statusBarEle.classList.add 'scroll-sync-on'
      @statusBarTooltip?.dispose()
      @statusBarTooltip = atom.tooltips.add @statusBarEle, title: 'Scroll Sync: On'

    # Get data about the different opened panes
    panes = atom.workspace.getCenter().getPanes()

    # We will attempt to guess the ID of the pane in use, to scroll the correct file
    activePane = 0

    if panes.length != 2
      atom.notifications.addError "Please open exactly 2 panes", detail: "#{panes.length} panes open", dissmissable: true
      @stopTracking()
      return

    @trackingDisposables = new CompositeDisposable
    @paneInfo = []

    @addPaneInfo pane for pane in panes

    # Initialise the correlation map, and do not try to follow insertions if the files are too much different
    @simpleScroll = @textChanged()

    # Scroll the other pane to follow the active one
    @scrollPosChanged activePane

  addPaneInfo: (pane) ->

    i = @paneInfo.length

    # If this is the pane in use, note it !
    if pane == atom.workspace.getActivePane()
      activePane = i

    # Initialize our data structure
    editor = pane.getActiveEditor()
    editorEle = atom.views.getView editor

    buffer = editor.getBuffer()

    # If something went wrong, cancel everything
    if not editor or not buffer
      @stopTracking()
      return

    @paneInfo.push {editorEle, buffer, editor}

    @lineHeight = editor.getLineHeightInPixels()

    ## Set the triggers

    # Stop tracking if the pane is closed
    @trackingDisposables.add pane.onWillDestroy => @stopTracking()

    # Keep tracking the changes
    @trackingDisposables.add buffer.onDidStopChanging => @textChanged()

    # And, of course, follow the scrolling !
    @trackingDisposables.add editorEle.onDidChangeScrollTop => @scrollPosChanged i


  textChanged: ->
    # Create a map of the corresponding lines for each pane... If we want to try to follow the insertions
    if not @simpleScroll and @tracking

      # Get the differences
      # diffs = dmp.diff_main @paneInfo[0].buffer.getText(), @paneInfo[1].buffer.getText()
      # dmp.diff_cleanupSemantic diffs

      # Initialise the structures
      map0by1 = [0]
      map1by0 = [0]

      # Count the number of equal lines, to determine the similarity of the files
      # n_equal = 0
      # n_total = 0
      #
      # for diff in diffs
      #   [diffType, diffStr] = diff
      #   lineCount = diffStr.match(/\n/g)?.length ? 0
      #   for i in [0...lineCount]
      #     # Store the length of the modified array, otherwise we have trouble for equal lines as the two arrays get modified
      #     tmp = map1by0.length
      #
      #     # For each line, we set the corresponding one on the other pane
      #     if diffType in [DIFF_EQUAL, DIFF_INSERT] then map1by0.push map0by1.length
      #     if diffType in [DIFF_EQUAL, DIFF_DELETE] then map0by1.push tmp
      #
      #   # And we count the number of equal lines
      #   if diffType == DIFF_EQUAL then n_equal += lineCount
      #   n_total += lineCount
      #
      # # Make sure that the files are not too much different (at least 20% common lines)
      # if n_equal < n_total / 5 then return true

      # Save our work, we don't want to do it again !
      @paneInfo[0].mapToOther = map0by1
      @paneInfo[1].mapToOther = map1by0
    return false

  scrollPosChanged: (pane) ->
    # Get the data about the panes
    thisInfo  = @paneInfo[pane]
    otherInfo = @paneInfo[1-pane]

    # If something went wrong, or if we scroll to follow the other panee, don't go further
    if not @tracking or not thisInfo or not otherInfo or thisInfo.scrolling then return

    # Future scroll top position of the other pane, for the moment it is the same as on our pane...
    pos = thisInfo.editorEle.getScrollTop()

    ## ... but, if needed, we determine the number of lines to add/remove to get the panes synced !
    if not @simpleScroll
      # Find the First line from first row in current pane
      thisRow = thisInfo.editorEle.getFirstVisibleScreenRow()+1

      thisLine = thisInfo.editor.bufferPositionForScreenPosition([thisRow, 0]).row

      # Find the corresponding row in the other pane
      otherRow = otherInfo.editor.screenPositionForBufferPosition([thisLine, 0]).row

      # calculate position
      pos = otherRow * @lineHeight - @lineHeight

    # console.log('thisRow', thisRow)
    # console.log('thisLine', thisLine)
    # console.log('otherRow', otherRow)
    # console.log('pos', pos)
    # Make sure the scrolling won't trigger the function to avoid an infinite loop
    otherInfo.scrolling = yes

    # Scroll the other pane
    otherInfo.editorEle.setScrollTop(pos)
    #
    #   # Find the line at a third of the screen - looked more logical to me
    #   thisLine = thisInfo.editorEle.getFirstVisibleScreenRow() * 2 + thisInfo.editorEle.getLastVisibleScreenRow()
    #   thisLine = Math.round thisLine / 3
    #
    #   # Find the corresponding line in the other pane
    #   otherLine = thisInfo.mapToOther[thisLine]
    #
    #   # Add the difference in pixels
    #   pos += (otherLine - thisLine) * @lineHeight
    #
    # # Make sure the scrolling won't trigger the function to avoid an infinite loop
    # otherInfo.scrolling = yes
    #
    # # Scroll the other pane
    # otherInfo.editorEle.setScrollTop pos

    # We have to wait for the editor to redraw before removing our scrolling flag.
    # Since I haven't found a trigger, we'll use that for now
    setTimeout ->
      otherInfo.scrolling = no
    , 10

  stopTracking: ->
    # Reset the information about the panes
    @paneInfo = null

    # Update statusbar
    if @statusBarEle?
      @statusBarEle.classList.remove 'scroll-sync-on'
      @statusBarTooltip?.dispose()
      @statusBarTooltip = atom.tooltips.add @statusBarEle, title: 'Scroll Sync: Off'

    # Reset our internal variables
    @tracking = no
    @simpleScroll = false

    # Clear the triggers
    @trackingDisposables.dispose()
    @trackingDisposables.clear()

  deactivate: ->
    # Stop the scroll triggers
    @stopTracking() if @tracking

    # Remove our item in the status bar
    @statusBarTooltip?.dispose()
    @statusBarTooltip = null
    @statusBarTile?.destroy()
    @statusBarTile = null
    @statusBarEle = null

    @disposables.dispose()
    @disposables.clear()

module.exports = new ScrlSync
