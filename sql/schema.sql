CREATE TABLE users (
    user_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE projects (
    project_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    start_date DATE,
    end_date DATE,
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE project_members (
    project_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role VARCHAR(30) NOT NULL,
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (project_id, user_id),
    CONSTRAINT fk_project_members_project
        FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE,
    CONSTRAINT fk_project_members_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT chk_project_members_role
        CHECK (role IN ('owner', 'manager', 'member'))
);

CREATE TABLE tasks (
    task_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    created_by INTEGER NOT NULL,
    assignee_id INTEGER,
    status VARCHAR(30) NOT NULL DEFAULT 'new',
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date DATE,
    completed_at TIMESTAMP,

    CONSTRAINT fk_tasks_project
        FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE,
    CONSTRAINT fk_tasks_created_by_user
        FOREIGN KEY (created_by) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_tasks_assignee_user
        FOREIGN KEY (assignee_id) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_tasks_creator_project_member
        FOREIGN KEY (project_id, created_by)
        REFERENCES project_members (project_id, user_id),
    CONSTRAINT fk_tasks_assignee_project_member
        FOREIGN KEY (project_id, assignee_id)
        REFERENCES project_members (project_id, user_id),
    CONSTRAINT chk_tasks_status
        CHECK (status IN ('new', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT chk_tasks_priority
        CHECK (priority IN ('low', 'medium', 'high')),
    CONSTRAINT chk_tasks_completed_at
        CHECK (completed_at IS NULL OR completed_at >= created_at)
);

CREATE TABLE comments (
    comment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_task
        FOREIGN KEY (task_id) REFERENCES tasks (task_id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT
);

CREATE TABLE time_entries (
    time_entry_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    work_date DATE NOT NULL,
    hours NUMERIC(5, 2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_time_entries_task
        FOREIGN KEY (task_id) REFERENCES tasks (task_id) ON DELETE CASCADE,
    CONSTRAINT fk_time_entries_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT chk_time_entries_hours CHECK (hours > 0 AND hours <= 24)
);

CREATE TABLE labels (
    label_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    color VARCHAR(20)
);

CREATE TABLE task_labels (
    task_id INTEGER NOT NULL,
    label_id INTEGER NOT NULL,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (task_id, label_id),
    CONSTRAINT fk_task_labels_task
        FOREIGN KEY (task_id) REFERENCES tasks (task_id) ON DELETE CASCADE,
    CONSTRAINT fk_task_labels_label
        FOREIGN KEY (label_id) REFERENCES labels (label_id) ON DELETE CASCADE
);
