import os

class Config:
    SQLALCHEMY_DATABASE_URI = "mysql+pymysql://root:Harshith%40799@localhost/lume"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = "super-secret-key"
    # Keeping long-lived session for now as it's useful for the student app
    from datetime import timedelta
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=30)