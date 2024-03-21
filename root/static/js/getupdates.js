$( document ).ready( function() {

function fetchUpdates() {

    fetch( 'getserverupdates' )
        .then( response => response.json() )
        .then( data => {

            // hide error box
            document.getElementById( "errormsg" ).textContent = '';
            document.getElementById( "errormsg" ).style.display = 'none';
            document.getElementById( "errorh1" ).style.display = 'none';
            document.getElementById( "errorh2" ).style.display = 'none';
            var soundStop = document.getElementById( "catalystdownsound" );
            if ( soundStop != null ) { soundStop.pause(); soundStop.currentTime = 0; }

            // extract globalstate from serverlist as it's not a server
            // it's just a cheap way to transfer everything needed in one update

            /*
               globalstate:{
                 lasterror:{},
                 statetracker:{},
                 jointrackerdirection:{},
                 eventtracker:{},
                 jointrackerconcount:{},
                 sounds:{
                   playalarmsound:false,
                   playjoinsound:false,
                   playleavesound:false
                 },
                 playertracker:{}
               }
            */
            var globalstate;
            if ( Object.keys( data ).includes( "globalstate" ) ) {
              globalstate = data.globalstate;
              delete data[ "globalstate" ];
            }

            // update sound elements
            const sounds = globalstate.sounds;
            if ( sounds.playalarmsound == "true" ) {
              const audioElement = document.getElementById( "alarmsound" );
              if (audioElement) { audioElement.play(); }
            } else if ( sounds.playjoinsound == "true" ) {
              const audioElement = document.getElementById( "joinsound" );
              if (audioElement) { audioElement.play(); }
            } else if ( sounds.playleavesound == "true" ) {
              const audioElement = document.getElementById( "leavesound" );
              if (audioElement) { audioElement.play(); }
            }

            // Accessing the "jointrackerconcount" section
            const joinTrackerCount = globalstate.jointrackerconcount["ob-lobby"];

            // sort servers 
            const serversArray = Object.keys( data ).map( key => ( { name: key, ...data[key] } ) );
            serversArray.sort( ( a, b ) => {

              if ( a.isup > b.isup ) return -1;
              if ( a.isup < b.isup ) return 1;

              if ( a.enginetype < b.enginetype ) return -1;
              if ( a.enginetype > b.enginetype ) return 1;

              return a.name.localeCompare( b.name );
            });

            const serverlist = document.getElementById( "serverlist" );

            while( serverlist.rows.length > 1 ) {
              serverlist.deleteRow(1);
            }

            let currEngine = "NaN";
            serversArray.forEach( server => {

              if ( currEngine != server.enginetype ) {
                if ( currEngine != "NaN" ) {
                  let tbodyRef = serverlist.getElementsByTagName( "tbody" )[0];
                  let newDividerRow = tbodyRef.insertRow();
                  for ( var i = 0; i < 5; i++ ) {
                    let newCell = newDividerRow.insertCell();
                      newCell.className = "server-divider";
                      if ( i == 0 ) {
                        newCell.height = 20;
                      }
                  }
                }
                currEngine = server.enginetype;
              }

              var tbodyRef = serverlist.getElementsByTagName( "tbody" )[0];
              const newServerRow = tbodyRef.insertRow();
              const name = newServerRow.insertCell(0);
              name.style.verticalAlign = "middle";
              name.textContent = server.name + ( server.maintenancemode == 1 ? " (m)" : "" );

              const isup = newServerRow.insertCell(1);
              isup.style.verticalAlign = "middle";
              if ( server.state == "Starting" ) {
                isup.innerHTML = `<img src="static/images/starting.gif" style="width: 40px; height=40px;"/>`;
              } else if ( server.state == "Stopping" ) {
                isup.innerHTML = `<img src="static/images/stopping.gif" style="width: 40px; height=40px;"/>`;
              } else if ( server.state == 1 || server.state == "Running" ) {
                isup.innerHTML = `<img src="static/images/green_check_mark_circle.gif" style="width: 40px; height=40px;"/>`;
              } else if ( server.maintenancemode == 0 ) {
                isup.innerHTML = `<div><blink><img src="static/images/red_batsu_mark_circle.gif" style="width: 40px; height=40px;"/></blink></div>`;
              } else {
                isup.innerHTML = `<img src="static/images/red_batsu_mark_circle.gif" style="width: 40px; height=40px;"/>`;
              }
              
              const playercount = newServerRow.insertCell(2);
              playercount.style.verticalAlign = "middle";
              //playercount.textContent = server.enginetype;
              if ( globalstate.jointrackerdirection[ server.name ] == "Up" ) {
                playercount.innerHTML = `<p><span style="color: green; font-weight: bold;"><blink>${server.numconnections}</blink></span></p>`;
              } else if ( globalstate.jointrackerdirection[ server.name ] == "Down" ) {
                if ( globalstate.lasterror[ server.name ] != '' ) {
                  playercount.innerHTML = `<p><span style="color: red; font-weight: bold;"><blink>${globalstate.reason}.${server.name}</blink></span></p>`;
                } else {
                  playercount.innerHTML = `<p><span style="color: red; font-weight: bold;"><blink>${server.numconnections}</blink></span></p>`;
                }
              } else if ( globalstate.jointrackerdirection[ server.name ] == "NoChange" && globalstate.lasterror[ server.name ] != '' ) {
                  let lasterror = globalstate.lasterror[ server.name ];
                  playercount.innerHTML = `<p><span style="color: red; font-weight: bold; font-size: 10px;">${lasterror}</span></p>`;
              } else {
                playercount.innerHTML = server.numconnections;
              }

              const lastchecked = newServerRow.insertCell(3);
              lastchecked.textContent = server.lastchecked;
              
              const joinhistory = newServerRow.insertCell(4);
              joinhistory.style.verticalAlign = "middle";
              joinhistory.style.fontSize = "10px";
              const playerTracker = globalstate.playertracker[ server.name ];
              if ( playerTracker != null && playerTracker != "undefined" ) {
                var playerTrackerList = '';
                for ( let i = 0; i < playerTracker.length; i++ ) {
                  const time = playerTracker[i].slice( 0, playerTracker[i].indexOf( "#" ) );
                  const player = playerTracker[i].slice( playerTracker[i].indexOf( "#" ) + 1 );
                  playerTrackerList += player +  " @ " + time + "<br>";
                }
                joinhistory.innerHTML = playerTrackerList;
              }

            });
        })
        .catch(error => {
            console.error( 'Error fetching updates:', error );
            document.getElementById( "errormsg" ).textContent = error;
            document.getElementById( "errormsg" ).style.display = 'block';
            document.getElementById( "errorh1" ).style.display = 'block';
            document.getElementById( "errorh2" ).style.display = 'block';
            document.getElementById( "catalystdownsound" ).play();
        });
}

// Call fetchUpdates initially
fetchUpdates();

// Then set an interval to fetch updates periodically
setInterval(fetchUpdates, 10000); // Every 10 seconds
});
