-- Companies
CREATE TABLE companies (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    country_code VARCHAR(2) NOT NULL,
    default_currency CHAR(3) NOT NULL, -- e.g., "INR", "USD"
    created_at TIMESTAMP DEFAULT now()
);

-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(16) NOT NULL CHECK (role IN ('admin','manager','employee')),
    manager_id UUID REFERENCES users(id), -- optional for employees
    is_manager_approver BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT now()
);

-- Expenses
CREATE TABLE expenses (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    submitter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount NUMERIC(14,2) NOT NULL,           -- original amount
    currency CHAR(3) NOT NULL,               -- original currency
    amount_in_company_currency NUMERIC(14,2) NOT NULL, -- converted
    category TEXT,
    description TEXT,
    date_of_expense DATE NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending','approved','rejected')),
    current_step INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- Receipts (for OCR scanning)
CREATE TABLE receipts (
    id UUID PRIMARY KEY,
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,         -- stored in S3 or similar
    ocr_extracted JSONB,            -- parsed OCR fields
    created_at TIMESTAMP DEFAULT now()
);

-- Approval flows (each company can define multiple)
CREATE TABLE approval_flows (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT now()
);

-- Approvers inside each flow (with step sequence)
CREATE TABLE approvers (
    id UUID PRIMARY KEY,
    flow_id UUID NOT NULL REFERENCES approval_flows(id) ON DELETE CASCADE,
    step_order INT NOT NULL,
    approver_user_id UUID REFERENCES users(id), -- assign specific user
    approver_role VARCHAR(16),                  -- or assign by role
    is_manager_step BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT now()
);

-- Conditional rules for approval (percentage / specific approver / hybrid)
CREATE TABLE conditional_rules (
    id UUID PRIMARY KEY,
    flow_id UUID NOT NULL REFERENCES approval_flows(id) ON DELETE CASCADE,
    type VARCHAR(32) NOT NULL 
        CHECK (type IN ('percentage','specific_approver','hybrid')),
    percentage_threshold INT,        -- for percentage rules
    specific_user_id UUID REFERENCES users(id), -- for specific approver
    created_at TIMESTAMP DEFAULT now()
);

-- Stores every decision taken by approvers
CREATE TABLE approver_actions (
    id UUID PRIMARY KEY,
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    approver_id UUID NOT NULL REFERENCES users(id),
    step_order INT NOT NULL,
    action VARCHAR(16) NOT NULL CHECK (action IN ('approved','rejected','escalated')),
    comment TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- Currency exchange rates (cache for conversions)
CREATE TABLE exchange_rates (
    base_currency CHAR(3) NOT NULL,
    target_currency CHAR(3) NOT NULL,
    rate NUMERIC(14,6) NOT NULL,
    fetched_at TIMESTAMP DEFAULT now(),
    PRIMARY KEY (base_currency, target_currency)
);

-- Country to currency mapping (optional, can just fetch from API on signup)
CREATE TABLE country_currency (
    country_code VARCHAR(2) PRIMARY KEY,
    country_name TEXT NOT NULL,
    currency_code CHAR(3) NOT NULL
);
