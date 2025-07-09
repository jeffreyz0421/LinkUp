DROP TABLE users IF EXISTS;

CREATE TABLE users (
    userid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL
);

DROP TABLE user_profiles IF EXISTS;

CREATE TABLE user_profiles (
    userid UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,
    birthdate DATE,
    hobbies TEXT[],
    friends UUID[],
    last_active_location geography(Point, 4326),
    verified_email BOOLEAN,
    verified_phone_number BOOLEAN
);

DROP TABLE friendships IF EXISTS;

CREATE TABLE friendships {
    userid1 UUID NOT NULL,
    userid2 UUID NOT NULL,
    PRIMARY KEY (userid1, userid2),
    FOREIGN KEY (userid1) REFERENCES users(userid) ON DELETE CASCADE,
    FOREIGN KEY (userid2) REFERENCES users(userid) ON DELETE CASCADE,
    CHECK (userid1 < userid2) -- have to order UUIDs when inserting a friendship
};

DROP TABLE universities IF EXISTS;

CREATE TABLE universities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    area geometry
);

DROP TABLE buildings IF EXISTS;

CREATE TABLE buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(id),
    name VARCHAR(255) NOT NULL,
    location geography(Point, 4326) NOT NULL
);