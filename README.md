# Spice Route — Restaurant Order Management System

**DevNest Python Developer Internship — Week 2 Project**

A production-grade hybrid restaurant ordering backend built with Python Flask,
Supabase PostgreSQL, and the DevNest AI proxy gateway. Supports Dine-In QR
table ordering and Home Delivery from a single unified API.

---

## Internship Brief Coverage

| Requirement from Brief | Implementation |
|---|---|
| Display restaurant menu | `GET /api/v1/menu/` with category, search, availability filters |
| Add / update / remove food items | Admin CRUD on `/api/v1/menu/` |
| Food categories and pricing | `category`, `subcategory`, `price` fields with live filter |
| Customer order placement | `POST /api/v1/orders/` — dine-in and delivery routing |
| Quantity selection | Per-item `quantity` field validated on order creation |
| Multiple item ordering | Accepts array of items in a single order payload |
| Automatic bill generation | `billing_service.py` runs before any DB write |
| GST / tax calculation | Strict 18% GST multiplier on subtotal |
| Invoice formatting | HTML invoice email sent via Gmail SMTP |
| Final amount calculation | subtotal + gst_amount = total_amount |
| Store customer orders | `orders` + `order_items` tables in Supabase |
| Maintain order history | `GET /api/v1/orders/user/<user_id>` |
| Retrieve previous order records | `GET /api/v1/orders/<order_id>` |
| Total orders tracking | Admin analytics endpoint |
| Daily revenue calculation | Daily breakdown in analytics response |
| Most sold items analysis | Pareto sort in analytics (top 20 by quantity) |
| Sales summary generation | Full summary object in analytics response |
| Flask API for orders / menu | All routes under `/api/v1/` |
| GET / POST request handling | All standard HTTP methods implemented |
| Deployment on Render | gunicorn start command — deploy-ready |
| README documentation | This file |

**Bonus features implemented beyond the brief:**
- OTP-based auth (signup, login, forgot password, reset)
- Dine-In QR mode with `table_id` routing
- India Post pincode resolution for delivery
- Mapbox coordinate storage
- AI Waiter Recommendation (deepshi-r1)
- AI Complaint Triage with strict JSON output (deepshi-r2)
- Mock Razorpay payment verification
- Session-based auth middleware with role enforcement
- RLS security policies on all Supabase tables
- Supabase cron jobs for OTP and session cleanup

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.11+ |
| Framework | Flask 3.0 |
| Database | Supabase (PostgreSQL) |
| Deployment | Render (gunicorn) |
| Frontend | Flutter Web (separate repo) |
| Email | Gmail SMTP — smtplib, TLS Port 587 |
| AI Gateway | DevNest Proxy — deepshi-r1, deepshi-r2 |
| Pincode API | India Post public API |

---

## Project Structure

```
restaurant-hybrid-system/
└── backend/
    ├── app.py                      Flask app factory
    ├── config.py                   Environment variable loader
    ├── extensions.py               Supabase client singleton
    ├── requirements.txt
    ├── supabase_schema.sql         Full schema — paste into Supabase SQL Editor
    ├── routes/
    │   ├── auth.py                 Signup, OTP verify, login, logout, forgot/reset password
    │   ├── menu.py                 Public menu read + admin CRUD
    │   ├── orders.py               Hybrid order creation (dine-in and delivery)
    │   ├── payments.py             Mock Razorpay verify + invoice email
    │   ├── ai.py                   AI recommendation + complaint triage
    │   ├── admin.py                Analytics, complaints management, user list
    │   └── postal.py               Pincode resolution
    ├── services/
    │   ├── otp_service.py          Supabase-backed OTP operations
    │   ├── email_service.py        Gmail SMTP — OTP emails and HTML invoice
    │   ├── ai_service.py           DevNest proxy bridge (deepshi-r1 / deepshi-r2)
    │   ├── postal_service.py       India Post API parser + Mapbox coordinate builder
    │   └── billing_service.py      GST calculation engine
    ├── middleware/
    │   └── auth_middleware.py      require_auth / require_admin decorators
    └── utils/
        ├── response.py             Standardised JSON response helpers
        └── validators.py           Email, phone, pincode, UUID validators
```

