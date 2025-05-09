
DROP TABLE IF EXISTS Project;
CREATE TABLE Project (
    ProjectId INTEGER PRIMARY KEY AUTOINCREMENT,
    Title TEXT NOT NULL UNIQUE,
    Summary TEXT,
    Author TEXT,
    Date TEXT NOT NULL, -- Use TEXT in ISO format (YYYY-MM-DD) for SQLite
    Keywords TEXT,      -- You can store as comma-separated string or normalize it later
    Permalink TEXT,
    FilePath TEXT,
    Thumbnail TEXT
);

DROP TABLE IF EXISTS Category;
CREATE TABLE Category (
    CategoryId INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL UNIQUE,
    Description TEXT
);

DROP TABLE IF EXISTS Language;
CREATE TABLE Language (
    LanguageId INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL UNIQUE,
    DisplayName TEXT NOT NULL,
    Description TEXT
);

DROP TABLE IF EXISTS ProjectLanguage;
CREATE TABLE ProjectLanguage (
    ProjectId INTEGER NOT NULL,
    LanguageId INTEGER NOT NULL,
    PRIMARY KEY (ProjectId, LanguageId),
    FOREIGN KEY (ProjectId) REFERENCES Project(ProjectId) ON DELETE CASCADE,
    FOREIGN KEY (LanguageId) REFERENCES Language(LanguageId) ON DELETE CASCADE
);


DROP TABLE IF EXISTS ProjectCategory;
CREATE TABLE ProjectCategory (
    ProjectId INTEGER NOT NULL,
    CategoryId INTEGER NOT NULL,
    PRIMARY KEY (ProjectId, CategoryId),
    FOREIGN KEY (ProjectId) REFERENCES Project(ProjectId) ON DELETE CASCADE,
    FOREIGN KEY (CategoryId) REFERENCES Category(CategoryId) ON DELETE CASCADE
);
