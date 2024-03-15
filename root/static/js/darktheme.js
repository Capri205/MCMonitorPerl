$( document ).ready( function() {

  var toggle = document.getElementById("toggle-darktheme");

  // catch state on page reload and apply
  // Turn the theme off if darktheme element exists in localStorage
  if (localStorage.getItem("darktheme")) {
    toggle.checked = true;
    toggle.title = "Switch to light theme";
    document.body.classList.add("darktheme");
  }

  // catch toggle slider being pressed
  toggle.addEventListener('click', function(e) {
  //  e.preventDefault();
    if (document.body.classList.contains("darktheme")) {
      document.body.classList.remove("darktheme");
      toggle.checked = false;
      toggle.title = "Switch to dark theme";
      localStorage.removeItem("darktheme");
      //location.reload();
    } else {
      document.body.classList.add("darktheme");
      toggle.title = "Switch to light theme";
      localStorage.setItem("darktheme", true);
    }
  });
});
