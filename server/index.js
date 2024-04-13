// SPDX-License-Identifier: MIT

// Importing necessary modules
const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const env = require('../lib/env/env.json');

// Initializing express application
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
const Room = require('./models/room');
var io = require('socket.io')(server);

/// @dev Array containing player factions
/// Used to later calculate the turns in function to boardgame faction order
/// One can simple organize this as pretended
const playerFactions = [
  'Crimea',
  'Saxony',
  'Polania',
  'Albion',
  'Nordic',
  'Rusviet',
  'Togawa',
];

// Middleware for parsing JSON requests  |  client -> server
app.use(express.json());

// MongoDB connection string   |   your MondoDB URL string 
const DB = `mongodb+srv://${env.username}:${env.password}@cluster0.noe1aet.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0`;

// Function to check if a player faction is already picked in a room
function isPlayerFactionAlreadyPicked(room, playerFaction) {
  return room.players.some(player => player.playerfaction === playerFaction);
};

// Function to check if a player mat is already picked in a room
function isPlayerMatAlreadyPicked(room, playerMat) {
  return room.players.some(player => player.playermat === playerMat);
};

function reorderPlayers(players) {
  // Sort players based on playerMat
  players.sort((a, b) => {
    if (a.playermat < b.playermat) return -1;
    if (a.playermat > b.playermat) return 1;
    return 0;
  });

  // Find the first player
  const firstPlayer = players[0];

  // Find the index of the first player's playerfaction in the playerFactions array
  let currentIndex = playerFactions.indexOf(firstPlayer.playerfaction);

  // Reorder players array based on playerfaction index relative to the first player
  const reorderedPlayers = []; // Initialize empty array

  for (let i = 0; i < playerFactions.length; i++) {
    const currentFaction = playerFactions[currentIndex];
    const currentPlayer = players.find(player => player.playerfaction === currentFaction);
    if (currentPlayer) {
      reorderedPlayers.push(currentPlayer);
    }
    currentIndex++;
    if (currentIndex >= playerFactions.length) {
      currentIndex = 0; // Wrap around if index exceeds the length of playerFactions
    }
  }

  return reorderedPlayers;
}

