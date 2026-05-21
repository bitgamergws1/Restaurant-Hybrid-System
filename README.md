# Restaurant Hybrid Order Management System — Backend

A production-grade Python Flask backend for a hybrid restaurant ordering platform supporting
Dine-In QR table ordering and Home Delivery. Deployed on Render, backed by Supabase PostgreSQL,
and integrated with the DevNest AI proxy gateway.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend Runtime | Python 3.11+ / Flask 3.0 |
| Database | Supabase (PostgreSQL) |
| Deployment | Render (gunicorn) |
| Frontend | Flutter Web |
| Email | Gmail SMTP via smtplib (TLS, Port 587) |
| AI Gateway | DevNest Proxy (deepshi-r1, deepshi-r2) |
| Postal Lookup | India Post public API |

---

## Folder Structure

```
restaurant-hybrid-system/
└── backend/
    ├── app.py                      Flask app factory — blueprint registration and CORS
    ├── config.py                   Central env var loader — no hardcoded secrets
    ├── extensions.py               Supabase client singleton
    ├── requirements.txt            Production dependencies
    ├── supabase_schema.sql         PostgreSQL schema — paste into Supabase SQL Editor
    ├── routes/
    │   ├── auth.py                 Signup, login, OTP verify, forgot/reset password
    │   ├── menu.py                 Public menu read + admin CRUD
    │   ├── orders.py               Hybrid order creation (dine-in and delivery)
    │   ├── payments.py             Mock Razorpay verify + invoice email trigger
    │   ├── ai.py                   AI recommendation + complaint triage
    │   ├── admin.py                Analytics, complaints management, user list
    │   └── postal.py               Pincode resolution endpoint
    ├── services/
    │   ├── otp_service.py          Supabase-backed OTP CRUD operations
    │   ├── email_service.py        Gmail SMTP — OTP and invoice HTML emails
    │   ├── ai_service.py           DevNest proxy bridge — model routing
    │   ├── postal_service.py       India Post API parser + Mapbox coordinate builder
    │   └── billing_service.py      GST calculation engine
    ├── middleware/
    │   └── auth_middleware.py      Session token validator — require_auth / require_admin
    └── utils/
        ├── response.py             Standardised JSON response helpers
        └── validators.py           Email, phone, pincode, UUID, field validators
```

---

## Environment Variables

Set these directly in Render's Environment tab. No `.env` file is used in production.

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Supabase service role key (not the anon key) |
| `GMAIL_SENDER` | Gmail address used to send emails |
| `GMAIL_APP_PASSWORD` | 16-character Gmail App Password (not your login password) |
| `DEVNEST_TOKEN` | `DEVNEST_EVAL_2026` |
| `FRONTEND_ORIGIN` | Your Flutter Web deployment URL (e.g. `https://yourapp.web.app`) |
| `RESTAURANT_NAME` | Display name used in emails and responses |
| `RESTAURANT_SUPPORT_EMAIL` | Support email shown in invoice footer |
| `TRACKING_BASE_URL` | Base URL for order tracking links in invoice emails |

---

## Supabase Setup

### Step 1 — Run the schema

Open your Supabase project, go to **SQL Editor**, paste the entire contents of
`supabase_schema.sql` and run it. This creates all tables, indices, and triggers.

### Step 2 — Configure the Cron Job

In Supabase go to **Database → Cron Jobs** and create a new job:

- Schedule: `*/2 * * * *`
- SQL to run:

```sql
DELETE FROM user_otps WHERE expires_at < NOW();
DELETE FROM sessions WHERE expires_at < NOW();
```

This purges expired OTP records and sessions every 2 minutes.
---

## Row Level Security

Every table has RLS enabled. The policies follow this model:

| Table | anon key | service_role key |
|---|---|---|
| `users` | Blocked (all operations) | Full access |
| `user_otps` | Blocked (all operations) | Full access |
| `sessions` | Blocked (all operations) | Full access |
| `menu_items` | SELECT only — available items | Full access |
| `orders` | Blocked (all operations) | Full access |
| `order_items` | Blocked (all operations) | Full access |
| `complaints` | Blocked (all operations) | Full access |
| `payments` | Blocked (all operations) | Full access |

