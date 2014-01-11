# Server for Chatternets

express = require("express")
logfmt = require("logfmt")
uuid = require('node-uuid')
app = express()

app.use(logfmt.requestLogger())
app.use(express.bodyParser())

# Helper Functions

normalizeURL = (urlRaw) ->
  urlNormal = urlRaw
  return urlNormal.replace(/([\?#].*$)/gi, "")

generateId = () ->
  return uuid.v1()

MAX_ROOM_SIZE = 5
urlToURLIds = {}
urlIdToURL = {}
urlIdToPeerIds = {}

# The following conditions hold, as a result of this function:
# - the connected peer has been given an id
# - that id has been added to a room that has no more than MAX_ROOM_SIZE
#   other peers
#
# Returns: peer id that has been created for the connected user
onPeerConnected = (urlRaw) ->
  urlNormal = normalizeURL(urlRaw)

  if not urlToURLIds.hasOwnProperty(urlNormal)
    urlId = generateId()
    urlIdToURL[urlId] = urlNormal
    urlToURLIds[urlNormal] = [urlId]

  peerId = generateId()

  for urlId in urlToURLIds[urlNormal]
    if not urlIdToPeerIds.hasOwnProperty(urlId)
      urlIdToPeerIds[urlId] = [peerId]
      return { peer_id: peerId, url_id: urlId, peers: []}

    if urlIdToPeerIds[urlId].length < MAX_ROOM_SIZE
      peerIds = urlIdToPeerIds[urlId].slice(0)
      urlIdToPeerIds[urlId].push(peerId)
      return { peer_id: peerId, url_id: urlId, peers: peerIds}

  # If we get here, that means we didn't find a room to join.
  # So, we create one.
  urlId = generateId()
  urlIdToURL[urlId] = urlNormal
  urlToURLIds[urlNormal].push(urlId)
  urlIdToPeerIds[urlId] = [peerId]
  return { peer_id: peerId, url_id: urlId, peers: []}

# Remove the peer from the room identified by urlId.
# Perform any cleanup necessary.
onPeerDisconnected = (peerId, urlId) ->
  if not urlIdToPeerIds.hasOwnProperty(urlId)
    return { success: false, message: "That urlId was not recognized" }

  # Remove the peer id from the url id's room
  index = urlIdToPeerIds[urlId].indexOf(peerId)
  if index == -1
    return {
      success: false,
      message: "That peerId, urlId pair was not recognized" }
  urlIdToPeerIds[urlId].splice(index, 1)

  # If the removed peer was the last peer, do some clean up...
  if urlIdToPeerIds[urlId].length == 0
    delete urlIdToPeerIds[urlId]

    # Remove the url id from the url id -> url map
    url = urlIdToURL[urlId]
    delete urlIdToURL[urlId]

    # Remove the url id from the url -> [url id] map
    index = urlToURLIds[url].indexOf(urlId)
    if index == -1
      return
    urlToURLIds[url].splice(index, 1)

    # If this was the last url id, remove the url
    if urlToURLIds[url].length == 0
      delete urlToURLIds[url]

  return { success: true }

#####################
# Server code

app.get '/', (req, res) ->
  res.sendfile('dashboard/index.html')

app.get '/bookmarklet/:file', (req, res) ->
  res.sendfile('bookmarklet/' + req.params.file)

app.get '/bookmarklet/compiled/:file', (req, res) ->
  res.sendfile('bookmarklet/compiled/' + req.params.file)


peer_id = "peernum"
url_id = "onlyurl"
peer_id_counter = 0
curr_peers = []

app.post '/new_peer', (req, res) ->

  result = onPeerConnected(req.body.full_url)
  # TODO(brie): remove this. left in for now, for debugging
  console.log(JSON.stringify(urlToURLIds, null, 4))
  console.log(JSON.stringify(urlIdToURL, null, 4))
  console.log(JSON.stringify(urlIdToPeerIds, null, 4))
  res.send(JSON.stringify(result))

app.post '/delete_peer', (req, res) ->
  result = onPeerDisconnected(req.body.peer_id, req.body.url_id)
  # TODO(brie): remove this. left in for now, for debugging
  console.log(JSON.stringify(urlToURLIds, null, 4))
  console.log(JSON.stringify(urlIdToURL, null, 4))
  console.log(JSON.stringify(urlIdToPeerIds, null, 4))
  if result.success
    res.send(200)
  else
    res.send(500, { error: result.message })

app.post '/update_peer', (req, res) ->
  res.send('TODO - not implemented')

port = process.env.PORT || 5000

app.listen port, ->
  console.log("Listening on " + port)

