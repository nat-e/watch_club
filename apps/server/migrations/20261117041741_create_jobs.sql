-- The states of a job. Delayed jobs and retries wait as `available`, with a later `run_at`
CREATE TYPE job_state AS ENUM ('available', 'executing', 'completed', 'failed', 'cancelled');

-- A background job, which the server runs from this queue
CREATE TABLE jobs (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    queue text NOT NULL,
    -- The job's type, such as `delete_expired_sessions`, and its arguments
    kind text NOT NULL,
    args jsonb NOT NULL DEFAULT '{}',
    state job_state NOT NULL DEFAULT 'available',
    -- 0 runs first
    priority smallint NOT NULL DEFAULT 0 CHECK (priority BETWEEN 0 AND 9),
    -- The number of times the job started
    attempt smallint NOT NULL DEFAULT 0,
    max_attempts smallint NOT NULL CHECK (max_attempts > 0),
    run_at timestamptz NOT NULL DEFAULT now(),
    -- The start of the latest attempt
    attempted_at timestamptz,
    finished_at timestamptz,
    inserted_at timestamptz NOT NULL DEFAULT now()
);

-- Lets the runner claim a queue's next jobs, in the order it runs them, without going through the
-- finished jobs that make up most of the table
CREATE INDEX jobs_available_to_run ON jobs (queue, priority, run_at, id)
WHERE state = 'available';
-- Lets the maintenance find the jobs a crash left running every minute, among the few running
CREATE INDEX jobs_running ON jobs (attempted_at) WHERE state = 'executing';
-- Lets the maintenance find the finished jobs old enough to delete without reading the others
CREATE INDEX jobs_finished ON jobs (finished_at)
WHERE state IN ('completed', 'failed', 'cancelled');

-- The next run of each recurring job that the server's code schedules
CREATE TABLE job_schedules (
    name text PRIMARY KEY,
    -- The cron expression that `next_run_at` comes from, such as `0 3 * * SUN`
    cron text NOT NULL,
    next_run_at timestamptz NOT NULL
);
