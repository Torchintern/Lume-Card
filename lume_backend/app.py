import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from config import Config
from models import db, Student, LumeUser, ScholarApplication, KYCApplication, KYCSlot
from otp import generate_otp, verify_otp
import bcrypt
from datetime import datetime, timedelta, time
from flask import jsonify

app = Flask(__name__)
app.config.from_object(Config)
CORS(app)

db.init_app(app)
jwt = JWTManager(app)

UPLOAD_FOLDER = 'uploads/profile_pics'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# ================== JWT Error Handlers =======================
@jwt.unauthorized_loader
def unauthorized_response(error_string):
    return jsonify({"error": f"Unauthorized: {error_string}"}), 401

@jwt.invalid_token_loader
def invalid_token_response(error_string):
    return jsonify({"error": f"Invalid token: {error_string}"}), 403

@jwt.expired_token_loader
def expired_token_response(jwt_header, jwt_payload):
    return jsonify({"error": "Token has expired"}), 405

# ==================== SEND OTP ========================
@app.route("/auth/send-otp", methods=["POST"])
def send_otp():
    phone = request.json.get("phone")

    if not phone:
        return jsonify({"error": "Phone number required"}), 400

    student = Student.query.filter_by(mobile=phone).first()

    if not student:
        return jsonify({"error": "Mobile not registered with any institute"}), 404

    if not student.card_issued:
        return jsonify({"error": "Card not issued yet"}), 400

    if student.institute_status != "active":
        return jsonify({"error": "Student inactive or blocked"}), 403

    otp = generate_otp(phone)

    return jsonify({
        "message": "OTP sent successfully",
        "dev_otp": otp 
    })


# ================== VERIFY OTP & RETURN PROFILE ===========================
@app.route("/auth/verify-otp", methods=["POST"])
def verify_otp_route():
    phone = request.json.get("phone")
    otp = request.json.get("otp")

    if not phone or not otp:
        return jsonify({"error": "Phone and OTP required"}), 400

    is_valid, message = verify_otp(phone, otp)

    if not is_valid:
        return jsonify({"error": message}), 400

    student = Student.query.filter_by(mobile=phone).first()

    if not student:
        return jsonify({"error": "Student not found"}), 404
    
    # Match the last 10 digits to be robust against country code variations
    user = LumeUser.query.filter(LumeUser.phone.like(f"%{phone[-10:]}")).first()
    user_exists = user is not None
    
    return jsonify({
        "message": "OTP verified successfully",
        "is_registered": user_exists,
        "student": {
            "full_name": student.full_name,
            "id": student.id,
            "institute_name": student.institute_name,
            "reg_no": student.reg_no,
            "department": student.department,
            "dob": str(student.dob) if student.dob else None,
            "blood_group": student.blood_group,
            "email": student.email,
            "batch_start_year": str(student.batch_start_year) if student.batch_start_year else None,
            "batch_end_year": str(student.batch_end_year) if student.batch_end_year else None,
            "profile_image": user.profile_image if user else None
        }
    })

