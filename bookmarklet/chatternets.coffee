console.log("chatternets loaded")

# Compatibility shim
navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;


class Chatternet

  constructor: (@ui) ->
    @peer = null
    @urlId = null
    @pageId = window.location.toString().split("?")[1].split("=")[1]
    @rawUrl = document.referrer  # window.parent.location is blocked (XSS)
    console.log @rawUrl
    @openCalls = {}

  start: =>
    @getInitDataFromServer()

  # Fetch the peer data from the server necessary to initiate video calls
  getInitDataFromServer: =>
    console.log "getting init data from server.."
    $.ajax
      url: "/new_peer"
      type: "POST"
      data:
        "full_url": @rawUrl
        "page_id": @pageId
      success: (jsonData) =>
        @initPeerConnections(jsonData)
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("ERROR")
        console.log textStatus
        console.log jqXHR
        
  # Create a peer for ourselves and create callbacks for peer events.
  # Then start the local video stream.
  initPeerConnections: (jsonData) =>
    console.log("Opening connections")
    data = JSON.parse(jsonData)
    console.log data
    @urlId = data.url_id
    console.log data.peer_id
    @peer = new Peer(data.peer_id, {key: 'rrvwvw4tuyxpqfr', debug: true});
    @peer.on "open", =>
      @handlePeerOpen()
    @peer.on "call", (call) =>
      @handlePeerCalling(call)
    @peer.on "error", (err) =>
      @handlePeerError(err)
    @startLocalStream(data.peers)

  # Start the local video stream, and then send video calls to peers.
  startLocalStream: (peerIdsToConnect) =>
    console.log 'starting local stream'
    # Get audio/video stream
    navigator.getUserMedia {audio: true, video: true}, (stream) =>
      @handleStartedLocalStream(stream, peerIdsToConnect)
    , () =>
        console.error "Error starting local stream!"
        $('#setup-error').show()
        $("#setup-instructions").hide()

  # Create the local video stream, send video calls to peers
  handleStartedLocalStream: (stream, peerIdsToConnect) =>
    # Set your video display
    $('#setup-instructions').addClass('animated slideOutUp');
    $('.intro').fadeOut('slow')
    $('#video-container').show()
    $('#my-video').prop('src', window.URL.createObjectURL(stream))
    window.localStream = stream

    console.log "Loaded local stream"
    for peerId in peerIdsToConnect
      @callPeer(peerId) # Has to happen after window.localStream is set

  # Initiate a call to another peer.
  callPeer: (peerId) =>
    console.log("attempting to call peer " + peerId)
    call = @peer.call(peerId, window.localStream)
    console.log(call)
    @addPeerVideoCall(call)

  # Respond to our peer opening (ie, our local peer being created)
  handlePeerOpen: =>
    console.log("peer opened with id " + @peer.id)
    console.log @peer
    $('#my-id').text(@peer.id);

  # Respond to another peer calling our peer.
  handlePeerCalling: (call) =>
    call.answer(window.localStream)  # TODO? Answers call immediately
    @addPeerVideoCall(call)

  removePeerVideoCall: (call, videoSelector) =>
    $(videoSelector).remove()
    delete @openCalls[call.peer]
    if $.isEmptyObject(@openCalls)
      @ui.usersIsZero()

  # Display a video stream for the call -- may be in response to a peer calling us,
  # or us calling another peer.
  addPeerVideoCall: (call) =>
    # Wait for stream on the call, then set peer video display
    console.log("call peer id is " + call.peer)
    videoClass = "their-video " + call.peer
    videoSelector = "#video-container .their-video." + call.peer
    $("#video-container")
      .append("<div class='user other'><video class='" +
        videoClass+ "' autoplay></video><div class='mic'>" +
        "<i class='fa fa-microphone-slash'></i></div></div>")
      .trigger('user_connected')
    call.on 'stream', (stream) ->
      $(videoSelector).prop('src', URL.createObjectURL(stream))
    call.on 'close', =>
      @removePeerVideoCall(call, videoSelector)
    call.on 'error', =>
      @removePeerVideoCall(call, videoSelector)
    @openCalls[call.peer] = call  # Save the call in the list of openCalls.

  handlePeerError: (err) =>
    console.log("== PEER ERROR: ==")
    console.log err
    # TODO tell server about error

class initialContainer
  constructor: ->
    @waitingForUsers = true

  start: ->
    $('#setup-instructions').addClass('animated slideInDown')

    $container = $('#sample-user-container')
    $container.masonry
        columnWidth: 10,
        itemSelector: '.sample-user',
        isOriginLeft: true

    numUsersAdded = 0;
    interval = setInterval () ->
        if (numUsersAdded > 0)
          $(".sample-user").removeClass("u" + (numUsersAdded-1)).addClass("u" + numUsersAdded)
          elem = $("<div />").addClass("sample-user other u" + numUsersAdded)
          icon = $("<i />").addClass("fa fa-users")
          elem.append(icon)
        else
          elem = $('<div class="sample-user me"><i class="fa fa-user"></i></div>')
        $container.append(elem)
        $container.masonry('appended', elem)
        $container.masonry()
        numUsersAdded += 1
        if (numUsersAdded == 3)
            window.clearInterval(interval)
    , 400

    $videoContainer = $("#video-container")
    $videoContainer.on "user_connected", () =>
        console.log("on user_connected")
        if (@waitingForUsers)
          $(".waiting-message").slideUp()
          @waitingForUsers = false
          $myVideo = $(".my-video-container-waiting")
          if $myVideo
            $myVideo.removeClass("well my-video-container-waiting")
            $myVideo.addClass("my-video-container user")
          console.log("no longer Waiting for users")

  usersIsZero: ->
    @waitingForUsers = true
    $(".waiting-message").slideDown()


$(document).ready ->
  ui = new initialContainer()
  ui.start()

  chatternet = new Chatternet(ui)
  chatternet.start()

  $("#video-container").on 'click', "video.their-video", (evt) =>
    videoElem = $(evt.currentTarget)
    micElem = videoElem.parent().find(".mic i")
    console.log(videoElem)
    if videoElem.prop('muted')
      videoElem.prop('muted', false);
      videoElem.attr('muted', false);
      videoElem.removeClass("muted-video")
      micElem.removeClass("fa-microphone").addClass("fa-microphone-slash")
    else
      videoElem.prop('muted', true);
      videoElem.attr('muted', true);
      videoElem.addClass("muted-video")
      micElem.removeClass("fa-microphone-slash").addClass("fa-microphone")
    console.log(videoElem.prop('muted'))




#   // Hang up on an existing call if present
#    openCalls[0].close();

