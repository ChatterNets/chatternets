# Server for Chatternets

express = require("express")
logfmt = require("logfmt")
uuid = require('node-uuid')
io = require('socket.io')
app = express()
server = require('http').createServer(app)
io = io.listen(server)

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
pageIdToPeerAndUrlId = {}

getPeerCount = (url) =>
  urlPeercount = 0
  return 0 if not urlToURLIds[url]
  for urlId in urlToURLIds[url]
    console.log urlIdToPeerIds[urlId]
    urlPeercount += if urlIdToPeerIds[urlId] then urlIdToPeerIds[urlId].length else 0
  return urlPeercount

getFullSummary = =>
  summary = []
  for url, urlIds of urlToURLIds
    urlPeercount = getPeerCount(url)
    summary.push([url, urlPeercount])
    console.log("URL: " + url + " peercount: " + urlPeercount)
  summary.sort (item) =>
    return item[1]
  return summary

# The following conditions hold, as a result of this function:
# - the connected peer has been given an id
# - that id has been added to a room that has no more than MAX_ROOM_SIZE
#   other peers
#
# Returns: peer id that has been created for the connected user
onPeerConnected = (urlRaw, pageId) ->
  urlNormal = normalizeURL(urlRaw)

  if not urlToURLIds.hasOwnProperty(urlNormal)  # If the raw URL isn't yet mapped, map it.
    urlId = generateId()
    urlIdToURL[urlId] = urlNormal
    urlToURLIds[urlNormal] = [urlId]

  peerId = generateId()
  peerIds = []
  roomFound = false
  for urlId in urlToURLIds[urlNormal]
    if not urlIdToPeerIds.hasOwnProperty(urlId)
      # We are the first peer for this id
      urlIdToPeerIds[urlId] = [peerId]
      roomFound = true
      break

    if urlIdToPeerIds[urlId].length < MAX_ROOM_SIZE
      # There is space in this id for us
      peerIds = urlIdToPeerIds[urlId].slice(0)
      urlIdToPeerIds[urlId].push(peerId)
      roomFound = true
      break

  if not roomFound
    # If we get here, that means we didn't find a room to join.
    # So, we create one.
    urlId = generateId()
    urlIdToURL[urlId] = urlNormal
    urlToURLIds[urlNormal].push(urlId)
    urlIdToPeerIds[urlId] = [peerId]
  pageIdToPeerAndUrlId[pageId] = {"peerId": peerId, "urlId": urlId}
  getFullSummary() # TODO REMOVE
  console.log "EMIT PEER CONNECTED"
  io.sockets.emit('peer-connected', {"url": urlNormal, "peer_count": getPeerCount(urlNormal)});
  return { peer_id: peerId, url_id: urlId, peers: peerIds}

# Remove the peer from the room identified by urlId.
# Perform any cleanup necessary.
onPeerDisconnected = (pageId) ->
  console.log "disconnecting..."
  console.log pageId
  # console.log(JSON.stringify(pageIdToPeerAndUrlId, null, 4))

  if not pageIdToPeerAndUrlId[pageId]
    return { success: false, message: "That page id was not recognized" }

  peerId = pageIdToPeerAndUrlId[pageId].peerId
  urlId = pageIdToPeerAndUrlId[pageId].urlId
  url = urlIdToURL[urlId]
  
  # Remove the peer id from the url id's room
  index = urlIdToPeerIds[urlId].indexOf(peerId)
  if index == -1
    return {
      success: false,
      message: "That peer_id, url_id pair was not recognized" }
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
      console.log("Something is horribly wrong")
      return
    urlToURLIds[url].splice(index, 1)

    # If this was the last url id, remove the url
    if urlToURLIds[url].length == 0
      delete urlToURLIds[url]

  delete pageIdToPeerAndUrlId[pageId]
  console.log("URL" + url)
  io.sockets.emit('peer-disconnected', {"url": url, "peer_count": getPeerCount(url)});
  return { success: true }

# These functions must take in (peerId, urlId) and return
# { success: true } or
# { success: false, message: "[error message]"}
VALID_UPDATE_STATUSES = {
    "DEAD": onPeerDisconnected
}

#####################
# Server code

app.get '/', (req, res) ->
  res.sendfile('dashboard/index.html')

app.get '/bookmarklet/:file', (req, res) ->
  res.sendfile('bookmarklet/' + req.params.file)

app.get '/bookmarklet/compiled/:file', (req, res) ->
  res.sendfile('bookmarklet/compiled/' + req.params.file)
app.get '/bookmarklet/library/:file', (req, res) ->
  res.sendfile('bookmarklet/library/' + req.params.file)

app.get '/dashboard/compiled/:file', (req, res) ->
  res.sendfile('dashboard/compiled/' + req.params.file)
app.get '/dashboard/library/:file', (req, res) ->
  res.sendfile('dashboard/library/' + req.params.file)
# Create a new peer for the given url
app.post '/new_peer', (req, res) ->
  if not req.body.hasOwnProperty("full_url") or not req.body.hasOwnProperty("page_id")
    res.send(500, { error: "Must specify full_url and page_id parameters" })
    return

  result = onPeerConnected(req.body.full_url, req.body.page_id)
  res.send(JSON.stringify(result))

# Delete myself as a peer, given my peer id and the url id that I'm part of
app.post '/delete_peer', (req, res) ->
  res.header("Access-Control-Allow-Origin", "*")  # Allow cross-site scripting here
  if not (req.body.hasOwnProperty("page_id"))
    console.log("ERROR: req body has no page_id param")
    res.send(500, { error: "Must specify page_id parameter" })
    return

  result = onPeerDisconnected(req.body.page_id)
  if result.success
    console.log("SUCCESS!")
    res.send(200)
  else
    console.log("ERROR: " + result.message)
    res.send(500, { error: result.message })

# Update the status of some other peer, given their peer id, the url id, and
# what state I'm reporting for them.
# Valid statuses are those contained in VALID_UPDATE_STATUSES.
# app.post '/update_peer', (req, res) ->
#   if not (req.body.hasOwnProperty("peer_id") and req.body.hasOwnProperty("url_id") and req.body.hasOwnProperty("status"))
#     res.send(500, {
#       error: "Must specify peer_id, url_id, and status parameters" })
#     return

#   if not VALID_UPDATE_STATUSES.hasOwnProperty(req.body.status)
#     res.send(500, { error: req.body.status + " is not a valid status" })
#     return

#   result = VALID_UPDATE_STATUSES[req.body.status](
#     req.body.peer_id, req.body.url_id)

#   # TODO(brie): remove this. left in for now, for debugging
#   console.log(JSON.stringify(urlToURLIds, null, 4))
#   console.log(JSON.stringify(urlIdToURL, null, 4))
#   console.log(JSON.stringify(urlIdToPeerIds, null, 4))

#   if result.success
#     res.send(200)
#   else
#     res.send(500, { error: result.message })


port = process.env.PORT || 5000

server.listen port, ->
  console.log("Listening on " + port)

im = require('imagemagick');


io.sockets.on 'connection', (socket) =>
  console.log 'saw connection'
  summary = getFullSummary()
  console.log(JSON.stringify(summary,null, 4))
  # Send over the current data of how many people are on which pages (maybe suggest a few if none)
  socket.emit('peer_urls', summary)


  # Then, for each new connection that happens, emit to all sockets the new connection (?)
  # socket.on 'video-exit', (data) =>
  #   console.log('exit video')
  #   console.log(data)
