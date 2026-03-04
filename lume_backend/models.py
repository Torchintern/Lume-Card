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
    phone = db.Column(db.String(15), unique=True)
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