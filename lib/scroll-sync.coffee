
{CompositeDisposable} = require 'atom'
dmpmod  = require 'diff_match_patch'
dmp     = new dmpmod.diff_match_patch()

DIFF_EQUAL  =  0
DIFF_INSERT =  1
DIFF_DELETE = -1

paneInfo = [null, null]

# This needs to get global, otherwise the events still get triggered
disposables = new CompositeDisposable

class ScrlSync

  activate: (state) ->
    @tracking = no
    @statusBarEle = document.createElement 'a'
    atom.commands.add 'atom-workspace', 'scroll-sync:toggle': =>
      if not @tracking then @startTracking() else @stopTracking()

  consumeStatusBar: (statusBar) ->
    @statusBarEle.classList.add 'inline-block'
    @statusBarEle.classList.add 'text-highlight'
    @statusBarEle.setAttribute 'href', '#'
    @statusBarEle.textContent = 'ScrlSync'
    @statusBarEle.style.display = if @tracking then 'inline-block' else 'none'
    @statusBarEle.addEventListener 'click', => @stopTracking()
    @statusBarTile = statusBar.addLeftTile item: @statusBarEle, priority: 100

  startTracking: ->
    # Update our internal variable
    @tracking = yes

    # Display the statusbar's element
    @statusBarEle.style.display = 'inline-block'

    # Get data about the different opened panes
    panes = atom.workspace.getPanes()

    # We will attempt to guess the ID of the pane in use, to scroll the correct file
    activePane = 0

    if panes.length != 2 then alert "Please open exactly 2 panes"; @stopTracking(); return

    for i in [0..1] then do (i) =>
      pane = panes[i]

      # If this is the pane in use, note it !
      if pane == atom.workspace.getActivePane()
        activePane = i

      # Initialize our data structure
      editor = pane.getActiveEditor()
      editorEle = atom.views.getView editor

      buffer = editor.getBuffer()

      # If something went wrong, cancel everything
      if not editor or not buffer then @stopTracking(); return

      paneInfo[i] = {
        editorEle, buffer
      }

      @lineHeight = editor.getLineHeightInPixels()

      ## Set the triggers

      # Stop tracking if the pane is closed
      disposables.add pane.onWillDestroy => @stopTracking()

      # Keep tracking the changes
      disposables.add buffer.onDidStopChanging => @textChanged()

      # And, of course, follow the scrolling !
      disposables.add editor.onDidChangeScrollTop => @scrollPosChanged i

    # Initialise the correlation map, and do not try to follow insertions if the files are too much different
    @simpleScroll = @textChanged()

    # Scroll the other pane to follow the active one
    @scrollPosChanged activePane

  textChanged: ->
    # Create a map of the corresponding lines for each pane... If we want to try to follow the insertions
    if not @simpleScroll

      # Get the differences
      diffs = dmp.diff_main paneInfo[0].buffer.getText(), paneInfo[1].buffer.getText()
      dmp.diff_cleanupSemantic diffs

      # Initialise the structures
      map0by1 = [0]
      map1by0 = [0]

      # Count the number of equal lines, to determine the similarity of the files
      n_equal = 0
      n_total = 0

      for diff in diffs
        [diffType, diffStr] = diff
        lineCount = diffStr.match(/\n/g)?.length ? 0
        for i in [0...lineCount]
          # Store the length of the modified array, otherwise we have trouble for equal lines as the two arrays get modified
          tmp = map1by0.length

          # For each line, we set the corresponding one on the other pane
          if diffType in [DIFF_EQUAL, DIFF_INSERT] then map1by0.push map0by1.length
          if diffType in [DIFF_EQUAL, DIFF_DELETE] then map0by1.push tmp

        # And we count the number of equal lines
        if diffType == DIFF_EQUAL then n_equal += lineCount
        n_total += lineCount

      # Make sure that the files are not too much different (at least 20% common lines)
      if n_equal < n_total / 5 then return true

      # Save our work, we don't want to do it again !
      paneInfo[0].mapToOther = map0by1
      paneInfo[1].mapToOther = map1by0
    return false

  scrollPosChanged: (pane) ->
    # Get the data about the panes
    thisInfo  = paneInfo[pane]
    otherInfo = paneInfo[1-pane]

    # If something went wrong, or if we scroll to follow the other panee, don't go further
    if not @tracking or not thisInfo or not otherInfo or thisInfo.scrolling then return

    # Future scroll top position of the other pane, for the moment it is the same as on our pane...
    pos = thisInfo.editorEle.getScrollTop()

    ## ... but, if needed, we determine the number of lines to add/remove to get the panes synced !
    if not @simpleScroll
      # Find the line at a third of the screen - looked more logical to me
      thisLine = thisInfo.editorEle.getFirstVisibleScreenRow() * 2 + thisInfo.editorEle.getLastVisibleScreenRow()
      thisLine = Math.round thisLine / 3

      # Find the corresponding line in the other pane
      otherLine = thisInfo.mapToOther[thisLine]

      # Add the difference in pixels
      pos += (otherLine - thisLine) * @lineHeight

    # Make sure the scrolling won't trigger the function to avoid an infinite loop
    otherInfo.scrolling = yes

    # Scroll the other pane
    otherInfo.editorEle.setScrollTop pos

    # We have to wait for the editor to redraw before removing our scrolling flag.
    # Since I haven't found a trigger, we'll use that for now
    setTimeout ->
      otherInfo.scrolling = no
    , 10

  stopTracking: ->
    # Reset the information about the panes
    paneInfo = [null, null]

    # Hide the statusbar element
    @statusBarEle.style.display = 'none'

    # Update our internal variable
    @tracking = no

    # Clear the triggers
    disposables.dispose()
    disposables.clear()

  deactivate: ->
    # Stop the scroll triggers
    @stopTracking()

    # Remove our item in the status bar
    @statusBarTile?.destroy()
    @statusBarTile = null

module.exports = new ScrlSync