---

## Environment Variables

Set these in Render → Environment tab. No `.env` file used in production.

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Service role key (not the anon key) |
| `GMAIL_SENDER` | Gmail address for outgoing emails |
| `GMAIL_APP_PASSWORD` | 16-character Gmail App Password |
| `DEVNEST_TOKEN` | `DEVNEST_EVAL_2026` |
| `FRONTEND_ORIGIN` | Flutter Web deployment URL |
| `RESTAURANT_NAME` | Display name used in emails (default: Spice Route) |
| `RESTAURANT_SUPPORT_EMAIL` | Support address shown in invoice footer |
| `TRACKING_BASE_URL` | Base URL for order tracking links in invoice |

---

## Supabase Setup

### Step 1 — Schema

Open **SQL Editor** in your Supabase project and paste the full contents of
`supabase_schema.sql`. Run it. Creates all tables, indices, triggers, RLS
policies, and cron jobs in one shot.

### Step 2 — Cron Jobs

The schema automatically registers two cron jobs via `pg_cron`:

| Job | Schedule | SQL |
|---|---|---|
| `purge_expired_otps` | Every 2 min | `DELETE FROM user_otps WHERE expires_at < NOW()` |
| `purge_expired_sessions` | Every 2 min | `DELETE FROM sessions WHERE expires_at < NOW()` |

To verify they registered, run in SQL Editor:
```sql
SELECT jobname, schedule, active FROM cron.job
WHERE jobname IN ('purge_expired_otps', 'purge_expired_sessions');
```

---

## Database Schema

### `users`
| Column | Type | Notes |
|---|---|---|
| id | UUID | PK |
| name | VARCHAR(255) | |
| email | VARCHAR(255) | Unique, indexed |
| phone | VARCHAR(20) | Optional |
| password_hash | TEXT | Werkzeug PBKDF2 |
| role | VARCHAR(20) | `customer`, `admin`, `staff` |
| is_verified | BOOLEAN | Set true after OTP confirm |

### `user_otps`
Supabase-persisted OTP store. Cron-cleaned every 2 minutes.

| Column | Type | Notes |
|---|---|---|
| email | VARCHAR(255) | Indexed with purpose |
| otp_code | VARCHAR(6) | 6-digit numeric |
| purpose | VARCHAR(20) | `signup` or `reset` |
| metadata | JSONB | Holds signup payload until OTP verified |
| expires_at | TIMESTAMPTZ | 5 minutes from creation |
| is_verified | BOOLEAN | Marked true after use — blocks replay |

### `sessions`
| Column | Type | Notes |
|---|---|---|
| user_id | UUID | FK → users |
| token | TEXT | 64-char hex, sent as `X-Session-Token` |
| expires_at | TIMESTAMPTZ | 24 hours from creation |

### `menu_items`
| Column | Type | Notes |
|---|---|---|
| name | VARCHAR(255) | GIN FTS indexed |
| price | NUMERIC(10,2) | Non-negative |
| category | VARCHAR(100) | Indexed |
| is_available | BOOLEAN | Indexed — used in live filters |
| sort_order | INTEGER | Controls display order |
| tags | TEXT[] | |

### `orders`
| Column | Type | Notes |
|---|---|---|
| order_type | VARCHAR(20) | `dine_in` or `delivery` |
| table_id | VARCHAR(50) | Dine-in only |
| delivery_address | JSONB | Delivery only |
| delivery_coordinates | JSONB | `{lat, lng}` from Mapbox |
| status | VARCHAR(30) | Transition-enforced enum |
| subtotal | NUMERIC(10,2) | |
| gst_amount | NUMERIC(10,2) | 18% of subtotal |
| total_amount | NUMERIC(10,2) | Final billed amount |
| payment_status | VARCHAR(20) | `pending`, `paid`, `failed`, `refunded` |
| invoice_sent | BOOLEAN | |

### `order_items`
| Column | Type | Notes |
|---|---|---|
| item_name | VARCHAR(255) | Snapshotted at order time |
| quantity | INTEGER | Min 1 |
| unit_price | NUMERIC(10,2) | Snapshotted — frontend price ignored |
| item_total | NUMERIC(10,2) | unit_price × quantity |

