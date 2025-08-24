-- Library Management System Schema (MySQL 8+)
-- -------------------------------------------------

-- (Optional) choose/create a database
-- CREATE DATABASE IF NOT EXISTS library_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- USE library_db;

-- Ensure InnoDB for FK support
-- You can also set at table level with ENGINE=InnoDB

-- -------------------------------------------------
-- Core reference tables
-- -------------------------------------------------

CREATE TABLE branches (
  branch_id       BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name            VARCHAR(150) NOT NULL,
  phone           VARCHAR(30),
  email           VARCHAR(150),
  address_line1   VARCHAR(200) NOT NULL,
  address_line2   VARCHAR(200),
  city            VARCHAR(100) NOT NULL,
  state_province  VARCHAR(100),
  postal_code     VARCHAR(20),
  country         VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_branches_name_city (name, city)
) ENGINE=InnoDB;

CREATE TABLE publishers (
  publisher_id  BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(200) NOT NULL,
  website       VARCHAR(255),
  UNIQUE KEY uq_publishers_name (name)
) ENGINE=InnoDB;

CREATE TABLE authors (
  author_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  first_name  VARCHAR(100) NOT NULL,
  last_name   VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_authors_name (first_name, last_name)
) ENGINE=InnoDB;

CREATE TABLE categories (
  category_id  BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name         VARCHAR(120) NOT NULL,
  description  VARCHAR(255),
  UNIQUE KEY uq_categories_name (name)
) ENGINE=InnoDB;

-- -------------------------------------------------
-- Books & classification (M–M via junctions)
-- -------------------------------------------------

