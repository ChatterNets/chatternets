// TODO(brie): we don't really need jquery, but adding it for hacking speed.
// we can take it out later, if we want
var js = document.createElement('script');
js.src = "//ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js";
js.onload = function() {

    var frame = $("<iframe/>");
    frame.attr("src", "//chatternets.herokuapp.com/bookmarklet/chatternets.html");
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
    $("body").css("paddingRight", frameWidth).append(frame);

};
document.head.appendChild(js);