### `complaints`
| Column | Type | Notes |
|---|---|---|
| raw_text | TEXT | Original complaint |
| category | VARCHAR(100) | AI classified |
| sentiment | VARCHAR(50) | AI classified |
| priority | VARCHAR(20) | `low`, `medium`, `high`, `critical` |
| status | VARCHAR(30) | `open` → `in_review` → `resolved` / `closed` |

### `payments`
| Column | Type | Notes |
|---|---|---|
| razorpay_payment_id | TEXT | Indexed |
| amount | NUMERIC(10,2) | |
| status | VARCHAR(20) | `pending`, `success`, `failed` |
| gateway_response | JSONB | Full Razorpay payload |
| verified_at | TIMESTAMPTZ | |

---

## Row Level Security

RLS is enabled on all 8 tables.

| Table | anon key | service_role key |
|---|---|---|
| `users` | Blocked | Full access |
| `user_otps` | Blocked | Full access |
| `sessions` | Blocked | Full access |
| `menu_items` | SELECT — available items only | Full access |
| `orders` | Blocked | Full access |
| `order_items` | Blocked | Full access |
| `complaints` | Blocked | Full access |
| `payments` | Blocked | Full access |

The Flask backend uses the `service_role` key which bypasses RLS entirely.
The policies protect against direct anon key access and the Supabase
auto-generated REST API being hit without going through Flask.

---

## API Reference

**Base URL:** `https://your-render-app.onrender.com/api/v1`

Protected routes require:
```
X-Session-Token: <token from login or verify-otp>
```

---

### Auth — `/api/v1/auth`

| Method | Route | Auth | Description |
|---|---|---|---|
| POST | `/signup` | Public | Create account, send OTP |
| POST | `/verify-otp` | Public | Verify OTP, activate account |
| POST | `/resend-otp` | Public | Resend fresh OTP |
| POST | `/login` | Public | Authenticate, get session token |
| POST | `/logout` | Token | Invalidate session |
| POST | `/forgot-password` | Public | Send reset OTP |
| POST | `/reset-password` | Public | Verify OTP, update password |

#### POST `/signup`
```json
{
  "name": "Priya Sharma",
  "email": "priya@example.com",
  "password": "securepass123",
  "phone": "9876543210"
}
```
Response `201` — OTP sent. Call `/verify-otp` next.

#### POST `/verify-otp`
```json
{ "email": "priya@example.com", "otp": "482910", "purpose": "signup" }
```
Response `201`:
```json
{
  "data": {
    "user": { "id": "...", "name": "Priya Sharma", "role": "customer" },
    "token": "a3f8c2d1..."
  }
}
```

#### POST `/login`
```json
{ "email": "priya@example.com", "password": "securepass123" }
```

#### POST `/forgot-password`
```json
{ "email": "priya@example.com" }
```
Always returns the same message regardless of whether email exists.

#### POST `/reset-password`
```json
{ "email": "priya@example.com", "otp": "193847", "new_password": "newpass456" }
```
Invalidates all existing sessions after password change.

---

### Menu — `/api/v1/menu`

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | `/` | Public | Full menu with filters |
| GET | `/categories` | Public | All active categories |
| GET | `/<item_id>` | Public | Single item |
| POST | `/` | Admin | Create menu item |
| PATCH | `/<item_id>` | Admin | Partial update |
| DELETE | `/<item_id>` | Admin | Remove item |

#### GET `/` — Query parameters
| Param | Default | Description |
|---|---|---|
| `available` | `true` | Filter to available items only |
| `category` | — | Filter by category name |
| `search` | — | Text search across name and description |

#### POST `/` — Create item
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

#### PATCH `/<item_id>` — Update (all fields optional)
```json
{ "price": 320, "is_available": false }
```

---

### Orders — `/api/v1/orders`

| Method | Route | Auth | Description |
|---|---|---|---|
| POST | `/` | Token | Create order |
| GET | `/<order_id>` | Token | Get order with items |
| PATCH | `/<order_id>/status` | Admin | Update status |
| GET | `/user/<user_id>` | Token | User order history |

