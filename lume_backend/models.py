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
    card_issued = db.Column(db.Boolean, default=False)
    institute_status = db.Column(db.String(20), default="active")


class LumeUser(db.Model):
    __tablename__ = "lume_users"

    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey("students.id"))
    reg_no = db.Column(db.String(30), unique=True)
    phone = db.Column(db.String(15), unique=True)
    email = db.Column(db.String(150))
    pin_hash = db.Column(db.String(255))
    profile_image = db.Column(db.String(255), nullable=True)
    status = db.Column(db.Enum('active','inactive','blocked'), default='inactive')
    
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
    created_at = db.Column(db.DateTime, server_default=db.func.now())