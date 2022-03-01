let toggle = document.querySelector(".toggle-darktheme");

// catch state on page reload and apply
// Turn the theme off if darktheme element exists in localStorage
if (localStorage.getItem("darktheme")) {
  toggle.checked = true;
  document.body.classList.add("darktheme");
  toggle.title = "Toggle dark theme";
}

toggle.addEventListener('click', function(e) {
//  e.preventDefault();
  if (document.body.classList.contains("darktheme")) {
    document.body.classList.remove("darktheme");
    toggle.title = "Toggle dark theme";
    localStorage.removeItem("darktheme");
    //location.reload();
  } else {
    document.body.classList.add("darktheme");
    toggle.title = "Toggle dark theme";
    localStorage.setItem("darktheme", true);
  }
});