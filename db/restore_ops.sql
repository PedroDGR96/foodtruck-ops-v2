-- =============================================
-- Restaurant Ops Backup & Recovery Scripts
-- =============================================
-- Uses SQLite for ops data (fallback storage)
-- PostgreSQL RLS used by main app
-- =============================================

-- Enable foreign keys and transactions
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- Function to create backup directory if it doesn't exist
CREATE TABLE IF NOT EXISTS backups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  source_type TEXT NOT NULL, -- 'backup', 'migration', 'checkpoint'
  size_bytes INTEGER,
  checksum TEXT,
  status TEXT DEFAULT 'completed'
);

-- =============================================
-- BACKUP FUNCTION (SQLite)
-- =============================================

CREATE TABLE IF NOT EXISTS orders_backup (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code TEXT NOT NULL UNIQUE,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(10,2),
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'completed', -- completed, failed
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kitchen_orders_backup (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  order_code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, cooking, ready_for_pickup, ready, sold_out
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payment_history_backup (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  order_code TEXT NOT NULL UNIQUE,
  amount NUMERIC(10,2),
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'completed', -- completed, failed
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cash_register_backup (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_code TEXT UNIQUE NOT NULL,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(10,2),
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'completed', -- completed, refunded
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS daily_report_backup (
  report_code TEXT NOT NULL UNIQUE,
  order_codes TEXT NOT NULL,      -- comma-separated list of order codes for this report
  total_sales NUMERIC(10,2),
  status TEXT NOT NULL DEFAULT 'generated', -- generated, processed
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- RESTORE FUNCTIONS (SQLite)
-- =============================================

-- Restore orders from backup
CREATE TABLE IF NOT EXISTS orders_restore (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code TEXT NOT NULL UNIQUE,
  business_id UUID REFERENCES app_settings(id), -- RLS policy uses this GUC
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Restore kitchen_orders from backup
CREATE TABLE IF NOT EXISTS kitchen_orders_restore (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  order_code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Restore payment_history from backup
CREATE TABLE IF NOT EXISTS payment_history_restore (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  order_code TEXT NOT NULL UNIQUE,
  amount NUMERIC(10,2),
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Restore cash_register from backup
CREATE TABLE IF NOT EXISTS cash_register_restore (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_code TEXT UNIQUE NOT NULL,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(10,2),
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Restore daily_report from backup
CREATE TABLE IF NOT EXISTS daily_report_restore (
  report_code TEXT NOT NULL UNIQUE,
  order_codes TEXT NOT NULL, -- comma-separated list of order codes
  total_sales NUMERIC(10,2),
  status TEXT NOT NULL DEFAULT 'generated',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- RESTORE LOG (SQLite)
-- =============================================

CREATE TABLE IF NOT EXISTS restore_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_type TEXT NOT NULL, -- 'backup', 'restore', 'checkpoint'
  target_id UUID,
  source_id UUID,
  checksum TEXT,
  status TEXT DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- SYNC QUEUE (SQLite)
-- =============================================

CREATE TABLE IF NOT EXISTS sync_queue_restore (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, synced_to_kitchen, completed
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- TRANSACTION COMPLETE
-- =============================================

COMMIT;

-- =============================================
-- USAGE INTELLECTUAL PROPERTY NOTICE
-- =============================================
-- This is a SQLite-based backup/restore system for restaurant POS operations.
-- PostgreSQL RLS and tenant isolation used by main app.
-- Backup files are stored in /home/pedrp/.traycer/worktrees/local__foodtruck-ops__30f7087a4a/t12-mock-adapters/db/backups/
-- =============================================