**Why this is safe:**
The Flask backend uses `SUPABASE_SERVICE_KEY` (service_role), which bypasses
RLS at the database level. All authentication and authorisation logic is enforced
inside the Flask middleware layer.

The RLS policies protect against three threat vectors:
1. Someone using the Supabase anon key directly from a browser or Postman
2. The Supabase auto-generated REST API being hit without going through Flask
3. Misconfigured client code accidentally using the wrong key

`menu_items` is the only table with a partial public SELECT because the menu
must remain readable without a session token (browse before login UX). The
policy restricts this to `is_available = true` rows only — unpublished items
are never exposed.

---

## Database Schema

### `users`
Stores registered user accounts.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| name | VARCHAR(255) | Full name |
| email | VARCHAR(255) | Unique, indexed |
| phone | VARCHAR(20) | Optional |
| password_hash | TEXT | Werkzeug PBKDF2 hash |
| role | VARCHAR(20) | `customer`, `admin`, `staff` |
| is_verified | BOOLEAN | Set true after OTP confirmation |
| created_at | TIMESTAMPTZ | Auto |
| updated_at | TIMESTAMPTZ | Auto via trigger |

### `user_otps`
Supabase-persisted OTP registry. Cron-cleaned every 2 minutes.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| email | VARCHAR(255) | Indexed with purpose |
| otp_code | VARCHAR(6) | 6-digit numeric |
| purpose | VARCHAR(20) | `signup` or `reset` |
| metadata | JSONB | Stores signup payload (name, password_hash, phone) |
| expires_at | TIMESTAMPTZ | OTP expiry (5 minutes from creation) |
| is_verified | BOOLEAN | Marked true on successful verify to block reuse |

### `sessions`
Token-based session store.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | FK → users |
| token | TEXT | 64-char hex, unique, sent as `X-Session-Token` header |
| expires_at | TIMESTAMPTZ | 24 hours from creation |

### `menu_items`
Full product catalog.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| name | VARCHAR(255) | FTS indexed |
| description | TEXT | |
| price | NUMERIC(10,2) | Non-negative |
| category | VARCHAR(100) | Indexed |
| subcategory | VARCHAR(100) | |
| is_available | BOOLEAN | Indexed — used for live menu filters |
| image_url | TEXT | |
| tags | TEXT[] | |
| sort_order | INTEGER | Controls display order |

### `orders`
Hybrid order records.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | FK → users |
| order_type | VARCHAR(20) | `dine_in` or `delivery` |
| table_id | VARCHAR(50) | Set for dine-in orders only |
| delivery_address | JSONB | Full address object for delivery |
| delivery_coordinates | JSONB | `{lat, lng}` from Mapbox |
| status | VARCHAR(30) | Enum with enforced transitions |
| subtotal | NUMERIC(10,2) | Pre-GST total |
| gst_amount | NUMERIC(10,2) | 18% of subtotal |
| total_amount | NUMERIC(10,2) | Final billed amount |
| payment_status | VARCHAR(20) | `pending`, `paid`, `failed`, `refunded` |
| payment_id | TEXT | Razorpay payment ID after verification |
| special_instructions | TEXT | |
| invoice_sent | BOOLEAN | Tracks invoice email dispatch |

### `order_items`
Line items for each order.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| order_id | UUID | FK → orders (cascade delete) |
| menu_item_id | UUID | FK → menu_items (restrict delete) |
| item_name | VARCHAR(255) | Snapshotted at order time |
| quantity | INTEGER | Minimum 1 |
| unit_price | NUMERIC(10,2) | Snapshotted at order time |
| item_total | NUMERIC(10,2) | unit_price × quantity |

### `complaints`
AI-triaged customer feedback.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| user_id | UUID | FK → users |
| order_id | UUID | FK → orders |
| raw_text | TEXT | Original complaint input |
| category | VARCHAR(100) | AI classified |
| sentiment | VARCHAR(50) | AI classified |
| priority | VARCHAR(20) | `low`, `medium`, `high`, `critical` |
| status | VARCHAR(30) | `open`, `in_review`, `resolved`, `closed` |

### `payments`
Payment transaction audit trail.

