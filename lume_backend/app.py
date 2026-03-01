import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from config import Config
from models import db, Student, LumeUser, ScholarApplication
from otp import generate_otp, verify_otp
import bcrypt

app = Flask(__name__)
app.config.from_object(Config)
CORS(app)

db.init_app(app)
jwt = JWTManager(app)

UPLOAD_FOLDER = 'uploads/profile_pics'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# JWT Error Handlers
@jwt.unauthorized_loader
def unauthorized_response(error_string):
    return jsonify({"error": f"Unauthorized: {error_string}"}), 401

@jwt.invalid_token_loader
def invalid_token_response(error_string):
    return jsonify({"error": f"Invalid token: {error_string}"}), 403

@jwt.expired_token_loader
def expired_token_response(jwt_header, jwt_payload):
    return jsonify({"error": "Token has expired"}), 405

# SEND OTP
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


# VERIFY OTP & RETURN PROFILE
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
            "profile_image": user.profile_image if user else None
        }
    })

# SET PIN
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
            "profile_image": user.profile_image if user else None
        })

# LOGIN WITH PIN
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
        "profile_image": user.profile_image if (user and user.profile_image) else None
    })



# GET USER PROFILE
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
        
        # Sync user status with card issued
    if user and student:
        expected_status = "active" if student.card_issued else "inactive"
        if user.status != "blocked" and user.status != expected_status:
            user.status = expected_status
            db.session.commit()

    return jsonify({
        "student": {
            "full_name": (student.full_name if student else "Lume User") or "Lume User",
            "mobile": (student.mobile if student else user.phone) or user.phone,
            "email": (student.email if student else user.email) or user.email,
            "reg_no": (student.reg_no if student else "") or "",
            "department": (student.department if student else ""),
            "institute_name": (student.institute_name if student else ""),
            "dob": str(student.dob) if (student and student.dob) else None,
            "blood_group": (student.blood_group if student else None),
            "profile_image": user.profile_image if (user and user.profile_image) else None,
            "lume_status": user.status if user else "inactive"
        }
    })


@app.route("/auth/test", methods=["GET"])
@jwt_required()
def test_jwt():
    return jsonify({"message": "JWT is working", "identity": get_jwt_identity()})


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

@app.route('/uploads/profile_pics/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

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

# CREATE SCHOLAR APPLICATION
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

# GET SCHOLAR APPLICATION STATUS
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
# RUN SERVER
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)