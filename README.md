Paddle App: Digital Payment between parties

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
1. User Registration:
Users register with details such as name, email, username, and phone number.

2. Login & Authentication:
OAuth 2.0-based authentication is supported for secure login.

3. Wallet Setup:
Users can add and manage cards for future payments.

4. Court Booking:
View available courts filtered by date and time, then select a slot to book.

5. Payment Options:
Choose between a single payment or split payment mode.
In split mode, users select other participants, and the cost is divided equally.

6. Transaction Processing:
Mastercard Send APIs are used for fund transfer and transaction processing.

7. Transaction History & Notifications:
All transactions are logged in the database, and confirmation emails are sent to all participants.