| Column | Type | Notes |
|---|---|---|
| id | UUID | Primary key |
| order_id | UUID | FK → orders |
| razorpay_payment_id | TEXT | Indexed |
| razorpay_order_id | TEXT | |
| amount | NUMERIC(10,2) | |
| status | VARCHAR(20) | `pending`, `success`, `failed` |
| gateway_response | JSONB | Full payload from Razorpay |
| verified_at | TIMESTAMPTZ | Set on successful verification |

---

## API Reference

All routes are prefixed with `/api/v1`. Protected routes require the header:
```
X-Session-Token: <token received from login or verify-otp>
```

---

### Auth — `/api/v1/auth`

#### `POST /signup`
Creates a new account and sends a 6-digit OTP to the email address.

Request:
```json
{
  "name": "Arjun Sharma",
  "email": "arjun@example.com",
  "password": "securepass123",
  "phone": "9876543210"
}
```

Response `201`:
```json
{
  "success": true,
  "message": "OTP sent to your email. Please verify to complete registration.",
  "data": { "email": "arjun@example.com" }
}
```

---

#### `POST /verify-otp`
Verifies the OTP and completes account creation (purpose: `signup`) or
confirms identity before password reset (purpose: `reset`).

Request:
```json
{
  "email": "arjun@example.com",
  "otp": "482910",
  "purpose": "signup"
}
```

Response `201` (signup):
```json
{
  "success": true,
  "data": {
    "user": { "id": "...", "name": "Arjun Sharma", "email": "...", "role": "customer" },
    "token": "a3f8c2..."
  }
}
```

---

#### `POST /resend-otp`
Resends a fresh OTP for an active pending session.

Request:
```json
{
  "email": "arjun@example.com",
  "purpose": "signup"
}
```

---

#### `POST /login`
Authenticates credentials and returns a session token.

Request:
```json
{
  "email": "arjun@example.com",
  "password": "securepass123"
}
```

Response `200`:
```json
{
  "success": true,
  "data": {
    "user": { "id": "...", "name": "...", "email": "...", "role": "customer", "phone": "..." },
    "token": "a3f8c2..."
  }
}
```

---

#### `POST /logout`
Invalidates the session token. Requires `X-Session-Token` header.

---

#### `POST /forgot-password`
Sends a reset OTP if the email exists. Always returns the same message to prevent email enumeration.

Request:
```json
{ "email": "arjun@example.com" }
```

---

#### `POST /reset-password`
Verifies the reset OTP and updates the password. Invalidates all existing sessions.

Request:
```json
{
  "email": "arjun@example.com",
  "otp": "193847",
  "new_password": "newpassword456"
}
```

---

### Menu — `/api/v1/menu`

#### `GET /` — Public
Returns the full menu. Supports query parameters:

| Param | Description |
|---|---|
| `available` | `true` (default) — filter only available items |
| `category` | Filter by category name |
| `search` | Text search across name, description, subcategory |

#### `GET /categories` — Public
Returns a sorted list of all active categories.

#### `GET /<item_id>` — Public
Returns a single menu item by ID.

#### `POST /` — Admin/Staff
Creates a new menu item.

Request:
```json
{
  "name": "Paneer Tikka",
  "description": "Marinated cottage cheese grilled in tandoor",
  "price": 280,
  "category": "Starters",
  "subcategory": "Vegetarian",
  "is_available": true,
  "tags": ["veg", "spicy"],
  "sort_order": 5
}
```

#### `PATCH /<item_id>` — Admin/Staff
Partially updates a menu item. All fields optional.

```json
{
  "price": 320,
  "is_available": false
}
```

#### `DELETE /<item_id>` — Admin/Staff
Permanently removes a menu item.

---

### Orders — `/api/v1/orders`

#### `POST /` — Authenticated
Creates an order. The `order_type` field determines routing logic.

Dine-In request:
```json
{
  "order_type": "dine_in",
  "table_id": "T-04",
  "items": [
    { "menu_item_id": "uuid-here", "quantity": 2 },
    { "menu_item_id": "uuid-here", "quantity": 1 }
  ],
  "special_instructions": "Extra chutney please"
}
```

Delivery request:
```json
{
  "order_type": "delivery",
  "pincode": "400001",
  "address_line": "12 Marine Lines, near post office",
  "coordinates": { "lat": 18.9388, "lng": 72.8354 },
  "items": [
    { "menu_item_id": "uuid-here", "quantity": 1 }
  ]
}
```

