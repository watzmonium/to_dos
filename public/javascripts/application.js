// application.js
// the $ is the jquery object, and we're passing it an anon function
$(function() {

  // can use form.delete or just .delete depending on how much control you need
  $(".delete").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      // this.submit();

      var form = $(this);
      var request = $.ajax({
        url: form.attr("action"),
        method: form.attr("method")
      });

      // this only works when the request competes succesfully
      // data is the return from the request (in this case sinatra methods)
      // jqXHR is stuff from the req
      request.done(function(data, textStatus, jqXHR) {
        if (jqXHR.status === 204) {
          form.parent("li").remove();
        } else if (jqXHR.status === 200) {
          document.location = data;
        }
      });

      // request.fail should also exist
    }
  });
});