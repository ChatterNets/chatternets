# Server for Chatternets

express = require("express")
logfmt = require("logfmt")
app = express()

app.use(logfmt.requestLogger())

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
  console.log(req, res)
  response = JSON.stringify({"peer_id": peer_id + peer_id_counter, "peers": curr_peers, "url_id": url_id})
  peer_id_counter += 1
  res.send(response)

app.post '/delete_peer', (req, res) ->
  console.log(req, res)

app.post '/update_peer', (req, res) ->
  console.log(req, res)


port = process.env.PORT || 5000

app.listen port, ->
  console.log("Listening on " + port)