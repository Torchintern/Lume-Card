from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Student(db.Model):
    __tablename__ = "students"

    id = db.Column(db.Integer, primary_key=True)
    institute_name = db.Column(db.String(150))
    full_name = db.Column(db.String(150))
    reg_no = db.Column(db.String(30), unique=True)
    department = db.Column(db.String(100))
    mobile = db.Column(db.String(15), unique=True)
    email = db.Column(db.String(150))
    dob = db.Column(db.Date)
    blood_group = db.Column(db.String(5))
    batch_start_year = db.Column(db.Integer, nullable=True)
    batch_end_year = db.Column(db.Integer, nullable=True)

    card_issued = db.Column(db.Boolean, default=False)
    institute_status = db.Column(db.String(20), default="active")


class LumeUser(db.Model):
    __tablename__ = "lume_users"

    id = db.Column(db.Integer, primary_key=True)

    student_id = db.Column(db.Integer, db.ForeignKey("students.id"))

    student = db.relationship("Student", backref="lume_user")

    reg_no = db.Column(db.String(30), unique=True)
    phone = db.Column(db.String(15), unique=True, index=True)
    email = db.Column(db.String(150))

    pin_hash = db.Column(db.String(255))

    profile_image = db.Column(db.String(255), nullable=True)

    # KYC Status
    kyc_status = db.Column(
        db.Enum('Completed', 'Pending', 'Rejected', 'Booked'),
        default='Pending'
    )


class ScholarApplication(db.Model):
    __tablename__ = "scholar_applications"

    id = db.Column(db.Integer, primary_key=True)

    registered_student_id = db.Column(db.Integer, nullable=False)

    full_name = db.Column(db.String(150))
    email = db.Column(db.String(150))
    phone = db.Column(db.String(15))

    loan_amount = db.Column(db.String(50))
    city = db.Column(db.String(100))
    country = db.Column(db.String(100))

    admission_status = db.Column(db.String(50))
    target_intake = db.Column(db.String(20))

    status = db.Column(db.String(20), default="pending")

    created_at = db.Column(
        db.DateTime,
        server_default=db.func.now()
    )


# ===================== KYC SLOT =========================

class KYCSlot(db.Model):
    __tablename__ = "kyc_slots"

    id = db.Column(db.Integer, primary_key=True)

    slot_date = db.Column(db.Date, index=True)
    slot_time = db.Column(db.Time, index=True)

    max_capacity = db.Column(db.Integer, default=40)
    booked_count = db.Column(db.Integer, default=0)

    created_at = db.Column(
        db.DateTime,
        server_default=db.func.now()
    )

# ===================== KYC APPLICATION =========================
class KYCApplication(db.Model):
    __tablename__ = "kyc_applications"

    __table_args__ = (
        db.UniqueConstraint('student_id', name='unique_student_kyc'),
    )

    id = db.Column(db.Integer, primary_key=True)

    student_id = db.Column(
        db.Integer,
        db.ForeignKey("students.id"),
        unique=True
    )

    student = db.relationship("Student")

    full_name = db.Column(db.String(150))

    aadhaar_number = db.Column(db.String(12), index=True)
    pan_number = db.Column(db.String(10), index=True)

    no_pan = db.Column(db.Boolean, default=False)

    slot_id = db.Column(db.Integer, db.ForeignKey("kyc_slots.id"))

    slot = db.relationship("KYCSlot", backref="kyc_applications")

    kyc_status = db.Column(
        db.Enum('Completed', 'Pending', 'Rejected', 'Booked'),
        default='Pending'
    )

    remarks = db.Column(db.Text)

    created_at = db.Column(
        db.DateTime,
        server_default=db.func.now()
    )
    
