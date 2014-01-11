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

app.post '/new_peer', (req, res) ->
  console.log(req, res)

app.post '/delete_peer', (req, res) ->
  console.log(req, res)

app.post '/update_peer', (req, res) ->
  console.log(req, res)


port = process.env.PORT || 5000

app.listen port, ->
  console.log("Listening on " + port)