CREATE TABLE books (
  book_id         BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  isbn13          CHAR(13) NOT NULL,
  title           VARCHAR(255) NOT NULL,
  subtitle        VARCHAR(255),
  publisher_id    BIGINT UNSIGNED,
  published_year  YEAR,
  edition         VARCHAR(50),
  language_code   VARCHAR(10) DEFAULT 'en',
  pages           INT UNSIGNED,
  CONSTRAINT uq_books_isbn13 UNIQUE (isbn13),
  CONSTRAINT fk_books_publisher
    FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE book_authors (
  book_id    BIGINT UNSIGNED NOT NULL,
  author_id  BIGINT UNSIGNED NOT NULL,
  author_order SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (book_id, author_id),
  CONSTRAINT fk_book_authors_book
    FOREIGN KEY (book_id) REFERENCES books(book_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_book_authors_author
    FOREIGN KEY (author_id) REFERENCES authors(author_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE book_categories (
  book_id     BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (book_id, category_id),
  CONSTRAINT fk_book_categories_book
    FOREIGN KEY (book_id) REFERENCES books(book_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_book_categories_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- -------------------------------------------------
-- Physical inventory (copies) & availability
-- -------------------------------------------------

CREATE TABLE copies (
  copy_id     BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  book_id     BIGINT UNSIGNED NOT NULL,
  branch_id   BIGINT UNSIGNED NOT NULL,
  barcode     VARCHAR(64) NOT NULL,
  condition_note VARCHAR(200),
  status      ENUM('AVAILABLE','ON_LOAN','RESERVED','LOST','MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE',
  acquired_at DATE,
  CONSTRAINT uq_copies_barcode UNIQUE (barcode),
  CONSTRAINT fk_copies_book
    FOREIGN KEY (book_id) REFERENCES books(book_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_copies_branch
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- -------------------------------------------------
-- People: members & staff (+ a 1–1 membership card)
-- -------------------------------------------------

CREATE TABLE members (
  member_id      BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  first_name     VARCHAR(100) NOT NULL,
  last_name      VARCHAR(100) NOT NULL,
  email          VARCHAR(150) NOT NULL,
  phone          VARCHAR(30),
  date_of_birth  DATE,
  joined_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  active         TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT uq_members_email UNIQUE (email)
) ENGINE=InnoDB;

-- 1–1 relationship: each member may have exactly one card
CREATE TABLE membership_cards (
  member_id    BIGINT UNSIGNED PRIMARY KEY,
  card_number  VARCHAR(50) NOT NULL,
  issued_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at   DATETIME NOT NULL,
  active       TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT uq_membership_cards_number UNIQUE (card_number),
  CONSTRAINT fk_membership_cards_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT chk_card_dates CHECK (expires_at > issued_at)
) ENGINE=InnoDB;

CREATE TABLE staff (
  staff_id     BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  first_name   VARCHAR(100) NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  email        VARCHAR(150) NOT NULL,
  phone        VARCHAR(30),
  branch_id    BIGINT UNSIGNED NOT NULL,
  role         ENUM('LIBRARIAN','ASSISTANT','MANAGER','ADMIN') NOT NULL,
  hired_at     DATE NOT NULL,
  active       TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT uq_staff_email UNIQUE (email),
  CONSTRAINT fk_staff_branch
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- -------------------------------------------------
-- Circulation: loans, returns, reservations, fines & payments
-- -------------------------------------------------

CREATE TABLE loans (
  loan_id       BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  copy_id       BIGINT UNSIGNED NOT NULL,
  member_id     BIGINT UNSIGNED NOT NULL,
  issued_by     BIGINT UNSIGNED NOT NULL, -- staff who issued
  loan_date     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_date      DATETIME NOT NULL,
  return_date   DATETIME,
  status        ENUM('OPEN','RETURNED','OVERDUE','LOST') NOT NULL DEFAULT 'OPEN',
  CONSTRAINT fk_loans_copy
    FOREIGN KEY (copy_id) REFERENCES copies(copy_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_loans_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_loans_staff
    FOREIGN KEY (issued_by) REFERENCES staff(staff_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT chk_loan_dates CHECK (due_date > loan_date),
  INDEX idx_loans_member_status (member_id, status),
  INDEX idx_loans_copy_status (copy_id, status)
) ENGINE=InnoDB;

-- Reservations typically target a title; fulfillment may link to a specific copy
CREATE TABLE reservations (
  reservation_id    BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  book_id           BIGINT UNSIGNED NOT NULL,
  member_id         BIGINT UNSIGNED NOT NULL,
  requested_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status            ENUM('PENDING','READY','FULFILLED','CANCELLED','EXPIRED') NOT NULL DEFAULT 'PENDING',
  fulfilled_copy_id BIGINT UNSIGNED NULL,
  fulfilled_at      DATETIME,
  CONSTRAINT fk_reservations_book
    FOREIGN KEY (book_id) REFERENCES books(book_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_reservations_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_reservations_fulfilled_copy
    FOREIGN KEY (fulfilled_copy_id) REFERENCES copies(copy_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  INDEX idx_reservations_member_status (member_id, status)
) ENGINE=InnoDB;

-- Fines assessed usually per loan
CREATE TABLE fines (
  fine_id     BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  member_id   BIGINT UNSIGNED NOT NULL,
  loan_id     BIGINT UNSIGNED NOT NULL,
  amount_cents INT UNSIGNED NOT NULL,
  reason      ENUM('LATE_RETURN','LOST_ITEM','DAMAGED_ITEM','OTHER') NOT NULL,
  assessed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid        TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT chk_fines_amount CHECK (amount_cents > 0),
  CONSTRAINT fk_fines_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_fines_loan
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  INDEX idx_fines_member_paid (member_id, paid)
) ENGINE=InnoDB;

CREATE TABLE payments (
  payment_id    BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  member_id     BIGINT UNSIGNED NOT NULL,
  fine_id       BIGINT UNSIGNED NULL,
  amount_cents  INT UNSIGNED NOT NULL,
  method        ENUM('CASH','CARD','MOBILE','OTHER') NOT NULL,
  paid_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reference     VARCHAR(100),
  CONSTRAINT chk_payments_amount CHECK (amount_cents > 0),
  CONSTRAINT fk_payments_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_payments_fine
    FOREIGN KEY (fine_id) REFERENCES fines(fine_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  INDEX idx_payments_member_date (member_id, paid_at)
) ENGINE=InnoDB;

-- -------------------------------------------------
-- Helpful constraints & business rules via indexes/checks
-- -------------------------------------------------

-- Prevent a copy from being loaned out twice concurrently (unique open loan per copy)
CREATE UNIQUE INDEX uq_open_loan_per_copy
  ON loans (copy_id, status)
  WHERE status IN ('OPEN','OVERDUE');

-- Only one active reservation per member per book (optional business rule)
CREATE UNIQUE INDEX uq_active_reservation_per_member_book
  ON reservations (book_id, member_id, status)
  WHERE status IN ('PENDING','READY');

-- -------------------------------------------------
-- End of schema
-- -------------------------------------------------
