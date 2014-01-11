(function() {
// TODO(brie): we don't really need jquery, but adding it for speed.
// we can take it out later
var chatternet_unique_page_id = window.location.host + Math.random().toString(36).slice(2);
console.log(chatternet_unique_page_id)
chatternet_jquery_loading_script = document.createElement('script')
chatternet_jquery_loading_script.src = "//ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js";


chatternet_jquery_loading_script.onload = function() {

    var frame = $("<iframe/>");
    frame.attr("src", "//chatternets.herokuapp.com/bookmarklet/chatternets.html?chatterid=" + chatternet_unique_page_id);

    var frameWidth = "400px";

    frame.css({
        margin: "0px",
        padding: "0px",
        position: "fixed",
        top: 0,
        bottom: 0,
        right: 0,
        resize: "none",
        zIndex: 2147483647,
        width: frameWidth,
        height: "100%"
    });
    $("html").css({
        paddingRight: frameWidth,
        overflow: "scroll"
    });
    $("body").css("overflow", "scroll").after(frame);

    $("body").css("paddingRight", frameWidth).append(frame);

    window.onbeforeunload = function() {
        console.log("before unloading")
        $.ajax({ /* //chatternets.herokuapp.com */
          url: '//chatternets.herokuapp.com/delete_peer',
          type: "POST",
          data: {
              page_id: chatternet_unique_page_id
          },
          async: false
        });
    }
};
document.head.appendChild(chatternet_jquery_loading_script);
})();
