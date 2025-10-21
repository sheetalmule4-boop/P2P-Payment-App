from app import app, db, ExpirationMonth, ExpirationYear
from datetime import datetime

# This script seeds the database with expiration months and years.
with app.app_context():
    db.create_all()

    # Seed months: "01" to "12"
    months = [f"{i:02}" for i in range(1, 13)]
    for m in months:
        if not ExpirationMonth.query.filter_by(value=m).first():
            db.session.add(ExpirationMonth(value=m))

    # Seed years: current year to current year + 10
    current_year = datetime.now().year
    years = [str(y) for y in range(current_year, current_year + 11)]
    for y in years:
        if not ExpirationYear.query.filter_by(value=y).first():
            db.session.add(ExpirationYear(value=y))

    db.session.commit()s
    print("Expiration months and years added successfully.")