# ================ SET PIN ====================
@app.route("/auth/set-pin", methods=["POST"])
def set_pin():
    phone = request.json.get("phone")
    pin = request.json.get("pin")

    if not phone or not pin:
        return jsonify({"error": "Phone and PIN required"}), 400

    if not pin.isdigit() or len(pin) != 6:
        return jsonify({"error": "PIN must be exactly 6 digits"}), 400

    student = Student.query.filter_by(mobile=phone).first()

    if not student:
        return jsonify({"error": "Student not found"}), 404

    existing = LumeUser.query.filter_by(phone=phone).first()
    
    # Hash PIN
    hashed_pin = bcrypt.hashpw(pin.encode(), bcrypt.gensalt()).decode()

    if existing:
        # PWD RESET FLOW
        existing.pin_hash = hashed_pin
        existing.status = "active" if student.card_issued else "inactive"
        db.session.commit()
        token = create_access_token(identity=str(existing.id))
        return jsonify({
            "message": "PIN updated successfully",
            "token": token,
            "student_id": student.id,
            "full_name": student.full_name,
            "mobile": student.mobile,
            "email": student.email,
            "reg_no": student.reg_no,
            "department": student.department,
            "institute_name": student.institute_name,
            "dob": str(student.dob) if student.dob else None,
            "blood_group": student.blood_group,
            "batch_start_year": str(student.batch_start_year) if student.batch_start_year else None,
            "batch_end_year": str(student.batch_end_year) if student.batch_end_year else None,
            "profile_image": existing.profile_image if existing else None
        })
    else:
        # REGISTRATION FLOW
        user = LumeUser(
        student_id=student.id,
        reg_no=student.reg_no,
        phone=phone,
        email=student.email,
        pin_hash=hashed_pin,
        status="active" if student.card_issued else "inactive"
    )

        db.session.add(user)
        db.session.commit()

        token = create_access_token(identity=str(user.id))

        return jsonify({
            "message": "Registration successful",
            "token": token,
            "student_id": student.id,
            "full_name": student.full_name,
            "mobile": student.mobile,
            "email": student.email,
            "reg_no": student.reg_no or "",
            "department": student.department,
            "institute_name": student.institute_name,
            "dob": str(student.dob) if student.dob else None,
            "blood_group": student.blood_group,
            "batch_start_year": str(student.batch_start_year) if student.batch_start_year else None,
            "batch_end_year": str(student.batch_end_year) if student.batch_end_year else None,
            "profile_image": user.profile_image if user else None
        })

# ================ LOGIN WITH PIN =====================
@app.route("/auth/login-pin", methods=["POST"])
def login_pin():
    phone = request.json.get("phone")
    pin = request.json.get("pin")

    if not phone or not pin:
        return jsonify({"error": "Phone and PIN required"}), 400

    user = LumeUser.query.filter_by(phone=phone).first()

    if not user:
        return jsonify({"error": "User not registered"}), 404

    if not bcrypt.checkpw(pin.encode(), user.pin_hash.encode()):
        return jsonify({"error": "Invalid PIN"}), 401

    token = create_access_token(identity=str(user.id))
    student = db.session.get(Student, user.student_id)
    
    # Fallback lookup by reg_no if ID fails
    if not student and user.reg_no:
        student = Student.query.filter_by(reg_no=user.reg_no).first()

    return jsonify({
        "message": "Login successful",
        "token": token,
        "student_id": student.id if student else None,
        "full_name": (student.full_name if student else "Lume User") or "Lume User",
        "mobile": (student.mobile if student else "") or "",
        "email": (student.email if student else "") or "",
        "reg_no": (student.reg_no if student else "") or "",
        "department": (student.department if student else ""),
        "institute_name": (student.institute_name if student else ""),
        "dob": str(student.dob) if (student and student.dob) else None,
        "blood_group": (student.blood_group if student else None),
        "batch_start_year": str(student.batch_start_year) if (student and student.batch_start_year) else None,
        "batch_end_year": str(student.batch_end_year) if (student and student.batch_end_year) else None,
        "profile_image": user.profile_image if (user and user.profile_image) else None
    })



