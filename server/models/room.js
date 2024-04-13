// Importing necessary modules
const mongoose = require('mongoose'); // Importing mongoose module
const playerSchema = require('./player'); // Importing playerSchema from './player' file

// Defining the schema for a room document
const roomSchema = new mongoose.Schema({
  // Field for occupancy indicating the number of players in the room
  occupancy: {
    type: Number,
  },
  // Field for storing the index of the current turn
  turnIndex: {
    type: Number,
    default: 0,
  },
  // Field for total number of turns
  totalTurns: {
    type: Number,
    default: 1,
  },
  // Field indicating if the room is open for joining
  isJoin: {
    type: Boolean,
    default: true,
  },
  // Field indicating if the room is paused
  isPaused: {
    type: Boolean,
    default: false,
  },
  // Array of players in the room, referencing playerSchema
  players: [playerSchema],
  // Current turn player, referencing playerSchema
  turn: playerSchema,
  // Creator of the room, referencing playerSchema
  creator: playerSchema,
});

// Creating a model for the room schema
const roomModel = mongoose.model('Room', roomSchema);

// Exporting the roomModel for use in other parts of the application
module.exports = roomModel;
