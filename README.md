Paddle App

Paddle App is a cross-platform mobile application built using Flutter that enables users to book paddle courts, share expenses, and manage peer-to-peer (P2P) payments securely.
It supports user authentication, payment processing, and real-time transaction tracking through RESTful APIs integrated with Mastercard Send.

**Tech Stack**
Frontend (Mobile Application)
Flutter – Cross-platform UI framework for iOS and Android development
Dart – Programming language used with Flutter
Visual Studio Code – Primary IDE for Flutter development
SharedPreferences – Local key-value storage for lightweight data persistence
Xcode – iOS emulator and development tool for app testing and debugging

Backend (Server Application)
Flask – Lightweight Python web framework for building RESTful APIs
Python – Backend programming language for business logic and API integration
SQLite – Relational database for storing user, booking, and transaction data
SQLAlchemy – Object Relational Mapper (ORM) for efficient and secure database interaction

**Key Features**

Book Paddle Courts – View and reserve available courts with friends
Split and Share Expenses – Divide costs among group members seamlessly
Transaction History – View and track previous payments and bookings
Court Availability – Browse available time slots in real-time
Wallet Management – Add and manage cards securely within the app
P2P Payments – Send and receive funds using Mastercard Send APIs

**Authentication and API Integration**

This project is a Proof of Concept (PoC) designed to demonstrate application flow, UI, and API integration structure.
For security reasons, certain sensitive components (such as OAuth 2.0, JWT-based authentication, and direct Mastercard Send API calls) are implemented within the organization’s private source code and are not included in this repository.

**Summary**

Paddle App highlights:
Cross-platform development using Flutter
REST API integration using Flask and SQLAlchemy
Secure data handling and modular architecture
Real-world fintech workflow simulation with Mastercard Send

User application flow:
1. User register in the app using personal details like Name, Email ID, username (User choice) and Phone Number.
2. User login into the app using username and password. (OAUTH authentication is supported)
3. User can add card into the app to use to make payments
4. User can view all available courts based on date and time.
5. User selects court and make decision about the payment whether it will be one payment or split payment
6. If user selects split payment, then system will ask to select usernames of other players.
7. All players will be charged equal amount to book the court.
8. Transaction history will be saved to view transactions and confirmation email will be sent to all players.
9. User data is stored in MySQL database and Mastercard Send API is called to perform actual payment processing.


