# Dashboard for viewing chatternets

urlMap = {}
urlArr = []
peer_template =  Handlebars.templates["active_peer_site"]

updateItem = (url, peer_count) =>
  if not urlMap[url]
    urlMap[url] = {"url": url, "peer_count": peer_count}
    urlArr.push(urlMap[url])
  urlMap[url].peer_count = peer_count
  if peer_count == 0
    ind = urlArr.indexOf(urlMap[url])
    if ind != -1
      urlArr.splice(ind, 1)
      delete urlMap[url]

updateUI = =>
  $(".active-peer-sites").empty()
  urlArr.sort (a, b) =>
    return a.peer_count - b.peer_count
  for item in urlArr
    $(".active-peer-sites").prepend(peer_template({"url": item.url, "peer_count": item.peer_count}))
  if urlArr.length == 0
    $(".active-peer-sites").prepend("<p>You're the first! Click the bookmarklet on any site. We can recommend <a href='http://www.google.com' target='_blank'>Google</a>, or <a href='http://www.xkcd.com' target='_blank'>xkcd</a>, or any other!</p>")

$(document).ready =>
  console.log(Handlebars.templates)
  peer_template =  Handlebars.templates["active_peer_site"]
  host = location.origin.replace(/^http/, 'ws')
  ws = new WebSocket(host);
  ws.onmessage =  (event) =>
    console.log("MESSAGE")
    console.log event.data
    data = JSON.parse(event.data)
    if data.name == "peer_urls"
      for item in data.data
        updateItem(item[0], item[1])
      updateUI()
    else if data.name == "peer-connected" || data.name == "peer-disconnected"
      updateItem(data.data.url, data.data.peer_count)
      updateUI()
      console.log(data.data)


