# 📚 Library Management System (MySQL)

## 📌 Project Overview
This project is a **Database Management System (DBMS)** designed using **MySQL**.  
It manages books, authors, members, staff, loans, reservations, and fines in a library.  

The system demonstrates:
- ✅ Relational database design
- ✅ Proper use of Primary Keys, Foreign Keys, and Constraints
- ✅ Relationships (1–1, 1–M, and M–M)
- ✅ Normalized structure for efficiency and data integrity

---

## ⚙️ Features
- Manage **Books, Authors, Publishers, and Categories**
- Track **Members, Membership Cards, and Staff**
- Record **Loans, Reservations, and Fines**
- Ensure data integrity with constraints and relationships
- Demonstrates **1NF, 2NF, 3NF, and BCNF** principles

---

## 🗂️ Database Schema
The schema is implemented in `schema.sql` and contains:
- Tables with **PK, FK, UNIQUE, NOT NULL, CHECK**
- Many-to-Many relationships (`book_authors`, `book_categories`)
- Business rules (unique loans per copy, one active reservation per member/book)

---

## 🚀 How to Run
1. Install **MySQL 8+**.
2. Clone this repository:
   ```bash
   git clone https://github.com/your-username/library-management-system.git
   cd library-management-system