// Socket.io event handler for connection
io.on('connection', (socket) => {
  // with socket -> send data to connected client
  // with io -> send data to everyone
  console.log('Player connected!');

  // Interval for updating player timers
  let roomTimerInterval;

  // This event handler creates a new room for the game
  socket.on('createRoom', async ({ nickname, playerfaction, playermat, timer }) => {
    try {
      // Check if the nickname is provided
      if (nickname == '') {
        socket.emit('errorOccurred', 'Please enter a valid nickname!');
        return;
      };
      // Create a new room and initialize player details
      let room = new Room();
      let player = {
        nickname,
        socketID: socket.id,
        playerfaction,
        playermat,
        timer,
      };
      // Add the player to the room and set the initial turn and creator
      room.players.push(player);
      room.turn = player;
      room.creator = player;

      // Save the room to the database and emit success event
      ///@dev add `console.log(room.toString());` here for room checks prints
      room = await room.save();
      const roomId = room._id.toString();

      // Join the room and notify clients about the room creation
      socket.join(roomId);
      io.to(roomId).emit('createRoomSuccess', room);
      console.log(room);
      console.log(roomId.toString());
    } catch (e) {
      console.log(e);
    }
  });

  // This event handler allows a player to join an existing room
  socket.on('joinRoom', async ({ nickname, roomId, playerfaction, playermat }) => {
    try {
      // Check if the provided roomId is valid
      if (!roomId.match(/^[0-9a-fA-F]{24}$/)) {
        socket.emit('errorOccurred', 'Please enter a valid Room ID.');
        return;
      }
      // Retrieve the room information from the database
      let room = await Room.findById(roomId);

      // Check if the room is joinable
      if (room.isJoin) {
        // Check if the selected player faction or player mat is already picked
        if (isPlayerFactionAlreadyPicked(room, playerfaction) || isPlayerMatAlreadyPicked(room, playermat)) {
          socket.emit('errorOccurred', 'Player faction or player mat is already picked in this room.');
          return;
        };
        // Check if the nickname is provided
        if (nickname == '') {
          socket.emit('errorOccurred', 'Please enter a valid nickname!');
          return;
        };

        // Retrieve timer from the first player
        let timer = room.players[0].timer;
        let player = {
          nickname,
          socketID: socket.id,
          playerfaction,
          playermat,
          timer,
        };
        // Join the room and update room information
        socket.join(roomId);
        room.players.push(player);

        // Check if the room is full
        if (room.players.length > 6) {
          // Close the room for joining
          room.isJoin = false;

          // Reorganize the players and set the first player
          room.players = reorderPlayers(room.players);
          room.turn = room.players[0];
        } else {
          room.isJoin = true;
        }
        // Save the updated room information and emit events to clients
        room = await room.save();
        ///@dev add `console.log(room.toString());` here for room checks prints
        io.to(roomId).emit('updateRoom', room);
        socket.emit('joinRoomSuccess', room);
      } else if (room.players.some(player => player.socketID == socket._id)) {
        // If the player is already in the room, let them rejoin
        socket.join(roomId);
        socket.emit('joinRoomSuccess', room);
      } else {
        // If the game is already closed, prevent joining and notify the player
        socket.emit('errorOccurred', 'This game is in progress, try another room');
      }
    } catch (e) {
      console.log(e);
    }
  });

  // Socket event handler for 'startGame' event
  socket.on('startGame', async ({ roomId }) => {
    try {
      let room = await Room.findById(roomId);

      if (room.players.length == 1) {
        //console.log('Erro para snackbar');
        socket.emit('errorOccurred', 'You aren\'t playing with Automa!!');
        return;
      }
      room.isJoin = false;
      // Reorganize the players
      room.players = reorderPlayers(room.players);
      // Set the first player
      room.turn = room.players[0];
      room = await room.save();

      ///@dev Add `console.log(room.toString());` here for room checks prints
      /// Emit the updated room data to all clients
      io.to(roomId).emit('updateRoom', room);
      console.log('\n\n\nGame Started\n\n\n');
      console.log(room);

      // Start next timer
      startPlayerTimer(roomId, 0);

    } catch (e) {
      console.log(e);
    }
  });

  // This function handles the turn-based logic in the game
  socket.on('turn', async ({ roomId }) => {
    try {
      // Pause the current player's timer
      clearInterval(roomTimerInterval);

      // Retrieve room information from the database
      let room = await Room.findById(roomId);
      let atualTurn = parseInt(room.turnIndex);

      // Check if it's the last player's turn or not
      if (atualTurn < (room.players.length - 1)) {
        // Move to the next player's turn
        room.turnIndex++;
        atualTurn++;
        room.turn = room.players[atualTurn];
      } else {
        // Move to the first player's turn
        room.turn = room.players[0];
        room.turnIndex = 0;
        atualTurn = 0;
        room.totalTurns++;
      }
      // Ensure the player's timer is reset to 10 if it's less than 10
      if (room.players[atualTurn].timer < 10) {
        room.players[atualTurn].timer = 10
      }
      // Save room data and emit an event to notify clients about the new turn
      room = await room.save();
      io.to(roomId).emit('newTurn', room);

      // Start the timer for the next player
      startPlayerTimer(roomId, atualTurn);

    } catch (e) {
      console.log(e);
    }
  });

  // This function starts the timer for a player's turn
  const startPlayerTimer = async (roomId, playerIndex) => {
    let _room = await Room.findById(roomId);

    // Set an interval to update the timer every second
    roomTimerInterval = setInterval(async () => {
      let room = await Room.findById(roomId);
      if (room.isPaused || _room.turn.socketID != room.turn.socketID) {
        // Pause the timer if the game is paused or it's not the current player's turn
        clearInterval(roomTimerInterval);
        return;
      } else if (room.players[playerIndex].timer > 0) {
        // Decrement the player's timer if it's greater than 0
        room.players[playerIndex].timer--;
        room = await room.save();
        io.to(roomId).emit('updateRoom', room);
      } else {
        // If the player's timer reaches 0, auto-pass the turn
        room = await room.save();
        io.to(roomId).emit('updateRoom', room);
        autoPassTurn(roomId);
      }
    }, 1000); // Update timer every second
  }

  // This function automatically passes the turn when a player's timer reaches 0
  const autoPassTurn = async (roomId) => {
    // Pause the current player's timer
    clearInterval(roomTimerInterval);

    let room = await Room.findById(roomId);
    let atualTurn = parseInt(room.turnIndex);

    if (atualTurn < (room.players.length - 1)) {
      room.turnIndex++;
      atualTurn++;
      room.turn = room.players[atualTurn];
    } else {
      room.turn = room.players[0];
      room.turnIndex = 0;
      atualTurn = 0;
      room.totalTurns++;
    }
    if (room.players[atualTurn].timer < 10) {
      room.players[atualTurn].timer = 10
    }
    room = await room.save();
    io.to(roomId).emit('newTurn', room);
    // Start the timer for the next player
    startPlayerTimer(roomId, atualTurn);
  }

  // This event handler pauses the game
  socket.on('pause', async ({ roomId }) => {
    try {
      clearInterval(roomTimerInterval);
      let room = await Room.findById(roomId);
      room.isPaused = true;
      room = await room.save();
      io.to(roomId).emit('updateRoom', room);

    } catch (e) {
      console.log(e);
    }
  });

  // This event handler resumes the game
  socket.on('toContinue', async ({ roomId, atualTurn }) => {
    try {
      let room = await Room.findById(roomId);
      room.isPaused = false;
      room = await room.save();
      startPlayerTimer(roomId, atualTurn);

    } catch (e) {
      console.log(e);
    }
  });
});

// Connecting to MongoDB
mongoose
  .connect(DB)
  .then(() => {
    console.log('connection to MongoDB success!');
  })
  .catch((e) => {
    console.log(e);
  });

server.listen(port, '0.0.0.0', () => {

  console.log(`Server Started and running on port ${port}`);

});