# ============ GET USER PROFILE ===================
@app.route("/auth/profile", methods=["GET"])
@jwt_required()
def get_profile():
    user_id = get_jwt_identity()
    user = db.session.get(LumeUser, int(user_id))
    if not user:
        return jsonify({"error": "User not found"}), 404
        
    student = db.session.get(Student, user.student_id) if user else None

    # Fallback lookup by reg_no if ID fails
    if user and not student and user.reg_no:
        student = Student.query.filter_by(reg_no=user.reg_no).first()
        
    # Fetch latest KYC application
    kyc = None
    if student:
        kyc = KYCApplication.query.filter_by(student_id=student.id)\
            .order_by(KYCApplication.created_at.desc())\
            .first()
            
    if kyc:
        user.kyc_status = kyc.kyc_status
    else:
        user.kyc_status = "Completed" if student.card_issued else "Pending"

    db.session.commit()

    return jsonify({
        "student": {
            "id": student.id if student else None,
            "full_name": (student.full_name if student else "Lume User") or "Lume User",
            "mobile": (student.mobile if student else user.phone) or user.phone,
            "email": (student.email if student else user.email) or user.email,
            "reg_no": (student.reg_no if student else "") or "",
            "department": (student.department if student else ""),
            "institute_name": (student.institute_name if student else ""),
            "dob": str(student.dob) if (student and student.dob) else None,
            "blood_group": (student.blood_group if student else None),
            "batch_start_year": str(student.batch_start_year) if (student and student.batch_start_year) else None,
            "batch_end_year": str(student.batch_end_year) if (student and student.batch_end_year) else None,
            "profile_image": user.profile_image if (user and user.profile_image) else None,
            "lume_status": student.institute_status if student else "inactive",
            "kyc_status": user.kyc_status,
            "kyc_remarks": kyc.remarks if kyc else None
        }
    })

# ================= JWT Test ================
@app.route("/auth/test", methods=["GET"])
@jwt_required()
def test_jwt():
    return jsonify({"message": "JWT is working", "identity": get_jwt_identity()})

