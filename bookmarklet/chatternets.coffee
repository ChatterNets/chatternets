console.log("chatternets loaded")

# Compatibility shim
navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;


class Chatternet

  constructor: ->
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
        console.log "error starting local stream"
        $('#setup-error').show()

  # Create the local video stream, send video calls to peers
  handleStartedLocalStream: (stream, peerIdsToConnect) =>
    # Set your video display
    $('#setup-instructions').addClass('animated slideOutUp');
    $('.intro').fadeOut('slow')
    $('#video-container').show()
    $('#my-video').prop('src', URL.createObjectURL(stream))
    window.localStream = stream

    console.log "loaded local stream"
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

  # Display a video stream for the call -- may be in response to a peer calling us,
  # or us calling another peer.
  addPeerVideoCall: (call) =>
    # Wait for stream on the call, then set peer video display
    console.log("call peer id is " + call.peer)
    videoClass = "their-video " + call.peer
    videoSelector = "#video-container .their-video." + call.peer
    $("#video-container")
      .append("<div class='user'><video class='" +
        videoClass+ "' autoplay></video></div>")
      .trigger('user_connected')
    call.on 'stream', (stream) ->
      $(videoSelector).prop('src', URL.createObjectURL(stream))
    call.on 'close', =>
      @removePeerVideoCall(call, videoSelector)
    call.on 'error', =>
      @removePeerVideoCall(call, videoSelector)
    @openCalls[call.peer] = call  # Save the call in the list of openCalls.

  handlePeerError: (err) =>
    console.log("PEER ERROR: ")
    console.log err
    # TODO tell server about error


$(document).ready ->
  chatternet = new Chatternet()
  chatternet.start()


#   // Hang up on an existing call if present
#    openCalls[0].close();

