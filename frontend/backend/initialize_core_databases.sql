CREATE TABLE users (
    userid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL
);

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

CREATE TABLE friendships {
    userid1 UUID NOT NULL,
    userid2 UUID NOT NULL,
    PRIMARY KEY (userid1, userid2),
    FOREIGN KEY (userid1) REFERENCES users(userid) ON DELETE CASCADE,
    FOREIGN KEY (userid2) REFERENCES users(userid) ON DELETE CASCADE,
    CHECK (userid1 < userid2) -- Have to order UUIDs when inserting a friendship!
};

CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    spots UUID[]
);

CREATE TABLE spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    location geography(Point, 4326) NOT NULL,
    description TEXT
);