Response `201`:
```json
{
  "success": true,
  "data": {
    "order": { ... },
    "items": [ ... ],
    "billing": {
      "subtotal": 280.00,
      "gst_amount": 50.40,
      "gst_rate": 0.18,
      "total_amount": 330.40
    }
  }
}
```

#### `GET /<order_id>` — Authenticated
Returns order with all line items. Users can only access their own orders.

#### `PATCH /<order_id>/status` — Admin/Staff
Updates order status. Enforced transition rules:

```
pending → confirmed → preparing → ready → out_for_delivery → delivered
pending → cancelled
confirmed → cancelled
```

Request:
```json
{ "status": "confirmed" }
```

#### `GET /user/<user_id>` — Authenticated
Returns all orders for a user, newest first.

---

### Payments — `/api/v1/payments`

#### `POST /verify` — Authenticated
Mock Razorpay verification. Accepts test mode IDs (`pay_*` and `order_*` prefixed).
On success, marks order as `paid` and status as `confirmed`, and logs the payment record.

Request:
```json
{
  "order_id": "uuid-here",
  "razorpay_payment_id": "pay_TestMockXYZ123",
  "razorpay_order_id": "order_TestMockABC456"
}
```

#### `POST /invoice/<order_id>` — Authenticated
Sends the HTML invoice email to the user's registered address.
Only works for orders with `payment_status: paid`.

---

### AI — `/api/v1/ai`

#### `POST /recommend` — Authenticated
Sends a customer prompt to the AI waiter powered by `deepshi-r1`.
Automatically provides the live menu as context.

Request:
```json
{
  "prompt": "I want something spicy and vegetarian, not too heavy"
}
```

Response `200`:
```json
{
  "success": true,
  "data": {
    "recommendation": "Based on your preference...",
    "model_used": "deepshi-r1"
  }
}
```

#### `POST /triage` — Authenticated
Submits a raw customer complaint. The AI (deepshi-r2) classifies and stores it.

Request:
```json
{
  "raw_text": "Bhai khana bohot thanda tha aur delivery mein 1 ghanta lag gaya",
  "order_id": "uuid-here"
}
```

Response `201`:
```json
{
  "success": true,
  "data": {
    "complaint_id": "uuid-here",
    "triage": {
      "category": "delivery",
      "sentiment": "very_negative",
      "priority": "high"
    },
    "model_used": "deepshi-r2"
  }
}
```

#### `GET /health`
Checks if the DevNest proxy is reachable.

---

### Admin — `/api/v1/admin`

#### `GET /analytics` — Admin/Staff
Returns the full analytics dashboard. Supports optional date filters:

Query params: `from=2025-01-01` and `to=2025-12-31`

Response includes:
- Total orders, paid orders, cancelled orders
- Dine-in vs delivery breakdown
- Total revenue, GST collected, subtotal, average order value
- Daily revenue breakdown (sorted newest first)
- Top 20 selling items sorted by quantity (Pareto distribution)
- Complaints breakdown by priority and status
- Menu availability stats

#### `GET /complaints` — Admin/Staff
Returns all complaints. Filter by `status` or `priority` query params.

#### `PATCH /complaints/<complaint_id>/status` — Admin/Staff
Updates complaint status to `open`, `in_review`, `resolved`, or `closed`.

#### `GET /users` — Admin/Staff
Returns all registered users (excludes password_hash).

---

### Postal — `/api/v1/postal`

#### `GET /<pincode>` — Authenticated
Resolves a 6-digit Indian pincode using the India Post public API.

Response `200`:
```json
{
  "success": true,
  "data": {
    "success": true,
    "location": {
      "pincode": "400001",
      "district": "Mumbai",
      "state": "Maharashtra",
      "country": "India",
      "division": "Mumbai",
      "region": "Mumbai HQ",
      "areas": ["Fort", "GPO Mumbai", "Ballard Estate"]
    }
  }
}
```

---

## AI Model Routing

| Feature | Model | Reasoning |
|---|---|---|
| AI Waiter Recommendations | `deepshi-r1` | Fast reasoning, conversational, good for food pairing |
| Complaint Triage | `deepshi-r2` | Deeper semantic understanding, strict JSON output |

The triage pipeline instructs deepshi-r2 to return only a raw JSON object.
The backend validates the response against allowed enum values before writing
to the database. Malformed responses are caught and a `503` is returned.

