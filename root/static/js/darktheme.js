let toggle = document.querySelector(".toggle-darktheme");

// catch state on page reload and apply
// Turn the theme off if darktheme element exists in localStorage
console.log( "toggle.checked: " + toggle.checked );
if (localStorage.getItem("darktheme")) {
  console.log("darktheme is in local storage (toggled on). need to apply to page");
  toggle.checked = true;
  document.body.classList.add("darktheme");
  toggle.title = "Toggle dark theme";
} else {
    console.log("darktheme is not in local storage (toggled off?)");
}

toggle.addEventListener('click', function(e) {
//  e.preventDefault();
  console.log( "toggle.checked: " + toggle.checked );

  if (document.body.classList.contains("darktheme")) {
    console.log("darktheme is off");
    document.body.classList.remove("darktheme");
    toggle.title = "Toggle dark theme";
    localStorage.removeItem("darktheme");
    //location.reload();
  } else {
    console.log("darktheme is on");
    document.body.classList.add("darktheme");
    toggle.title = "Toggle dark theme";
    localStorage.setItem("darktheme", true);
  }
});