# ============ Upload Profile ==================
@app.route('/auth/upload-profile-image', methods=['POST'])
@jwt_required()
def upload_profile_image():
    user_id = get_jwt_identity()
    user = db.session.get(LumeUser, int(user_id))
    if not user:
        return jsonify({"error": "User not found"}), 404

    if 'image' not in request.files:
        return jsonify({"error": "No image part"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    if file:
        # Create a unique filename using user ID
        ext = file.filename.rsplit('.', 1)[1].lower()
        filename = secure_filename(f"profile_{user_id}.{ext}")
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(file_path)
        
        user.profile_image = filename
        db.session.commit()
        
        return jsonify({
            "message": "Successfully uploaded", 
            "profile_image": filename,
            "profile_image_url": f"/uploads/profile_pics/{filename}"
        })
    
    return jsonify({"error": "Upload failed"}), 500

# ================ Upload Profile ===========
@app.route('/uploads/profile_pics/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# =================== Remove profile ===============
@app.route('/auth/remove-profile-image', methods=['POST'])
@jwt_required()
def remove_profile_image():
    user_id = get_jwt_identity()
    user = db.session.get(LumeUser, user_id)

    if not user:
        return jsonify({"error": "User not found"}), 404

    if user.profile_image:
        path = os.path.join(app.config['UPLOAD_FOLDER'], user.profile_image)
        if os.path.exists(path):
            os.remove(path)

    user.profile_image = None
    db.session.commit()

    return jsonify({"message": "Profile image removed"})

# ================== CREATE SCHOLAR APPLICATION ===========================
@app.route("/scholar/apply", methods=["POST"])
def create_scholar_application():
    data = request.json
    reg_id = data.get("registered_student_id")

    if not reg_id:
        return jsonify({"success": False}), 400

    # block multiple pending applications
    existing = ScholarApplication.query.filter_by(
        registered_student_id=reg_id,
        status="pending"
    ).first()

    if existing:
        return jsonify({"success": False}), 409

    new_app = ScholarApplication(
        registered_student_id=reg_id,
        full_name=data.get("full_name"),
        email=data.get("email"),
        phone=data.get("phone"),
        loan_amount=data.get("loan_amount"),
        city=data.get("city"),
        country=data.get("country"),
        admission_status=data.get("admission_status"),
        target_intake=data.get("target_intake"),
        status="pending"
    )

    db.session.add(new_app)
    db.session.commit()

    return jsonify({"success": True})

# =================  GET SCHOLAR APPLICATION STATUS =================
@app.route("/scholar/status/<int:reg_id>", methods=["GET"])
def scholar_status(reg_id):

    appn = ScholarApplication.query.filter_by(
        registered_student_id=reg_id
    ).order_by(ScholarApplication.created_at.desc()).first()

    if not appn:
        return jsonify({
            "hasApplication": False,
            "status": None
        })

    return jsonify({
        "hasApplication": True,
        "status": appn.status
    })
    
# =============== Book KYC =====================
@app.route("/kyc/book", methods=["POST"])
def book_kyc():

    data = request.json

    slot = db.session.get(KYCSlot, data["slot_id"])

    if not slot:
        return jsonify({"error": "Slot not found"}), 404

    if slot.booked_count >= slot.max_capacity:
        return jsonify({"error": "Slot full"}), 400

    # Check for existing application
    existing = KYCApplication.query.filter_by(student_id=data["student_id"]).first()

    if existing:
        if existing.kyc_status != "Rejected":
            return jsonify({
                "error": "KYC already booked or completed"
            }), 400
        
        # Update existing rejected application
        existing.full_name = data["full_name"]
        existing.aadhaar_number = data["aadhaar_number"]
        existing.pan_number = data.get("pan_number")
        existing.no_pan = data.get("no_pan")
        existing.slot_id = slot.id
        existing.kyc_status = "Booked"
        existing.remarks = None  # Clear previous rejection remarks
        
    else:
        # Create new application
        new_app = KYCApplication(
            student_id=data["student_id"],
            full_name=data["full_name"],
            aadhaar_number=data["aadhaar_number"],
            pan_number=data.get("pan_number"),
            no_pan=data.get("no_pan"),
            slot_id=slot.id,
            kyc_status="Booked"
        )
        db.session.add(new_app)

    slot.booked_count += 1

    # Update user KYC status
    user = LumeUser.query.filter_by(student_id=data["student_id"]).first()
    if user:
        user.kyc_status = "Booked"

    db.session.commit()

    return jsonify({"success": True})
  
# =======  Get KYC Applications  =============== 
@app.route("/kyc/status/<int:student_id>", methods=["GET"])
def get_kyc_status(student_id):

    appn = KYCApplication.query.filter_by(student_id=student_id)\
        .order_by(KYCApplication.created_at.desc())\
        .first()

    if not appn:
        return jsonify({
            "kyc_status": "Pending",
            "remarks": None
        })

    return jsonify({
        "kyc_status": appn.kyc_status,
        "remarks": appn.remarks
    }) 
    
# ============ Get KYC Slots ===================
@app.route("/kyc/slots", methods=["GET"])
def get_kyc_slots():

    cleanup_expired_slots()

    start_date = datetime.today().date() + timedelta(days=2)

    days_to_show = 14
    start_hour = 10
    end_hour = 15

    slots = []

    for d in range(days_to_show):

        date = start_date + timedelta(days=d)

        # Skip Sunday
        if date.weekday() == 6:
            continue

        # Skip 2nd Saturday
        if date.weekday() == 5 and 8 <= date.day <= 14:
            continue

        for hour in range(start_hour, end_hour):

            slot_time = time(hour, 0)

            slot = KYCSlot.query.filter_by(
                slot_date=date,
                slot_time=slot_time
            ).first()

            if not slot:

                slot = KYCSlot(
                    slot_date=date,
                    slot_time=slot_time,
                    max_capacity=40,
                    booked_count=0
                )

                db.session.add(slot)
                db.session.commit()

            available = slot.max_capacity - slot.booked_count
            status = "green"

            if available == 0:
                status = "full"
            elif available < 6:
                status = "orange"

            slots.append({
                "id": slot.id,
                "date": slot.slot_date.strftime("%Y-%m-%d"),
                "time": slot.slot_time.strftime("%H:%M"),
                "available": available,
                "status": status
            })

    return jsonify(slots)

# Delete Expired slots
def cleanup_expired_slots():

    now = datetime.now()

    expired = KYCSlot.query.filter(
        KYCSlot.slot_date < now.date()
    ).all()

    for slot in expired:
        db.session.delete(slot)

    db.session.commit()
    
# ============ RUN SERVER =======================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)