#### POST `/` — Dine-In
```json
{
  "order_type": "dine_in",
  "table_id": "T-04",
  "items": [
    { "menu_item_id": "uuid", "quantity": 2 },
    { "menu_item_id": "uuid", "quantity": 1 }
  ],
  "special_instructions": "No onions"
}
```

#### POST `/` — Home Delivery
```json
{
  "order_type": "delivery",
  "pincode": "400001",
  "address_line": "12 Marine Lines, near post office",
  "coordinates": { "lat": 18.9388, "lng": 72.8354 },
  "items": [
    { "menu_item_id": "uuid", "quantity": 1 }
  ]
}
```

Response `201`:
```json
{
  "data": {
    "order": { "id": "...", "status": "pending", ... },
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

#### Order Status Transitions
```
pending ──┬──> confirmed ──> preparing ──> ready ──> out_for_delivery ──> delivered
          └──> cancelled
confirmed ──> cancelled
```
Invalid transitions return `400` with allowed next states listed.

---

### Payments — `/api/v1/payments`

| Method | Route | Auth | Description |
|---|---|---|---|
| POST | `/verify` | Token | Verify payment, confirm order |
| POST | `/invoice/<order_id>` | Token | Email invoice to user |

#### POST `/verify` — Mock Razorpay
Accepts test-mode IDs. Valid format: `pay_*` and `order_*` with length > 6/8.
```json
{
  "order_id": "uuid",
  "razorpay_payment_id": "pay_TestMockXYZ123",
  "razorpay_order_id": "order_TestMockABC456"
}
```
On success: order marked `paid` + `confirmed`, payment record logged.

#### POST `/invoice/<order_id>`
Sends HTML invoice to the user's registered email. Only works on `paid` orders.

---

### AI — `/api/v1/ai`

| Method | Route | Auth | Description |
|---|---|---|---|
| POST | `/recommend` | Token | Food recommendation |
| POST | `/triage` | Token | Complaint classification |
| GET | `/health` | Public | Proxy health check |

#### POST `/recommend`
```json
{ "prompt": "I want something spicy and vegetarian, not too heavy" }
```
Response:
```json
{
  "data": {
    "recommendation": "Based on your preference I'd suggest...",
    "model_used": "deepshi-r1"
  }
}
```

#### POST `/triage`
```json
{
  "raw_text": "Bhai khana bohot thanda tha aur delivery mein 1 ghanta lag gaya",
  "order_id": "uuid"
}
```
Response `201`:
```json
{
  "data": {
    "complaint_id": "uuid",
    "triage": {
      "category": "delivery",
      "sentiment": "very_negative",
      "priority": "high"
    },
    "model_used": "deepshi-r2"
  }
}
```

---

### Admin — `/api/v1/admin`

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | `/analytics` | Admin | Full analytics dashboard |
| GET | `/complaints` | Admin | All complaints with filters |
| PATCH | `/complaints/<id>/status` | Admin | Update complaint status |
| GET | `/users` | Admin | All registered users |

#### GET `/analytics` — Query params: `from=YYYY-MM-DD`, `to=YYYY-MM-DD`

Response includes:
- Total, paid, cancelled order counts
- Dine-in vs delivery split
- Total revenue, GST collected, average order value
- Daily revenue breakdown sorted newest first
- Top 20 selling items by quantity sold (Pareto)
- Complaints breakdown by priority and status
- Menu availability stats

---

### Postal — `/api/v1/postal`

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | `/<pincode>` | Token | Resolve 6-digit Indian pincode |

Response:
```json
{
  "data": {
    "location": {
      "pincode": "400001",
      "district": "Mumbai",
      "state": "Maharashtra",
      "country": "India",
      "areas": ["Fort", "GPO Mumbai", "Ballard Estate"]
    }
  }
}
```

---

## Billing Engine

All calculations in `services/billing_service.py` run before any DB write.
Prices are always fetched from the live `menu_items` table — frontend-supplied
prices are intentionally ignored to prevent tampering.

```
unit_price × quantity    = item_total      (per line item)
sum(item_total)          = subtotal
subtotal × 0.18          = gst_amount
subtotal + gst_amount    = total_amount
```

All values rounded to 2 decimal places.

---

## AI Service — DevNest Proxy

Both models are called via the DevNest proxy at:
`https://devnest-proxy-server.onrender.com/v1/proxy/ai`

