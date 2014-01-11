
urlMap = {}
urlArr = []
console.log Handlebars.templates
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
  console.log "TEMPLATES"
  console.log Handlebars.templates

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
  socket = io.connect('//chatternets.herokuapp.com');
  socket.on 'peer_urls', (data) =>
    console.log(data);
    for item in data
      updateItem(item[0], item[1])
    updateUI()
    

  socket.on 'peer-connected', (data) =>
    updateItem(data.url, data.peer_count)
    updateUI()
    console.log(data)

  socket.on 'peer-disconnected', (data) =>
    updateItem(data.url, data.peer_count)
    updateUI()
    console.log(data)

# <iframe src="#{url}" scrolling="no" ></iframe>
# <div class="frame-overlay"></div>