---

## OTP Flow

```
Client                    Backend                   Supabase            Gmail
  |                          |                          |                  |
  |-- POST /signup --------> |                          |                  |
  |                          |-- DELETE old OTP ------> |                  |
  |                          |-- INSERT new OTP ------> |                  |
  |                          |-- send_otp_email ------> |                  |
  |                          |                          |           (email sent)
  |<-- 201 OTP sent -------- |                          |                  |
  |                          |                          |                  |
  |-- POST /verify-otp ----> |                          |                  |
  |                          |-- SELECT otp_record ----> |                  |
  |                          |-- check expiry           |                  |
  |                          |-- UPDATE is_verified ---> |                  |
  |                          |-- INSERT user ----------> |                  |
  |                          |-- INSERT session -------> |                  |
  |<-- 201 token + user ---- |                          |                  |
```

OTP records are marked `is_verified = true` immediately after use so they
cannot be replayed. The Supabase cron job hard-deletes all expired records
every 2 minutes.

---

## Order Status Transitions

```
         +---> cancelled
         |
pending --+---> confirmed ---> preparing ---> ready ---> out_for_delivery ---> delivered
                    |
                    +---> cancelled
```

Invalid transitions are rejected with a `400` error listing the allowed next states.

---

## Billing Engine

All calculations happen in `services/billing_service.py` before any database write.

```
unit_price × quantity = item_total    (per line item)
sum(item_total)       = subtotal
subtotal × 0.18       = gst_amount
subtotal + gst_amount = total_amount
```

All values are rounded to 2 decimal places. Prices are always read from the
live `menu_items` table at order time — the frontend-supplied price is ignored
to prevent tampering.

---

## Deployment on Render

1. Create a new **Web Service** on Render.
2. Connect your GitHub repository.
3. Set the **Root Directory** to `backend`.
4. Set the **Build Command**:
   ```
   pip install -r requirements.txt
   ```
5. Set the **Start Command**:
   ```
   gunicorn app:create_app()
   ```
6. Add all environment variables from the table above in the **Environment** tab.
7. Deploy.

Render will assign a public URL. Set this URL as the `FRONTEND_ORIGIN` variable
(or set `*` during development).

---

## Gmail App Password Setup

1. Go to your Google Account → Security → 2-Step Verification (must be enabled).
2. Go to **App Passwords** and create a new one for "Mail".
3. Copy the 16-character password and set it as `GMAIL_APP_PASSWORD` in Render.
4. Set `GMAIL_SENDER` to the same Gmail address.

Do not use your actual Gmail login password. App Passwords bypass 2FA for
SMTP without exposing your main credentials.

---

## Progress Status

| Module | Status |
|---|---|
| Supabase schema (all tables + indices + triggers) | Done |
| Auth — signup, login, logout | Done |
| Auth — OTP verify, resend, forgot password, reset | Done |
| OTP persistence in Supabase `user_otps` table | Done |
| Session token management in `sessions` table | Done |
| Menu CRUD (public read + admin write) | Done |
| Category filter, text search, availability toggle | Done |
| Hybrid order creation (dine-in + delivery) | Done |
| India Post pincode resolution + Mapbox coordinates | Done |
| Order status management with transition validation | Done |
| Billing engine — subtotal, 18% GST, total | Done |
| Mock Razorpay payment verification | Done |
| Invoice HTML email via Gmail SMTP | Done |
| AI Waiter Recommendation (deepshi-r1) | Done |
| AI Complaint Triage (deepshi-r2, strict JSON) | Done |
| Admin analytics — revenue, Pareto top items | Done |
| Admin complaints management | Done |
| Auth middleware — require_auth / require_admin | Done |
| Input validators — email, phone, pincode, UUID | Done |
| Standardised JSON response wrapper | Done |
| Flutter Web frontend | Pending |

---

## Pending — Flutter Web Frontend

The backend is fully operational and ready for Flutter integration.
The next phase covers:

- QR code scanner for table-based dine-in session initiation
- Customer-facing order flow (menu browse, cart, checkout)
- AI waiter chat widget
- Order tracking screen (consumes `TRACKING_BASE_URL`)
- Admin dashboard UI (analytics, order management, menu editor)
- Razorpay Flutter SDK integration (test mode)
