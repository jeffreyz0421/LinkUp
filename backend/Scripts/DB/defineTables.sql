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


CREATE TYPE functiontype AS ENUM ('meetup', 'linkup', 'gangup', 'pullup');
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
    active BOOLEAN,
    bio TEXT,
    birthdate DATE,
    hobbies VARCHAR(63)[],
    friends UUID[],
    last_active_location geography(Point, 4326),
    last_active TIMESTAMP WITH TIME ZONE NOT NULL,
    school_id UUID REFERENCES universities(university_id),
    verified_email BOOLEAN,
    verified_phone_number BOOLEAN,
    functions_attended smallint,
    rating smallint
);

CREATE TABLE friendships (
    user_id1 UUID NOT NULL,
    user_id2 UUID NOT NULL,
    PRIMARY KEY (user_id1, user_id2),
    FOREIGN KEY (user_id1) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id2) REFERENCES users(user_id) ON DELETE CASCADE,
    CHECK (user_id1 != user_id2)
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


CREATE INDEX idx_function_attendees_function_id ON function_attendees(function_id);
CREATE INDEX idx_function_attendees_user_id ON function_attendees(user_id);