class LumeCard(db.Model):
    __tablename__ = "lume_cards"

    id = db.Column(db.Integer, primary_key=True)

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("lume_users.id"),
        nullable=False,
        unique=True
    )

    user = db.relationship("LumeUser", backref="card")

    # Card details
    card_number = db.Column(db.String(16), unique=True, index=True)
    expiry_month = db.Column(db.Integer)
    expiry_year = db.Column(db.Integer)
    cvv = db.Column(db.String(3))

    network = db.Column(db.Enum("RUPAY"), default="RUPAY")

    card_type = db.Column(
        db.Enum("VIRTUAL", "PHYSICAL"),
        default="VIRTUAL"
    )

    pin_hash = db.Column(db.String(255))

    # Balance
    balance = db.Column(db.Numeric(12,2), default=0.00)
    ncmc_balance = db.Column(db.Numeric(12,2), default=0.00)
    ncmc_unclaimed_balance = db.Column(db.Numeric(12,2), default=0.00)
    ncmc_last_updated = db.Column(db.DateTime, default=db.func.current_timestamp())

    # Card state
    card_state = db.Column(
        db.Enum("ACTIVE", "BLOCKED", "REPLACED", "EXPIRED"),
        default="ACTIVE"
    )

    card_lock = db.Column(
        db.Enum("LOCKED", "UNLOCKED"),
        default="UNLOCKED"
    )

    is_freezed = db.Column(db.Boolean, default=False)

    # Controls
    pos_enabled = db.Column(db.Boolean, default=False)
    online_enabled = db.Column(db.Boolean, default=False)
    atm_enabled = db.Column(db.Boolean, default=False)
    contactless_enabled = db.Column(db.Boolean, default=False)
    tokenised_enabled = db.Column(db.Boolean, default=False)

    tap_and_pay_enabled = db.Column(db.Boolean, default=False)
    ncmc_enabled = db.Column(db.Boolean, default=False)

    # Limits
    pos_limit = db.Column(db.Integer, default=0)
    online_limit = db.Column(db.Integer, default=0)
    contactless_limit = db.Column(db.Integer, default=0)
    tokenised_limit = db.Column(db.Integer, default=0)
    atm_limit = db.Column(db.Integer, default=0)

    order_status = db.Column(
        db.Enum(
            "NOT_REQUESTED",
            "ORDERED",
            "PRINTING",
            "DISPATCHED",
            "DELIVERED",
            "RECEIVED"
        ),
        default="NOT_REQUESTED"
    )

    delivery_address = db.Column(db.String(255), nullable=True)
    delivery_city = db.Column(db.String(100), nullable=True)
    delivery_state = db.Column(db.String(100), nullable=True)
    delivery_pincode = db.Column(db.String(20), nullable=True)
    delivery_phone = db.Column(db.String(20), nullable=True)

    # Reissue metadata
    reissue_reason = db.Column(db.String(500), nullable=True)
    reissue_payment_success = db.Column(db.Boolean, nullable=True)

    issued_at = db.Column(
        db.DateTime,
        server_default=db.func.now()
    )

# ===================== TRANSACTIONS =========================
class Transaction(db.Model):
    __tablename__ = "transactions"

    id = db.Column(db.Integer, primary_key=True)
    
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("lume_users.id"),
        nullable=False
    )
    user = db.relationship("LumeUser", backref="transactions")

    title = db.Column(db.String(255), nullable=False)
    
    transaction_type = db.Column(
        db.Enum("paid", "received", "topup"), 
        nullable=False
    )
    
    amount = db.Column(db.Numeric(12, 2), nullable=False)
    
    status = db.Column(
        db.Enum("Success", "Expired", "Cancelled", "Pending"),
        default="Success"
    )

    category = db.Column(
        db.Enum("Card", "Transit"),
        default="Card"
    )

    created_at = db.Column(
        db.DateTime,
        server_default=db.func.now(),
        index=True
    )

# ===================== MANDATES =========================
class Mandate(db.Model):
    __tablename__ = "mandates"

    id = db.Column(db.Integer, primary_key=True)
    
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("lume_users.id"),
        nullable=False
    )
    user = db.relationship("LumeUser", backref="mandates")

    mandate_type = db.Column(db.String(50)) # "Frequency" or "Threshold"
    frequency = db.Column(db.String(50), nullable=True) # "Weekly" or "Monthly"
    day_of_week = db.Column(db.String(20), nullable=True)
    date_of_month = db.Column(db.Integer, nullable=True)
    
    amount = db.Column(db.Numeric(12, 2), nullable=True) # Recharge amount
    threshold_amount = db.Column(db.Numeric(12, 2), nullable=True)
    
    status = db.Column(
        db.Enum("Active", "Paused", "Inactive", "Pending"),
        default="Active"
    )

    last_processed_at = db.Column(db.DateTime, nullable=True)

    created_at = db.Column(
        db.DateTime,
        server_default=db.func.now(),
        index=True
    )