from app import app, db, Nationality

with app.app_context():
    db.create_all()

    nationalities = [
        "American Indian or Alaska Native",
        "Asian",
        "Black or African American",
        "Native Hawaiian or Other Pacific Islander",
        "White",
        "Hispanic/Latino"
    ]

    for name in nationalities:
        if not Nationality.query.filter_by(name=name).first():
            db.session.add(Nationality(name=name))

    db.session.commit()
    print("Nationalities added successfully.")
