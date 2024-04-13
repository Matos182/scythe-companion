
# Scythe Companion App

Welcome to the Scythe Companion App repository! This project offers an expanded feature set building upon the functionality of the original Scythe Coin Calculator, enhancing the experience for players of the renowned board game, Scythe. Designed to streamline coin calculations and manage turn timers, this Android application enables players to delve deeper into strategic gameplay with ease.

This app serves as a supplementary tool for physical multiplayer games of Scythe. While designed to optimize multiplayer experiences, it may not be fully compatible for solo play against the Automa.


## Features

- **Homepage Interface**: The intuitive homepage interface provides options for simple calculations, room creation, room joining, and final result calculation, utilizing the functionalities of the previous Scythe Coin Calculator.

- **Scythe Coin Calculator**: This section allows users to input various variables for each player, such as their name, Popularity, Lands, Resources accumulated, Stars, Player's coins, and building reward coins. Upon inputting these values, users can simply click the convert button to initiate the conversion process and calculate the total coin reward, prominently displayed at the top of the page. The application supports up to seven players, with final results viewable on a dedicated final page. A refresh button in the AppBar enables convenient resetting of all parameters.

- **Room Creation and Joining**: The client-side functionality allows users to create and join rooms. Upon room creation, users input their name, faction, and player mat sorting. Additionally, room creators can set the individual turn global timer. Room joining is facilitated through a unique room ID generated upon creation.

- **Gameplay Management**: Once a room is composed, the creator assumes the role of the party leader and can initiate the game. The server resolves turn order, and during gameplay, the current turn player can press a button on their device to pass the turn. A decrementing timer tracks the turn player’s time in seconds, with a pause feature available for game interruptions.


## Installation

> This project's code was built for apk. Share your experiences with other builds!

> The server needs to be running for the App to work properly.

1. Clone the repository to your local machine using: `git clone https://github.com/Matos182/scythe-coin-calculator.git`
2. Create a Mongoose account and insert credentials in the `server.js` file.
3. In the project folder, open a terminal and upgrade your Flutter dependencies using `flutter pub get` and `flutter run`.
4. Run Flutter Icons: `flutter pub run flutter_launcher_icons:main`.
5. Compile the code using Flutter: `flutter build apk`.
6. Install and update dependencies on Node.js App
7. Run the `server.js` server.

As the final product requires the server to work properly, no binary file is provided in this release.

## Technology Stack

- **Server-side**: Utilizes Node.js to control the server-side operations, with MongoDB employed as the database solution.

- **Client-side**: Developed using Dart and Flutter, offering cross-platform compatibility for Android devices.

## Contributing

Contributions are welcome! If you have suggestions for new features, improvements, or bug fixes, feel free to open an issue or submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgements

-   Inspired by the board game Scythe created by Jamey Stegmaier.
-   App is written with Dart and built with Flutter.
-   The server is written in JavaScript and operated on a Node.js server, using [Mongoose database](https://www.mongodb.com/).

## Buy me a Coffee

Thank you!

XMR Address:
46cX3Gw71JyAoP91cde3YgFPV4uDopiSS2TTdsZyjk4nGy5SuYvBSeoYwscnfr57eN6b7Pp5sZMzrHNhjs22vHESBD2bRrz

BNB Smart Chain Address:
0x363365b8E01f4e6EbBc2630467c3354b4b74EC0C
