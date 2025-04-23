BEGIN;

-- Таблиця ролей
CREATE TABLE "role" (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(100) NOT NULL,
    description VARCHAR(255)
);

-- Таблиця планів підписки
CREATE TABLE "subscription_plan" (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    max_homes INT NOT NULL,
    max_sensors INT NOT NULL,
    price NUMERIC NOT NULL,
    duration_days INT NOT NULL
);

-- Таблиця режимів безпеки
CREATE TABLE "default_security_mode" (
    mode_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mode_name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    is_selectable BOOLEAN DEFAULT FALSE
);

-- Таблиця користувачів (user)
CREATE TABLE "user" (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    password VARCHAR(256),
    google_id VARCHAR(128),
    google_refresh_token TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    email_confirmed BOOLEAN DEFAULT FALSE,
    subscription_plan_name VARCHAR(100),
    FOREIGN KEY (role_id) REFERENCES "role"(role_id) ON DELETE CASCADE
);

-- Таблиця підписок
CREATE TABLE "subscription" (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    plan_id UUID NOT NULL,
    start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES "subscription_plan"(plan_id) ON DELETE CASCADE
);

-- Таблиця будинків
CREATE TABLE "home" (
    home_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    default_mode_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_archived BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
    FOREIGN KEY (default_mode_id) REFERENCES "default_security_mode"(mode_id) ON DELETE CASCADE
);

-- Таблиця мобільних пристроїв
CREATE TABLE "mobile_device" (
    user_device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_token TEXT NOT NULL,
    device_info VARCHAR(256),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE
);

-- Таблиця сенсорів
CREATE TABLE "sensor" (
    sensor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_id UUID NOT NULL,
    user_id UUID,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_closed BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT FALSE,
    is_security_breached BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (home_id) REFERENCES "home"(home_id) ON DELETE CASCADE
);

-- Таблиця сповіщень безпеки
CREATE TABLE "security_user_notifications" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_id UUID NOT NULL,
    sensor_id UUID,
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    importance VARCHAR(50) NOT NULL CHECK (importance IN ('low', 'medium', 'high')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    type VARCHAR(50) NOT NULL,
    data TEXT,
    FOREIGN KEY (home_id) REFERENCES "home"(home_id) ON DELETE CASCADE
);

-- Таблиця загальних сповіщень
CREATE TABLE "general_user_notifications" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    importance VARCHAR(50) NOT NULL CHECK (importance IN ('low', 'medium', 'high')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    type VARCHAR(50) NOT NULL,
    data TEXT,
    FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE
);

-- Вставка даних в таблицю ролей
INSERT INTO "role" (role_name, description)
VALUES
    ('user', NULL),
    ('admin', NULL);

-- Вставка даних в таблицю планів підписки
INSERT INTO "subscription_plan" (name, max_homes, max_sensors, price, duration_days)
VALUES
    ('premium', 5, 20, 10.0, 30),
    ('basic', 1, 4, 0.0, 365);

-- Вставка даних в таблицю режимів безпеки
INSERT INTO "default_security_mode" (mode_name, description, is_selectable)
VALUES
    ('armed', 'all sensors are active', TRUE),
    ('disarmed', 'all sensors are disabled', TRUE),
    ('custom', 'user changed default security mode', FALSE),
    ('alert', 'security breach detected', FALSE);

-- Вставка адміністратора (user)
INSERT INTO "user" (name, email, password, email_confirmed, role_id)
VALUES (
    'admin',
    'admin@safehome.com',
    'scrypt:32768:8:1$ZZVneUPUgNaVS50m$5829a2c811ecb90cabf4846952d381bb7fe021c7b0ebb9abeb7b044bd362f26e1c220932eb8d22084004d36d1e017c093e7bbc0f5f2c9b603ca72c4b3ce45e90',
    TRUE,
    (SELECT role_id FROM "role" WHERE role_name = 'admin')
);


-- Index to quickly look up default security modes by their name
CREATE INDEX idx_default_security_mode_name ON default_security_mode (mode_name);

-- Indexes for fast lookup and sorting of general user notifications
CREATE INDEX idx_general_notifications_user_id ON "general_user_notifications" (user_id); -- Filter notifications by user
CREATE INDEX idx_general_notifications_created_at ON "general_user_notifications" (created_at); -- Sort/filter notifications by creation time

-- Indexes to speed up queries related to mobile devices
CREATE INDEX idx_mobile_device_user_id ON "mobile_device" (user_id); -- Filter devices by user
CREATE INDEX idx_mobile_device_token ON "mobile_device" (device_token); -- Filter/search by device token
CREATE INDEX idx_mobile_device_user_token ON mobile_device (user_id, device_token); -- Compound index for combined user & token queries

-- Indexes to optimize queries on security-related notifications
CREATE INDEX idx_security_user_notifications_home_id ON "security_user_notifications" (home_id); -- Filter by home
CREATE INDEX idx_security_user_notifications_user_id ON "security_user_notifications" (user_id); -- Filter by user
CREATE INDEX idx_security_user_notifications_home_created ON "security_user_notifications" (home_id, created_at DESC); -- Filter by home & sort by time
CREATE INDEX idx_security_user_notifications_user_created ON "security_user_notifications" (user_id, created_at DESC); -- Filter by user & sort by time

-- Indexes for the "home" table
CREATE INDEX idx_home_user_id ON "home"(user_id); -- Filter homes by user
CREATE INDEX idx_home_is_archived ON "home"(is_archived); -- Filter archived/non-archived homes
CREATE INDEX idx_home_default_mode_id ON "home"(default_mode_id); -- Filter homes by their default security mode
CREATE INDEX idx_home_user_id_is_archived ON "home"(user_id, is_archived); -- Compound index for filtering homes by user and archive status

-- Indexes for the "sensor" table
CREATE INDEX idx_sensor_home_id ON "sensor" (home_id); -- Filter sensors by home
CREATE INDEX idx_sensor_is_active ON "sensor" (is_active); -- Filter active/inactive sensors
CREATE INDEX idx_sensor_is_closed ON "sensor" (is_closed); -- Filter closed/open sensors
CREATE INDEX idx_sensor_is_archived ON "sensor" (is_archived); -- Filter archived/non-archived sensors
CREATE INDEX idx_sensor_is_breached ON "sensor" (is_security_breached); -- Filter sensors that triggered breach
CREATE INDEX idx_sensor_home_is_archived ON "sensor" (home_id, is_archived); -- Compound index for sensors by home and archive status
CREATE INDEX idx_sensor_user_is_archived ON "sensor" (user_id, is_archived); -- Compound index for sensors by user and archive status

-- Indexes for the "subscription" table
CREATE INDEX idx_subscription_user_id ON "subscription" (user_id); -- Filter subscriptions by user
CREATE INDEX idx_subscription_plan_id ON "subscription" (plan_id); -- Filter subscriptions by plan
CREATE INDEX idx_subscription_start_date ON "subscription" (start_date); -- Filter/sort subscriptions by start date
CREATE INDEX idx_subscription_user_active ON subscription (user_id, is_active); -- Filter active subscriptions by user

-- Index for quick lookups of subscription plans by name
CREATE INDEX idx_subscription_plan_name ON subscription_plan (name);

-- Index to speed up filtering users by their role
CREATE INDEX idx_user_role_id ON "user" (role_id);


COMMIT;