Payload format:
```json
{ "model": "deepshi-r1", "prompt": "...", "system": "..." }
```

Response extraction chain: `reply → response → content → message → text → output`

| Feature | Model | Reason |
|---|---|---|
| AI Waiter Recommendation | `deepshi-r1` | Fast reasoning, conversational |
| Complaint Triage | `deepshi-r2` | Deep semantic analysis, strict JSON |

Both calls include:
- `_strip_thinking` — strips leaked `<thinking>` blocks and raw SSE reasoning fragments from deepshi model responses
- Auto-retry on HTTP 502 / 503 / 504 (cold-start protection on Render)
- Proxy error marker detection

---

## OTP Flow

```
Client              Flask Backend            Supabase            Gmail
  |                      |                       |                  |
  |-- POST /signup ────> |                       |                  |
  |                      |-- DELETE old OTPs --> |                  |
  |                      |-- INSERT new OTP ---> |                  |
  |                      |-- send OTP email ─────────────────────> |
  |<── 201 ──────────── |                       |            email sent
  |                      |                       |                  |
  |-- POST /verify-otp > |                       |                  |
  |                      |-- SELECT otp record -> |                  |
  |                      |   check expiry         |                  |
  |                      |-- UPDATE is_verified -> |                  |
  |                      |-- INSERT user ──────-> |                  |
  |                      |-- INSERT session ───-> |                  |
  |<── 201 token ─────── |                       |                  |
```

OTPs are marked `is_verified = true` immediately on use — replay blocked.
Cron job hard-deletes all expired records every 2 minutes.

---

## Deployment

### Render Setup

1. Create a **Web Service** on [render.com](https://render.com)
2. Connect your GitHub repository
3. Set **Root Directory** to `backend`
4. Set **Build Command:**
   ```
   pip install -r requirements.txt
   ```
5. Set **Start Command:**
   ```
   gunicorn "app:create_app()"
   ```
6. Add all environment variables in the **Environment** tab
7. Deploy

Health check endpoint: `GET /health`

### Gmail App Password

1. Google Account → Security → 2-Step Verification (must be ON)
2. App Passwords → Create one for Mail
3. Copy the 16-character password → set as `GMAIL_APP_PASSWORD`
4. Set `GMAIL_SENDER` to the same Gmail address

---

## Submission Checklist

| Requirement | Status |
|---|---|
| GitHub Repository |  `https://github.com/bitgamergws1/Restaurant-Hybrid-System/` - repo |
| Complete Source Code | All backend files in `backend/` |
| Deployment Link | Render URL after deploy |
| Demo Video | Record a Postman walkthrough of key routes |
| README Documentation | This file |

---

## Progress

| Module | Status |
|---|---|
| Supabase schema — all tables, indices, triggers, RLS, cron jobs | Done |
| Auth — signup, OTP verify, login, logout | Done |
| Auth — resend OTP, forgot password, reset password | Done |
| OTP persistence in `user_otps` Supabase table | Done |
| Session tokens in `sessions` table | Done |
| Menu CRUD — public read + admin write | Done |
| Category filter, text search, availability toggle | Done |
| Hybrid order creation — dine-in and delivery | Done |
| India Post pincode resolution + Mapbox coordinates | Done |
| Order status transitions with validation | Done |
| Billing engine — subtotal, 18% GST, total | Done |
| Mock Razorpay payment verification | Done |
| HTML invoice email via Gmail SMTP | Done |
| AI Waiter Recommendation via deepshi-r1 | Done |
| AI Complaint Triage via deepshi-r2 | Done |
| `_strip_thinking` — reasoning leak scrubber | Done |
| Auto-retry on proxy 502 / 503 / 504 | Done |
| Admin analytics — revenue, Pareto top items | Done |
| Admin complaints management | Done |
| Auth middleware — require_auth / require_admin | Done |
| Input validators — email, phone, pincode, UUID | Done |
| Standardised JSON response wrapper | Done |
| Row Level Security on all 8 tables | Done |
| pg_cron jobs registered via SQL | Done |
| Flutter Web frontend | Pending |
