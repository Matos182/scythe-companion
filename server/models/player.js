// Importing necessary modules
const { Double } = require('mongodb'); // Importing Double from MongoDB module
const mongoose = require('mongoose'); // Importing mongoose module

// Defining the schema for a player document
const playerSchema = new mongoose.Schema({
  // Field for player's nickname, trimmed to remove whitespace
  nickname: {
    type: String,
    trim: true,
  },
  // Field for player's socket ID
  socketID: {
    type: String,
  },
  // Field for player's faction or team
  playerfaction: {
    type: String,
  },
  // Field for player's mat or board
  playermat: {
    type: String,
  },
  // Field for player's timer with default value of 20
  timer: {
    type: Number,
    default: 20,
  },
});

// Exporting the playerSchema for use in other parts of the application
module.exports = playerSchema;
