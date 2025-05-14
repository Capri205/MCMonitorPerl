let intervalId = null;

/* Check to see if the monitoring agent is alive and redirect to the main page if so
** Makes an ajax call to the controller which checks for the agent running or not
**
** @parms none
** returns nothing
*/
function checkAgentStatus() {

  console.log("checking check_agent");
  fetch('check_agent')

      .then(response => response.json())
      .then( data => {

console.log("data: ", data);

          // check for errors being returned
          if ( data.issue !== "NO_MONRUN" ) {
              window.location.href = "/";
          }

      })
      .catch(error => {
          console.error( 'Error checking agent:', error , ", " , error.message );
          document.getElementById( "message" ).textContent = error;
          document.getElementById( "catalystdownsound" ).play();
      });
}

setInterval(checkAgentStatus, 5000);
