// Generated by CoffeeScript 1.6.3
(function() {
  var MAX_ROOM_SIZE, VALID_UPDATE_STATUSES, WebSocketServer, app, express, generateId, getFullSummary, getPeerCount, logfmt, normalizeURL, onPeerConnected, onPeerDisconnected, pageIdToPeerAndUrlId, port, server, urlIdToPeerIds, urlIdToURL, urlToURLIds, uuid, wss,
    _this = this;

  express = require("express");

  logfmt = require("logfmt");

  uuid = require('node-uuid');

  app = express();

  WebSocketServer = require('ws').Server;

  server = require('http').createServer(app);

  wss = new WebSocketServer({
    server: server
  });

  wss.broadcast = function(data) {
    var client, _i, _len, _ref, _results;
    _ref = wss.clients;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      client = _ref[_i];
      _results.push(client.send(data));
    }
    return _results;
  };

  console.log('websocket server created');

  app.use(logfmt.requestLogger());

  app.use(express.bodyParser());

  normalizeURL = function(urlRaw) {
    var urlNormal;
    urlNormal = urlRaw;
    return urlNormal.replace(/([\?#].*$)/gi, "");
  };

  generateId = function() {
    return uuid.v1();
  };

  MAX_ROOM_SIZE = 5;

  urlToURLIds = {};

  urlIdToURL = {};

  urlIdToPeerIds = {};

  pageIdToPeerAndUrlId = {};

  getPeerCount = function(url) {
    var urlId, urlPeercount, _i, _len, _ref;
    urlPeercount = 0;
    if (!urlToURLIds[url]) {
      return 0;
    }
    _ref = urlToURLIds[url];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      urlId = _ref[_i];
      console.log(urlIdToPeerIds[urlId]);
      urlPeercount += urlIdToPeerIds[urlId] ? urlIdToPeerIds[urlId].length : 0;
    }
    return urlPeercount;
  };

  getFullSummary = function() {
    var summary, url, urlIds, urlPeercount;
    summary = [];
    for (url in urlToURLIds) {
      urlIds = urlToURLIds[url];
      urlPeercount = getPeerCount(url);
      summary.push([url, urlPeercount]);
      console.log("URL: " + url + " peercount: " + urlPeercount);
    }
    summary.sort(function(item) {
      return item[1];
    });
    return summary;
  };

  onPeerConnected = function(urlRaw, pageId) {
    var peerId, peerIds, roomFound, urlId, urlNormal, _i, _len, _ref;
    urlNormal = normalizeURL(urlRaw);
    if (!urlToURLIds.hasOwnProperty(urlNormal)) {
      urlId = generateId();
      urlIdToURL[urlId] = urlNormal;
      urlToURLIds[urlNormal] = [urlId];
    }
    peerId = generateId();
    peerIds = [];
    roomFound = false;
    _ref = urlToURLIds[urlNormal];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      urlId = _ref[_i];
      if (!urlIdToPeerIds.hasOwnProperty(urlId)) {
        urlIdToPeerIds[urlId] = [peerId];
        roomFound = true;
        break;
      }
      if (urlIdToPeerIds[urlId].length < MAX_ROOM_SIZE) {
        peerIds = urlIdToPeerIds[urlId].slice(0);
        urlIdToPeerIds[urlId].push(peerId);
        roomFound = true;
        break;
      }
    }
    if (!roomFound) {
      urlId = generateId();
      urlIdToURL[urlId] = urlNormal;
      urlToURLIds[urlNormal].push(urlId);
      urlIdToPeerIds[urlId] = [peerId];
    }
    pageIdToPeerAndUrlId[pageId] = {
      "peerId": peerId,
      "urlId": urlId
    };
    getFullSummary();
    console.log("EMIT PEER CONNECTED");
    wss.broadcast(JSON.stringify({
      'name': 'peer-connected',
      'data': {
        "url": urlNormal,
        "peer_count": getPeerCount(urlNormal)
      }
    }));
    return {
      peer_id: peerId,
      url_id: urlId,
      peers: peerIds
    };
  };

  onPeerDisconnected = function(pageId) {
    var index, peerId, url, urlId;
    console.log("disconnecting...");
    console.log(pageId);
    if (!pageIdToPeerAndUrlId[pageId]) {
      return {
        success: false,
        message: "That page id was not recognized"
      };
    }
    peerId = pageIdToPeerAndUrlId[pageId].peerId;
    urlId = pageIdToPeerAndUrlId[pageId].urlId;
    url = urlIdToURL[urlId];
    index = urlIdToPeerIds[urlId].indexOf(peerId);
    if (index === -1) {
      return {
        success: false,
        message: "That peer_id, url_id pair was not recognized"
      };
    }
    urlIdToPeerIds[urlId].splice(index, 1);
    if (urlIdToPeerIds[urlId].length === 0) {
      delete urlIdToPeerIds[urlId];
      url = urlIdToURL[urlId];
      delete urlIdToURL[urlId];
      index = urlToURLIds[url].indexOf(urlId);
      if (index === -1) {
        console.log("Something is horribly wrong");
        return;
      }
      urlToURLIds[url].splice(index, 1);
      if (urlToURLIds[url].length === 0) {
        delete urlToURLIds[url];
      }
    }
    delete pageIdToPeerAndUrlId[pageId];
    console.log("URL" + url);
    wss.broadcast(JSON.stringify({
      'name': 'peer-disconnected',
      'data': {
        "url": url,
        "peer_count": getPeerCount(url)
      }
    }));
    return {
      success: true
    };
  };

  VALID_UPDATE_STATUSES = {
    "DEAD": onPeerDisconnected
  };

  app.get('/', function(req, res) {
    return res.sendfile('dashboard/index.html');
  });

  app.get('/bookmarklet/:file(*)', function(req, res) {
    return res.sendfile('bookmarklet/' + req.params.file);
  });

  app.get('/dashboard/:file(*)', function(req, res) {
    return res.sendfile('dashboard/' + req.params.file);
  });

  app.get('/bookmarklet/compiled/:file', function(req, res) {
    return res.sendfile('bookmarklet/compiled/' + req.params.file);
  });

  app.get('/bookmarklet/library/:file', function(req, res) {
    return res.sendfile('bookmarklet/library/' + req.params.file);
  });

  app.get('/dashboard/compiled/:file', function(req, res) {
    return res.sendfile('dashboard/compiled/' + req.params.file);
  });

  app.get('/dashboard/library/:file', function(req, res) {
    return res.sendfile('dashboard/library/' + req.params.file);
  });

  app.post('/new_peer', function(req, res) {
    var result;
    if (!req.body.hasOwnProperty("full_url") || !req.body.hasOwnProperty("page_id")) {
      res.send(500, {
        error: "Must specify full_url and page_id parameters"
      });
      return;
    }
    result = onPeerConnected(req.body.full_url, req.body.page_id);
    return res.send(JSON.stringify(result));
  });

  app.post('/delete_peer', function(req, res) {
    var result;
    res.header("Access-Control-Allow-Origin", "*");
    if (!(req.body.hasOwnProperty("page_id"))) {
      console.log("ERROR: req body has no page_id param");
      res.send(500, {
        error: "Must specify page_id parameter"
      });
      return;
    }
    result = onPeerDisconnected(req.body.page_id);
    if (result.success) {
      console.log("SUCCESS!");
      return res.send(200);
    } else {
      console.log("ERROR: " + result.message);
      return res.send(500, {
        error: result.message
      });
    }
  });

  port = process.env.PORT || 5000;

  server.listen(port, function() {
    return console.log("Listening on " + port);
  });

  wss.on('connection', function(socket) {
    var summary;
    console.log('saw connection');
    summary = getFullSummary();
    console.log("FULL SUMMARY");
    console.log(summary);
    return socket.send(JSON.stringify({
      "name": 'peer_urls',
      "data": summary
    }));
  });

}).call(this);
