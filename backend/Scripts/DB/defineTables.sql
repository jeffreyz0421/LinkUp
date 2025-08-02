DROP TABLE IF EXISTS function_attendees CASCADE;
DROP TABLE IF EXISTS functions CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS buildings CASCADE;
DROP TABLE IF EXISTS communities CASCADE;
DROP TABLE IF EXISTS universities CASCADE;
DROP TABLE IF EXISTS users CASCADE;


DROP TYPE IF EXISTS functiontype CASCADE;
DROP TYPE IF EXISTS attendancestatus CASCADE;
DROP TYPE IF EXISTS friendshipstatus CASCADE;


CREATE TYPE functiontype AS ENUM ('meetup', 'linkup', 'gangup', 'pullup');
CREATE TYPE friendshipstatus AS ENUM ('requested', 'accepted');
CREATE TYPE attendancestatus AS ENUM ('invited', 'going', 'already there');


CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL
);

CREATE TABLE universities (
    university_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    area geometry
);

CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    active BOOLEAN DEFAULT true,
    bio TEXT DEFAULT 'Hi!',
    birthdate DATE,
    hobbies VARCHAR(63)[] DEFAULT '{}',
    friends UUID[] DEFAULT '{}',
    last_active_location geography(Point, 4326),
    last_active TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    school_id UUID REFERENCES universities(university_id),
    verified_email BOOLEAN DEFAULT false,
    verified_phone_number BOOLEAN DEFAULT false,
    functions_attended smallint DEFAULT 0,
    rating smallint DEFAULT 0
);

CREATE TABLE friendships (
    user_id1 UUID NOT NULL,
    user_id2 UUID NOT NULL,
    friendship_status friendshipstatus NOT NULL,
    PRIMARY KEY (user_id1, user_id2),
    FOREIGN KEY (user_id1) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id2) REFERENCES users(user_id) ON DELETE CASCADE,
    CHECK (user_id1 != user_id2),
    CHECK (user_id1 < user_id2)
);

CREATE TABLE buildings (
    building_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(university_id),
    name VARCHAR(255) NOT NULL,
    location geography(Point, 4326) NOT NULL
);

CREATE TABLE communities (
    community_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255)
);

CREATE TABLE functions (
    function_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host UUID REFERENCES users(user_id) NOT NULL,
    host1 UUID REFERENCES users(user_id), --Only used in case of a linkup--
    function_type functiontype NOT NULL,
    place_id VARCHAR(255) NOT NULL,
    function_name VARCHAR(255) NOT NULL,
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at TIMESTAMP WITH TIME ZONE,
    vibe VARCHAR(50)
);

CREATE TABLE function_attendees (
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    function_id UUID REFERENCES functions(function_id) ON DELETE CASCADE,
    attendance_status attendancestatus,
    PRIMARY KEY (user_id, function_id)
);

-- Make sure a user profile is created whenever a user signs up
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_profiles (user_id, active, last_active, verified_email, verified_phone_number, functions_attended, rating)
    VALUES (NEW.user_id, true, NOW(), false, false, 0, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_user_profile
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_profile();

CREATE INDEX idx_function_attendees_function_id ON function_attendees(function_id);
CREATE INDEX idx_function_attendees_user_id ON function_attendees(user_id);

CREATE EXTENSION IF NOT EXISTS POSTGIS;