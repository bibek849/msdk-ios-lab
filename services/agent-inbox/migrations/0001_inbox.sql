-- One contributor pilot. Retained tracking is a notification subscription, never
-- authorization to execute the event or work on a closed/reassigned task.
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  delivery_id TEXT NOT NULL UNIQUE,
  payload_sha256 TEXT NOT NULL,
  recipient_id INTEGER NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('issue', 'pull_request')),
  number INTEGER NOT NULL CHECK (number > 0),
  document TEXT NOT NULL,
  acknowledged INTEGER NOT NULL DEFAULT 0 CHECK (acknowledged IN (0, 1)),
  received_at TEXT NOT NULL
);
CREATE INDEX events_pending ON events(recipient_id, acknowledged, id);
CREATE INDEX events_acknowledged ON events(acknowledged, id);

CREATE TABLE tracked_items (
  recipient_id INTEGER NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('issue', 'pull_request')),
  number INTEGER NOT NULL CHECK (number > 0),
  PRIMARY KEY (recipient_id, item_type, number)
);

-- A duplicate delivery is still acknowledged when full. New data is rejected
-- atomically so GitHub can redeliver after the maintainer frees capacity.
CREATE TRIGGER events_capacity BEFORE INSERT ON events
WHEN NOT EXISTS (SELECT 1 FROM events WHERE delivery_id = NEW.delivery_id)
BEGIN
  SELECT CASE WHEN (SELECT COUNT(*) FROM events WHERE acknowledged = 0) >= 1000
    THEN RAISE(ABORT, 'inbox_capacity') END;
  SELECT CASE WHEN (SELECT COUNT(*) FROM events) >= 10000
    THEN RAISE(ABORT, 'inbox_capacity') END;
END;

CREATE TRIGGER tracking_capacity BEFORE INSERT ON tracked_items
WHEN NOT EXISTS (
  SELECT 1 FROM tracked_items WHERE recipient_id = NEW.recipient_id
    AND item_type = NEW.item_type AND number = NEW.number
)
BEGIN
  SELECT CASE WHEN (SELECT COUNT(*) FROM tracked_items) >= 10000
    THEN RAISE(ABORT, 'inbox_capacity') END;
END;
