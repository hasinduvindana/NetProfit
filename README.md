# NetProfit 📈

NetProfit is a professional-grade business management and payroll application built with Flutter. It streamlines employee management, expense tracking, and salary disbursements with a modern, high-performance user interface.

## 🚀 Key Features

- **Glassmorphism UI**: A premium, frosted-glass design theme with real-time hover effects and smooth animations optimized for high-end devices like the Google Pixel 7.
- **Dynamic Dashboard**: A 2x2 grid navigation system providing instant insights into employee counts and monthly business costs (Fuel, Ice, Advances, and Misc).
- **Automated Payroll Logic**: Smart transition logic for their salary date of every month that:
  - Carries forward employee debts (negative balances) as expenses for the next month.
  - Automatically settles positive balances into the business total expense collection.
- **Secure PIN Authorization**: All financial transactions and sensitive updates are secured with a 4-digit PIN verification system using SHA-256 hashing.
- **Automated PDF Reports**: Generate professional expense and payment history reports in PDF format directly from the app.

## 🛠️ Technical Stack

- **Framework**: [Flutter](https://flutter.dev/) (3.x)
- **Backend**: [Firebase](https://firebase.google.com/)
  - **Firestore**: Real-time NoSQL database for business records.
  - **Authentication**: Google Sign-In and secure Firebase Auth.
  - **Cloud Functions**: Scheduled Node.js functions for monthly payroll automation.
- **State Management**: StatefulWidgets with optimized StreamBuilders for real-time UI updates.
- **Security**: Crypto-standard SHA-256 PIN hashing.

## 🛡️ License

Developed by **CoderixSoft Technologies.**

## © 2026 CoderixSoft Technologies. All rights reserved.

## UI ScreenShots

**1. Loading Screen**

<img width="314" height="627" alt="image" src="https://github.com/user-attachments/assets/e8b8c83b-b628-44e2-a272-b8c1b4b0f16e" />
<img width="295" height="616" alt="image" src="https://github.com/user-attachments/assets/b8c1ae6b-ee15-44b6-bd28-b2b522db7a2a" />

**2. Login & Signup Screens**

<img width="303" height="615" alt="image" src="https://github.com/user-attachments/assets/d83cd79b-8ea3-4ff4-b83d-2c044d4f4e45" />
<img width="300" height="620" alt="image" src="https://github.com/user-attachments/assets/1b8e0d6d-627e-4efc-83c4-6e9babc93b26" />
<img width="317" height="622" alt="image" src="https://github.com/user-attachments/assets/7e7b2329-b510-40ee-9083-65b035f4403f" />

**3. Admin Dashboard**

<img width="308" height="621" alt="image" src="https://github.com/user-attachments/assets/bc9040f7-3698-4727-ae37-a8dcb85c911d" />
<img width="304" height="623" alt="image" src="https://github.com/user-attachments/assets/999b40ce-f602-4187-acdc-cc1e5171493b" />

**4. Manage Employee**

<img width="303" height="620" alt="image" src="https://github.com/user-attachments/assets/8caf2316-30a6-46b2-9f5f-1e20843020a3" />

**5. Current Empployee**

<img width="312" height="621" alt="image" src="https://github.com/user-attachments/assets/3faeb9d0-df08-4319-a97a-a16268eb3bfa" />

**6. Salary Status**


<img width="323" height="628" alt="image" src="https://github.com/user-attachments/assets/66d1b680-1e1b-46c9-9fd2-0b2e76435011" />

**7. Expences**

<img width="305" height="619" alt="image" src="https://github.com/user-attachments/assets/2b7ea977-6767-4b66-99de-164cdc4af884" />











